import Foundation
import SQLite3

extension TokenUsageStore {
    func migrateLegacyJSONEventsIfNeeded(database: OpaquePointer) throws -> Bool {
        let legacyEvents = loadJSONEvents(from: fileURL)
        guard !legacyEvents.isEmpty else {
            return false
        }

        _ = try insertEvents(legacyEvents, database: database)
        try removeLegacyEventsFileWithoutLock()
        return true
    }

    func insertEvents(_ events: [TokenUsageEvent], database: OpaquePointer) throws -> Int {
        try execute("BEGIN IMMEDIATE TRANSACTION", database: database)
        var insertedCount = 0
        do {
            for event in events {
                insertedCount += try insertEvent(event, database: database)
            }
            try execute("COMMIT", database: database)
            return insertedCount
        } catch {
            try? execute("ROLLBACK", database: database)
            throw error
        }
    }

    func replaceDatabaseEvents(_ events: [TokenUsageEvent], database: OpaquePointer) throws {
        try execute("BEGIN IMMEDIATE TRANSACTION", database: database)
        do {
            try execute("DELETE FROM token_usage_events", database: database)
            for event in events {
                _ = try insertEvent(event, database: database)
            }
            try execute("COMMIT", database: database)
        } catch {
            try? execute("ROLLBACK", database: database)
            throw error
        }
    }

    func insertEvent(_ event: TokenUsageEvent, database: OpaquePointer) throws -> Int {
        try event.validate()

        let sql = """
        INSERT OR IGNORE INTO token_usage_events (
            span_id,
            device_id,
            project_id,
            artifact_id,
            run_id,
            created_at,
            ai_tool,
            task_type,
            stage,
            model,
            input_tokens,
            output_tokens,
            latency_ms,
            source_system,
            source_user,
            source_history,
            source_repo_context,
            source_tool_output,
            source_generated_output,
            source_unknown,
            total_tokens,
            payload_json
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            throw TokenUsageStoreError.databaseWriteFailed
        }
        defer { sqlite3_finalize(statement) }

        let payload = try TokenUsageSanitizer.eventData(event)
        sqlite3_bind_text(statement, 1, event.spanID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, event.deviceID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 3, event.projectID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 4, event.artifactID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 5, event.runID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(
            statement,
            6,
            Self.normalizedCreatedAt(event.createdAt) ?? event.createdAt,
            -1,
            SQLITE_TRANSIENT
        )
        sqlite3_bind_text(statement, 7, event.aiTool.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 8, event.taskType.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 9, event.stage.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 10, event.model, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(statement, 11, sqlite3_int64(event.inputTokens))
        sqlite3_bind_int64(statement, 12, sqlite3_int64(event.outputTokens))
        sqlite3_bind_int64(statement, 13, sqlite3_int64(event.latencyMS))
        sqlite3_bind_int64(statement, 14, sqlite3_int64(event.tokenBreakdown.system))
        sqlite3_bind_int64(statement, 15, sqlite3_int64(event.tokenBreakdown.user))
        sqlite3_bind_int64(statement, 16, sqlite3_int64(event.tokenBreakdown.history))
        sqlite3_bind_int64(statement, 17, sqlite3_int64(event.tokenBreakdown.repoContext))
        sqlite3_bind_int64(statement, 18, sqlite3_int64(event.tokenBreakdown.toolOutput))
        sqlite3_bind_int64(statement, 19, sqlite3_int64(event.tokenBreakdown.generatedOutput))
        sqlite3_bind_int64(statement, 20, sqlite3_int64(event.tokenBreakdown.unknown))
        sqlite3_bind_int64(statement, 21, sqlite3_int64(event.totalTokens))
        _ = payload.withUnsafeBytes { buffer in
            sqlite3_bind_blob(statement, 22, buffer.baseAddress, Int32(buffer.count), SQLITE_TRANSIENT)
        }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw TokenUsageStoreError.databaseWriteFailed
        }
        return Int(sqlite3_changes(database))
    }

}
