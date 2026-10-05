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
        guard startDate < endDate else { return [:] }
        var sql = """
        SELECT COUNT(*), COALESCE(SUM(total_tokens), 0),
               COALESCE(SUM(\(Self.dashboardFreshTokenSQL)), 0)
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

        var totals = [String: TokenUsageInputScopeTotals]()
        var dayStart = calendar.startOfDay(for: startDate)
        while dayStart < endDate {
            // Calendar boundaries preserve short/long DST days and historical
            // offsets. Clamp the first and last days to the caller's exact range.
            guard let followingDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                failureObserver?.markFailure()
                return [:]
            }
            let nextDayStart = calendar.startOfDay(for: followingDay)
            guard nextDayStart > dayStart else {
                failureObserver?.markFailure()
                return [:]
            }
            let lowerBound = max(dayStart, startDate)
            let upperBound = min(nextDayStart, endDate)
            let startValue = ISO8601DateFormatter.tokenUsage.string(from: lowerBound)
            let endValue = ISO8601DateFormatter.tokenUsage.string(from: upperBound)
            guard sqlite3_bind_text(statement, 1, startValue, -1, SQLITE_TRANSIENT) == SQLITE_OK,
                  sqlite3_bind_text(statement, 2, endValue, -1, SQLITE_TRANSIENT) == SQLITE_OK,
                  sqlite3_step(statement) == SQLITE_ROW
            else {
                failureObserver?.markFailure()
                return [:]
            }
            if sqlite3_column_int64(statement, 0) > 0 {
                let dayID = TokenUsageDashboardSnapshot.dayID(for: dayStart, calendar: calendar)
                totals[dayID] = TokenUsageInputScopeTotals(
                    includeCache: Int(sqlite3_column_int64(statement, 1)),
                    freshOnly: Int(sqlite3_column_int64(statement, 2))
                )
            }
            guard sqlite3_step(statement) == SQLITE_DONE,
                  sqlite3_reset(statement) == SQLITE_OK
            else {
                failureObserver?.markFailure()
                return [:]
            }
            dayStart = nextDayStart
        }
        return totals
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

    /// The tools a dashboard query is scoped to, or nil when it is not scoped by tool.
    static func dashboardToolList(
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil
    ) -> [TokenUsageAITool]? {
        if let visibleTools {
            return visibleTools
                .filter { !dashboardToolsOnly || $0.isDashboardTool }
                .sorted { $0.rawValue < $1.rawValue }
        }
        return dashboardToolsOnly ? TokenUsageAITool.dashboardTools : nil
    }

    static func dashboardToolCondition(
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil
    ) -> String? {
        guard let tools = dashboardToolList(dashboardToolsOnly: dashboardToolsOnly, visibleTools: visibleTools) else {
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
