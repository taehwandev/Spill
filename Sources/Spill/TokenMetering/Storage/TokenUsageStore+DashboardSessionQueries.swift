import Foundation
import SQLite3

/// Session/work-item source rows pre-aggregated in SQL per (project, task, stage, run, 15-minute
/// UTC slice) instead of one row per event. Every real time zone offset and DST transition falls on
/// a quarter hour, so all events in one slice share a local day and the Swift-side day bucketing
/// against the app's Calendar stays exact while an "all time" history collapses to a few rows.
struct TokenUsageDashboardSessionSourceRow {
    let projectID: String
    let taskType: TokenUsageTaskType
    let stage: TokenUsageStage
    let runID: String
    /// Latest created_at in the slice.
    let rawCreatedAt: String
    let createdAt: Date?
    let dayBucket: String
    let eventCount: Int
    let totalTokens: Int
    let freshTokens: Int
    let latencyMS: Int
}

extension TokenUsageStore {
    /// Local day boundaries still come from the app's real Calendar in Swift; SQL only sums
    /// within quarter-hour UTC slices, which never straddle a local midnight. Grouping by
    /// (project_id, task_type, stage, day bucket) happens in TokenUsageDashboardSnapshot.
    func loadSessionSourceRows(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool,
        visibleTools: Set<TokenUsageAITool>? = nil,
        selectedTool: TokenUsageAITool? = nil,
        projectID: String? = nil,
        calendar: Calendar,
        database: OpaquePointer,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> [TokenUsageDashboardSessionSourceRow] {
        var conditions = [String]()
        if startDate != nil, endDate != nil {
            conditions.append("created_at >= ? AND created_at < ?")
        }
        if selectedTool != nil {
            conditions.append("ai_tool = ?")
        } else if let toolCondition = Self.dashboardToolCondition(
            dashboardToolsOnly: dashboardToolsOnly,
            visibleTools: visibleTools
        ) {
            conditions.append(toolCondition)
        }
        if projectID != nil {
            conditions.append("project_id = ?")
        }
        let whereClause = conditions.isEmpty ? "" : "WHERE \(conditions.joined(separator: " AND "))"

        let sql = """
        SELECT project_id, task_type, stage, run_id, MAX(created_at),
               SUM(total_tokens), SUM(\(Self.dashboardFreshTokenSQL)), SUM(latency_ms), COUNT(*)
        FROM token_usage_events
        \(whereClause)
        GROUP BY project_id, task_type, stage, run_id, \(Self.dashboardQuarterHourSliceSQL)
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            failureObserver?.markFailure()
            return []
        }
        defer { sqlite3_finalize(statement) }

        var bindIndex: Int32 = 1
        Self.bindDashboardDateRange(startingAt: startDate, endingBefore: endDate, statement: statement)
        if startDate != nil, endDate != nil {
            bindIndex += 2
        }
        if let selectedTool {
            sqlite3_bind_text(statement, bindIndex, selectedTool.rawValue, -1, SQLITE_TRANSIENT)
            bindIndex += 1
        }
        if let projectID {
            sqlite3_bind_text(statement, bindIndex, projectID, -1, SQLITE_TRANSIENT)
            bindIndex += 1
        }

        var rows = [TokenUsageDashboardSessionSourceRow]()
        var stepResult = sqlite3_step(statement)
        while stepResult == SQLITE_ROW {
            defer { stepResult = sqlite3_step(statement) }
            guard let projectIDText = Self.columnString(statement, 0),
                  let taskTypeText = Self.columnString(statement, 1),
                  let stageText = Self.columnString(statement, 2),
                  let runIDText = Self.columnString(statement, 3),
                  let createdAtText = Self.columnString(statement, 4),
                  // Mirrors event(from:)'s guard: a row with a task_type/stage slug that no
                  // longer parses is skipped, exactly like the full-event read path.
                  let taskType = TokenUsageTaskType(rawValue: taskTypeText),
                  let stage = TokenUsageStage(rawValue: stageText)
            else {
                continue
            }

            let parsedDate = ISO8601DateFormatter.parseTokenUsageDate(from: createdAtText)
            let dayBucket = parsedDate.map {
                TokenUsageDashboardSnapshot.dayID(for: $0, calendar: calendar)
            } ?? String(createdAtText.prefix(10))

            rows.append(TokenUsageDashboardSessionSourceRow(
                projectID: projectIDText,
                taskType: taskType,
                stage: stage,
                runID: runIDText,
                rawCreatedAt: createdAtText,
                createdAt: parsedDate,
                dayBucket: dayBucket,
                eventCount: Int(sqlite3_column_int64(statement, 8)),
                totalTokens: Int(sqlite3_column_int64(statement, 5)),
                freshTokens: Int(sqlite3_column_int64(statement, 6)),
                latencyMS: Int(sqlite3_column_int64(statement, 7))
            ))
        }
        if stepResult != SQLITE_DONE {
            failureObserver?.markFailure()
        }
        return rows
    }

    /// Groups normalized `YYYY-MM-DDTHH:MM:SS.sssZ` timestamps by quarter hour; any other
    /// stored form stays its own group so its date is parsed exactly as before.
    static let dashboardQuarterHourSliceSQL = """
    CASE WHEN created_at GLOB '????-??-??T??:??:??.???Z'
         THEN substr(created_at, 1, 14) || ((CAST(substr(created_at, 15, 2) AS INTEGER) / 15) * 15)
         ELSE created_at END
    """

    func sessionSourceRows(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool = true,
        visibleTools: Set<TokenUsageAITool>? = nil,
        selectedTool: TokenUsageAITool? = nil,
        projectID: String? = nil,
        calendar: Calendar = .autoupdatingCurrent,
        database: OpaquePointer? = nil,
        failureObserver: TokenUsageQueryFailureObserver? = nil
    ) -> [TokenUsageDashboardSessionSourceRow] {
        withDatabaseConnection(database, default: []) { database in
            loadSessionSourceRows(
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                visibleTools: visibleTools,
                selectedTool: selectedTool,
                projectID: projectID,
                calendar: calendar,
                database: database,
                failureObserver: failureObserver
            )
        }
    }
}
