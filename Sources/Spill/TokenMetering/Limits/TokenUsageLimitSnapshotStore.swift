import Foundation

/// Local-only persistence for the latest limit snapshot per
/// `(ai_tool, limit_key)`. One small JSON file beside the token-metering
/// store, so the main process (which captures) and the dashboard helper
/// (which displays) share state without touching the usage-event schema.
///
/// Writers merge one limit at a time rather than replacing a tool's whole
/// set. A single capture pass only sees the limits the tool happened to write
/// down — a plan with no five-hour window, a session file whose newest
/// `rate_limits` line carries `primary` alone, a client cache that answered
/// with the weekly window only — and whole-set replacement turned each of
/// those into "the other gauge is gone", which is what made the chips flicker
/// between weekly-only and five-hour-only. Limits that genuinely disappear
/// still age out, but on their own retention clock instead of on the next
/// partial capture.
final class TokenUsageLimitSnapshotStore: @unchecked Sendable {
    private let fileURL: URL
    private let lock = NSLock()
    private let now: () -> Date

    init(
        fileURL: URL = TokenUsageLimitSnapshotStore.defaultFileURL(),
        now: @escaping () -> Date = Date.init
    ) {
        self.fileURL = fileURL
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
        lock.withLock {
            var kept = loadLocked().filter { !Self.hasAgedOut($0, at: moment) }
            for snapshot in incoming {
                if let index = kept.firstIndex(where: {
                    $0.aiTool == tool && $0.limitKey == snapshot.limitKey
                }) {
                    guard Self.prefersIncoming(snapshot, over: kept[index], at: moment) else {
                        continue
                    }
                    kept[index] = snapshot
                } else {
                    kept.append(snapshot)
                }
            }
            saveLocked(kept)
        }
    }

    /// Replaces every snapshot for `tool` with the given set. An empty set
    /// clears the tool. Reads of other tools are unaffected. Captures use
    /// `mergeSnapshots` instead; this stays for deliberate resets.
    func replaceSnapshots(for tool: TokenUsageAITool, with snapshots: [TokenUsageLimitSnapshot]) {
        lock.withLock {
            var all = loadLocked().filter { $0.aiTool != tool }
            all.append(contentsOf: snapshots.filter { $0.aiTool == tool })
            saveLocked(all)
        }
    }

    /// Display-ready snapshots: aged-out limits removed and closed windows
    /// resolved to their post-reset value.
    func snapshots(for tool: TokenUsageAITool) -> [TokenUsageLimitSnapshot] {
        allSnapshots().filter { $0.aiTool == tool }
    }

    func allSnapshots() -> [TokenUsageLimitSnapshot] {
        let moment = now()
        return storedSnapshots()
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

    /// Exact readings outrank estimates, and a fresh exact reading is not
    /// downgraded to a guess merely because the tool's cache went missing for
    /// one pass. Once the exact reading is older than its own window it can no
    /// longer describe the current window, so the estimate takes over.
    static func prefersIncoming(
        _ incoming: TokenUsageLimitSnapshot,
        over stored: TokenUsageLimitSnapshot,
        at now: Date
    ) -> Bool {
        if incoming.source != .estimated || stored.source == .estimated {
            return true
        }
        return stored.age(at: now) > (stored.windowDuration ?? minimumRetention)
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
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporaryURL)
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
        }
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
