import Foundation
import SQLite3

/// Estimated remaining-allowance gauges for tools that do not persist their
/// server percentages locally (Claude, Antigravity windows), plus the
/// Antigravity credits balance the client caches.
///
/// Consumption numerators are exact — Spill's own imported per-turn events,
/// hour-bucketed and summed over rolling five-hour and weekly windows. Only
/// the denominator is estimated: the highest window consumption ever observed
/// for that tool, so the gauge reads "how close am I to my own worst burn".
/// Every produced snapshot is tagged `estimated`, which the UI renders with
/// the mandated `~` prefix; the AGY credits reading is tagged `client_cache`.
final class TokenUsageEstimatedLimitCapture: @unchecked Sendable {
    private struct Window {
        let key: String
        let label: String
        let seconds: TimeInterval
        let minutes: Int
    }

    private static let windows: [Window] = [
        Window(key: "session_5h", label: "5-hour", seconds: 5 * 3_600, minutes: 300),
        Window(key: "week_all", label: "Weekly", seconds: 7 * 24 * 3_600, minutes: 10_080),
    ]

    private let usageStore: TokenUsageStore
    private let antigravityStateURL: URL?
    private let now: () -> Date
    private let lock = NSLock()
    private var cachedHourlyByTool: [TokenUsageAITool: [(hourStart: Date, totalTokens: Int)]] = [:]
    private var cachedRevision: UInt64?

    init(
        usageStore: TokenUsageStore,
        antigravityStateURL: URL? = TokenUsageEstimatedLimitCapture.defaultAntigravityStateURL(),
        now: @escaping () -> Date = Date.init
    ) {
        self.usageStore = usageStore
        self.antigravityStateURL = antigravityStateURL
        self.now = now
    }

    static func defaultAntigravityStateURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Antigravity/User/globalStorage/state.vscdb")
    }

    func captureEstimates(into store: TokenUsageLimitSnapshotStore) {
        for tool in [TokenUsageAITool.claude, .antigravity] {
            var snapshots = estimatedWindowSnapshots(for: tool)
            if tool == .antigravity, let credits = antigravityCreditsSnapshot() {
                snapshots.append(credits)
            }
            store.replaceSnapshots(for: tool, with: snapshots)
        }
    }
}

extension TokenUsageEstimatedLimitCapture {
    /// Rolling-window gauges from the tool's own hour-bucketed history. The
    /// full-history aggregation is cached against the store's data revision,
    /// so a paced pass with no new events recomputes only the cheap window
    /// sums over the cached buckets.
    private func estimatedWindowSnapshots(for tool: TokenUsageAITool) -> [TokenUsageLimitSnapshot] {
        let hourly = hourlyTotals(for: tool)
        guard !hourly.isEmpty else {
            return []
        }

        let capturedAt = now()
        return Self.windows.compactMap { window in
            let highWater = Self.maximumWindowTotal(hourly: hourly, windowSeconds: window.seconds)
            guard highWater > 0 else {
                return nil
            }
            let current = Self.windowTotal(hourly: hourly, windowSeconds: window.seconds, endingAt: capturedAt)
            let usedPercent = min(100, Double(current) / Double(highWater) * 100)
            return TokenUsageLimitSnapshot(
                aiTool: tool,
                limitKey: window.key,
                label: window.label,
                usedPercent: usedPercent,
                remainingCredits: nil,
                windowMinutes: window.minutes,
                resetsAt: nil,
                capturedAt: capturedAt,
                source: .estimated
            )
        }
    }

    private func hourlyTotals(for tool: TokenUsageAITool) -> [(hourStart: Date, totalTokens: Int)] {
        let revision = usageStore.aggregateCacheLock.withLock { usageStore.dataRevisionStorage }
        if let cached = lock.withLock(
            { cachedRevision == revision ? cachedHourlyByTool[tool] : nil }
        ) {
            return cached
        }

        let hourly = usageStore.hourlyTotalTokens(for: tool)
        lock.withLock {
            if cachedRevision != revision {
                cachedHourlyByTool.removeAll()
                cachedRevision = revision
            }
            cachedHourlyByTool[tool] = hourly
        }
        return hourly
    }

    /// Sum of buckets whose hour start falls inside the window ending now.
    /// Hour granularity is acceptable for an explicitly estimated gauge.
    static func windowTotal(
        hourly: [(hourStart: Date, totalTokens: Int)],
        windowSeconds: TimeInterval,
        endingAt end: Date
    ) -> Int {
        let start = end.addingTimeInterval(-windowSeconds)
        return hourly
            .filter { $0.hourStart > start && $0.hourStart <= end }
            .reduce(0) { $0 + $1.totalTokens }
    }

