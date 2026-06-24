import Foundation
import SQLite3

extension TokenUsageStore {
    func loadAllPeriodTotalTokens(
        now: Date,
        calendar: Calendar,
        dashboardToolsOnly: Bool,
        database: OpaquePointer
    ) -> [TokenUsageDashboardPeriod: Int] {
        let todayRange = TokenUsageDashboardSnapshot.cutoffDateRange(for: .today, periodOffset: 0, now: now, calendar: calendar)
        let sevenRange = TokenUsageDashboardSnapshot.cutoffDateRange(for: .sevenDays, periodOffset: 0, now: now, calendar: calendar)
        let thirtyRange = TokenUsageDashboardSnapshot.cutoffDateRange(for: .thirtyDays, periodOffset: 0, now: now, calendar: calendar)

        guard let todayStart = todayRange.start, let todayEnd = todayRange.end,
              let sevenStart = sevenRange.start, let sevenEnd = sevenRange.end,
              let thirtyStart = thirtyRange.start, let thirtyEnd = thirtyRange.end
        else {
            return [
                .today: 0,
                .sevenDays: 0,
                .thirtyDays: 0,
                .all: loadDashboardCountAndTotal(dashboardToolsOnly: dashboardToolsOnly, database: database).totalTokens
            ]
        }

        let toolFilter = dashboardToolsOnly ? " AND ai_tool IN ('codex', 'claude', 'antigravity')" : ""
        let sql = """
        SELECT
          COALESCE(SUM(CASE WHEN created_at >= ? AND created_at < ? THEN total_tokens ELSE 0 END), 0),
          COALESCE(SUM(CASE WHEN created_at >= ? AND created_at < ? THEN total_tokens ELSE 0 END), 0),
          COALESCE(SUM(CASE WHEN created_at >= ? AND created_at < ? THEN total_tokens ELSE 0 END), 0),
          COALESCE(SUM(total_tokens), 0)
        FROM token_usage_events
        WHERE 1=1\(toolFilter)
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return [:]
        }
        defer { sqlite3_finalize(statement) }

        let fmt = ISO8601DateFormatter.tokenUsage
        sqlite3_bind_text(statement, 1, fmt.string(from: todayStart), -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, fmt.string(from: todayEnd), -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 3, fmt.string(from: sevenStart), -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 4, fmt.string(from: sevenEnd), -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 5, fmt.string(from: thirtyStart), -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 6, fmt.string(from: thirtyEnd), -1, SQLITE_TRANSIENT)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return [:]
        }

        return [
            .today: Int(sqlite3_column_int64(statement, 0)),
            .sevenDays: Int(sqlite3_column_int64(statement, 1)),
            .thirtyDays: Int(sqlite3_column_int64(statement, 2)),
            .all: Int(sqlite3_column_int64(statement, 3))
        ]
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
        database: OpaquePointer
    ) -> [String: Int] {
        var sql = """
        SELECT created_at, total_tokens
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
            return [:]
        }
        defer { sqlite3_finalize(statement) }

        let startValue = ISO8601DateFormatter.tokenUsage.string(from: startDate)
        let endValue = ISO8601DateFormatter.tokenUsage.string(from: endDate)
        sqlite3_bind_text(statement, 1, startValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, endValue, -1, SQLITE_TRANSIENT)

        var totals = [String: Int]()
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let createdAt = Self.columnString(statement, 0),
                  let date = ISO8601DateFormatter.parseTokenUsageDate(from: createdAt)
            else {
                continue
            }
            let dayID = TokenUsageDashboardSnapshot.dayID(for: date, calendar: calendar)
            totals[dayID, default: 0] += Int(sqlite3_column_int64(statement, 1))
        }
        return totals
    }

    static func dashboardToolWhereClause(dashboardToolsOnly: Bool) -> String {
        dashboardToolsOnly
            ? "WHERE ai_tool IN ('codex', 'claude', 'antigravity')"
            : ""
    }

    static func dashboardWhereClause(
        startingAt startDate: Date?,
        endingBefore endDate: Date?,
        dashboardToolsOnly: Bool
    ) -> String {
        var conditions = [String]()
        if startDate != nil, endDate != nil {
            conditions.append("created_at >= ? AND created_at < ?")
        }
        if dashboardToolsOnly {
            conditions.append("ai_tool IN ('codex', 'claude', 'antigravity')")
        }
        guard !conditions.isEmpty else {
            return ""
        }
        return "WHERE \(conditions.joined(separator: " AND "))"
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
