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
        try backfillDashboardColumns(database: database)
        try normalizeStoredCreatedAtValues(database: database)
        try execute(
            """
            CREATE INDEX IF NOT EXISTS idx_token_usage_events_created_at
            ON token_usage_events(created_at)
            """,
            database: database
        )

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
