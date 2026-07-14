import Foundation
import SQLite3

extension TokenUsageStore {
    static let dashboardFreshTokenSQL = "output_tokens + COALESCE(accounting_uncached_input_tokens, 0)"

    func loadDashboardSummary(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer
    ) -> TokenUsageDashboardSummary {
        let totals = loadDashboardCountAndTotal(
            startingAt: startDate,
            endingBefore: endDate,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools,
            database: database
        )
        return TokenUsageDashboardSummary(
            eventCount: totals.eventCount,
            totalTokens: totals.totalTokens,
            exactFreshTotalTokens: totals.exactFreshTotalTokens,
            toolTotals: loadGroupedTokenTotals(
                column: "ai_tool",
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database
            ),
            taskTotals: loadGroupedTokenTotals(
                column: "task_type",
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database
            ),
            sourceTotals: loadSourceTokenTotals(
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database
            )
        )
    }

    func loadDashboardDateBounds(
        selectedTool: TokenUsageAITool?,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer
    ) -> TokenUsageDashboardDateBounds {
        var conditions = [String]()
        if selectedTool != nil {
            conditions.append("ai_tool = ?")
        } else if let toolCondition = Self.dashboardToolCondition(
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools
        ) {
            conditions.append(toolCondition)
        }

        var sql = """
        SELECT MIN(created_at), MAX(created_at)
        FROM token_usage_events
        """
        if !conditions.isEmpty {
            sql += "\nWHERE \(conditions.joined(separator: " AND "))"
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return .empty
        }
        defer { sqlite3_finalize(statement) }

        if let selectedTool {
            sqlite3_bind_text(statement, 1, selectedTool.rawValue, -1, SQLITE_TRANSIENT)
        }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return .empty
        }

        let earliest = Self.columnString(statement, 0)
            .flatMap(ISO8601DateFormatter.parseTokenUsageDate(from:))
        let latest = Self.columnString(statement, 1)
            .flatMap(ISO8601DateFormatter.parseTokenUsageDate(from:))
        return TokenUsageDashboardDateBounds(earliest: earliest, latest: latest)
    }

    func loadDashboardCountAndTotal(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer
    ) -> (eventCount: Int, totalTokens: Int, exactFreshTotalTokens: Int) {
        loadDashboardCountAndTotalIfAvailable(
            startingAt: startDate,
            endingBefore: endDate,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools,
            database: database
        ) ?? (0, 0, 0)
    }

    func loadDashboardCountAndTotalIfAvailable(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer
    ) -> (eventCount: Int, totalTokens: Int, exactFreshTotalTokens: Int)? {
        let sql = """
        SELECT COUNT(*),
               COALESCE(SUM(total_tokens), 0),
               COALESCE(SUM(\(Self.dashboardFreshTokenSQL)), 0)
        FROM token_usage_events
        \(Self.dashboardWhereClause(startingAt: startDate, endingBefore: endDate, dashboardToolsOnly: dashboardToolsOnly, visibleTools: visibleTools))
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return nil
        }
        defer { sqlite3_finalize(statement) }
        Self.bindDashboardDateRange(startingAt: startDate, endingBefore: endDate, statement: statement)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }

        return (
            eventCount: Int(sqlite3_column_int64(statement, 0)),
            totalTokens: Int(sqlite3_column_int64(statement, 1)),
            exactFreshTotalTokens: Int(sqlite3_column_int64(statement, 2))
        )
    }

    func loadMenuBarTokenTotalIfAvailable(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        inputScope: TokenUsageInputScope,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer
    ) -> Int? {
        let tokenExpression = switch inputScope {
        case .includeCache:
            "total_tokens"
        case .freshOnly:
            Self.dashboardFreshTokenSQL
        }
        let sql = """
        SELECT COALESCE(SUM(\(tokenExpression)), 0)
        FROM token_usage_events
        \(Self.dashboardWhereClause(startingAt: startDate, endingBefore: endDate, dashboardToolsOnly: dashboardToolsOnly, visibleTools: visibleTools))
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return nil
        }
        defer { sqlite3_finalize(statement) }
        Self.bindDashboardDateRange(startingAt: startDate, endingBefore: endDate, statement: statement)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }

        return Int(sqlite3_column_int64(statement, 0))
    }

    func loadGroupedTokenTotals(
        column: String,
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer
    ) -> [String: Int] {
        let sql = """
        SELECT \(column), COALESCE(SUM(total_tokens), 0)
        FROM token_usage_events
        \(Self.dashboardWhereClause(startingAt: startDate, endingBefore: endDate, dashboardToolsOnly: dashboardToolsOnly, visibleTools: visibleTools))
        GROUP BY \(column)
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return [:]
        }
        defer { sqlite3_finalize(statement) }
        Self.bindDashboardDateRange(startingAt: startDate, endingBefore: endDate, statement: statement)

        var totals = [String: Int]()
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let keyText = sqlite3_column_text(statement, 0) else {
                continue
            }
            let key = String(cString: keyText)
            guard !key.isEmpty else {
                continue
            }
            totals[key] = Int(sqlite3_column_int64(statement, 1))
        }
        return totals
    }

    func loadSourceTokenTotals(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer
    ) -> [String: Int] {
        let sql = """
        SELECT
            COALESCE(SUM(source_system), 0),
            COALESCE(SUM(source_user), 0),
            COALESCE(SUM(source_history), 0),
            COALESCE(SUM(source_repo_context), 0),
            COALESCE(SUM(source_tool_output), 0),
            COALESCE(SUM(source_generated_output), 0),
            COALESCE(SUM(source_unknown), 0)
        FROM token_usage_events
        \(Self.dashboardWhereClause(startingAt: startDate, endingBefore: endDate, dashboardToolsOnly: dashboardToolsOnly, visibleTools: visibleTools))
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return [:]
        }
        defer { sqlite3_finalize(statement) }
        Self.bindDashboardDateRange(startingAt: startDate, endingBefore: endDate, statement: statement)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return [:]
        }

        return [
            "system": Int(sqlite3_column_int64(statement, 0)),
            "user": Int(sqlite3_column_int64(statement, 1)),
            "history": Int(sqlite3_column_int64(statement, 2)),
            "repo_context": Int(sqlite3_column_int64(statement, 3)),
            "tool_output": Int(sqlite3_column_int64(statement, 4)),
            "generated_output": Int(sqlite3_column_int64(statement, 5)),
            "unknown": Int(sqlite3_column_int64(statement, 6))
        ]
    }

}
