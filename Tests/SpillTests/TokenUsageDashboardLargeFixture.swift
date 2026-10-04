import Foundation
import SQLite3
@testable import Spill

/// Synthetic history only. Store-owned schema and triggers keep accounting and
/// rollups identical to normal writes; bulk loading is outside measured actions.
struct TokenUsageDashboardLargeFixture {
    let directoryURL: URL
    let usageStore: TokenUsageStore
    let calendar: Calendar
    let now: Date
    let currentMonthStart: Date
    let previousMonthStart: Date
    let selectedDayID = "2026-10-02"
    let eventCount: Int
    let selectedDayEventCount: Int

    init(eventCount: Int = 100_000) throws {
        guard eventCount >= 10, eventCount % 10 == 0 else { throw Self.error(code: SQLITE_CONSTRAINT) }
        let selectedDayEventCount = eventCount / 5 * 4
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DashboardLargeFixture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .current
            calendar.firstWeekday = 1
            let currentMonthStart = try Self.date(month: 10, day: 1, hour: 0, calendar: calendar)
            let previousMonthStart = try Self.date(month: 9, day: 1, hour: 0, calendar: calendar)
            let currentDay = try Self.date(month: 10, day: 2, hour: 12, calendar: calendar)
            let previousDay = try Self.date(month: 9, day: 15, hour: 12, calendar: calendar)
            let store = TokenUsageStore(fileURL: directory.appendingPathComponent("events.json"))
            let prepared = store.withDatabaseConnection(nil, default: false) { _ in true }
            guard prepared else { throw Self.error(code: SQLITE_CANTOPEN) }
            try Self.bulkLoad(
                store: store, eventCount: eventCount, selectedDayEventCount: selectedDayEventCount,
                currentDay: currentDay, previousDay: previousDay
            )
            store.noteDataChanged()
            directoryURL = directory
            usageStore = store
            self.calendar = calendar
            now = try Self.date(month: 10, day: 3, hour: 12, calendar: calendar)
            self.currentMonthStart = currentMonthStart
            self.previousMonthStart = previousMonthStart
            self.eventCount = eventCount
            self.selectedDayEventCount = selectedDayEventCount
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    func remove() {
        try? FileManager.default.removeItem(at: directoryURL)
    }

    private static func date(month: Int, day: Int, hour: Int, calendar: Calendar) throws -> Date {
        guard let date = calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour)) else {
            throw error(code: SQLITE_ERROR)
        }
        return date
    }

    private static func bulkLoad(
        store: TokenUsageStore, eventCount: Int, selectedDayEventCount: Int, currentDay: Date, previousDay: Date
    ) throws {
        let template = templateEvent(date: currentDay)
        try template.validate()
        guard let payload = String(data: try JSONEncoder().encode(template), encoding: .utf8) else {
            throw error(code: SQLITE_ERROR)
        }
        var database: OpaquePointer?
        let openResult = sqlite3_open(store.eventsDatabaseURL.path, &database)
        guard openResult == SQLITE_OK, let database else {
            if let database { sqlite3_close(database) }
            throw error(code: openResult)
        }
        defer { sqlite3_close(database) }
        sqlite3_busy_timeout(database, 10_000)
        try execute("BEGIN IMMEDIATE", database: database)
        do {
            try insertRows(
                payload: payload,
                eventCount: eventCount,
                selectedDayEventCount: selectedDayEventCount,
                currentTimestamp: ISO8601DateFormatter.tokenUsage.string(from: currentDay),
                previousTimestamp: ISO8601DateFormatter.tokenUsage.string(from: previousDay),
                database: database
            )
            try execute("COMMIT", database: database)
        } catch {
            _ = sqlite3_exec(database, "ROLLBACK", nil, nil, nil)
            throw error
        }
    }

    private static func insertRows(
        payload: String, eventCount: Int, selectedDayEventCount: Int,
        currentTimestamp: String, previousTimestamp: String, database: OpaquePointer
    ) throws {
        let sql = """
        WITH RECURSIVE sequence(i) AS (
            VALUES(0) UNION ALL SELECT i + 1 FROM sequence WHERE i < ?4 - 1
        ), rows AS (
            SELECT printf('span_large_fixture_%06d', i) AS span,
                   CASE WHEN i % 2 = 0 THEN 'codex' ELSE 'claude' END AS tool,
                   CASE WHEN i < ?5 THEN ?2 ELSE ?3 END AS timestamp
            FROM sequence
        )
        INSERT INTO token_usage_events (
            span_id, device_id, project_id, artifact_id, run_id, created_at,
            ai_tool, task_type, stage, model, input_tokens, output_tokens, latency_ms,
            source_system, source_user, source_history, source_repo_context,
            source_tool_output, source_generated_output, source_unknown,
            accounting_uncached_input_tokens, accounting_cache_creation_input_tokens,
            accounting_cache_read_input_tokens, accounting_reasoning_output_tokens,
            total_tokens, payload_json
        )
        SELECT span, 'device_fixture', 'project_fixture', 'artifact_fixture', 'run_fixture', timestamp,
               tool, 'testing', 'verify', 'fixture-model', 980, 20, 0,
               0, 0, 0, 0, 0, 0, 1000, 80, 0, 900, 0, 1000,
               json_set(CAST(?1 AS TEXT), '$.span_id', span, '$.ai_tool', tool, '$.created_at', timestamp)
        FROM rows
        """
        var statement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(database, sql, -1, &statement, nil)
        guard prepareResult == SQLITE_OK, let statement else { throw error(code: prepareResult) }
        defer { sqlite3_finalize(statement) }
        for (index, value) in [payload, currentTimestamp, previousTimestamp].enumerated() {
            let bindResult = value.withCString {
                sqlite3_bind_text(statement, Int32(index + 1), $0, -1, SQLITE_TRANSIENT)
            }
            guard bindResult == SQLITE_OK else { throw error(code: bindResult) }
        }
        for (index, value) in [eventCount, selectedDayEventCount].enumerated() {
            let bindResult = sqlite3_bind_int64(statement, Int32(index + 4), Int64(value))
            guard bindResult == SQLITE_OK else { throw error(code: bindResult) }
        }
        let result = sqlite3_step(statement)
        guard result == SQLITE_DONE else { throw error(code: result) }
    }

    private static func execute(_ sql: String, database: OpaquePointer) throws {
        let result = sqlite3_exec(database, sql, nil, nil, nil)
        guard result == SQLITE_OK else { throw error(code: result) }
    }

    private static func error(code: Int32) -> NSError {
        NSError(domain: "SpillTests.SyntheticSQLiteFixture", code: Int(code))
    }

    private static func templateEvent(date: Date) -> TokenUsageEvent {
        TokenUsageEvent(
            schemaVersion: 1, deviceID: "device_fixture", projectID: "project_fixture",
            artifactID: "artifact_fixture", runID: "run_fixture", spanID: "span_large_template",
            aiTool: .codex, taskType: .testing, stage: .verify, model: "fixture-model",
            inputTokens: 980, outputTokens: 20, totalTokens: 1_000,
            tokenBreakdown: TokenUsageBreakdown(
                system: 0, user: 0, history: 0, repoContext: 0, toolOutput: 0,
                generatedOutput: 0, unknown: 1_000
            ),
            tokenAccounting: TokenUsageAccounting(uncachedInputTokens: 80, cacheReadInputTokens: 900),
            latencyMS: 0, createdAt: ISO8601DateFormatter.tokenUsage.string(from: date)
        )
    }
}
