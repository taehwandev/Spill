import Foundation
import SQLite3

extension TokenUsageStore {
    func prepareDatabaseSchema(database: OpaquePointer) throws {
        try execute(
            """
            CREATE TABLE IF NOT EXISTS token_usage_events (
                span_id TEXT PRIMARY KEY NOT NULL,
                device_id TEXT,
                project_id TEXT,
                artifact_id TEXT,
                run_id TEXT,
                created_at TEXT NOT NULL,
                ai_tool TEXT NOT NULL,
                task_type TEXT,
                stage TEXT,
                model TEXT,
                input_tokens INTEGER,
                output_tokens INTEGER,
                latency_ms INTEGER,
                total_tokens INTEGER NOT NULL,
                payload_json BLOB NOT NULL
            )
            """,
            database: database
        )
        try ensureDashboardColumns(database: database)
        // Whole-history passes run once per store (see runOneTimeHistoryMaintenanceIfNeeded);
        // the version stamp lands at the end of this function so it also covers the chain below.
        let ranOneTimeHistoryMaintenance = try runOneTimeHistoryMaintenanceIfNeeded(database: database)
        try execute(
            """
            CREATE INDEX IF NOT EXISTS idx_token_usage_events_created_at
            ON token_usage_events(created_at)
            """,
            database: database
        )
        // Created before the user_version migration block below: removeTimeWindowDuplicateEvents
        // runs up to five times across versions 5-10 on a database that jumps straight from an
        // old version to the current one, and its correlated EXISTS subquery matches on exactly
        // (run_id, input_tokens, output_tokens). Without this index in place first, every one of
        // those passes falls back to a full table scan per candidate row on a table that can hold
        // hundreds of thousands of events — this was the root cause of a confirmed production
        // main-thread hang at app launch (see refreshMenuBarTokenTotalAsync). idx_token_usage_events_run_id
        // below becomes a redundant no-op once this broader index exists, but is left in place
        // since other queries reference it by name.
        try execute(
            """
            CREATE INDEX IF NOT EXISTS idx_token_usage_events_dedup_lookup
            ON token_usage_events(run_id, input_tokens, output_tokens)
            """,
            database: database
        )

        try prepareDatabaseMigrations(database: database)
        try preparePrivateUsageChangeTracking(database: database)

        try execute(
            """
            CREATE INDEX IF NOT EXISTS idx_token_usage_events_tool_created_at
            ON token_usage_events(ai_tool, created_at, total_tokens, input_tokens, output_tokens)
            """,
            database: database
        )
        try execute(
            """
            CREATE INDEX IF NOT EXISTS idx_token_usage_events_task_type_created_at
            ON token_usage_events(task_type, created_at, total_tokens)
            """,
            database: database
        )
        try execute(
            """
            CREATE INDEX IF NOT EXISTS idx_token_usage_events_stage_created_at
            ON token_usage_events(stage, created_at, total_tokens)
            """,
            database: database
        )
        try execute(
            """
            CREATE INDEX IF NOT EXISTS idx_token_usage_events_model_created_at
            ON token_usage_events(model, created_at, total_tokens)
            """,
            database: database
        )
        try execute(
            """
            CREATE INDEX IF NOT EXISTS idx_token_usage_events_run_id
            ON token_usage_events(run_id)
            """,
            database: database
        )
        try execute(
            """
            CREATE INDEX IF NOT EXISTS idx_token_usage_events_project_created_at
            ON token_usage_events(project_id, created_at, total_tokens)
            """,
            database: database
        )

        if ranOneTimeHistoryMaintenance {
            try execute(
                "PRAGMA user_version = \(Self.historyMaintenanceUserVersion)",
                database: database
            )
        }
    }