    /// Highest consumption of any sliding window across history — the
    /// observed high-water mark used as the estimation denominator. Two
    /// pointers over the sorted sparse buckets.
    static func maximumWindowTotal(
        hourly: [(hourStart: Date, totalTokens: Int)],
        windowSeconds: TimeInterval
    ) -> Int {
        var maximum = 0
        var runningTotal = 0
        var lowerIndex = 0
        for upperIndex in hourly.indices {
            runningTotal += hourly[upperIndex].totalTokens
            let windowStart = hourly[upperIndex].hourStart.addingTimeInterval(-windowSeconds)
            while hourly[lowerIndex].hourStart <= windowStart {
                runningTotal -= hourly[lowerIndex].totalTokens
                lowerIndex += 1
            }
            maximum = max(maximum, runningTotal)
        }
        return maximum
    }
}

extension TokenUsageEstimatedLimitCapture {
    /// Reads the credits balance Antigravity's client caches in its state
    /// database. Read-only, numeric varints only; any unexpected shape
    /// captures nothing. The value is what the client last synced, so it is
    /// tagged `client_cache` rather than server-exact.
    func antigravityCreditsSnapshot() -> TokenUsageLimitSnapshot? {
        guard let antigravityStateURL,
              FileManager.default.fileExists(atPath: antigravityStateURL.path),
              let credits = Self.readAvailableCredits(stateDatabaseURL: antigravityStateURL)
        else {
            return nil
        }
        return TokenUsageLimitSnapshot(
            aiTool: .antigravity,
            limitKey: "credits",
            label: "Credits",
            usedPercent: nil,
            remainingCredits: credits,
            windowMinutes: nil,
            resetsAt: nil,
            capturedAt: now(),
            source: .clientCache
        )
    }

    static func readAvailableCredits(stateDatabaseURL: URL) -> Int? {
        var database: OpaquePointer?
        let uri = "file:\(stateDatabaseURL.path)?mode=ro"
        guard sqlite3_open_v2(uri, &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK,
              let database
        else {
            sqlite3_close(database)
            return nil
        }
        defer { sqlite3_close(database) }

        let sql = "SELECT value FROM ItemTable WHERE key = 'antigravityUnifiedStateSync.modelCredits'"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return nil
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW,
              let valueText = sqlite3_column_text(statement, 0)
        else {
            return nil
        }
        return parseAvailableCredits(base64Payload: String(cString: valueText))
    }

    /// The payload is base64 protobuf: entries of `key-string, value-bytes`,
    /// where the available-credits entry's value is itself a small base64
    /// protobuf whose field is a varint. Only that varint is extracted.
    static func parseAvailableCredits(base64Payload: String) -> Int? {
        guard let outer = Data(base64Encoded: base64Payload),
              let keyRange = outer.range(of: Data("availableCreditsSentinelKey".utf8))
        else {
            return nil
        }

        // Scan a bounded region after the key for an inner base64 run.
        let tail = outer[keyRange.upperBound ..< min(outer.endIndex, keyRange.upperBound + 64)]
        let base64Characters = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8)
        let padding = UInt8(ascii: "=")
        var run: [UInt8] = []
        var best: [UInt8] = []
        func closeRun() {
            if run.count > best.count { best = run }
            run = []
        }
        for byte in tail {
            if byte == padding {
                // Padding ends a base64 token; anything after it is framing.
                run.append(byte)
                if run.count % 4 == 0 {
                    closeRun()
                }
            } else if base64Characters.contains(byte) {
                run.append(byte)
            } else {
                closeRun()
            }
        }
        closeRun()
        guard best.count >= 4,
              let inner = Data(base64Encoded: String(decoding: best, as: UTF8.self))
        else {
            return nil
        }

        // Inner payload: protobuf tag byte then a varint value.
        var index = inner.startIndex
        guard index < inner.endIndex else { return nil }
        index = inner.index(after: index)
        var value = 0
        var shift = 0
        while index < inner.endIndex, shift <= 42 {
            let byte = inner[index]
            value |= Int(byte & 0x7F) << shift
            if byte & 0x80 == 0 {
                return value
            }
            shift += 7
            index = inner.index(after: index)
        }
        return nil
    }
}
