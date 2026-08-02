import Foundation

/// Local-only persistence for the latest limit snapshot per
/// `(ai_tool, limit_key)`. One small JSON file beside the token-metering
/// store, so the main process (which captures) and the dashboard helper
/// (which displays) share state without touching the usage-event schema.
/// Writers replace a tool's whole snapshot set at once, which gives the
/// PRD's age-out semantics for free: limits absent from the newest capture
/// simply stop existing.
final class TokenUsageLimitSnapshotStore: @unchecked Sendable {
    private let fileURL: URL
    private let lock = NSLock()

    init(fileURL: URL = TokenUsageLimitSnapshotStore.defaultFileURL()) {
        self.fileURL = fileURL
    }

    static func defaultFileURL() -> URL {
        TokenUsageStore.defaultEventsURL()
            .deletingLastPathComponent()
            .appendingPathComponent("limit-snapshots.json")
    }

    /// Replaces every snapshot for `tool` with the given set. An empty set
    /// clears the tool. Reads of other tools are unaffected.
    func replaceSnapshots(for tool: TokenUsageAITool, with snapshots: [TokenUsageLimitSnapshot]) {
        lock.withLock {
            var all = loadLocked().filter { $0.aiTool != tool }
            all.append(contentsOf: snapshots.filter { $0.aiTool == tool })
            saveLocked(all)
        }
    }

    func snapshots(for tool: TokenUsageAITool) -> [TokenUsageLimitSnapshot] {
        lock.withLock { loadLocked().filter { $0.aiTool == tool } }
    }

    func allSnapshots() -> [TokenUsageLimitSnapshot] {
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

    private func loadLocked() -> [TokenUsageLimitSnapshot] {
        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }
        // A corrupt file must never break metering; limits are additive and
        // fail silent, so unreadable state just renders no gauges.
        return (try? JSONDecoder.tokenUsageLimit.decode([TokenUsageLimitSnapshot].self, from: data)) ?? []
    }

    private func saveLocked(_ snapshots: [TokenUsageLimitSnapshot]) {
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
