import Foundation
import SQLite3

extension TokenUsageStore {
    /// Schema version stamped once the one-time history maintenance below has run.
    /// Must stay above every version written by `prepareDatabaseMigrations` and
    /// `prepareDashboardDailyRollups`; bump it only when a new whole-history pass is
    /// genuinely required.
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

    func removeContentDuplicateEvents(database: OpaquePointer) throws {
        // Removes exact-content duplicates sharing (run_id, ai_tool, task_type, stage,
        // created_at, input_tokens, output_tokens). ai_tool, task_type, and stage are
        // included so events from different tools or workflow stages with the same token
        // counts are never incorrectly merged.
        let sql = """
        DELETE FROM token_usage_events
        WHERE rowid IN (
            SELECT rowid FROM (
                SELECT
                    rowid,
                    ROW_NUMBER() OVER (
                        PARTITION BY run_id, ai_tool, task_type, stage,
                                     created_at, input_tokens, output_tokens
                        ORDER BY
                            CASE WHEN accounting_uncached_input_tokens IS NOT NULL THEN 0 ELSE 1 END,
                            rowid
                    ) AS rn
                FROM token_usage_events
                WHERE run_id IS NOT NULL AND run_id != ''
                    AND input_tokens IS NOT NULL
                    AND output_tokens IS NOT NULL
            )
            WHERE rn > 1
        )
        """
        try execute(sql, database: database)
    }

    func removeTimeWindowDuplicateEvents(database: OpaquePointer, windowSeconds: Int = 30) throws {
        // Catches Bug #2 duplicates: Claude Code writes the same requestId 2-3x to the
        // transcript with slightly different timestamps (typically 1-5 s apart). Each
        // incremental Stop hook read creates a new event with a different span-id but the
        // same (run_id, input_tokens, output_tokens). All such events use span- format, so
        // span-id prefix discrimination cannot distinguish them.
        // Strategy: delete e1 when a "better" e2 exists with the same content within windowSeconds:
        //   - better = has accounting data and e1 does not, OR
        //   - equal accounting presence but e2.rowid < e1.rowid (keep the earliest write).
        let sql = """
        DELETE FROM token_usage_events
        WHERE rowid IN (
            SELECT e1.rowid
            FROM token_usage_events e1
            WHERE e1.run_id IS NOT NULL AND e1.run_id != ''
              AND e1.input_tokens IS NOT NULL
              AND e1.output_tokens IS NOT NULL
              AND EXISTS (
                  SELECT 1 FROM token_usage_events e2
                  WHERE e2.run_id = e1.run_id
                    AND e2.input_tokens = e1.input_tokens
                    AND e2.output_tokens = e1.output_tokens
                    AND e2.rowid != e1.rowid
                    AND ABS(
                        CAST(strftime('%s', e1.created_at) AS INTEGER) -
                        CAST(strftime('%s', e2.created_at) AS INTEGER)
                    ) <= \(windowSeconds)
                    AND (
                        (e2.accounting_uncached_input_tokens IS NOT NULL
                            AND e1.accounting_uncached_input_tokens IS NULL)
                        OR (
                            CASE WHEN e1.accounting_uncached_input_tokens IS NULL THEN 1 ELSE 0 END =
                            CASE WHEN e2.accounting_uncached_input_tokens IS NULL THEN 1 ELSE 0 END
                            AND e2.rowid < e1.rowid
                        )
                    )
              )
        )
        """
        try execute(sql, database: database)
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
