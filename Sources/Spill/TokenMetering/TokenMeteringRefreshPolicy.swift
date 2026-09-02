import Foundation

enum TokenMeteringRefreshPolicy {
    /// Periodic recovery is intentionally slow. User actions, inbox events,
    /// and store-change notifications remain the primary freshness paths.
    static let periodicFallbackInterval: TimeInterval = 30 * 60
    static let periodicFallbackIntervalNanoseconds = UInt64(
        periodicFallbackInterval * 1_000_000_000
    )

    /// Prevent independent periodic callers from repeatedly running the same
    /// active importers while still allowing every user-forced request through.
    static let activeImporterMinimumInterval: TimeInterval = 20 * 60
}
