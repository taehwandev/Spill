import Foundation
import SQLite3

extension TokenUsageStore {
    static let dashboardDailyRollupTable = "token_usage_dashboard_daily_totals"

    /// Keeps all-period chips proportional to days and tools rather than the
    /// complete event history. Triggers share the event write transaction.
    func prepareDashboardDailyRollups(database: OpaquePointer) throws {
        let userVersion = databaseUserVersion(database: database)
        let needsSeed = userVersion < 12 || !dashboardDailyRollupTableExists(database: database)
        if needsSeed {
            try withTransaction(.immediate, database: database) {
                try execute(
                    """
                    CREATE TABLE IF NOT EXISTS \(Self.dashboardDailyRollupTable) (
                        ai_tool TEXT NOT NULL,
                        utc_day TEXT NOT NULL,
                        event_count INTEGER NOT NULL,
                        total_tokens INTEGER NOT NULL,
                        fresh_tokens INTEGER NOT NULL,
                        PRIMARY KEY (ai_tool, utc_day)
                    ) WITHOUT ROWID
                    """,
                    database: database
                )
                try execute("DELETE FROM \(Self.dashboardDailyRollupTable)", database: database)
                try execute(
                    """
                    INSERT INTO \(Self.dashboardDailyRollupTable) (
                        ai_tool, utc_day, event_count, total_tokens, fresh_tokens
                    )
                    SELECT ai_tool,
                           substr(created_at, 1, 10),
                           COUNT(*),
                           COALESCE(SUM(total_tokens), 0),
                           COALESCE(SUM(\(Self.dashboardFreshTokenSQL)), 0)
                    FROM token_usage_events
                    GROUP BY ai_tool, substr(created_at, 1, 10)
                    """,
                    database: database
                )
                if userVersion < 12 {
                    try execute("PRAGMA user_version = 12", database: database)
                }
            }
        }

        try prepareDashboardDailyRollupTriggers(database: database)
    }

    private func dashboardDailyRollupTableExists(database: OpaquePointer) -> Bool {
        let sql = """
        SELECT 1
        FROM sqlite_master
        WHERE type = 'table'
          AND name = '\(Self.dashboardDailyRollupTable)'
        LIMIT 1
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return false
        }
        defer { sqlite3_finalize(statement) }
        return sqlite3_step(statement) == SQLITE_ROW
    }

    private func prepareDashboardDailyRollupTriggers(database: OpaquePointer) throws {
        let freshNew = "COALESCE(NEW.output_tokens + COALESCE(NEW.accounting_uncached_input_tokens, 0), 0)"
        let freshOld = "COALESCE(OLD.output_tokens + COALESCE(OLD.accounting_uncached_input_tokens, 0), 0)"

        try execute(
            """
            CREATE TRIGGER IF NOT EXISTS token_usage_dashboard_daily_totals_insert
            AFTER INSERT ON token_usage_events
            BEGIN
                INSERT INTO \(Self.dashboardDailyRollupTable) (
                    ai_tool, utc_day, event_count, total_tokens, fresh_tokens
                ) VALUES (
                    NEW.ai_tool, substr(NEW.created_at, 1, 10), 1,
                    NEW.total_tokens, \(freshNew)
                )
                ON CONFLICT(ai_tool, utc_day) DO UPDATE SET
                    event_count = event_count + 1,
                    total_tokens = total_tokens + NEW.total_tokens,
                    fresh_tokens = fresh_tokens + \(freshNew);
            END
            """,
            database: database
        )
        try execute(
            """
            CREATE TRIGGER IF NOT EXISTS token_usage_dashboard_daily_totals_delete
            AFTER DELETE ON token_usage_events
            BEGIN
                UPDATE \(Self.dashboardDailyRollupTable)
                SET event_count = event_count - 1,
                    total_tokens = total_tokens - OLD.total_tokens,
                    fresh_tokens = fresh_tokens - \(freshOld)
                WHERE ai_tool = OLD.ai_tool
                  AND utc_day = substr(OLD.created_at, 1, 10);
                DELETE FROM \(Self.dashboardDailyRollupTable)
                WHERE event_count <= 0;
            END
            """,
            database: database
        )
        try execute(
            """
            CREATE TRIGGER IF NOT EXISTS token_usage_dashboard_daily_totals_update
            AFTER UPDATE ON token_usage_events
            BEGIN
                UPDATE \(Self.dashboardDailyRollupTable)
                SET event_count = event_count - 1,
                    total_tokens = total_tokens - OLD.total_tokens,
                    fresh_tokens = fresh_tokens - \(freshOld)
                WHERE ai_tool = OLD.ai_tool
                  AND utc_day = substr(OLD.created_at, 1, 10);
                DELETE FROM \(Self.dashboardDailyRollupTable)
                WHERE event_count <= 0;
                INSERT INTO \(Self.dashboardDailyRollupTable) (
                    ai_tool, utc_day, event_count, total_tokens, fresh_tokens
                ) VALUES (
                    NEW.ai_tool, substr(NEW.created_at, 1, 10), 1,
                    NEW.total_tokens, \(freshNew)
                )
                ON CONFLICT(ai_tool, utc_day) DO UPDATE SET
                    event_count = event_count + 1,
                    total_tokens = total_tokens + NEW.total_tokens,
                    fresh_tokens = fresh_tokens + \(freshNew);
            END
            """,
            database: database
        )
    }
}
