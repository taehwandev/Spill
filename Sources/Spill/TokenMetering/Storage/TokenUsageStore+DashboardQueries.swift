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
        guard let totals = loadDashboardCountAndTotalIfAvailable(
            startingAt: startDate,
            endingBefore: endDate,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools,
            database: database
        ) else {
            return .empty
        }
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
        database: OpaquePointer,
        failureObserver: TokenUsageQueryFailureObserver? = nil
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
        // MIN/MAX over `ai_tool IN (...)` cannot use the min/max optimization and scans the
        // whole (ai_tool, created_at) index; one indexed lookup per tool is O(log N) each.
        if selectedTool == nil,
           let tools = Self.dashboardToolList(dashboardToolsOnly: dashboardToolsOnly, visibleTools: visibleTools),
           !tools.isEmpty {
            let perTool = tools.map { tool in
                let predicate = "FROM token_usage_events WHERE ai_tool = '\(tool.rawValue)'"
                return "SELECT (SELECT MIN(created_at) \(predicate)) AS earliest, (SELECT MAX(created_at) \(predicate)) AS latest"
            }
            sql = "SELECT MIN(earliest), MAX(latest) FROM (\(perTool.joined(separator: " UNION ALL ")))"
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            failureObserver?.markFailure()
            return .empty
        }
        defer { sqlite3_finalize(statement) }

        if let selectedTool {
            sqlite3_bind_text(statement, 1, selectedTool.rawValue, -1, SQLITE_TRANSIENT)
        }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            failureObserver?.markFailure()
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
        database: OpaquePointer,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> (eventCount: Int, totalTokens: Int, exactFreshTotalTokens: Int) {
        loadDashboardCountAndTotalIfAvailable(
            startingAt: startDate,
            endingBefore: endDate,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools,
            database: database,
            failureObserver: failureObserver
        ) ?? (0, 0, 0)
    }

    /// Returns nil for two different reasons the caller must keep distinct: a prepare/step
    /// failure (marks `failureObserver`, so a batch caller can fail closed) versus this query
    /// simply not being asked for -- it never returns nil for a valid empty range, since an empty
    /// range still steps one COUNT/SUM row of zeros. Only genuine statement failure marks the
    /// observer here; comparisonTokenTotal's own eventCount == 0 -> nil mapping stays a legitimate
    /// no-data result and must not be treated as a failure.
    func loadDashboardCountAndTotalIfAvailable(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer,
        failureObserver: TokenUsageQueryFailureObserver? = nil
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
            failureObserver?.markFailure()
            return nil
        }
        defer { sqlite3_finalize(statement) }
        Self.bindDashboardDateRange(startingAt: startDate, endingBefore: endDate, statement: statement)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            failureObserver?.markFailure()
            return nil
        }

        return (
            eventCount: Int(sqlite3_column_int64(statement, 0)),
            totalTokens: Int(sqlite3_column_int64(statement, 1)),
            exactFreshTotalTokens: Int(sqlite3_column_int64(statement, 2))
        )
    }

    struct DashboardFocusedTotals {
        let eventCount: Int
        let totalTokens: Int
        let exactFreshTotalTokens: Int
        let inputTokens: Int
        let outputTokens: Int
        let assistedEventCount: Int
        let assistedTotalTokens: Int
    }

    /// Mirrors TokenUsageDashboardSnapshot.lastUpdatedDates: MAX(created_at) per tool over the
    /// same dashboardToolsOnly/visibleTools-scoped rows, plus an overall max across all of them.
    func loadLastUpdatedByTool(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> [TokenUsageAITool: Date] {
        var sql = """
        SELECT ai_tool, MAX(created_at)
        FROM token_usage_events
        \(Self.dashboardWhereClause(startingAt: startDate, endingBefore: endDate, dashboardToolsOnly: dashboardToolsOnly, visibleTools: visibleTools))
        GROUP BY ai_tool
        """
        // GROUP BY ai_tool walks every matching index entry; a per-tool MAX is one index seek.
        // ?1/?2 are reused by every subquery, so the shared date-range binding still applies.
        if let tools = Self.dashboardToolList(dashboardToolsOnly: dashboardToolsOnly, visibleTools: visibleTools),
           !tools.isEmpty {
            let dateCondition = startDate != nil && endDate != nil ? " AND created_at >= ?1 AND created_at < ?2" : ""
            sql = tools.map { tool in
                "SELECT '\(tool.rawValue)', (SELECT MAX(created_at) FROM token_usage_events WHERE ai_tool = '\(tool.rawValue)'\(dateCondition))"
            }
            .joined(separator: " UNION ALL ")
        }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            failureObserver?.markFailure()
            return [:]
        }
        defer { sqlite3_finalize(statement) }
        Self.bindDashboardDateRange(startingAt: startDate, endingBefore: endDate, statement: statement)

        var result = [TokenUsageAITool: Date]()
        var stepResult = sqlite3_step(statement)
        while stepResult == SQLITE_ROW {
            defer { stepResult = sqlite3_step(statement) }
            guard let aiToolRaw = Self.columnString(statement, 0),
                  let maxCreatedAtText = Self.columnString(statement, 1),
                  let maxCreatedAt = ISO8601DateFormatter.parseTokenUsageDate(from: maxCreatedAtText)
            else {
                continue
            }

            let aiTool: TokenUsageAITool
            switch aiToolRaw {
            case "agy":
                aiTool = .antigravity
            default:
                aiTool = TokenUsageAITool(rawValue: aiToolRaw) ?? .unknown
            }
            result[aiTool] = maxCreatedAt
        }
        if stepResult != SQLITE_DONE {
            failureObserver?.markFailure()
        }
        return result
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

    /// Maps a stored ai_tool label to the tool the dashboard shows it under, matching
    /// TokenUsageAITool's decoder: "agy" is Antigravity, anything unrecognized is unknown.
    static func dashboardTool(storedLabel: String?) -> TokenUsageAITool {
        guard let storedLabel else {
            return .unknown
        }
        return storedLabel == "agy" ? .antigravity : (TokenUsageAITool(rawValue: storedLabel) ?? .unknown)
    }

    func loadSourceTokenTotals(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer,
        failureObserver: TokenUsageQueryFailureObserver? = nil
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
            failureObserver?.markFailure()
            return [:]
        }
        defer { sqlite3_finalize(statement) }
        Self.bindDashboardDateRange(startingAt: startDate, endingBefore: endDate, statement: statement)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            failureObserver?.markFailure()
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
