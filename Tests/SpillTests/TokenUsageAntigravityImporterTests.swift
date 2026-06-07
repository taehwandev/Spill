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
            diagnosticsURL: diagnosticsURL
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
            diagnosticsURL: diagnosticsURL
        )

        let summary = importer.importRecentEvents(into: store, since: Date(timeIntervalSince1970: 0))
        let event = try XCTUnwrap(store.loadEvents().first)

        XCTAssertEqual(summary.importedEvents, 1)
        XCTAssertEqual(event.inputTokens, 115)
        XCTAssertEqual(event.outputTokens, 10)
        XCTAssertEqual(event.totalTokens, 125)

        let diagnostic = try String(contentsOf: diagnosticsURL)
        XCTAssertTrue(diagnostic.contains(#""timestamp_source":"conversation_database_mtime""#))
        XCTAssertTrue(diagnostic.contains("no trusted per-row timestamp"))
        XCTAssertFalse(diagnostic.contains(databaseURL.path))
    }

    func testImporterUsesBatchAppendInsteadOfPerEventStoreAppend() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let source = try String(contentsOf: root.appendingPathComponent(
            "Sources/Spill/TokenMetering/TokenUsageAntigravityImporter.swift"
        ))

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
            {"ai_tool":"antigravity","task_type":"debugging","stage":"implement","updated_at":"1970-01-01T00:00:00.000Z","expires_at":"2999-01-01T00:00:00.000Z"}
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
        model: String
    ) -> Data {
        var usage = Data()
        usage.append(protoVarintField(1, 1020))
        inputTokenChunks.forEach { usage.append(protoVarintField(2, $0)) }
        outputTokenChunks.forEach { usage.append(protoVarintField(3, $0)) }
        cachedInputTokenChunks.forEach { usage.append(protoVarintField(5, $0)) }

        var generation = Data()
        generation.append(protoBytesField(4, usage))
        generation.append(protoBytesField(19, Data(model.utf8)))

        var envelope = Data()
        envelope.append(protoBytesField(1, generation))
        return envelope
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
}
