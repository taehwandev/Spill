import Foundation
import SQLite3

/// A narrow per-row projection for trend-bucket aggregation: only what
/// TokenUsageDashboardTrendBucketBuilder groups or sums by. ai_tool never fails to parse (the
/// column always resolves to some TokenUsageAITool, defaulting to .unknown), so unlike the
/// session source rows there is no skip-on-unparseable case here.
struct TokenUsageDashboardTrendSourceRow {
    let aiTool: TokenUsageAITool
    let rawCreatedAt: String
    let createdAt: Date?
    let dayBucket: String
    let monthBucket: String
    let totalTokens: Int
    let freshTokens: Int
}

extension TokenUsageStore {
    /// Day/month bucket boundaries are computed in Swift against the app's real Calendar, not in
    /// SQL -- the same timezone-safety reasoning as loadDashboardDayTokenTotals and
    /// loadSessionSourceRows.
    func loadTrendSourceRows(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil,
        calendar: Calendar,
        database: OpaquePointer
    ) -> [TokenUsageDashboardTrendSourceRow] {
        let whereClause = Self.dashboardWhereClause(
            startingAt: startDate,
            endingBefore: endDate,
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools
        )
        let sql = """
        SELECT ai_tool, created_at, total_tokens, \(Self.dashboardFreshTokenSQL)
        FROM token_usage_events
        \(whereClause)
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return []
        }
        defer { sqlite3_finalize(statement) }
        Self.bindDashboardDateRange(startingAt: startDate, endingBefore: endDate, statement: statement)

        var rows = [TokenUsageDashboardTrendSourceRow]()
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let aiToolRaw = Self.columnString(statement, 0),
                  let createdAtText = Self.columnString(statement, 1)
            else {
                continue
            }

            let aiTool: TokenUsageAITool
            switch aiToolRaw {
            case "agy":
                aiTool = .antigravity
            case "ollama":
                aiTool = .unknown
            default:
                aiTool = TokenUsageAITool(rawValue: aiToolRaw) ?? .unknown
            }

            let parsedDate = ISO8601DateFormatter.parseTokenUsageDate(from: createdAtText)
            let dayBucket = parsedDate.map {
                TokenUsageDashboardSnapshot.dayID(for: $0, calendar: calendar)
            } ?? String(createdAtText.prefix(10))
            let monthBucket = parsedDate.map { date -> String in
                let components = calendar.dateComponents([.year, .month], from: date)
                guard let year = components.year, let month = components.month else {
                    return String(createdAtText.prefix(7))
                }
                return String(format: "%04d-%02d", year, month)
            } ?? String(createdAtText.prefix(7))

            rows.append(TokenUsageDashboardTrendSourceRow(
                aiTool: aiTool,
                rawCreatedAt: createdAtText,
                createdAt: parsedDate,
                dayBucket: dayBucket,
                monthBucket: monthBucket,
                totalTokens: Int(sqlite3_column_int64(statement, 2)),
                freshTokens: Int(sqlite3_column_int64(statement, 3))
            ))
        }
        return rows
    }

    func trendSourceRows(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool = true,
        visibleTools: Set<TokenUsageAITool>? = nil,
        calendar: Calendar = .autoupdatingCurrent,
        database: OpaquePointer? = nil
    ) -> [TokenUsageDashboardTrendSourceRow] {
        withDatabaseConnection(database, default: []) { database in
            loadTrendSourceRows(
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                calendar: calendar,
                database: database
            )
        }
    }
}
