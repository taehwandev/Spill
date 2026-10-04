import Foundation
import SQLite3

extension TokenUsageStore {
    /// Schema version stamped once the one-time history maintenance below has run.
    /// Bump only when a new whole-history pass is genuinely required. Later
    /// targeted migrations may use a higher version without rerunning these scans.
    static let historyMaintenanceUserVersion = 13

    /// Runs the whole-history backfill and created_at normalization exactly once per
    /// store, gated on `user_version`. Both passes used to run on every database open:
    /// the backfill predicate touches seventeen columns that live in the same row
    /// record as `payload_json`, so checking it means reading the entire event table —
    /// about 1.2 s for ~330k events on a warm cache, longer cold — to find zero rows,
    /// because the insert path already fills every dashboard column. That per-open scan
    /// was the multi-second main-thread hang Sentry reported as the store grew.
    ///
    /// Returns true when the passes ran; the caller stamps the version only after the
    /// rest of the schema chain has completed, so an interrupted open retries the whole
    /// sequence next time instead of skipping migrations that never ran.
    func runOneTimeHistoryMaintenanceIfNeeded(database: OpaquePointer) throws -> Bool {
        guard databaseUserVersion(database: database) < Self.historyMaintenanceUserVersion else {
            return false
        }
        try backfillDashboardColumns(database: database)
        try normalizeStoredCreatedAtValues(database: database)
        return true
    }

    func backfillDashboardColumns(database: OpaquePointer) throws {
        let sql = """
        SELECT span_id, payload_json
        FROM token_usage_events
        WHERE run_id IS NULL
            OR device_id IS NULL
            OR project_id IS NULL
            OR artifact_id IS NULL
            OR task_type IS NULL
            OR stage IS NULL
            OR model IS NULL
            OR input_tokens IS NULL
            OR output_tokens IS NULL
            OR latency_ms IS NULL
            OR source_system IS NULL
            OR source_user IS NULL
            OR source_history IS NULL
            OR source_repo_context IS NULL
            OR source_tool_output IS NULL
            OR source_generated_output IS NULL
            OR source_unknown IS NULL
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            throw TokenUsageStoreError.databaseWriteFailed
        }
        defer { sqlite3_finalize(statement) }

        var events = [TokenUsageEvent]()
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let blob = sqlite3_column_blob(statement, 1) else {
                continue
            }
            let byteCount = Int(sqlite3_column_bytes(statement, 1))
            let data = Data(bytes: blob, count: byteCount)
            if let event = try? JSONDecoder().decode(TokenUsageEvent.self, from: data) {
                events.append(event)
            }
        }

        guard !events.isEmpty else {
            return
        }

        try withTransaction(.immediate, database: database) {
            for event in events {
                try updateDashboardColumns(for: event, database: database)
            }
        }
    }

    func normalizeStoredCreatedAtValues(database: OpaquePointer) throws {
        var updates = [(spanID: String, createdAt: String)]()
        do {
            let sql = """
            SELECT span_id, created_at
            FROM token_usage_events
            WHERE created_at NOT GLOB '????-??-??T??:??:??.???Z'
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
                  let statement
            else {
                throw TokenUsageStoreError.databaseWriteFailed
            }
            defer { sqlite3_finalize(statement) }

            while sqlite3_step(statement) == SQLITE_ROW {
                guard let spanIDText = sqlite3_column_text(statement, 0),
                      let createdAtText = sqlite3_column_text(statement, 1)
                else {
                    continue
                }

                let spanID = String(cString: spanIDText)
                let createdAt = String(cString: createdAtText)
                guard let normalizedCreatedAt = Self.normalizedCreatedAt(createdAt),
                      normalizedCreatedAt != createdAt
                else {
                    continue
                }

                updates.append((spanID: spanID, createdAt: normalizedCreatedAt))
            }
        }

        guard !updates.isEmpty else {
            return
        }

        try withTransaction(.immediate, database: database) {
            for update in updates {
                try updateCreatedAt(
                    spanID: update.spanID,
                    createdAt: update.createdAt,
                    database: database
                )
            }
        }
    }

    func updateCreatedAt(
        spanID: String,
        createdAt: String,
        database: OpaquePointer
    ) throws {
        let sql = """
        UPDATE token_usage_events
        SET created_at = ?
        WHERE span_id = ?
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            throw TokenUsageStoreError.databaseWriteFailed
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, createdAt, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, spanID, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw TokenUsageStoreError.databaseWriteFailed
        }
    }

    func updateDashboardColumns(for event: TokenUsageEvent, database: OpaquePointer) throws {
        let sql = """
        UPDATE token_usage_events
        SET device_id = ?,
            project_id = ?,
            artifact_id = ?,
            run_id = ?,
            task_type = ?,
            stage = ?,
            model = ?,
            input_tokens = ?,
            output_tokens = ?,
            latency_ms = ?,
            source_system = ?,
            source_user = ?,
            source_history = ?,
            source_repo_context = ?,
            source_tool_output = ?,
            source_generated_output = ?,
            source_unknown = ?
        WHERE span_id = ?
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            throw TokenUsageStoreError.databaseWriteFailed
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, event.deviceID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, event.projectID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 3, event.artifactID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 4, event.runID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 5, event.taskType.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 6, event.stage.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 7, event.model, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(statement, 8, sqlite3_int64(event.inputTokens))
        sqlite3_bind_int64(statement, 9, sqlite3_int64(event.outputTokens))
        sqlite3_bind_int64(statement, 10, sqlite3_int64(event.latencyMS))
        sqlite3_bind_int64(statement, 11, sqlite3_int64(event.tokenBreakdown.system))
        sqlite3_bind_int64(statement, 12, sqlite3_int64(event.tokenBreakdown.user))
        sqlite3_bind_int64(statement, 13, sqlite3_int64(event.tokenBreakdown.history))
        sqlite3_bind_int64(statement, 14, sqlite3_int64(event.tokenBreakdown.repoContext))
        sqlite3_bind_int64(statement, 15, sqlite3_int64(event.tokenBreakdown.toolOutput))
        sqlite3_bind_int64(statement, 16, sqlite3_int64(event.tokenBreakdown.generatedOutput))
        sqlite3_bind_int64(statement, 17, sqlite3_int64(event.tokenBreakdown.unknown))
        sqlite3_bind_text(statement, 18, event.spanID, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw TokenUsageStoreError.databaseWriteFailed
        }
    }
}
