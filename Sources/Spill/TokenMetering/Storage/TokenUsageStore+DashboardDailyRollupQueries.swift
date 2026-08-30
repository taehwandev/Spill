import Foundation
import SQLite3

extension TokenUsageStore {
    func loadDashboardDailyRollupTotals(
        startingAtUTCDate startDate: Date? = nil,
        endingBeforeUTCDate endDate: Date? = nil,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>?,
        database: OpaquePointer,
        failureObserver: TokenUsageQueryFailureObserver?
    ) -> TokenUsageInputScopeTotals? {
        var conditions = [String]()
        if startDate != nil, endDate != nil {
            conditions.append("utc_day >= ? AND utc_day < ?")
        }
        if let toolCondition = Self.dashboardToolCondition(
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools
        ) {
            conditions.append(toolCondition)
        }

        var sql = """
        SELECT COALESCE(SUM(total_tokens), 0),
               COALESCE(SUM(fresh_tokens), 0)
        FROM \(Self.dashboardDailyRollupTable)
        """
        if !conditions.isEmpty {
            sql += "\nWHERE \(conditions.joined(separator: " AND "))"
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            failureObserver?.markFailure()
            return nil
        }
        defer { sqlite3_finalize(statement) }

        if let startDate, let endDate {
            sqlite3_bind_text(statement, 1, Self.utcDayID(startDate), -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 2, Self.utcDayID(endDate), -1, SQLITE_TRANSIENT)
        }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            failureObserver?.markFailure()
            return nil
        }
        return TokenUsageInputScopeTotals(
            includeCache: Int(sqlite3_column_int64(statement, 0)),
            freshOnly: Int(sqlite3_column_int64(statement, 1))
        )
    }

    func loadDashboardPeriodTotalsFromDailyRollup(
        startingAt startDate: Date,
        endingBefore endDate: Date,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>?,
        database: OpaquePointer,
        failureObserver: TokenUsageQueryFailureObserver?
    ) -> TokenUsageInputScopeTotals? {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.locale = Locale(identifier: "en_US_POSIX")
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt

        let startUTCDate = utcCalendar.startOfDay(for: startDate)
        let endUTCDate = utcCalendar.startOfDay(for: endDate)
        let firstFullDay = startDate == startUTCDate
            ? startDate
            : (utcCalendar.date(byAdding: .day, value: 1, to: startUTCDate) ?? endDate)
        let fullDayEnd = endDate == endUTCDate ? endDate : endUTCDate

        if firstFullDay >= fullDayEnd {
            return loadRawDashboardTotals(
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database,
                failureObserver: failureObserver
            )
        }

        guard var totals = loadDashboardDailyRollupTotals(
            startingAtUTCDate: firstFullDay,
            endingBeforeUTCDate: fullDayEnd,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools,
            database: database,
            failureObserver: failureObserver
        ) else {
            return nil
        }

        if startDate < firstFullDay {
            guard let startEdge = loadRawDashboardTotals(
                startingAt: startDate,
                endingBefore: firstFullDay,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database,
                failureObserver: failureObserver
            ) else {
                return nil
            }
            totals = Self.adding(totals, startEdge)
        }
        if fullDayEnd < endDate {
            guard let endEdge = loadRawDashboardTotals(
                startingAt: fullDayEnd,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                database: database,
                failureObserver: failureObserver
            ) else {
                return nil
            }
            totals = Self.adding(totals, endEdge)
        }
        return totals
    }
}

private extension TokenUsageStore {
    func loadRawDashboardTotals(
        startingAt startDate: Date,
        endingBefore endDate: Date,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>?,
        database: OpaquePointer,
        failureObserver: TokenUsageQueryFailureObserver?
    ) -> TokenUsageInputScopeTotals? {
        guard let totals = loadDashboardCountAndTotalIfAvailable(
            startingAt: startDate,
            endingBefore: endDate,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools,
            database: database,
            failureObserver: failureObserver
        ) else {
            return nil
        }
        return TokenUsageInputScopeTotals(
            includeCache: totals.totalTokens,
            freshOnly: totals.exactFreshTotalTokens
        )
    }

    static func utcDayID(_ date: Date) -> String {
        String(ISO8601DateFormatter.tokenUsage.string(from: date).prefix(10))
    }

    static func adding(
        _ lhs: TokenUsageInputScopeTotals,
        _ rhs: TokenUsageInputScopeTotals
    ) -> TokenUsageInputScopeTotals {
        TokenUsageInputScopeTotals(
            includeCache: lhs.includeCache + rhs.includeCache,
            freshOnly: lhs.freshOnly + rhs.freshOnly
        )
    }
}
