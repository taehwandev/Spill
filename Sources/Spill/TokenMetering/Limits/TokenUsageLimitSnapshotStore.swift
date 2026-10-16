import Foundation

/// Local-only persistence for the latest limit snapshot per
/// `(ai_tool, limit_key)`. One small JSON file beside the token-metering
/// store, so the main process (which captures) and the dashboard helper
/// (which displays) share state without touching the usage-event schema.
///
/// Partial writers merge one limit at a time rather than replacing a tool's
/// whole set. A writer that receives an explicitly complete group can replace
/// only that bounded key prefix, retiring missing siblings without disturbing
/// independent groups from the same tool.
final class TokenUsageLimitSnapshotStore: @unchecked Sendable {
    struct CompleteGroup {
        let keyPrefix: String
        let capturedAt: Date
        let snapshots: [TokenUsageLimitSnapshot]
    }

    private let fileURL: URL
    private let dailyUsageFileURL: URL
    private let postsChangeNotifications: Bool
    private let lock = NSLock()
    private let now: () -> Date
    private let timeZone: TimeZone

    init(
        fileURL: URL = TokenUsageLimitSnapshotStore.defaultFileURL(),
        dailyUsageFileURL: URL? = nil,
        postsChangeNotifications: Bool? = nil,
        timeZone: TimeZone = .autoupdatingCurrent,
        now: @escaping () -> Date = Date.init
    ) {
        self.fileURL = fileURL
        self.dailyUsageFileURL = dailyUsageFileURL ?? fileURL.deletingLastPathComponent()
            .appendingPathComponent("limit-daily-usage.json")
        self.postsChangeNotifications = postsChangeNotifications
            ?? (fileURL.standardizedFileURL == Self.defaultFileURL().standardizedFileURL)
        self.timeZone = timeZone
        self.now = now
    }

    static func defaultFileURL() -> URL {
        TokenUsageStore.defaultEventsURL()
            .deletingLastPathComponent()
            .appendingPathComponent("limit-snapshots.json")
    }

    /// Upserts each incoming snapshot by `limitKey` and prunes whatever has
    /// aged out. Limits the pass did not see keep their stored reading.
    func mergeSnapshots(for tool: TokenUsageAITool, with snapshots: [TokenUsageLimitSnapshot]) {
        let incoming = snapshots.filter { $0.aiTool == tool }
        guard !incoming.isEmpty else {
            return
        }
        let moment = now()
        let didChange = lock.withLock { () -> Bool in
            let original = loadLocked()
            var kept = original.filter { !Self.hasAgedOut($0, at: moment) }
            var dailyUsage = loadDailyUsageLocked()
            for snapshot in incoming {
                if let index = kept.firstIndex(where: {
                    $0.aiTool == tool && $0.limitKey == snapshot.limitKey
                }) {
                    guard snapshot.capturedAt >= kept[index].capturedAt else { continue }
                    if snapshot.capturedAt > kept[index].capturedAt {
                        record(snapshot, after: kept[index], in: &dailyUsage)
                    }
                    kept[index] = snapshot
                } else {
                    record(snapshot, after: nil, in: &dailyUsage)
                    kept.append(snapshot)
                }
            }
            saveDailyUsageLocked(dailyUsage)
            saveLocked(kept)
            return kept != original
        }
        if didChange {
            postLimitsDidChangeNotificationIfNeeded()
        }
    }

