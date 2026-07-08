import Foundation
import SQLite3

extension TokenUsageStore {
    /// Returns the current maximum `rowid` for stored events of `aiTool`, or `0` if none
    /// exist. Callers capture this immediately before starting a long-running full rescan
    /// so that `reconcileClaudeSessions` can later exclude any row inserted after that
    /// point — see the `notInsertedAfterRowID` parameter there for why this matters.
    func maxRowID(forAITool aiTool: TokenUsageAITool) -> Int64 {
        guard let database = try? openDatabase() else {
            return 0
        }
        defer { sqlite3_close(database) }

        let sql = "SELECT COALESCE(MAX(rowid), 0) FROM token_usage_events WHERE ai_tool = ?"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return 0
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, aiTool.rawValue, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(statement) == SQLITE_ROW else {
            return 0
        }
        return sqlite3_column_int64(statement, 0)
    }

    /// Reconciles stored Claude events against the authoritative set produced by a full
    /// (`--all`) Claude history re-scan.
    ///
    /// The stable span_id formula (`sha256(run_id:model:requestId:span_input:output)`)
    /// makes every real turn hash to a single span_id, so a fresh full scan lists the
    /// complete, canonical set of span_ids for each session still on disk. Any stored
    /// Claude event whose `run_id` was re-scanned but whose `span_id` is not in that
    /// session's authoritative set is a pre-stable-span_id duplicate (old formulas mixed
    /// `turn_index`/`timestamp` into the hash) and is deleted here.
    ///
    /// Sessions whose transcripts are no longer on disk are absent from
    /// `authoritativeSpanIDsByRun` and are left completely untouched, so historical usage
    /// from removed transcripts is preserved.
    ///
    /// - Parameters:
    ///   - authoritativeSpanIDsByRun: run_id → the set of canonical span_ids the full scan
    ///     emitted for that session. Callers should exclude any run_id whose canonical
    ///     replacement events did not get successfully queued for insert, so a stale row is
    ///     never deleted without a confirmed replacement on the way in.
    ///   - notInsertedAfterRowID: rows with a higher rowid than this are never considered
    ///     for deletion. The scan subprocess that produced `authoritativeSpanIDsByRun` can
    ///     run for several seconds; a live Stop-hook turn for one of the very sessions being
    ///     rescanned can land in the database *during* that window, after the scan already
    ///     read past that transcript file. Such a turn's span_id would be legitimately
    ///     absent from this reconciliation's authoritative set even though it is not stale.
    ///     Capturing the max rowid immediately before starting the scan and passing it here
    ///     protects every row written during (or after) the scan from being swept up as if
    ///     it were a pre-stable-span_id duplicate.
    /// - Returns: the number of stale rows deleted.
    @discardableResult
    func reconcileClaudeSessions(
        authoritativeSpanIDsByRun: [String: Set<String>],
        notInsertedAfterRowID cutoffRowID: Int64
    ) -> Int {
        let scannedRuns = authoritativeSpanIDsByRun.filter { !$0.key.isEmpty }
        guard !scannedRuns.isEmpty else {
            return 0
        }

        return lock.withLock {
            guard let database = try? openDatabase() else {
                return 0
            }
            defer { sqlite3_close(database) }

            do {
                try execute("BEGIN IMMEDIATE TRANSACTION", database: database)
                try execute(
                    """
                    CREATE TEMP TABLE IF NOT EXISTS claude_reconcile_authoritative (
                        run_id TEXT NOT NULL,
                        span_id TEXT NOT NULL
                    )
                    """,
                    database: database
                )
                try execute("DELETE FROM claude_reconcile_authoritative", database: database)
                try insertAuthoritativePairs(scannedRuns, database: database)

                let deleted = try deleteStaleClaudeEvents(cutoffRowID: cutoffRowID, database: database)

                try execute("DROP TABLE IF EXISTS claude_reconcile_authoritative", database: database)
                try execute("COMMIT", database: database)
                return deleted
            } catch {
                try? execute("ROLLBACK", database: database)
                try? execute("DROP TABLE IF EXISTS claude_reconcile_authoritative", database: database)
                return 0
            }
        }
    }

    private func insertAuthoritativePairs(
        _ pairs: [String: Set<String>],
        database: OpaquePointer
    ) throws {
        let sql = "INSERT INTO claude_reconcile_authoritative (run_id, span_id) VALUES (?, ?)"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            throw TokenUsageStoreError.databaseWriteFailed
        }
        defer { sqlite3_finalize(statement) }

        for (runID, spanIDs) in pairs {
            for spanID in spanIDs {
                sqlite3_bind_text(statement, 1, runID, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(statement, 2, spanID, -1, SQLITE_TRANSIENT)
                guard sqlite3_step(statement) == SQLITE_DONE else {
                    throw TokenUsageStoreError.databaseWriteFailed
                }
                sqlite3_reset(statement)
            }
        }
    }

    private func deleteStaleClaudeEvents(cutoffRowID: Int64, database: OpaquePointer) throws -> Int {
        // Delete Claude events for every re-scanned session whose span_id is not in that
        // session's authoritative set. Restricting the run_id join to sessions present in
        // the authoritative table guarantees removed-transcript sessions are never touched.
        // The rowid cutoff guarantees rows written concurrently with (or after) the scan
        // that produced the authoritative set are never touched either — see
        // notInsertedAfterRowID's documentation on reconcileClaudeSessions.
        let sql = """
        DELETE FROM token_usage_events
        WHERE ai_tool = 'claude'
          AND rowid <= ?
          AND run_id IN (SELECT DISTINCT run_id FROM claude_reconcile_authoritative)
          AND span_id NOT IN (
              SELECT span_id FROM claude_reconcile_authoritative
              WHERE claude_reconcile_authoritative.run_id = token_usage_events.run_id
          )
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            throw TokenUsageStoreError.databaseWriteFailed
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, cutoffRowID)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw TokenUsageStoreError.databaseWriteFailed
        }
        return Int(sqlite3_changes(database))
    }
}
