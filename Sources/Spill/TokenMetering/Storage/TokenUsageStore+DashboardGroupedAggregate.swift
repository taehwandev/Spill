import Foundation
import SQLite3

extension TokenUsageStore {
    /// One scan of the events in range, grouped by every dimension the dashboard slices on.
    /// Replaces a dozen statements that each walked the same rows; the groups are tiny next
    /// to the events, so the remaining work happens on the aggregate rows in Swift.
    func loadDashboardGroupedAggregate(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> DashboardGroupedAggregate {
        let trimExpr = "TRIM(model, ' ' || char(9) || char(10) || char(13))"
        let modelKeyExpr = """
        CASE
            WHEN \(trimExpr) = ''
                OR LOWER(\(trimExpr)) IN ('unknown', 'unknown_model', 'model_unknown', 'unavailable')
            THEN 'model_unavailable'
            ELSE \(trimExpr)
        END
        """
        let hasAccounting = """
        accounting_uncached_input_tokens IS NOT NULL \
        AND accounting_cache_creation_input_tokens IS NOT NULL \
        AND accounting_cache_read_input_tokens IS NOT NULL \
        AND accounting_reasoning_output_tokens IS NOT NULL
        """
        let sql = """
        SELECT ai_tool, project_id, task_type, stage, \(modelKeyExpr),
               COUNT(*),
               COALESCE(SUM(total_tokens), 0),
               COALESCE(SUM(\(Self.dashboardFreshTokenSQL)), 0),
               COALESCE(SUM(input_tokens), 0),
               COALESCE(SUM(output_tokens), 0),
               COALESCE(SUM(CASE WHEN input_tokens > 0 AND \(hasAccounting)
                                 THEN accounting_uncached_input_tokens ELSE 0 END), 0),
               COALESCE(SUM(CASE WHEN input_tokens > 0 AND \(hasAccounting)
                                 THEN accounting_cache_creation_input_tokens ELSE 0 END), 0),
               COALESCE(SUM(CASE WHEN input_tokens > 0 AND \(hasAccounting)
                                 THEN accounting_cache_read_input_tokens ELSE 0 END), 0),
               COALESCE(SUM(CASE WHEN input_tokens > 0 THEN
                                 CASE WHEN \(hasAccounting)
                                      THEN MAX(0, input_tokens - (
                                          accounting_uncached_input_tokens
                                          + accounting_cache_creation_input_tokens
                                          + accounting_cache_read_input_tokens))
                                      ELSE input_tokens END
                                 ELSE 0 END), 0),
               COUNT(CASE WHEN input_tokens > 0 THEN 1 END),
               COALESCE(SUM(source_system), 0),
               COALESCE(SUM(source_user), 0),
               COALESCE(SUM(source_history), 0),
               COALESCE(SUM(source_repo_context), 0),
               COALESCE(SUM(source_tool_output), 0),
               COALESCE(SUM(source_generated_output), 0),
               COALESCE(SUM(source_unknown), 0)
        FROM token_usage_events
        \(Self.dashboardWhereClause(startingAt: startDate, endingBefore: endDate, dashboardToolsOnly: dashboardToolsOnly, visibleTools: visibleTools))
        GROUP BY ai_tool, project_id, task_type, stage, 5
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            failureObserver?.markFailure()
            return DashboardGroupedAggregate(rows: [])
        }
        defer { sqlite3_finalize(statement) }
        Self.bindDashboardDateRange(startingAt: startDate, endingBefore: endDate, statement: statement)

        func int(_ column: Int32) -> Int { Int(sqlite3_column_int64(statement, column)) }
        var rows = [DashboardGroupedAggregateRow]()
        var stepResult = sqlite3_step(statement)
        while stepResult == SQLITE_ROW {
            defer { stepResult = sqlite3_step(statement) }
            rows.append(DashboardGroupedAggregateRow(
                toolLabel: Self.columnString(statement, 0) ?? "",
                projectID: Self.columnString(statement, 1),
                taskType: Self.columnString(statement, 2),
                stage: Self.columnString(statement, 3),
                modelKey: Self.columnString(statement, 4),
                eventCount: int(5), totalTokens: int(6), freshTokens: int(7),
                inputTokens: int(8), outputTokens: int(9),
                uncachedInput: int(10), cacheCreationInput: int(11), cacheReadInput: int(12),
                unclassifiedInput: int(13), inputEventCount: int(14),
                sources: Dictionary(uniqueKeysWithValues: DashboardGroupedAggregate.sourceKeys.enumerated().map {
                    ($0.element, int(Int32(15 + $0.offset)))
                })
            ))
        }
        if stepResult != SQLITE_DONE {
            failureObserver?.markFailure()
        }
        return DashboardGroupedAggregate(rows: rows)
    }
}
