import Foundation
import SQLite3

/// Per-tool totals plus the row count of the same scope: what the tool chips need when the
/// selected tool narrows the main scan below the scope the chips describe.
struct DashboardToolScope: Equatable {
    let eventCount: Int
    let totals: [TokenUsageAITool: TokenUsageInputScopeTotals]
}

extension TokenUsageStore {
    func loadDashboardToolScope(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> DashboardToolScope {
        let sql = """
        SELECT ai_tool, COUNT(*),
               COALESCE(SUM(total_tokens), 0),
               COALESCE(SUM(\(Self.dashboardFreshTokenSQL)), 0)
        FROM token_usage_events
        \(Self.dashboardWhereClause(startingAt: startDate, endingBefore: endDate, dashboardToolsOnly: dashboardToolsOnly, visibleTools: visibleTools))
        GROUP BY ai_tool
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            failureObserver?.markFailure()
            return DashboardToolScope(eventCount: 0, totals: [:])
        }
        defer { sqlite3_finalize(statement) }
        Self.bindDashboardDateRange(startingAt: startDate, endingBefore: endDate, statement: statement)

        var eventCount = 0
        var totals = [TokenUsageAITool: TokenUsageInputScopeTotals]()
        var stepResult = sqlite3_step(statement)
        while stepResult == SQLITE_ROW {
            defer { stepResult = sqlite3_step(statement) }
            eventCount += Int(sqlite3_column_int64(statement, 1))
            // The tool-totals statement this replaces skipped blank labels but counted their rows.
            guard let label = Self.columnString(statement, 0), !label.isEmpty else { continue }
            let tool = Self.dashboardTool(storedLabel: label)
            let existing = totals[tool] ?? .zero
            totals[tool] = TokenUsageInputScopeTotals(
                includeCache: existing.includeCache + Int(sqlite3_column_int64(statement, 2)),
                freshOnly: existing.freshOnly + Int(sqlite3_column_int64(statement, 3))
            )
        }
        if stepResult != SQLITE_DONE {
            failureObserver?.markFailure()
        }
        return DashboardToolScope(eventCount: eventCount, totals: totals)
    }
}
