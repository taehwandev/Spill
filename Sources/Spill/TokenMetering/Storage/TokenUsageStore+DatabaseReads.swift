import Foundation
import SQLite3

extension TokenUsageStore {
    func loadDatabaseEvents(database: OpaquePointer) -> [TokenUsageEvent] {
        loadDatabaseEvents(startingAt: nil, endingBefore: nil, database: database)
    }

    func loadDatabaseEvents(
        startingAt startDate: Date?,
        endingBefore endDate: Date?,
        database: OpaquePointer
    ) -> [TokenUsageEvent] {
        var conditions = [String]()
        if startDate != nil {
            conditions.append("created_at >= ?")
        }
        if endDate != nil {
            conditions.append("created_at < ?")
        }

        var sql = """
        SELECT \(Self.eventSelectColumns)
        FROM token_usage_events
        """
        if !conditions.isEmpty {
            sql += "\nWHERE \(conditions.joined(separator: " AND "))"
        }
        sql += "\nORDER BY created_at ASC, rowid ASC"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        var bindIndex: Int32 = 1
        if let startDate {
            let startValue = ISO8601DateFormatter.tokenUsage.string(from: startDate)
            sqlite3_bind_text(statement, bindIndex, startValue, -1, SQLITE_TRANSIENT)
            bindIndex += 1
        }
        if let endDate {
            let endValue = ISO8601DateFormatter.tokenUsage.string(from: endDate)
            sqlite3_bind_text(statement, bindIndex, endValue, -1, SQLITE_TRANSIENT)
        }

        var events = [TokenUsageEvent]()
        while sqlite3_step(statement) == SQLITE_ROW {
            if let event = Self.event(from: statement, startingAt: 0) {
                events.append(event)
            }
        }
        return events
    }

    func loadDatabaseEventsAfterRowID(
        _ rowID: Int64,
        database: OpaquePointer
    ) -> (events: [TokenUsageEvent], maxRowID: Int64) {
        let sql = """
        SELECT rowid, \(Self.eventSelectColumns)
        FROM token_usage_events
        WHERE rowid > ?
        ORDER BY created_at ASC, rowid ASC
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return ([], rowID)
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 1, rowID)

        var events = [TokenUsageEvent]()
        var maxRowID = rowID
        while sqlite3_step(statement) == SQLITE_ROW {
            let currentRowID = sqlite3_column_int64(statement, 0)
            if currentRowID > maxRowID {
                maxRowID = currentRowID
            }
            if let event = Self.event(from: statement, startingAt: 1) {
                events.append(event)
            }
        }
        return (events, maxRowID)
    }

    static func event(from statement: OpaquePointer, startingAt offset: Int32) -> TokenUsageEvent? {
        guard let spanID = columnString(statement, offset + 0),
              let deviceID = columnString(statement, offset + 1),
              let projectID = columnString(statement, offset + 2),
              let artifactID = columnString(statement, offset + 3),
              let runID = columnString(statement, offset + 4),
              let createdAt = columnString(statement, offset + 5),
              let aiToolRaw = columnString(statement, offset + 6),
              let taskTypeRaw = columnString(statement, offset + 7),
              let stageRaw = columnString(statement, offset + 8),
              let model = columnString(statement, offset + 9),
              let taskType = TokenUsageTaskType(rawValue: taskTypeRaw),
              let stage = TokenUsageStage(rawValue: stageRaw)
        else {
            return nil
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

        let inputTokens = Int(sqlite3_column_int64(statement, offset + 10))
        let outputTokens = Int(sqlite3_column_int64(statement, offset + 11))
        let totalTokens = Int(sqlite3_column_int64(statement, offset + 12))
        let latencyMS = Int(sqlite3_column_int64(statement, offset + 13))
        let tokenBreakdown = TokenUsageBreakdown(
            system: Int(sqlite3_column_int64(statement, offset + 14)),
            user: Int(sqlite3_column_int64(statement, offset + 15)),
            history: Int(sqlite3_column_int64(statement, offset + 16)),
            repoContext: Int(sqlite3_column_int64(statement, offset + 17)),
            toolOutput: Int(sqlite3_column_int64(statement, offset + 18)),
            generatedOutput: Int(sqlite3_column_int64(statement, offset + 19)),
            unknown: Int(sqlite3_column_int64(statement, offset + 20))
        )
        let tokenAccounting: TokenUsageAccounting?
        if let uncachedInputTokens = optionalColumnInt(statement, offset + 21),
           let cacheCreationInputTokens = optionalColumnInt(statement, offset + 22),
           let cacheReadInputTokens = optionalColumnInt(statement, offset + 23),
           let reasoningOutputTokens = optionalColumnInt(statement, offset + 24) {
            tokenAccounting = TokenUsageAccounting(
                uncachedInputTokens: uncachedInputTokens,
                cacheCreationInputTokens: cacheCreationInputTokens,
                cacheReadInputTokens: cacheReadInputTokens,
                reasoningOutputTokens: reasoningOutputTokens
            )
        } else {
            tokenAccounting = nil
        }
        let event = TokenUsageEvent(
            schemaVersion: 1,
            deviceID: deviceID,
            projectID: projectID,
            artifactID: artifactID,
            runID: runID,
            spanID: spanID,
            aiTool: aiTool,
            taskType: taskType,
            stage: stage,
            model: model,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            totalTokens: totalTokens,
            tokenBreakdown: tokenBreakdown,
            tokenAccounting: tokenAccounting,
            latencyMS: latencyMS,
            createdAt: createdAt
        )
        guard (try? event.validate()) != nil else {
            return nil
        }
        return event
    }

    static func columnString(_ statement: OpaquePointer, _ index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let text = sqlite3_column_text(statement, index)
        else {
            return nil
        }
        return String(cString: text)
    }

    static func optionalColumnInt(_ statement: OpaquePointer, _ index: Int32) -> Int? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return Int(sqlite3_column_int64(statement, index))
    }

}