    /// Reconciles complete, independently timestamped groups in one locked
    /// load/save pass. The group values live only for this capture call; no
    /// extra cache or persisted scope field is introduced.
    func replaceCompleteGroups(
        for tool: TokenUsageAITool,
        with groups: [CompleteGroup]
    ) {
        guard !groups.isEmpty else {
            return
        }
        let moment = now()
        let didChange = lock.withLock { () -> Bool in
            let original = loadLocked()
            var kept = original.filter { !Self.hasAgedOut($0, at: moment) }
            var dailyUsage = loadDailyUsageLocked()
            for group in groups {
                let newestStored = kept
                    .filter { $0.aiTool == tool && $0.limitKey.hasPrefix(group.keyPrefix) }
                    .map(\.capturedAt)
                    .max()
                if let newestStored, newestStored > group.capturedAt {
                    continue
                }

                let previous = kept.filter {
                    $0.aiTool == tool && $0.limitKey.hasPrefix(group.keyPrefix)
                }
                kept.removeAll {
                    $0.aiTool == tool && $0.limitKey.hasPrefix(group.keyPrefix)
                }
                let accepted = group.snapshots.filter {
                    $0.aiTool == tool && $0.limitKey.hasPrefix(group.keyPrefix)
                }
                for snapshot in accepted {
                    record(snapshot, after: previous.first { $0.limitKey == snapshot.limitKey }, in: &dailyUsage)
                }
                kept.append(contentsOf: accepted)
            }
            saveDailyUsageLocked(dailyUsage)
            saveLocked(kept)
            return kept != original
        }
        if didChange {
            postLimitsDidChangeNotificationIfNeeded()
        }
    }

    func allDailyUsage() -> [TokenUsageDailyLimitUsage] {
        lock.withLock { loadDailyUsageLocked() }
    }

    func dailyUsage(for bucketKey: String) -> [TokenUsageDailyLimitUsage] {
        allDailyUsage().filter { $0.bucketKey == bucketKey }
    }

    /// Display-ready snapshots: aged-out limits removed and closed windows
    /// resolved to their post-reset value.
    func snapshots(for tool: TokenUsageAITool) -> [TokenUsageLimitSnapshot] {
        allSnapshots().filter { $0.aiTool == tool }
    }

    func allSnapshots() -> [TokenUsageLimitSnapshot] {
        let moment = now()
        return storedSnapshots()
            // Estimated gauges are no longer produced. Filtering them on read
            // retires the ones already written to disk without a migration,
            // and keeps a downgraded reading from reappearing.
            .filter { $0.source != .estimated }
            .filter { !Self.hasAgedOut($0, at: moment) }
            .map { $0.resolved(at: moment) }
    }

    /// The raw file contents, before age-out and window resolution.
    func storedSnapshots() -> [TokenUsageLimitSnapshot] {
        lock.withLock { loadLocked() }
    }

    /// The lowest-remaining percentage gauge for a tool — what the compact
    /// surfaces show when they only have room for one reading.
    static func mostConstrained(
        in snapshots: [TokenUsageLimitSnapshot]
    ) -> TokenUsageLimitSnapshot? {
        snapshots
            .filter { $0.remainingPercent != nil }
            .min { ($0.remainingPercent ?? 100) < ($1.remainingPercent ?? 100) }
    }
}

extension TokenUsageLimitSnapshotStore {
    /// A limit with no reading for this long no longer describes the account —
    /// a plan change or a renamed limit, not a quiet week. Retention is two
    /// windows so a busy limit ages out promptly, floored at a week so an
    /// unused five-hour gauge (which resolves to "reset", not to nothing)
    /// survives an ordinary break from the tool.
    static let minimumRetention: TimeInterval = 7 * 24 * 3_600

    static func retention(for snapshot: TokenUsageLimitSnapshot) -> TimeInterval {
        guard let window = snapshot.windowDuration, window > 0 else {
            return minimumRetention
        }
        return max(window * 2, minimumRetention)
    }

    static func hasAgedOut(_ snapshot: TokenUsageLimitSnapshot, at now: Date) -> Bool {
        snapshot.age(at: now) > retention(for: snapshot)
    }

}

