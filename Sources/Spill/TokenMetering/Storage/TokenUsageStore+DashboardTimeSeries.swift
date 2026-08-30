import Foundation
import SQLite3

extension TokenUsageStore {
    func loadAllPeriodTotalTokens(
        now: Date,
        calendar: Calendar,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> [TokenUsageDashboardPeriod: TokenUsageInputScopeTotals] {
        let todayRange = TokenUsageDashboardSnapshot.cutoffDateRange(for: .today, periodOffset: 0, now: now, calendar: calendar)
        let sevenRange = TokenUsageDashboardSnapshot.cutoffDateRange(for: .sevenDays, periodOffset: 0, now: now, calendar: calendar)
        let thirtyRange = TokenUsageDashboardSnapshot.cutoffDateRange(for: .thirtyDays, periodOffset: 0, now: now, calendar: calendar)

        guard let todayStart = todayRange.start, let todayEnd = todayRange.end,
              let sevenStart = sevenRange.start, let sevenEnd = sevenRange.end,
              let thirtyStart = thirtyRange.start, let thirtyEnd = thirtyRange.end
        else {
            let allTotals = loadDashboardCountAndTotal(
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database,
                failureObserver: failureObserver
            )
            return [
                .today: .zero,
                .sevenDays: .zero,
                .thirtyDays: .zero,
                .all: TokenUsageInputScopeTotals(
                    includeCache: allTotals.totalTokens,
                    freshOnly: allTotals.exactFreshTotalTokens
                )
            ]
        }

        guard let today = loadDashboardPeriodTotalsFromDailyRollup(
            startingAt: todayStart,
            endingBefore: todayEnd,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools,
            database: database,
            failureObserver: failureObserver
        ), let sevenDays = loadDashboardPeriodTotalsFromDailyRollup(
            startingAt: sevenStart,
            endingBefore: sevenEnd,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools,
            database: database,
            failureObserver: failureObserver
        ), let thirtyDays = loadDashboardPeriodTotalsFromDailyRollup(
            startingAt: thirtyStart,
            endingBefore: thirtyEnd,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools,
            database: database,
            failureObserver: failureObserver
        ), let all = loadDashboardDailyRollupTotals(
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools,
            database: database,
            failureObserver: failureObserver
        ) else {
            return [:]
        }

        return [.today: today, .sevenDays: sevenDays, .thirtyDays: thirtyDays, .all: all]
    }

    /// Hour-bucketed total tokens for one tool across all history, ordered by
    /// hour (UTC). One indexed aggregate scan; callers cache the result against
    /// the store's data revision because it only changes when events do.
    func hourlyTotalTokens(for tool: TokenUsageAITool) -> [(hourStart: Date, totalTokens: Int)] {
        withDatabaseConnection(nil, default: []) { database in
            let sql = """
            SELECT strftime('%Y-%m-%dT%H', created_at), SUM(total_tokens)
            FROM token_usage_events
            WHERE ai_tool = ?
            GROUP BY 1
            ORDER BY 1
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
                  let statement
            else {
                return []
            }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_text(statement, 1, tool.rawValue, -1, SQLITE_TRANSIENT)

            var results: [(hourStart: Date, totalTokens: Int)] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let hourText = sqlite3_column_text(statement, 0),
                      let hourStart = Self.hourBucketFormatter.date(from: String(cString: hourText))
                else {
                    continue
                }
                results.append((hourStart, Int(sqlite3_column_int64(statement, 1))))
            }
            return results
        }
    }

    private static let hourBucketFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH"
        return formatter
    }()

    func loadTotalTokens(
        startingAt startDate: Date,
        endingBefore endDate: Date,
        dashboardToolsOnly: Bool,
        database: OpaquePointer
    ) -> Int {
        var sql = """
        SELECT COALESCE(SUM(total_tokens), 0)
        FROM token_usage_events
        WHERE created_at >= ? AND created_at < ?
        """
        if dashboardToolsOnly {
            sql += " AND ai_tool IN ('codex', 'claude', 'antigravity')"
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return 0
        }
        defer { sqlite3_finalize(statement) }

        let startValue = ISO8601DateFormatter.tokenUsage.string(from: startDate)
        let endValue = ISO8601DateFormatter.tokenUsage.string(from: endDate)
        sqlite3_bind_text(statement, 1, startValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, endValue, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return 0
        }

        return Int(sqlite3_column_int64(statement, 0))
    }

    func loadDashboardDayTokenTotals(
        startingAt startDate: Date,
        endingBefore endDate: Date,
        calendar: Calendar,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil,
        database: OpaquePointer,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> [String: TokenUsageInputScopeTotals] {
        var sql = """
        SELECT created_at,
               total_tokens,
               \(Self.dashboardFreshTokenSQL)
        FROM token_usage_events
        WHERE created_at >= ? AND created_at < ?
        """
        if let toolCondition = Self.dashboardToolCondition(
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools
        ) {
            sql += " AND \(toolCondition)"
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            failureObserver?.markFailure()
            return [:]
        }
        defer { sqlite3_finalize(statement) }

        let startValue = ISO8601DateFormatter.tokenUsage.string(from: startDate)
        let endValue = ISO8601DateFormatter.tokenUsage.string(from: endDate)
        sqlite3_bind_text(statement, 1, startValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, endValue, -1, SQLITE_TRANSIENT)

        var totals = [String: TokenUsageInputScopeTotals]()
        var stepResult = sqlite3_step(statement)
        while stepResult == SQLITE_ROW {
            defer { stepResult = sqlite3_step(statement) }
            guard let createdAt = Self.columnString(statement, 0),
                  let date = ISO8601DateFormatter.parseTokenUsageDate(from: createdAt)
            else {
                continue
            }
            let dayID = TokenUsageDashboardSnapshot.dayID(for: date, calendar: calendar)
            let current = totals[dayID, default: .zero]
            totals[dayID] = TokenUsageInputScopeTotals(
                includeCache: current.includeCache + Int(sqlite3_column_int64(statement, 1)),
                freshOnly: current.freshOnly + Int(sqlite3_column_int64(statement, 2))
            )
        }
        if stepResult != SQLITE_DONE {
            failureObserver?.markFailure()
        }
        return totals
    }

    static func dashboardToolWhereClause(
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil
    ) -> String {
        guard let condition = dashboardToolCondition(
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools
        ) else {
            return ""
        }
        return "WHERE \(condition)"
    }

    static func dashboardWhereClause(
        startingAt startDate: Date?,
        endingBefore endDate: Date?,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil
    ) -> String {
        var conditions = [String]()
        if startDate != nil, endDate != nil {
            conditions.append("created_at >= ? AND created_at < ?")
        }
        if let toolCondition = dashboardToolCondition(
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools
        ) {
            conditions.append(toolCondition)
        }
        guard !conditions.isEmpty else {
            return ""
        }
        return "WHERE \(conditions.joined(separator: " AND "))"
    }

    static func dashboardToolCondition(
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil
    ) -> String? {
        let tools: [TokenUsageAITool]?
        if let visibleTools {
            tools = visibleTools
                .filter { !dashboardToolsOnly || $0.isDashboardTool }
                .sorted { $0.rawValue < $1.rawValue }
        } else if dashboardToolsOnly {
            tools = TokenUsageAITool.dashboardTools
        } else {
            tools = nil
        }

        guard let tools else {
            return nil
        }
        guard !tools.isEmpty else {
            return "0=1"
        }
        let rawValues = tools
            .map { "'\($0.rawValue)'" }
            .joined(separator: ", ")
        return "ai_tool IN (\(rawValues))"
    }

    static func bindDashboardDateRange(
        startingAt startDate: Date?,
        endingBefore endDate: Date?,
        statement: OpaquePointer
    ) {
        guard let startDate, let endDate else {
            return
        }

        let startValue = ISO8601DateFormatter.tokenUsage.string(from: startDate)
        let endValue = ISO8601DateFormatter.tokenUsage.string(from: endDate)
        sqlite3_bind_text(statement, 1, startValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, endValue, -1, SQLITE_TRANSIENT)
    }

    static func normalizedCreatedAt(_ createdAt: String) -> String? {
        guard let date = ISO8601DateFormatter.parseTokenUsageDate(from: createdAt) else {
            return nil
        }

        return ISO8601DateFormatter.tokenUsage.string(from: date)
    }

}