    private func prepareDatabaseMigrations(database: OpaquePointer) throws {
        let userVersion = databaseUserVersion(database: database)
        if userVersion < 2 {
            try execute("DROP INDEX IF EXISTS idx_token_usage_events_tool_created_at", database: database)
            try execute("DROP INDEX IF EXISTS idx_token_usage_events_task_type_created_at", database: database)
            try execute("DROP INDEX IF EXISTS idx_token_usage_events_stage_created_at", database: database)
            try execute("DROP INDEX IF EXISTS idx_token_usage_events_model_created_at", database: database)
            try execute("DROP INDEX IF EXISTS idx_token_usage_events_project_created_at", database: database)
            try execute("PRAGMA user_version = 2", database: database)
        }
        if userVersion < 3 {
            try removeContentDuplicateEvents(database: database)
            try execute("PRAGMA user_version = 3", database: database)
        }
        if userVersion < 5 {
            try removeTimeWindowDuplicateEvents(database: database)
            try execute("PRAGMA user_version = 5", database: database)
        }
        // user_version 6: re-run time-window dedup to catch Bug #2 duplicates that
        // accumulated after user_version 5 ran. The Swift active importer now tracks
        // emitted requestIds across batches (emitted_request_ids_by_source in state),
        // so this one-time pass cleans the residual same-day duplicates.
        if userVersion < 6 {
            try removeTimeWindowDuplicateEvents(database: database)
            try execute("PRAGMA user_version = 6", database: database)
        }
        // user_version 7: re-run time-window dedup to clean duplicates from the Python
        // Stop hook turn_index bug. The hook used relative turn_index (0 per batch) while
        // the Swift importer used cumulative absolute indices — same turn produced different
        // span_ids across the two paths. Draining 280 pending inbox files created ~694
        // extra events. The Python hook now persists next_turn_index so future span_ids
        // stay in sync with the Swift importer.
        if userVersion < 7 {
            try removeTimeWindowDuplicateEvents(database: database)
            try execute("PRAGMA user_version = 7", database: database)
        }
        // user_version 8: wider 120-second window dedup to catch cross-path duplicates
        // that fall outside the 30 s window. The Python history import ("Import All Once")
        // re-imported Claude sessions with correct absolute turn_index, creating events
        // that pair with the earlier wrong-turn_index Stop hook events at timestamp
        // differences up to ~90 s. Exact match on (run_id, input_tokens, output_tokens)
        // within 120 s is extremely unlikely to be two distinct legitimate turns.
        if userVersion < 8 {
            try removeTimeWindowDuplicateEvents(database: database, windowSeconds: 120)
            try execute("PRAGMA user_version = 8", database: database)
        }
        // user_version 9: fix "keep last vs keep first" span_id mismatch. Both
        // deduplicateAssistantTurns (Swift) and _deduplicate_transcript_turns (Python)
        // previously kept the LATER Bug #2 occurrence within a single batch, but the
        // cross-batch emittedRequestIDsBySource rule kept the FIRST. When two Bug #2
        // occurrences spanned different batches, the two paths chose different occurrences
        // → different turn_index AND timestamp → different span_id → both survived the DB
        // PRIMARY KEY check → duplicates. Both dedup functions now always keep the FIRST
        // occurrence, ensuring within-batch and cross-batch paths agree on the canonical
        // turn. Re-run wider dedup to clean residual duplicates from the old mismatch.
        if userVersion < 9 {
            try removeTimeWindowDuplicateEvents(database: database, windowSeconds: 120)
            try execute("PRAGMA user_version = 9", database: database)
        }
        // user_version 10: final cleanup after the requestId-stable span_id formula lands.
        // The new formula drops turnIndex and timestamp from the hash when requestId is
        // present — all Bug #2 occurrences now hash to the same span_id, so the DB PRIMARY
        // KEY blocks them at insert time going forward. Historical events in the DB still
        // carry the old timestamp-based span_ids (T1 and T2 for the same turn) with gaps
        // up to ~300 s. Use a 300 s window to eliminate the residual old pairs.
        if userVersion < 10 {
            try removeTimeWindowDuplicateEvents(database: database, windowSeconds: 300)
            try execute("PRAGMA user_version = 10", database: database)
        }
        if userVersion < 11 {
            try execute(
                """
                CREATE TABLE IF NOT EXISTS private_usage_event_changes (
                    change_id INTEGER PRIMARY KEY AUTOINCREMENT,
                    event_created_at TEXT NOT NULL
                )
                """,
                database: database
            )
            try execute(
                """
                INSERT INTO private_usage_event_changes (event_created_at)
                SELECT created_at FROM token_usage_events
                """,
                database: database
            )
            try execute("PRAGMA user_version = 11", database: database)
        }

    }

    private func preparePrivateUsageChangeTracking(database: OpaquePointer) throws {
        try execute(
            """
            CREATE TABLE IF NOT EXISTS private_usage_event_changes (
                change_id INTEGER PRIMARY KEY AUTOINCREMENT,
                event_created_at TEXT NOT NULL
            )
            """,
            database: database
        )
        try execute(
            """
            CREATE TRIGGER IF NOT EXISTS token_usage_events_private_usage_insert
            AFTER INSERT ON token_usage_events
            BEGIN
                INSERT INTO private_usage_event_changes (event_created_at)
                VALUES (NEW.created_at);
            END
            """,
            database: database
        )
        try execute(
            """
            CREATE TRIGGER IF NOT EXISTS token_usage_events_private_usage_update
            AFTER UPDATE ON token_usage_events
            BEGIN
                INSERT INTO private_usage_event_changes (event_created_at)
                VALUES (NEW.created_at);
            END
            """,
            database: database
        )
        try execute(
            """
            CREATE TRIGGER IF NOT EXISTS token_usage_events_private_usage_delete
            AFTER DELETE ON token_usage_events
            BEGIN
                INSERT INTO private_usage_event_changes (event_created_at)
                VALUES (OLD.created_at);
            END
            """,
            database: database
        )
    }

    func ensureDashboardColumns(database: OpaquePointer) throws {
        let existingColumns = databaseColumns(tableName: "token_usage_events", database: database)
        let requiredColumns: [(name: String, definition: String)] = [
            ("device_id", "TEXT"),
            ("project_id", "TEXT"),
            ("artifact_id", "TEXT"),
            ("run_id", "TEXT"),
            ("task_type", "TEXT"),
            ("stage", "TEXT"),
            ("model", "TEXT"),
            ("input_tokens", "INTEGER"),
            ("output_tokens", "INTEGER"),
            ("latency_ms", "INTEGER"),
            ("source_system", "INTEGER"),
            ("source_user", "INTEGER"),
            ("source_history", "INTEGER"),
            ("source_repo_context", "INTEGER"),
            ("source_tool_output", "INTEGER"),
            ("source_generated_output", "INTEGER"),
            ("source_unknown", "INTEGER"),
            ("accounting_uncached_input_tokens", "INTEGER"),
            ("accounting_cache_creation_input_tokens", "INTEGER"),
            ("accounting_cache_read_input_tokens", "INTEGER"),
            ("accounting_reasoning_output_tokens", "INTEGER")
        ]

        for column in requiredColumns where !existingColumns.contains(column.name) {
            try execute(
                "ALTER TABLE token_usage_events ADD COLUMN \(column.name) \(column.definition)",
                database: database
            )
        }
    }

    func databaseColumns(tableName: String, database: OpaquePointer) -> Set<String> {
        let sql = "PRAGMA table_info(\(tableName))"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        var columns = Set<String>()
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let columnName = sqlite3_column_text(statement, 1) else {
                continue
            }
            columns.insert(String(cString: columnName))
        }
        return columns
    }

}
