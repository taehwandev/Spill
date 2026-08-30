import Foundation
import SQLite3
import XCTest
@testable import Spill

final class TokenUsageStoreSchemaTests: XCTestCase {
    func testSameStorePreparesSchemaAfterDatabaseFileIsRecreated() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TokenUsageStoreSchemaTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let store = TokenUsageStore(fileURL: directoryURL.appendingPathComponent("events.json"))
        _ = try store.appendEvent(Self.event(spanID: "span_schema_01"))
        XCTAssertEqual(store.loadEvents().map(\.spanID), ["span_schema_01"])

        try removeSQLiteFiles(at: store.eventsDatabaseURL)

        _ = try store.appendEvent(Self.event(spanID: "span_schema_02"))

        XCTAssertEqual(store.loadEvents().map(\.spanID), ["span_schema_02"])
    }

    func testVersionElevenSeedsPrivateUsageChangeJournalFromExistingEvents() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TokenUsageStoreSchemaTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let fileURL = directoryURL.appendingPathComponent("events.json")
        let initialStore = TokenUsageStore(fileURL: fileURL)
        try initialStore.appendEvent(Self.event(spanID: "span_schema_backfill"))

        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open(initialStore.eventsDatabaseURL.path, &database), SQLITE_OK)
        let downgradeSQL = """
        DROP TRIGGER IF EXISTS token_usage_events_private_usage_insert;
        DROP TRIGGER IF EXISTS token_usage_events_private_usage_update;
        DROP TRIGGER IF EXISTS token_usage_events_private_usage_delete;
        DROP TABLE IF EXISTS private_usage_event_changes;
        PRAGMA user_version = 10;
        """
        XCTAssertEqual(sqlite3_exec(database, downgradeSQL, nil, nil, nil), SQLITE_OK)
        sqlite3_close(database)

        let migratedStore = TokenUsageStore(fileURL: fileURL)
        let changes = migratedStore.loadPrivateUsageEventChanges(afterChangeID: 0)

        XCTAssertEqual(changes.changes.map(\.eventCreatedAt), ["2026-06-07T04:00:00.000Z"])
        XCTAssertGreaterThan(changes.maxChangeID, 0)
    }

    func testVersionTwelveRollupSeedsWhenVersionThirteenPredatesItsTable() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TokenUsageStoreSchemaTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let fileURL = directoryURL.appendingPathComponent("events.json")
        let initialStore = TokenUsageStore(fileURL: fileURL)
        try initialStore.appendEvent(Self.event(spanID: "span_rollup", inputTokens: 7, outputTokens: 3))

        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open(initialStore.eventsDatabaseURL.path, &database), SQLITE_OK)
        let downgradeSQL = """
        DROP TRIGGER IF EXISTS token_usage_dashboard_daily_totals_insert;
        DROP TRIGGER IF EXISTS token_usage_dashboard_daily_totals_update;
        DROP TRIGGER IF EXISTS token_usage_dashboard_daily_totals_delete;
        DROP TABLE IF EXISTS token_usage_dashboard_daily_totals;
        PRAGMA user_version = 13;
        """
        XCTAssertEqual(sqlite3_exec(database, downgradeSQL, nil, nil, nil), SQLITE_OK)
        sqlite3_close(database)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let now = try XCTUnwrap(ISO8601DateFormatter.parseTokenUsageDate(from: "2026-06-08T12:00:00.000Z"))
        let migratedStore = TokenUsageStore(fileURL: fileURL)

        XCTAssertEqual(
            migratedStore.allPeriodInputScopeTotals(now: now, calendar: calendar)[.all],
            TokenUsageInputScopeTotals(includeCache: 10, freshOnly: 3)
        )

        try migratedStore.appendEvent(Self.event(spanID: "span_rollup", inputTokens: 17, outputTokens: 3))
        XCTAssertEqual(
            migratedStore.allPeriodInputScopeTotals(now: now, calendar: calendar)[.all],
            TokenUsageInputScopeTotals(includeCache: 20, freshOnly: 3)
        )

        try migratedStore.clearEvents()
        XCTAssertEqual(
            migratedStore.allPeriodInputScopeTotals(now: now, calendar: calendar)[.all],
            .zero
        )
    }

    private func removeSQLiteFiles(at databaseURL: URL) throws {
        let sidecarURLs = [
            databaseURL,
            URL(fileURLWithPath: "\(databaseURL.path)-wal"),
            URL(fileURLWithPath: "\(databaseURL.path)-shm")
        ]

        for url in sidecarURLs where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private static func event(
        spanID: String,
        inputTokens: Int = 7,
        outputTokens: Int = 3
    ) -> TokenUsageEvent {
        TokenUsageEvent(
            schemaVersion: 1,
            deviceID: "device_schema",
            projectID: "project_schema",
            artifactID: "artifact_schema",
            runID: "run_schema",
            spanID: spanID,
            aiTool: .codex,
            taskType: "testing",
            stage: "verify",
            model: "test-model",
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            totalTokens: inputTokens + outputTokens,
            tokenBreakdown: TokenUsageBreakdown(
                system: 0,
                user: 0,
                history: 0,
                repoContext: 0,
                toolOutput: 0,
                generatedOutput: 0,
                unknown: inputTokens + outputTokens
            ),
            latencyMS: 0,
            createdAt: "2026-06-07T04:00:00.000Z"
        )
    }
}