private extension TokenUsageLimitSnapshotStore {
    func record(
        _ snapshot: TokenUsageLimitSnapshot,
        after previous: TokenUsageLimitSnapshot?,
        in dailyUsage: inout [TokenUsageDailyLimitUsage]
    ) {
        guard snapshot.source != .estimated,
              let used = snapshot.usedPercent,
              used.isFinite, (0...100).contains(used)
        else { return }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let day = calendar.dateComponents([.year, .month, .day], from: snapshot.capturedAt)
        guard let year = day.year, let month = day.month, let date = day.day else { return }
        let bucketKey = String(format: "%04d-%02d-%02d", year, month, date)
        let previousUsed = previous?.usedPercent
        let previousReset = previous?.resetsAt.map { $0 <= snapshot.capturedAt } ?? false
        let baseline = previousReset ? 0 : (previousUsed ?? used)
        let increment: Double
        if let previousUsed {
            increment = previousReset || used < previousUsed
                ? used
                : max(0, used - previousUsed)
        } else {
            increment = 0
        }
        let updatedAt = ISO8601DateFormatter.tokenUsage.string(from: snapshot.capturedAt)

        if let index = dailyUsage.firstIndex(where: {
            $0.bucketKey == bucketKey && $0.aiTool == snapshot.aiTool && $0.limitKey == snapshot.limitKey
        }) {
            guard dailyUsage[index].updatedAt < updatedAt else { return }
            dailyUsage[index].label = snapshot.label
            dailyUsage[index].endPercent = used
            dailyUsage[index].peakPercent = max(dailyUsage[index].peakPercent, used)
            dailyUsage[index].consumedDeltaPercent += increment
            dailyUsage[index].updatedAt = updatedAt
        } else {
            dailyUsage.append(TokenUsageDailyLimitUsage(
                bucketKey: bucketKey,
                aiTool: snapshot.aiTool,
                limitKey: snapshot.limitKey,
                label: snapshot.label,
                startPercent: baseline,
                endPercent: used,
                peakPercent: used,
                consumedDeltaPercent: increment,
                updatedAt: updatedAt
            ))
        }
    }

    func loadDailyUsageLocked() -> [TokenUsageDailyLimitUsage] {
        guard let data = try? Data(contentsOf: dailyUsageFileURL) else { return [] }
        return (try? JSONDecoder().decode([TokenUsageDailyLimitUsage].self, from: data)) ?? []
    }

    func saveDailyUsageLocked(_ usage: [TokenUsageDailyLimitUsage]) {
        guard let data = try? JSONEncoder.tokenUsageLimit.encode(usage.sorted(by: {
            ($0.bucketKey, $0.aiTool.rawValue, $0.limitKey) <
                ($1.bucketKey, $1.aiTool.rawValue, $1.limitKey)
        })) else { return }
        let directory = dailyUsageFileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let temporaryURL = directory.appendingPathComponent(".limit-daily-usage-\(UUID().uuidString).tmp")
        do {
            try data.write(to: temporaryURL)
            if FileManager.default.fileExists(atPath: dailyUsageFileURL.path) {
                _ = try FileManager.default.replaceItemAt(dailyUsageFileURL, withItemAt: temporaryURL)
            } else {
                try FileManager.default.moveItem(at: temporaryURL, to: dailyUsageFileURL)
            }
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
        }
    }
}

private extension TokenUsageLimitSnapshotStore {
    func loadLocked() -> [TokenUsageLimitSnapshot] {
        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }
        // A corrupt file must never break metering; limits are additive and
        // fail silent, so unreadable state just renders no gauges.
        return (try? JSONDecoder.tokenUsageLimit.decode([TokenUsageLimitSnapshot].self, from: data)) ?? []
    }

    func saveLocked(_ snapshots: [TokenUsageLimitSnapshot]) {
        guard let data = try? JSONEncoder.tokenUsageLimit.encode(snapshots) else {
            return
        }
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let temporaryURL = directory.appendingPathComponent(".limit-snapshots-\(UUID().uuidString).tmp")
        do {
            try data.write(to: temporaryURL)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporaryURL)
            } else {
                try FileManager.default.moveItem(at: temporaryURL, to: fileURL)
            }
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
        }
    }

    func postLimitsDidChangeNotificationIfNeeded() {
        guard postsChangeNotifications else {
            return
        }
        NotificationCenter.default.post(
            name: TokenUsageLimitInboxMonitor.limitsDidChangeNotification,
            object: nil
        )
        DistributedNotificationCenter.default().postNotificationName(
            TokenUsageLimitInboxMonitor.limitsDidChangeNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }
}

private extension JSONDecoder {
    static let tokenUsageLimit: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

private extension JSONEncoder {
    static let tokenUsageLimit: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
}
