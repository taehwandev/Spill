import Foundation
import SQLite3

/// A narrow per-row projection for session/work-item aggregation: only the columns
/// TokenUsageDashboardSnapshot.sessionRows actually groups or sums by, instead of the full
/// TokenUsageEvent (token breakdown, accounting, span/device/artifact IDs, model). Streaming
/// this instead of full events is what lets the "all time" work-item view avoid holding the
/// wide struct for every one of a large event history.
struct TokenUsageDashboardSessionSourceRow {
    let projectID: String
    let taskType: TokenUsageTaskType
    let stage: TokenUsageStage
    let runID: String
    let rawCreatedAt: String
    let createdAt: Date?
    let dayBucket: String
    let totalTokens: Int
    let freshTokens: Int
    let latencyMS: Int
}

extension TokenUsageStore {
    /// Deliberately does not attempt day-bucket grouping in SQL: created_at's day boundary
    /// must match the app's real Calendar (locale/timezone/DST), the same reasoning that keeps
    /// loadDashboardDayTokenTotals streaming narrow rows and bucketing them in Swift rather than
    /// doing it with a SQL date function. Grouping by (project_id, task_type, stage, day bucket)
    /// happens in TokenUsageDashboardSnapshot, not here.
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
        if let selectedTool {
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
        SELECT project_id, task_type, stage, run_id, created_at,
               total_tokens, \(Self.dashboardFreshTokenSQL), latency_ms
        FROM token_usage_events
        \(whereClause)
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
