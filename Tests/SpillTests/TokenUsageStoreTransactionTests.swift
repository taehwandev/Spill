import Foundation
import SQLite3
import XCTest
@testable import Spill

/// Covers the shared `withTransaction` helper that replaced the six hand-rolled
/// transaction sites in `TokenUsageStore`. The public round-trip proves the write flavor
/// still commits, and the raw-connection tests exercise the helper's rollback and its
/// deferred (read) BEGIN/COMMIT ordering directly.
final class TokenUsageStoreTransactionTests: XCTestCase {
    private enum TransactionTestError: Error {
        case injected
    }

    // MARK: - Write-path behavior preserved

    func testWritePathRoundTripStillCommits() throws {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())

        try store.appendEvent(Self.event(spanID: "span_txn_append"))
        XCTAssertEqual(store.loadEvents().map(\.spanID), ["span_txn_append"])

        try store.replaceEvents([
            Self.event(spanID: "span_txn_replace_a"),
            Self.event(spanID: "span_txn_replace_b")
        ])
        XCTAssertEqual(
            Set(store.loadEvents().map(\.spanID)),
            ["span_txn_replace_a", "span_txn_replace_b"]
        )
    }

    // MARK: - Rollback on failure

    func testImmediateTransactionRollsBackWhenBodyThrows() throws {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let (databaseURL, cleanup) = try makeRawDatabaseURL()
        defer { cleanup() }

        let database = try openRawDatabase(at: databaseURL)
        defer { sqlite3_close(database) }
        try store.execute("CREATE TABLE t (id INTEGER)", database: database)

        XCTAssertThrowsError(
            try store.withTransaction(.immediate, database: database) {
                try store.execute("INSERT INTO t (id) VALUES (1)", database: database)
                throw TransactionTestError.injected
            }
        ) { error in
            XCTAssertTrue(error is TransactionTestError)
        }

        // The row inserted mid-transaction must be gone: the body threw, so the helper
        // rolled the whole transaction back.
        XCTAssertEqual(rowCount(in: database, table: "t"), 0)
    }

    // MARK: - Deferred (read) flavor

    func testDeferredTransactionReturnsBodyResultAndClosesTransaction() throws {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let (databaseURL, cleanup) = try makeRawDatabaseURL()
        defer { cleanup() }

        let reader = try openRawDatabase(at: databaseURL)
        defer { sqlite3_close(reader) }
        try store.execute("CREATE TABLE t (id INTEGER)", database: reader)

        let result = try store.withTransaction(.deferred, database: reader) {
            try store.execute("SELECT COUNT(*) FROM t", database: reader)
            return 42
        }
        XCTAssertEqual(result, 42)

        // The deferred read transaction must have been committed (closed). A separate
        // connection with no busy timeout should acquire the write lock immediately; if the
        // helper had left the read transaction open, this write would fail with SQLITE_BUSY.
        let writer = try openRawDatabase(at: databaseURL)
        defer { sqlite3_close(writer) }
        XCTAssertEqual(
            sqlite3_exec(writer, "INSERT INTO t (id) VALUES (1)", nil, nil, nil),
            SQLITE_OK
        )
        XCTAssertEqual(rowCount(in: reader, table: "t"), 1)
    }

    // MARK: - Helpers

    private func temporaryEventsURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("events.json")
    }

    /// Returns a URL for a fresh SQLite file in its own temp directory plus a cleanup
    /// closure that removes the directory (and any WAL/SHM sidecars).
    private func makeRawDatabaseURL() throws -> (url: URL, cleanup: () -> Void) {
        let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let url = directoryURL.appendingPathComponent("transaction-test.db")
        return (url, { try? FileManager.default.removeItem(at: directoryURL) })
    }

    private func openRawDatabase(at url: URL) throws -> OpaquePointer {
        var database: OpaquePointer?
        guard sqlite3_open(url.path, &database) == SQLITE_OK, let database else {
            sqlite3_close(database)
            XCTFail("Failed to open raw SQLite database at \(url.path)")
            throw TransactionTestError.injected
        }
        return database
    }

    private func rowCount(in database: OpaquePointer, table: String) -> Int {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT COUNT(*) FROM \(table)", -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return -1
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return -1
        }
        return Int(sqlite3_column_int(statement, 0))
    }

    private static func event(spanID: String) -> TokenUsageEvent {
        TokenUsageEvent(
            schemaVersion: 1,
            deviceID: "device_txn",
            projectID: "project_txn",
            artifactID: "artifact_txn",
            runID: "run_txn",
            spanID: spanID,
            aiTool: .codex,
            taskType: "testing",
            stage: "verify",
            model: "test-model",
            inputTokens: 7,
            outputTokens: 3,
            totalTokens: 10,
            tokenBreakdown: TokenUsageBreakdown(
                system: 0,
                user: 0,
                history: 0,
                repoContext: 0,
                toolOutput: 0,
                generatedOutput: 0,
                unknown: 10
            ),
            latencyMS: 0,
            createdAt: "2026-06-07T04:00:00.000Z"
        )
    }
}
