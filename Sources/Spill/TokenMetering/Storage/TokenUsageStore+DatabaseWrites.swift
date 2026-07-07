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

    private static let insertEventSQL = """
        INSERT INTO token_usage_events (
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
            accounting_uncached_input_tokens,
            accounting_cache_creation_input_tokens,
            accounting_cache_read_input_tokens,
            accounting_reasoning_output_tokens,
            total_tokens,
            payload_json
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(span_id) DO UPDATE SET
            input_tokens = excluded.input_tokens,
            output_tokens = excluded.output_tokens,
            latency_ms = excluded.latency_ms,
            source_system = excluded.source_system,
            source_user = excluded.source_user,
            source_history = excluded.source_history,
            source_repo_context = excluded.source_repo_context,
            source_tool_output = excluded.source_tool_output,
            source_generated_output = excluded.source_generated_output,
            source_unknown = excluded.source_unknown,
            accounting_uncached_input_tokens = COALESCE(
                excluded.accounting_uncached_input_tokens,
                token_usage_events.accounting_uncached_input_tokens
            ),
            accounting_cache_creation_input_tokens = COALESCE(
                excluded.accounting_cache_creation_input_tokens,
                token_usage_events.accounting_cache_creation_input_tokens
            ),
            accounting_cache_read_input_tokens = COALESCE(
                excluded.accounting_cache_read_input_tokens,
                token_usage_events.accounting_cache_read_input_tokens
            ),
            accounting_reasoning_output_tokens = COALESCE(
                excluded.accounting_reasoning_output_tokens,
                token_usage_events.accounting_reasoning_output_tokens
            ),
            total_tokens = excluded.total_tokens,
            payload_json = json_set(
                CAST(token_usage_events.payload_json AS TEXT),
                '$.input_tokens', excluded.input_tokens,
                '$.output_tokens', excluded.output_tokens,
                '$.latency_ms', excluded.latency_ms,
                '$.total_tokens', excluded.total_tokens,
                '$.token_breakdown.system', excluded.source_system,
                '$.token_breakdown.user', excluded.source_user,
                '$.token_breakdown.history', excluded.source_history,
                '$.token_breakdown.repo_context', excluded.source_repo_context,
                '$.token_breakdown.tool_output', excluded.source_tool_output,
                '$.token_breakdown.generated_output', excluded.source_generated_output,
                '$.token_breakdown.unknown', excluded.source_unknown
            )
        WHERE token_usage_events.ai_tool IN ('codex', 'claude', 'antigravity')
            AND excluded.ai_tool = token_usage_events.ai_tool
            AND (
                token_usage_events.input_tokens != excluded.input_tokens
                OR token_usage_events.output_tokens != excluded.output_tokens
                OR token_usage_events.latency_ms != excluded.latency_ms
                OR token_usage_events.source_system != excluded.source_system
                OR token_usage_events.source_user != excluded.source_user
                OR token_usage_events.source_history != excluded.source_history
                OR token_usage_events.source_repo_context != excluded.source_repo_context
                OR token_usage_events.source_tool_output != excluded.source_tool_output
                OR token_usage_events.source_generated_output != excluded.source_generated_output
                OR token_usage_events.source_unknown != excluded.source_unknown
                OR (
                    excluded.accounting_uncached_input_tokens IS NOT NULL
                    AND IFNULL(token_usage_events.accounting_uncached_input_tokens, -1) != excluded.accounting_uncached_input_tokens
                )
                OR (
                    excluded.accounting_cache_creation_input_tokens IS NOT NULL
                    AND IFNULL(token_usage_events.accounting_cache_creation_input_tokens, -1) != excluded.accounting_cache_creation_input_tokens
                )
                OR (
                    excluded.accounting_cache_read_input_tokens IS NOT NULL
                    AND IFNULL(token_usage_events.accounting_cache_read_input_tokens, -1) != excluded.accounting_cache_read_input_tokens
                )
                OR (
                    excluded.accounting_reasoning_output_tokens IS NOT NULL
                    AND IFNULL(token_usage_events.accounting_reasoning_output_tokens, -1) != excluded.accounting_reasoning_output_tokens
                )
                OR token_usage_events.total_tokens != excluded.total_tokens
            )
        """

    func insertEvent(_ event: TokenUsageEvent, database: OpaquePointer) throws -> Int {
        try event.validate()

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, Self.insertEventSQL, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            throw TokenUsageStoreError.databaseWriteFailed
        }
        defer { sqlite3_finalize(statement) }

        let payload = try TokenUsageSanitizer.eventData(event)
        bindInsertEvent(event, payload: payload, to: statement)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw TokenUsageStoreError.databaseWriteFailed
        }
        return Int(sqlite3_changes(database))
    }

    private func bindInsertEvent(_ event: TokenUsageEvent, payload: Data, to statement: OpaquePointer) {
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
        bindOptionalInt(event.tokenAccounting?.uncachedInputTokens, to: statement, at: 21)
        bindOptionalInt(event.tokenAccounting?.cacheCreationInputTokens, to: statement, at: 22)
        bindOptionalInt(event.tokenAccounting?.cacheReadInputTokens, to: statement, at: 23)
        bindOptionalInt(event.tokenAccounting?.reasoningOutputTokens, to: statement, at: 24)
        sqlite3_bind_int64(statement, 25, sqlite3_int64(event.totalTokens))
        _ = payload.withUnsafeBytes { buffer in
            sqlite3_bind_blob(statement, 26, buffer.baseAddress, Int32(buffer.count), SQLITE_TRANSIENT)
        }
    }

    private func bindOptionalInt(_ value: Int?, to statement: OpaquePointer, at index: Int32) {
        if let value {
            sqlite3_bind_int64(statement, index, sqlite3_int64(value))
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

}
