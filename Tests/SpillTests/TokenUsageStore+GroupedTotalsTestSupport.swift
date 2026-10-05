import Foundation
@testable import Spill

/// Reads per-dimension totals through the production grouped scan, so tests can assert one
/// dimension at a time without the app carrying a wrapper per statement it no longer runs.
extension TokenUsageStore {
    func groupedAggregate(
        dashboardToolsOnly: Bool = true,
        visibleTools: Set<TokenUsageAITool>? = nil
    ) -> DashboardGroupedAggregate {
        withDatabaseConnection(nil, default: DashboardGroupedAggregate(rows: [])) { database in
            loadDashboardGroupedAggregate(
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database
            )
        }
    }

    func dashboardFocusedTotals(dashboardToolsOnly: Bool = true) -> DashboardFocusedTotals {
        groupedAggregate(dashboardToolsOnly: dashboardToolsOnly).focusedTotals()
    }

    func inputAccountingTotals(dashboardToolsOnly: Bool = true) -> [String: Int] {
        var totals = [
            "uncached_input": 0, "cache_creation_input": 0, "cache_read_input": 0, "unclassified_input": 0
        ]
        for categories in groupedAggregate(dashboardToolsOnly: dashboardToolsOnly).inputAccountingByTool().values {
            totals.merge(categories, uniquingKeysWith: +)
        }
        return totals
    }

    func groupedProjectTotals(
        dashboardToolsOnly: Bool = true
    ) -> [String: (eventCount: Int, totals: TokenUsageInputScopeTotals)] {
        groupedAggregate(dashboardToolsOnly: dashboardToolsOnly).projectTotals()
    }

    func groupedInputScopeTotalsByTool() -> [TokenUsageAITool: TokenUsageInputScopeTotals] {
        groupedAggregate().toolTotals()
    }

    func groupedTaskTypeInputScopeTotals() -> [String: TokenUsageInputScopeTotals] {
        groupedAggregate().totalsByTool(key: \.taskType).mapValues(Self.sum)
    }

    func groupedStageInputScopeTotals() -> [String: TokenUsageInputScopeTotals] {
        groupedAggregate().totalsByTool(key: \.stage).mapValues(Self.sum)
    }

    func groupedModelInputScopeTotals() -> [String: TokenUsageInputScopeTotals] {
        groupedAggregate().modelTotals()
    }

    func groupedTaskTypeTotals() -> [String: Int] {
        groupedTaskTypeInputScopeTotals().mapValues(\.includeCache)
    }

    func groupedStageTotals() -> [String: Int] {
        groupedStageInputScopeTotals().mapValues(\.includeCache)
    }

    func groupedModelTotals() -> [String: Int] {
        groupedModelInputScopeTotals().mapValues(\.includeCache)
    }

    func allPeriodTotalTokens(
        now: Date,
        calendar: Calendar,
        dashboardToolsOnly: Bool = true,
        visibleTools: Set<TokenUsageAITool>? = nil
    ) -> [TokenUsageDashboardPeriod: Int] {
        allPeriodInputScopeTotals(
            now: now,
            calendar: calendar,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools
        )
        .mapValues(\.includeCache)
    }

    private static func sum(
        _ byTool: [TokenUsageAITool: TokenUsageInputScopeTotals]
    ) -> TokenUsageInputScopeTotals {
        byTool.values.reduce(.zero) {
            TokenUsageInputScopeTotals(
                includeCache: $0.includeCache + $1.includeCache,
                freshOnly: $0.freshOnly + $1.freshOnly
            )
        }
    }
}
