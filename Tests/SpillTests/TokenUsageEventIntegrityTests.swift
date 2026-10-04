import Foundation
import SQLite3
import XCTest
@testable import Spill

final class TokenUsageEventIntegrityTests: XCTestCase {
    func testLegacyTimeWindowMigrationPreservesDistinctSameCountTurns() throws {
        try withStore { store in
            let events = [
                event(spanID: "span_integrity_first", createdAt: "2026-06-05T00:00:00.000Z"),
                event(spanID: "span_integrity_second", createdAt: "2026-06-05T00:01:00.000Z")
            ]
            try assertMigrationPreserves(events, version: 9, store: store)
        }
    }

    func testLegacyTimeWindowMigrationPreservesDifferentToolsAndStages() throws {
        try withStore { store in
            let events = [
                event(spanID: "span_integrity_analysis", createdAt: "2026-06-05T00:00:00.000Z"),
                event(
                    spanID: "span_integrity_implement", stage: .implement,
                    createdAt: "2026-06-05T00:01:00.000Z"
                ),
                event(
                    spanID: "span_integrity_codex", aiTool: .codex,
                    createdAt: "2026-06-05T00:02:00.000Z"
                )
            ]
            try assertMigrationPreserves(events, version: 9, store: store)
        }
    }

    func testLegacyContentMigrationPreservesDistinctSpanIdentities() throws {
        try withStore { store in
            let events = [event(spanID: "span_integrity_request_a"), event(spanID: "span_integrity_request_b")]
            try assertMigrationPreserves(events, version: 2, store: store)
        }
    }

    func testSameSpanDecreaseWithoutAccountingRemainsReadableWithUnknownDetail() throws {
        try assertChangedTotalsClearPriorAccounting(input: 25, output: 7)
    }

    func testSameSpanIncreaseWithoutAccountingDoesNotReusePriorAttribution() throws {
        try assertChangedTotalsClearPriorAccounting(input: 225, output: 7)
    }

    func testSameSpanOutputChangeWithoutAccountingDoesNotReusePriorAttribution() throws {
        try assertChangedTotalsClearPriorAccounting(input: 125, output: 9)
    }

    func testSameSpanUnchangedTotalsPreservePriorExactAccountingAndGrouping() throws {
        try withStore { store in
            let accounting = TokenUsageAccounting(
                uncachedInputTokens: 20, cacheCreationInputTokens: 5,
                cacheReadInputTokens: 100, reasoningOutputTokens: 3
            )
            try store.appendEvent(event(spanID: "span_integrity_merge", accounting: accounting))
            _ = try store.appendEventsWithoutLoading([
                event(spanID: "span_integrity_merge", stage: .implement)
            ])
            let stored = try XCTUnwrap(store.loadEvents().first)
            XCTAssertEqual(stored.tokenAccounting, accounting)
            XCTAssertEqual(stored.stage, .classify)
            XCTAssertNoThrow(try stored.validate())
        }
    }

    func testSameSpanIncomingExactAccountingReplacesPriorDetailWithNewTotals() throws {
        try withStore { store in
            let previous = TokenUsageAccounting(uncachedInputTokens: 25, cacheReadInputTokens: 100)
            let replacement = TokenUsageAccounting(uncachedInputTokens: 10, cacheReadInputTokens: 15)
            try store.appendEvent(event(spanID: "span_integrity_merge", accounting: previous))
            _ = try store.appendEventsWithoutLoading([
                event(spanID: "span_integrity_merge", input: 25, accounting: replacement, stage: .implement)
            ])
            let stored = try XCTUnwrap(store.loadEvents().first)
            XCTAssertEqual(stored.inputTokens, 25)
            XCTAssertEqual(stored.tokenAccounting, replacement)
            XCTAssertEqual(stored.stage, .classify)
            XCTAssertNoThrow(try stored.validate())
        }
    }

    private func assertMigrationPreserves(_ events: [TokenUsageEvent], version: Int, store: TokenUsageStore) throws {
        try store.replaceEvents(events)
        let database = try store.openDatabase()
        try store.execute("PRAGMA user_version = \(version)", database: database)
        sqlite3_close(database)
        let reopened = TokenUsageStore(fileURL: store.eventsFileURL)
        XCTAssertEqual(Set(reopened.loadEvents().map(\.spanID)), Set(events.map(\.spanID)))
        let migratedDatabase = try reopened.openDatabase()
        defer { sqlite3_close(migratedDatabase) }
        XCTAssertEqual(reopened.databaseUserVersion(database: migratedDatabase), TokenUsageStore.historyMaintenanceUserVersion)
    }

    private func assertChangedTotalsClearPriorAccounting(input: Int, output: Int) throws {
        try withStore { store in
            let previous = TokenUsageAccounting(
                uncachedInputTokens: 20, cacheCreationInputTokens: 5,
                cacheReadInputTokens: 100, reasoningOutputTokens: 3
            )
            try store.appendEvent(event(spanID: "span_integrity_merge", accounting: previous))
            _ = try store.appendEventsWithoutLoading([
                event(spanID: "span_integrity_merge", input: input, output: output, stage: .implement)
            ])
            let stored = try XCTUnwrap(store.loadEvents().first)
            XCTAssertEqual(stored.inputTokens, input)
            XCTAssertEqual(stored.outputTokens, output)
            XCTAssertNil(stored.tokenAccounting)
            XCTAssertEqual(stored.stage, .classify)
            XCTAssertNoThrow(try stored.validate())

            let database = try store.openDatabase()
            defer { sqlite3_close(database) }
            var statement: OpaquePointer?
            let sql = """
            SELECT COUNT(*) FROM token_usage_events
            WHERE accounting_uncached_input_tokens IS NULL
              AND accounting_cache_creation_input_tokens IS NULL
              AND accounting_cache_read_input_tokens IS NULL
              AND accounting_reasoning_output_tokens IS NULL
            """
            XCTAssertEqual(sqlite3_prepare_v2(database, sql, -1, &statement, nil), SQLITE_OK)
            defer { sqlite3_finalize(statement) }
            XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
            XCTAssertEqual(sqlite3_column_int(statement, 0), 1)
        }
    }

    private func withStore(_ body: (TokenUsageStore) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(TokenUsageStore(fileURL: directory.appendingPathComponent("events.json")))
    }

    private func event(
        spanID: String, input: Int = 125, output: Int = 7,
        accounting: TokenUsageAccounting? = nil, aiTool: TokenUsageAITool = .claude,
        stage: TokenUsageStage = .classify, createdAt: String = "2026-06-05T00:00:00.000Z"
    ) -> TokenUsageEvent {
        TokenUsageEvent(
            schemaVersion: 1, deviceID: "device_integrity", projectID: "project_integrity",
            artifactID: "artifact_integrity", runID: "run_integrity", spanID: spanID, aiTool: aiTool,
            taskType: .analysis, stage: stage, model: "test-model", inputTokens: input,
            outputTokens: output, totalTokens: input + output,
            tokenBreakdown: TokenUsageBreakdown(
                system: 0, user: 0, history: 0, repoContext: 0, toolOutput: 0,
                generatedOutput: output, unknown: input
            ),
            tokenAccounting: accounting, latencyMS: 0, createdAt: createdAt
        )
    }
}
