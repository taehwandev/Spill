import Foundation
import SQLite3
import XCTest
@testable import Spill

private let TEST_AGY_SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class TokenUsageAntigravityImporterTests: XCTestCase {
    func testStableSpanIdentityIgnoresTokenCountChangesForSameGenerationRecord() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let conversationsURL = rootURL.appendingPathComponent("conversations", isDirectory: true)
        let databaseURL = conversationsURL.appendingPathComponent("conversation-a.db")
        let labelURL = rootURL.appendingPathComponent("labels/antigravity-timeline.jsonl")
        let diagnosticsURL = rootURL.appendingPathComponent("diagnostics/antigravity-active-importer-last.json")
        try writeAlwaysActiveLabel(at: labelURL)

        try writeAntigravityConversationDatabase(
            at: databaseURL,
            rows: [
                (
                    7,
                    antigravityGenerationMetadataBlob(
                        inputTokenChunks: [120],
                        outputTokenChunks: [34],
                        cachedInputTokenChunks: [56],
                        model: "gemini-3.5-flash-low"
                    )
                )
            ]
        )

        let store = TokenUsageStore(fileURL: rootURL.appendingPathComponent("events.json"))
        let importer = TokenUsageAntigravityImporter(
            conversationsDirectory: conversationsURL,
            labelTimelineURL: labelURL,
            diagnosticsURL: diagnosticsURL,
            stateURL: nil
        )

        let firstSummary = importer.importRecentEvents(into: store, since: Date(timeIntervalSince1970: 0))
        let firstEvent = try XCTUnwrap(store.loadEvents().first)

        XCTAssertEqual(firstSummary.importedEvents, 1)
        XCTAssertEqual(firstEvent.totalTokens, 210)

        try writeAntigravityConversationDatabase(
            at: databaseURL,
            rows: [
                (
                    7,
                    antigravityGenerationMetadataBlob(
                        inputTokenChunks: [240],
                        outputTokenChunks: [68],
                        cachedInputTokenChunks: [112],
                        model: "gemini-3.5-flash-low"
                    )
                )
            ]
        )

        let secondSummary = importer.importRecentEvents(into: store, since: Date(timeIntervalSince1970: 0))
        let events = store.loadEvents()

        XCTAssertEqual(secondSummary.parsedUsageEvents, 1)
        XCTAssertEqual(secondSummary.importedEvents, 0)
        XCTAssertEqual(secondSummary.skippedDuplicateEvents, 1)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].spanID, firstEvent.spanID)
        XCTAssertEqual(events[0].totalTokens, 210)
    }

    func testRepeatedUsageVarintFieldsAreSummed() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let conversationsURL = rootURL.appendingPathComponent("conversations", isDirectory: true)
        let databaseURL = conversationsURL.appendingPathComponent("conversation-a.db")
        let labelURL = rootURL.appendingPathComponent("labels/antigravity-timeline.jsonl")
        let diagnosticsURL = rootURL.appendingPathComponent("diagnostics/antigravity-active-importer-last.json")
        try writeAlwaysActiveLabel(at: labelURL)

        try writeAntigravityConversationDatabase(
            at: databaseURL,
            rows: [
                (
                    1,
                    antigravityGenerationMetadataBlob(
                        inputTokenChunks: [40, 60],
                        outputTokenChunks: [7, 3],
                        cachedInputTokenChunks: [10, 5],
                        model: "gemini-3.5-flash-low"
                    )
                )
            ]
        )

        let store = TokenUsageStore(fileURL: rootURL.appendingPathComponent("events.json"))
        let importer = TokenUsageAntigravityImporter(
            conversationsDirectory: conversationsURL,
            labelTimelineURL: labelURL,
            diagnosticsURL: diagnosticsURL,
            stateURL: rootURL.appendingPathComponent("state/antigravity-active-importer-state.json")
        )

        let summary = importer.importRecentEvents(into: store, since: Date(timeIntervalSince1970: 0))
        let event = try XCTUnwrap(store.loadEvents().first)

        XCTAssertEqual(summary.importedEvents, 1)
        XCTAssertEqual(event.projectID, "project_11111111111151119111111111111111")
        XCTAssertEqual(event.inputTokens, 115)
        XCTAssertEqual(event.outputTokens, 10)
        XCTAssertEqual(event.totalTokens, 125)

        let diagnostic = try String(contentsOf: diagnosticsURL)
        XCTAssertTrue(diagnostic.contains(#""timestamp_source":"generation_metadata_timestamp""#))
        XCTAssertTrue(diagnostic.contains(#""split_output_fallback_events":0"#))
        XCTAssertTrue(diagnostic.contains("without trusted numeric timestamps"))
        XCTAssertFalse(diagnostic.contains(databaseURL.path))
    }

    func testImporterUsesGenerationTimestampInsteadOfDatabaseModifiedTime() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let conversationsURL = rootURL.appendingPathComponent("conversations", isDirectory: true)
        let databaseURL = conversationsURL.appendingPathComponent("conversation-a.db")
        let labelURL = rootURL.appendingPathComponent("labels/antigravity-timeline.jsonl")
        let diagnosticsURL = rootURL.appendingPathComponent("diagnostics/antigravity-active-importer-last.json")
        try writeAlwaysActiveLabel(at: labelURL)
        let eventDate = try XCTUnwrap(ISO8601DateFormatter.parseTokenUsageDate(from: "2026-06-18T09:15:00.000Z"))
        let syncDate = try XCTUnwrap(ISO8601DateFormatter.parseTokenUsageDate(from: "2026-06-19T02:30:00.000Z"))

        try writeAntigravityConversationDatabase(
            at: databaseURL,
            rows: [
                (
                    1,
                    antigravityGenerationMetadataBlob(
                        inputTokenChunks: [40],
                        outputTokenChunks: [12],
                        cachedInputTokenChunks: [],
                        model: "gemini-3.5-flash-low",
                        createdAt: eventDate
                    )
                )
            ]
        )
        try FileManager.default.setAttributes([.modificationDate: syncDate], ofItemAtPath: databaseURL.path)

        let store = TokenUsageStore(fileURL: rootURL.appendingPathComponent("events.json"))
        let importer = TokenUsageAntigravityImporter(
            conversationsDirectory: conversationsURL,
            labelTimelineURL: labelURL,
            diagnosticsURL: diagnosticsURL,
            stateURL: rootURL.appendingPathComponent("state/antigravity-active-importer-state.json")
        )

        let summary = importer.importRecentEvents(into: store, since: Date(timeIntervalSince1970: 0))
        let event = try XCTUnwrap(store.loadEvents().first)

        XCTAssertEqual(summary.importedEvents, 1)
        XCTAssertEqual(event.createdAt, ISO8601DateFormatter.tokenUsage.string(from: eventDate))
        XCTAssertNotEqual(event.createdAt, ISO8601DateFormatter.tokenUsage.string(from: syncDate))
    }

    func testImporterUsesTimelineLabelsOnlyInsideCoveredWindow() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let conversationsURL = rootURL.appendingPathComponent("conversations", isDirectory: true)
        let databaseURL = conversationsURL.appendingPathComponent("conversation-a.db")
        let labelURL = rootURL.appendingPathComponent("labels/antigravity-timeline.jsonl")
        let diagnosticsURL = rootURL.appendingPathComponent("diagnostics/antigravity-active-importer-last.json")
        let coveredDate = try XCTUnwrap(ISO8601DateFormatter.parseTokenUsageDate(from: "2026-06-18T00:00:10.000Z"))
        let uncoveredDate = try XCTUnwrap(ISO8601DateFormatter.parseTokenUsageDate(from: "2026-06-18T00:01:00.000Z"))
        try FileManager.default.createDirectory(at: labelURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(
            """
            {"ai_tool":"antigravity","task_type":"code_review","stage":"verify","project_id":"project_11111111111151119111111111111111","updated_at":"2026-06-18T00:00:00.000Z","expires_at":"2026-06-18T00:00:30.000Z"}
            """.utf8
        ).write(to: labelURL)

        try writeAntigravityConversationDatabase(
            at: databaseURL,
            rows: [
                (
                    1,
                    antigravityGenerationMetadataBlob(
                        inputTokenChunks: [40],
                        outputTokenChunks: [12],
                        cachedInputTokenChunks: [],
                        model: "gemini-3.5-flash-low",
                        createdAt: coveredDate
                    )
                ),
                (
                    2,
                    antigravityGenerationMetadataBlob(
                        inputTokenChunks: [30],
                        outputTokenChunks: [8],
                        cachedInputTokenChunks: [],
                        model: "gemini-3.5-flash-low",
                        createdAt: uncoveredDate
                    )
                )
            ]
        )

        let store = TokenUsageStore(fileURL: rootURL.appendingPathComponent("events.json"))
        let importer = TokenUsageAntigravityImporter(
            conversationsDirectory: conversationsURL,
            labelTimelineURL: labelURL,
            diagnosticsURL: diagnosticsURL,
            stateURL: rootURL.appendingPathComponent("state/antigravity-active-importer-state.json")
        )

        let summary = importer.importRecentEvents(into: store, since: Date(timeIntervalSince1970: 0))
        let events = store.loadEvents().sorted { $0.createdAt < $1.createdAt }

        XCTAssertEqual(summary.importedEvents, 2)
        XCTAssertEqual(events[0].taskType, .codeReview)
        XCTAssertEqual(events[0].stage, .verify)
        XCTAssertEqual(events[0].projectID, "project_11111111111151119111111111111111")
        XCTAssertEqual(events[1].taskType, .uncategorized)
        XCTAssertEqual(events[1].stage, .summarize)
        XCTAssertEqual(events[1].projectID, "project_global")
    }

    func testImporterCanReadTemporaryCopyWhenDirectSQLiteOpenFails() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let conversationsURL = rootURL.appendingPathComponent("conversations", isDirectory: true)
        let databaseURL = conversationsURL.appendingPathComponent("conversation-a.db")
        let labelURL = rootURL.appendingPathComponent("labels/antigravity-timeline.jsonl")
        let diagnosticsURL = rootURL.appendingPathComponent("diagnostics/antigravity-active-importer-last.json")
        try writeAlwaysActiveLabel(at: labelURL)

        try writeAntigravityConversationDatabase(
            at: databaseURL,
            rows: [
                (
                    1,
                    antigravityGenerationMetadataBlob(
                        inputTokenChunks: [40],
                        outputTokenChunks: [12],
                        cachedInputTokenChunks: [8],
                        model: "gemini-3.5-flash-low"
                    )
                )
            ]
        )

        let store = TokenUsageStore(fileURL: rootURL.appendingPathComponent("events.json"))
        let importer = TokenUsageAntigravityImporter(
            conversationsDirectory: conversationsURL,
            labelTimelineURL: labelURL,
            diagnosticsURL: diagnosticsURL,
            stateURL: rootURL.appendingPathComponent("state/antigravity-active-importer-state.json"),
            forceTemporaryCopyFallback: true
        )

        let summary = importer.importRecentEvents(into: store, since: Date(timeIntervalSince1970: 0))
        let event = try XCTUnwrap(store.loadEvents().first)

        XCTAssertEqual(summary.scannedDatabases, 1)
        XCTAssertEqual(summary.scannedGenerationRows, 1)
        XCTAssertEqual(summary.importedEvents, 1)
        XCTAssertEqual(event.totalTokens, 60)
    }

    func testSplitOutputFieldsAreUsedWhenAggregateOutputIsMissing() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let conversationsURL = rootURL.appendingPathComponent("conversations", isDirectory: true)
        let databaseURL = conversationsURL.appendingPathComponent("conversation-a.db")
        let labelURL = rootURL.appendingPathComponent("labels/antigravity-timeline.jsonl")
        let diagnosticsURL = rootURL.appendingPathComponent("diagnostics/antigravity-active-importer-last.json")
        try writeAlwaysActiveLabel(at: labelURL)

        try writeAntigravityConversationDatabase(
            at: databaseURL,
            rows: [
                (
                    2,
                    antigravityGenerationMetadataBlob(
                        inputTokenChunks: [50],
                        outputTokenChunks: [],
                        cachedInputTokenChunks: [10],
                        splitOutputTokenChunks: [4, 8, 3],
                        model: "gemini-3.5-flash-low"
                    )
                )
            ]
        )

        let store = TokenUsageStore(fileURL: rootURL.appendingPathComponent("events.json"))
        let importer = TokenUsageAntigravityImporter(
            conversationsDirectory: conversationsURL,
            labelTimelineURL: labelURL,
            diagnosticsURL: diagnosticsURL,
            stateURL: rootURL.appendingPathComponent("state/antigravity-active-importer-state.json")
        )

        let summary = importer.importRecentEvents(into: store, since: Date(timeIntervalSince1970: 0))
        let event = try XCTUnwrap(store.loadEvents().first)

        XCTAssertEqual(summary.importedEvents, 1)
        XCTAssertEqual(summary.splitOutputFallbackEvents, 1)
        XCTAssertEqual(event.inputTokens, 60)
        XCTAssertEqual(event.outputTokens, 15)
        XCTAssertEqual(event.totalTokens, 75)

        let diagnostic = try String(contentsOf: diagnosticsURL)
        XCTAssertTrue(diagnostic.contains(#""split_output_fallback_events":1"#))
        XCTAssertFalse(diagnostic.contains(databaseURL.path))
    }

    func testUnsupportedGenerationRowsAreCountedSeparately() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let conversationsURL = rootURL.appendingPathComponent("conversations", isDirectory: true)
        let databaseURL = conversationsURL.appendingPathComponent("conversation-a.db")
        let labelURL = rootURL.appendingPathComponent("labels/antigravity-timeline.jsonl")
        let diagnosticsURL = rootURL.appendingPathComponent("diagnostics/antigravity-active-importer-last.json")
        try writeAlwaysActiveLabel(at: labelURL)

        try writeAntigravityConversationDatabase(
            at: databaseURL,
            rows: [
                (
                    1,
                    antigravityGenerationMetadataBlob(
                        inputTokenChunks: [50],
                        outputTokenChunks: [10],
                        cachedInputTokenChunks: [],
                        model: "gemini-3.5-flash-low"
                    )
                ),
                (2, Data([0x08, 0x01]))
            ]
        )

        let store = TokenUsageStore(fileURL: rootURL.appendingPathComponent("events.json"))
        let importer = TokenUsageAntigravityImporter(
            conversationsDirectory: conversationsURL,
            labelTimelineURL: labelURL,
            diagnosticsURL: diagnosticsURL,
            stateURL: rootURL.appendingPathComponent("state/antigravity-active-importer-state.json")
        )

        let summary = importer.importRecentEvents(into: store, since: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(summary.scannedGenerationRows, 2)
        XCTAssertEqual(summary.parsedUsageEvents, 1)
        XCTAssertEqual(summary.importedEvents, 1)
        XCTAssertEqual(summary.unsupportedRecords, 1)
        XCTAssertEqual(summary.cursorAdvancedDatabases, 1)

        let diagnostic = try String(contentsOf: diagnosticsURL)
        XCTAssertTrue(diagnostic.contains(#""unsupported_records":1"#))
        XCTAssertFalse(diagnostic.contains(databaseURL.path))

        let secondSummary = importer.importRecentEvents(into: store, since: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(secondSummary.scannedGenerationRows, 1)
        XCTAssertEqual(secondSummary.unsupportedRecords, 1)
        XCTAssertEqual(secondSummary.importedEvents, 0)
        XCTAssertEqual(secondSummary.cursorAdvancedDatabases, 0)

        try writeAntigravityConversationDatabase(
            at: databaseURL,
            rows: [
                (
                    1,
                    antigravityGenerationMetadataBlob(
                        inputTokenChunks: [50],
                        outputTokenChunks: [10],
                        cachedInputTokenChunks: [],
                        model: "gemini-3.5-flash-low"
                    )
                ),
                (
                    2,
                    antigravityGenerationMetadataBlob(
                        inputTokenChunks: [20],
                        outputTokenChunks: [5],
                        cachedInputTokenChunks: [],
                        model: "gemini-3.5-flash-low"
                    )
                )
            ]
        )

        let thirdSummary = importer.importRecentEvents(into: store, since: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(thirdSummary.scannedGenerationRows, 1)
        XCTAssertEqual(thirdSummary.unsupportedRecords, 0)
        XCTAssertEqual(thirdSummary.importedEvents, 1)
        XCTAssertEqual(thirdSummary.cursorAdvancedDatabases, 1)
        XCTAssertEqual(store.loadEvents().map(\.totalTokens).sorted(), [25, 60])
    }

    func testCancelledImportDiagnosticDoesNotClaimPersistedCursorAdvance() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let conversationsURL = rootURL.appendingPathComponent("conversations", isDirectory: true)
        let databaseURL = conversationsURL.appendingPathComponent("conversation-a.db")
        let labelURL = rootURL.appendingPathComponent("labels/antigravity-timeline.jsonl")
        let diagnosticsURL = rootURL.appendingPathComponent("diagnostics/antigravity-active-importer-last.json")
        let stateURL = rootURL.appendingPathComponent("state/antigravity-active-importer-state.json")
        try writeAlwaysActiveLabel(at: labelURL)

        try writeAntigravityConversationDatabase(
            at: databaseURL,
            rows: [
                (
                    1,
                    antigravityGenerationMetadataBlob(
                        inputTokenChunks: [50],
                        outputTokenChunks: [10],
                        cachedInputTokenChunks: [],
                        model: "gemini-3.5-flash-low"
                    )
                )
            ]
        )

        let store = TokenUsageStore(fileURL: rootURL.appendingPathComponent("events.json"))
        let importer = TokenUsageAntigravityImporter(
            conversationsDirectory: conversationsURL,
            labelTimelineURL: labelURL,
            diagnosticsURL: diagnosticsURL,
            stateURL: stateURL
        )
        var cancellationChecks = 0

        let summary = importer.importRecentEvents(into: store, since: Date(timeIntervalSince1970: 0)) {
            cancellationChecks += 1
            return cancellationChecks >= 2
        }

        XCTAssertEqual(summary.scannedDatabases, 1)
        XCTAssertEqual(summary.importedEvents, 0)
        XCTAssertEqual(summary.cursorAdvancedDatabases, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: stateURL.path))

        let diagnostic = try String(contentsOf: diagnosticsURL)
        XCTAssertTrue(diagnostic.contains(#""cursor_advanced_databases":0"#))
    }

    func testImporterSkipsRowsAtOrBeforeOpaqueCursor() throws {
        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let conversationsURL = rootURL.appendingPathComponent("conversations", isDirectory: true)
        let databaseURL = conversationsURL.appendingPathComponent("conversation-a.db")
        let labelURL = rootURL.appendingPathComponent("labels/antigravity-timeline.jsonl")
        let diagnosticsURL = rootURL.appendingPathComponent("diagnostics/antigravity-active-importer-last.json")
        let stateURL = rootURL.appendingPathComponent("state/antigravity-active-importer-state.json")
        try writeAlwaysActiveLabel(at: labelURL)

        try writeAntigravityConversationDatabase(
            at: databaseURL,
            rows: [
                (
                    1,
                    antigravityGenerationMetadataBlob(
                        inputTokenChunks: [10],
                        outputTokenChunks: [5],
                        cachedInputTokenChunks: [],
                        model: "gemini-3.5-flash-low"
                    )
                )
            ]
        )

        let store = TokenUsageStore(fileURL: rootURL.appendingPathComponent("events.json"))
        let importer = TokenUsageAntigravityImporter(
            conversationsDirectory: conversationsURL,
            labelTimelineURL: labelURL,
            diagnosticsURL: diagnosticsURL,
            stateURL: stateURL
        )

        let firstSummary = importer.importRecentEvents(into: store, since: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(firstSummary.scannedGenerationRows, 1)
        XCTAssertEqual(firstSummary.cursorAdvancedDatabases, 1)
        XCTAssertEqual(store.loadEvents().count, 1)

        try writeAntigravityConversationDatabase(
            at: databaseURL,
            rows: [
                (
                    1,
                    antigravityGenerationMetadataBlob(
                        inputTokenChunks: [10],
                        outputTokenChunks: [5],
                        cachedInputTokenChunks: [],
                        model: "gemini-3.5-flash-low"
                    )
                ),
                (
                    2,
                    antigravityGenerationMetadataBlob(
                        inputTokenChunks: [20],
                        outputTokenChunks: [6],
                        cachedInputTokenChunks: [4],
                        model: "gemini-3.5-flash-low"
                    )
                )
            ]
        )

        let secondSummary = importer.importRecentEvents(into: store, since: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(secondSummary.scannedGenerationRows, 1)
        XCTAssertEqual(secondSummary.parsedUsageEvents, 1)
        XCTAssertEqual(secondSummary.importedEvents, 1)
        XCTAssertEqual(secondSummary.cursorAdvancedDatabases, 1)
        XCTAssertEqual(store.loadEvents().map(\.totalTokens).sorted(), [15, 30])

        let state = try String(contentsOf: stateURL)
        XCTAssertFalse(state.contains(databaseURL.path))
        XCTAssertFalse(state.contains("conversation-a"))
        XCTAssertTrue(state.contains(#""max_generation_index_by_source""#))
    }

    func testRealDatabaseImport() throws {
        guard ProcessInfo.processInfo.environment["SPILL_RUN_REAL_AGY_IMPORT"] == "1" else {
            throw XCTSkip("Manual local AGY diagnostic; set SPILL_RUN_REAL_AGY_IMPORT=1 to run.")
        }

        let rootURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let store = TokenUsageStore(fileURL: rootURL.appendingPathComponent("events.json"))
        let importer = TokenUsageAntigravityImporter(
            diagnosticsURL: rootURL.appendingPathComponent("diagnostics/antigravity-active-importer-last.json"),
            stateURL: rootURL.appendingPathComponent("state/antigravity-active-importer-state.json")
        )

        let summary = importer.importRecentEvents(into: store, since: Date(timeIntervalSince1970: 0))
        print("REAL DB TEST RUN SUMMARY: \(summary)")
        let events = store.loadEvents().sorted { $0.createdAt < $1.createdAt }
        let byDay = Dictionary(grouping: events, by: { String($0.createdAt.prefix(10)) })
            .mapValues(\.count)
        let byLabel = Dictionary(
            grouping: events,
            by: { "\($0.taskType.rawValue)/\($0.stage.rawValue)" }
        )
        .mapValues(\.count)
        let object: [String: Any] = [
            "summary": [
                "scanned_databases": summary.scannedDatabases,
                "scanned_generation_rows": summary.scannedGenerationRows,
                "parsed_usage_events": summary.parsedUsageEvents,
                "imported_events": summary.importedEvents,
                "skipped_duplicate_events": summary.skippedDuplicateEvents,
                "unsupported_records": summary.unsupportedRecords,
                "failed_to_write_events": summary.failedToWriteEvents,
            ],
            "event_count": events.count,
            "first_created_at": events.first?.createdAt ?? NSNull(),
            "last_created_at": events.last?.createdAt ?? NSNull(),
            "days": byDay,
            "labels": byLabel,
        ]

        if let summaryPath = ProcessInfo.processInfo.environment["SPILL_AGY_REAL_IMPORT_SUMMARY_PATH"],
           !summaryPath.isEmpty {
            let summaryURL = URL(fileURLWithPath: summaryPath)
            try FileManager.default.createDirectory(
                at: summaryURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: summaryURL, options: [.atomic])
        }

        XCTAssertGreaterThanOrEqual(summary.scannedDatabases, 0)
    }

    func testRealDatabaseImportIncremental() throws {
        throw XCTSkip("Manual local AGY diagnostic; not part of automated tests.")
    }

    func testImporterUsesBatchAppendInsteadOfPerEventStoreAppend() throws {
        let source = try Self.source(named: "TokenUsageAntigravityImporter.swift")

        XCTAssertTrue(source.contains("store.appendEventsWithoutLoading(candidateEvents)"))
        XCTAssertFalse(source.contains("store.appendEvent("))
    }

    private func writeAlwaysActiveLabel(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(
            """
            {"ai_tool":"antigravity","task_type":"debugging","stage":"implement","project_id":"project_11111111111151119111111111111111","updated_at":"1970-01-01T00:00:00.000Z","expires_at":"2999-01-01T00:00:00.000Z"}
            """.utf8
        ).write(to: url)
    }

    private func writeAntigravityConversationDatabase(at databaseURL: URL, rows: [(Int, Data)]) throws {
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: databaseURL.path) {
            try FileManager.default.removeItem(at: databaseURL)
        }

        let database = try openSQLiteDatabase(databaseURL)
        defer { sqlite3_close(database) }

        try executeSQLite(
            """
            CREATE TABLE gen_metadata (
                idx integer,
                data blob,
                size integer NOT NULL DEFAULT 0,
                PRIMARY KEY (idx)
            )
            """,
            database: database
        )

        let sql = "INSERT INTO gen_metadata (idx, data, size) VALUES (?, ?, ?)"
        for row in rows {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
                  let statement
            else {
                throw sqliteError(database)
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_int64(statement, 1, sqlite3_int64(row.0))
            sqlite3_bind_int64(statement, 3, sqlite3_int64(row.1.count))
            let result = row.1.withUnsafeBytes { buffer -> Int32 in
                sqlite3_bind_blob(statement, 2, buffer.baseAddress, Int32(buffer.count), TEST_AGY_SQLITE_TRANSIENT)
                return sqlite3_step(statement)
            }

            guard result == SQLITE_DONE else {
                throw sqliteError(database)
            }
        }
    }

    private func antigravityGenerationMetadataBlob(
        inputTokenChunks: [Int],
        outputTokenChunks: [Int],
        cachedInputTokenChunks: [Int],
        splitOutputTokenChunks: [Int] = [],
        model: String,
        createdAt: Date = Date(timeIntervalSince1970: 1_780_000_000)
    ) -> Data {
        var usage = Data()
        usage.append(protoVarintField(1, 1020))
        inputTokenChunks.forEach { usage.append(protoVarintField(2, $0)) }
        outputTokenChunks.forEach { usage.append(protoVarintField(3, $0)) }
        cachedInputTokenChunks.forEach { usage.append(protoVarintField(5, $0)) }
        if let firstSplitOutput = splitOutputTokenChunks.first {
            usage.append(protoVarintField(9, firstSplitOutput))
            splitOutputTokenChunks.dropFirst().forEach { usage.append(protoVarintField(10, $0)) }
        }

        var generation = Data()
        generation.append(protoBytesField(4, usage))
        generation.append(protoBytesField(9, antigravityTimestampBlob(createdAt: createdAt)))
        generation.append(protoBytesField(19, Data(model.utf8)))

        var envelope = Data()
        envelope.append(protoBytesField(1, generation))
        return envelope
    }

    private func antigravityTimestampBlob(createdAt: Date) -> Data {
        var timestampMessage = Data()
        timestampMessage.append(protoVarintField(1, Int(createdAt.timeIntervalSince1970)))

        var timestampContainer = Data()
        timestampContainer.append(protoBytesField(4, timestampMessage))
        return timestampContainer
    }

    private func protoVarintField(_ number: Int, _ value: Int) -> Data {
        var data = protoVarint(UInt64(number << 3))
        data.append(protoVarint(UInt64(max(0, value))))
        return data
    }

    private func protoBytesField(_ number: Int, _ value: Data) -> Data {
        var data = protoVarint(UInt64((number << 3) | 2))
        data.append(protoVarint(UInt64(value.count)))
        data.append(value)
        return data
    }

    private func protoVarint(_ value: UInt64) -> Data {
        var value = value
        var bytes = [UInt8]()

        repeat {
            var byte = UInt8(value & 0x7f)
            value >>= 7
            if value != 0 {
                byte |= 0x80
            }
            bytes.append(byte)
        } while value != 0

        return Data(bytes)
    }

    private func openSQLiteDatabase(_ url: URL) throws -> OpaquePointer {
        var database: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &database, flags, nil) == SQLITE_OK,
              let database
        else {
            defer { sqlite3_close(database) }
            throw sqliteError(database)
        }
        return database
    }

    private func executeSQLite(_ sql: String, database: OpaquePointer) throws {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw sqliteError(database)
        }
    }

    private func sqliteError(_ database: OpaquePointer?) -> NSError {
        let code = database.map { Int(sqlite3_errcode($0)) } ?? -1
        let message = database
            .flatMap { sqlite3_errmsg($0) }
            .map { String(cString: $0) }
            ?? "Unknown SQLite error"
        return NSError(
            domain: "SpillTests.SQLite",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    private func temporaryDirectory() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func source(named fileName: String) throws -> String {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let sourcesURL = root.appendingPathComponent("Sources/Spill", isDirectory: true)
        let urls = FileManager.default.enumerator(
            at: sourcesURL,
            includingPropertiesForKeys: nil
        )?
            .compactMap { $0 as? URL }
            .filter { $0.lastPathComponent == fileName }
            .sorted { $0.path < $1.path } ?? []
        let sourceURL = try XCTUnwrap(urls.first, "Missing source file named \(fileName)")
        return try String(contentsOf: sourceURL)
    }
}
