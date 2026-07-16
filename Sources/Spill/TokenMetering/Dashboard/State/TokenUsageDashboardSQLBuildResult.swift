import Foundation

/// Bundles the snapshot pair with the surrounding aggregates a refresh publishes alongside it --
/// availableDateBounds, the period-filter chips, and the panel summary -- when they were all read
/// on one shared connection/transaction inside buildSnapshotOutputFromSQL. Keeping them together
/// is what lets the SQL path apply every field from a single DB commit point instead of stitching
/// in values read from three separate later connections (cross-field flicker). The events-based
/// path keeps using TokenUsageDashboardSnapshotBuildOutput directly, so that type is unchanged.
struct TokenUsageDashboardSQLBuildResult {
    let output: TokenUsageDashboardSnapshotBuildOutput
    let dateBounds: TokenUsageDashboardDateBounds
    let periodFilterTotals: [TokenUsageDashboardPeriod: TokenUsageInputScopeTotals]
    let panelSummary: TokenUsagePanelSummarySnapshot?
}
