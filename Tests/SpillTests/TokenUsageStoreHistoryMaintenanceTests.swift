import Foundation
import SQLite3
import XCTest
@testable import Spill

/// The whole-history backfill must run once per store, not on every open: on a
/// populated store the per-open scan read the entire event table to find nothing.
final class TokenUsageStoreHistoryMaintenanceTests: XCTestCase {
    func testHistoryMaintenanceRunsOnceAndIsSkippedOnLaterOpens() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TokenUsageStoreHistoryMaintenanceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let fileURL = directoryURL.appendingPathComponent("events.json")
        let initialStore = TokenUsageStore(fileURL: fileURL)
        try initialStore.appendEvent(Self.event(spanID: "span_history_maintenance"))
        let databasePath = initialStore.eventsDatabaseURL.path

        // A fresh store lands on the maintenance version after its first open.
        XCTAssertEqual(
            try Self.userVersion(at: databasePath),
            TokenUsageStore.historyMaintenanceUserVersion
        )

        // Blank a dashboard column the backfill would restore. A new store instance
        // (fresh schema checkpoint) must open WITHOUT re-running the backfill.
        try Self.execute("UPDATE token_usage_events SET model = NULL", at: databasePath)
        let reopenedStore = TokenUsageStore(fileURL: fileURL)
        _ = reopenedStore.loadEvents() // forces the open on a fresh schema checkpoint
        XCTAssertTrue(try Self.modelIsNull(at: databasePath), "per-open backfill must not run on a current store")

        // Rewinding the version below the gate makes the next open run it exactly once.
        try Self.execute(
            "PRAGMA user_version = \(TokenUsageStore.historyMaintenanceUserVersion - 1)",
            at: databasePath
        )
        let migratedStore = TokenUsageStore(fileURL: fileURL)
        _ = migratedStore.loadEvents()
        XCTAssertFalse(try Self.modelIsNull(at: databasePath), "gated backfill must restore the column once")
        XCTAssertEqual(
            try Self.userVersion(at: databasePath),
            TokenUsageStore.historyMaintenanceUserVersion
        )
    }

    private static func execute(_ sql: String, at path: String) throws {
        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open(path, &database), SQLITE_OK)
        defer { sqlite3_close(database) }
        XCTAssertEqual(sqlite3_exec(database, sql, nil, nil, nil), SQLITE_OK)
    }

    private static func userVersion(at path: String) throws -> Int {
        try scalar("PRAGMA user_version", at: path)
    }

    private static func modelIsNull(at path: String) throws -> Bool {
        try scalar("SELECT COUNT(*) FROM token_usage_events WHERE model IS NULL", at: path) == 1
    }

    private static func scalar(_ sql: String, at path: String) throws -> Int {
        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open(path, &database), SQLITE_OK)
        defer { sqlite3_close(database) }
        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(database, sql, -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
        return Int(sqlite3_column_int64(statement, 0))
    }

    private static func event(spanID: String) -> TokenUsageEvent {
        TokenUsageEvent(
            schemaVersion: 1,
            deviceID: "device_local_01",
            projectID: "project_global",
            artifactID: "artifact_global",
            runID: "run_local_01",
            spanID: spanID,
            aiTool: .claude,
            taskType: .analysis,
            stage: .implement,
            model: "claude-fable-5",
            inputTokens: 90,
            outputTokens: 10,
            totalTokens: 100,
            tokenBreakdown: TokenUsageBreakdown(
                system: 0, user: 0, history: 0, repoContext: 0,
                toolOutput: 0, generatedOutput: 0, unknown: 100
            ),
            latencyMS: 100,
            createdAt: "2026-06-07T04:00:00.000Z"
        )
    }
}
