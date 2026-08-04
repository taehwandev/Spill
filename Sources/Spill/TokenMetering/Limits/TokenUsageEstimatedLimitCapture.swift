import Foundation

/// Estimated remaining-allowance gauges for tools that do not persist their
/// server percentages locally (Antigravity windows; Claude only when its
/// client cache has no fresh exact reading).
///
/// The Antigravity "credits" value that lives in its state database is a
/// sentinel (`availableCreditsSentinelKey`), not a user-facing balance — the
/// user's Antigravity UI has no credits concept — so no credits gauge is
/// produced from it.
///
/// Consumption numerators are exact — Spill's own imported per-turn events,
/// hour-bucketed. The five-hour gauge uses chained fixed windows (a window
/// opens at the first usage after the previous one expires, matching the
/// tools' session semantics), which also yields a trustworthy reset stamp
/// because any usage gap longer than the window re-anchors the chain. The
/// weekly gauge deliberately stays a rolling window with no reset stamp:
/// week-long gaps never happen, so a chained weekly anchor would just replay
/// whenever local collection began and show a confidently wrong date. Only
/// the denominator is estimated: the highest window consumption ever observed
/// for that tool, so the gauge reads "how close am I to my own worst burn".
/// Every produced snapshot is tagged `estimated`, which the UI renders with
/// the mandated `~` prefix.
final class TokenUsageEstimatedLimitCapture: @unchecked Sendable {
    private struct Window {
        let key: String
        let label: String
        let seconds: TimeInterval
        let minutes: Int
        let usesChainedFixedWindows: Bool
    }

    private static let windows: [Window] = [
        Window(key: "session_5h", label: "5-hour", seconds: 5 * 3_600, minutes: 300, usesChainedFixedWindows: true),
        Window(key: "week_all", label: "Weekly", seconds: 7 * 24 * 3_600, minutes: 10_080, usesChainedFixedWindows: false),
    ]

    private let usageStore: TokenUsageStore
    private let now: () -> Date
    private let lock = NSLock()
    private var cachedHourlyByTool: [TokenUsageAITool: [(hourStart: Date, totalTokens: Int)]] = [:]
    private var cachedRevision: UInt64?

    init(
        usageStore: TokenUsageStore,
        now: @escaping () -> Date = Date.init
    ) {
        self.usageStore = usageStore
        self.now = now
    }

    /// Tools in `skipping` already received exact snapshots this pass, so
    /// their estimates must not overwrite them.
    func captureEstimates(
        into store: TokenUsageLimitSnapshotStore,
        skipping: Set<TokenUsageAITool> = []
    ) {
        for tool in [TokenUsageAITool.claude, .antigravity] where !skipping.contains(tool) {
            store.replaceSnapshots(for: tool, with: estimatedWindowSnapshots(for: tool))
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
            // Five-hour gauges chain fixed windows (a window opens at the
            // first usage after the previous one expires) so the reset stamp
            // matches the tools' real session semantics; an expired window
            // reads empty with no reset. Weekly gauges stay rolling with no
            // reset stamp — a chained weekly anchor is unknowable locally.
            let current: Int
            let resetsAt: Date?
            if window.usesChainedFixedWindows {
                let windowStart = Self.activeWindowStart(
                    hourly: hourly,
                    windowSeconds: window.seconds,
                    endingAt: capturedAt
                )
                current = windowStart.map {
                    Self.windowTotal(hourly: hourly, startingAt: $0, endingAt: capturedAt)
                } ?? 0
                resetsAt = windowStart?.addingTimeInterval(window.seconds)
            } else {
                current = Self.windowTotal(
                    hourly: hourly,
                    startingAt: capturedAt.addingTimeInterval(-window.seconds),
                    endingAt: capturedAt
                )
                resetsAt = nil
            }
            let usedPercent = min(100, Double(current) / Double(highWater) * 100)
            return TokenUsageLimitSnapshot(
                aiTool: tool,
                limitKey: window.key,
                label: window.label,
                usedPercent: usedPercent,
                remainingCredits: nil,
                windowMinutes: window.minutes,
                resetsAt: resetsAt,
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

    /// Start of the fixed window covering `end`, chained from history: the
    /// first bucket opens a window, and each later window opens at the first
    /// bucket at or after the previous window's expiry. Returns nil when no
    /// window is active (the next usage would open a fresh one). Hour-bucket
    /// granularity shifts the start by up to an hour, acceptable for an
    /// explicitly estimated gauge.
    static func activeWindowStart(
        hourly: [(hourStart: Date, totalTokens: Int)],
        windowSeconds: TimeInterval,
        endingAt end: Date
    ) -> Date? {
        guard var windowStart = hourly.first?.hourStart, windowStart <= end else {
            return nil
        }
        var index = hourly.startIndex
        while true {
            let expiry = windowStart.addingTimeInterval(windowSeconds)
            if end < expiry {
                return windowStart
            }
            while index < hourly.endIndex, hourly[index].hourStart < expiry {
                index += 1
            }
            guard index < hourly.endIndex, hourly[index].hourStart <= end else {
                return nil
            }
            windowStart = hourly[index].hourStart
        }
    }

    /// Sum of buckets whose hour start falls inside the given fixed window.
    static func windowTotal(
        hourly: [(hourStart: Date, totalTokens: Int)],
        startingAt start: Date,
        endingAt end: Date
    ) -> Int {
        hourly
            .filter { $0.hourStart >= start && $0.hourStart <= end }
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
