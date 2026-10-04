import Foundation
import SQLite3
import XCTest
@testable import Spill

final class TokenUsageCalendarDayAggregationTests: XCTestCase {
    func testSpringDSTDayUsesTwentyThreeHourLocalRange() throws {
        let calendar = try self.calendar("America/New_York")
        let start = try date("2026-03-08T05:00:00.000Z")
        let end = try date("2026-03-09T04:00:00.000Z")
        XCTAssertEqual(end.timeIntervalSince(start), 23 * 60 * 60)
        try assertTotals(
            timestamps: ["2026-03-08T04:59:59.000Z", "2026-03-08T05:00:00.000Z",
                         "2026-03-08T07:00:00.000Z", "2026-03-09T03:59:59.000Z",
                         "2026-03-09T04:00:00.000Z"],
            start: start, end: end, calendar: calendar,
            expected: ["2026-03-08": .init(includeCache: 30, freshOnly: 15)]
        )
    }

    func testFallDSTDayIncludesBothRepeatedHours() throws {
        let calendar = try self.calendar("America/New_York")
        let start = try date("2026-11-01T04:00:00.000Z")
        let end = try date("2026-11-02T05:00:00.000Z")
        XCTAssertEqual(end.timeIntervalSince(start), 25 * 60 * 60)
        try assertTotals(
            timestamps: ["2026-11-01T03:59:59.000Z", "2026-11-01T04:00:00.000Z",
                         "2026-11-01T05:30:00.000Z", "2026-11-01T06:30:00.000Z",
                         "2026-11-02T04:59:59.000Z", "2026-11-02T05:00:00.000Z"],
            start: start, end: end, calendar: calendar,
            expected: ["2026-11-01": .init(includeCache: 40, freshOnly: 20)]
        )
    }

    func testMidnightDSTTransitionDoesNotCarryOneAMIntoFollowingDay() throws {
        try assertTotals(
            timestamps: ["2018-11-04T03:00:00.000Z", "2018-11-05T01:59:59.000Z",
                         "2018-11-05T02:00:00.000Z", "2018-11-05T02:30:00.000Z"],
            start: date("2018-11-04T03:00:00.000Z"), end: date("2018-11-05T03:00:00.000Z"),
            calendar: calendar("America/Sao_Paulo"),
            expected: ["2018-11-04": .init(includeCache: 20, freshOnly: 10),
                       "2018-11-05": .init(includeCache: 20, freshOnly: 10)]
        )
    }

    func testNepalOffsetKeepsLocalMidnightEdgesHalfOpen() throws {
        try assertTotals(
            timestamps: ["2026-06-04T18:14:59.000Z", "2026-06-04T18:15:00.000Z",
                         "2026-06-05T18:14:59.000Z", "2026-06-05T18:15:00.000Z"],
            start: date("2026-06-04T18:15:00.000Z"), end: date("2026-06-05T18:15:00.000Z"),
            calendar: calendar("Asia/Kathmandu"),
            expected: ["2026-06-05": .init(includeCache: 20, freshOnly: 10)]
        )
    }

    func testPartialFirstAndLastDaysExcludeEventsOutsideRequestedRange() throws {
        try assertTotals(
            timestamps: ["2026-06-05T11:59:59.000Z", "2026-06-05T12:00:00.000Z",
                         "2026-06-05T23:59:59.000Z", "2026-06-06T00:00:00.000Z",
                         "2026-06-06T11:59:59.000Z", "2026-06-06T12:00:00.000Z"],
            start: date("2026-06-05T12:00:00.000Z"), end: date("2026-06-06T12:00:00.000Z"),
            calendar: calendar("UTC"),
            expected: ["2026-06-05": .init(includeCache: 20, freshOnly: 10),
                       "2026-06-06": .init(includeCache: 20, freshOnly: 10)]
        )
    }

    func testToolVisibilityAndAdvancedToolsKeepExactTotals() throws {
        try withStore { store in
            let timestamp = "2026-06-05T12:00:00.000Z"
            let known = TokenUsageAccounting(uncachedInputTokens: 3, cacheReadInputTokens: 5)
            _ = try store.appendEventsWithoutLoading([
                event(0, timestamp: timestamp, tool: .codex, accounting: known),
                event(1, timestamp: timestamp, tool: .claude, accounting: nil),
                event(2, timestamp: timestamp, tool: .openAI, accounting: known)
            ])
            let start = try date("2026-06-05T00:00:00.000Z")
            let end = try date("2026-06-06T00:00:00.000Z")
            let calendar = try self.calendar("UTC")
            func totals(advanced: Bool, visible: Set<TokenUsageAITool>? = nil) -> [String: TokenUsageInputScopeTotals] {
                store.dashboardDayInputScopeTotals(
                    startingAt: start, endingBefore: end, calendar: calendar,
                    dashboardToolsOnly: !advanced, visibleTools: visible
                )
            }
            XCTAssertEqual(totals(advanced: false), ["2026-06-05": .init(includeCache: 20, freshOnly: 7)])
            XCTAssertEqual(totals(advanced: true), ["2026-06-05": .init(includeCache: 30, freshOnly: 12)])
            XCTAssertEqual(totals(advanced: false, visible: [.claude, .openAI]),
                           ["2026-06-05": .init(includeCache: 10, freshOnly: 2)])
            XCTAssertEqual(totals(advanced: true, visible: [.openAI]),
                           ["2026-06-05": .init(includeCache: 10, freshOnly: 5)])
            XCTAssertTrue(totals(advanced: true, visible: []).isEmpty)
        }
    }

    func testUnknownInputKeepsRawPositiveDayWithZeroFreshAndOmitsEmptyDays() throws {
        try withStore { store in
            _ = try store.appendEventsWithoutLoading([
                event(0, timestamp: "2026-06-05T01:00:00.000Z", accounting: nil),
                event(1, timestamp: "2026-06-06T01:00:00.000Z", output: 0, accounting: nil)
            ])
            let totals = store.dashboardDayInputScopeTotals(
                startingAt: try date("2026-06-05T00:00:00.000Z"),
                endingBefore: try date("2026-06-08T00:00:00.000Z"), calendar: try calendar("UTC")
            )
            XCTAssertEqual(totals, ["2026-06-05": .init(includeCache: 10, freshOnly: 2),
                                    "2026-06-06": .init(includeCache: 8, freshOnly: 0)])
        }
    }

    func testEmptyOrReversedRangeDoesNotReportDatabaseFailure() throws {
        try withStore { store in
            let instant = try date("2026-06-05T12:00:00.000Z")
            let observer = TokenUsageQueryFailureObserver()
            for end in [instant, instant.addingTimeInterval(-1)] {
                XCTAssertTrue(store.dashboardDayInputScopeTotals(
                    startingAt: instant, endingBefore: end, calendar: try calendar("UTC"),
                    failureObserver: observer
                ).isEmpty)
            }
            XCTAssertFalse(observer.didFail)
        }
    }

    func testStatementPreparationFailureMarksObserver() throws {
        try withStore { store in
            var rawDatabase: OpaquePointer?
            XCTAssertEqual(sqlite3_open(":memory:", &rawDatabase), SQLITE_OK)
            let database = try XCTUnwrap(rawDatabase)
            defer { sqlite3_close(database) }
            let observer = TokenUsageQueryFailureObserver()
            XCTAssertTrue(store.loadDashboardDayTokenTotals(
                startingAt: try date("2026-06-05T00:00:00.000Z"),
                endingBefore: try date("2026-06-06T00:00:00.000Z"), calendar: try calendar("UTC"),
                dashboardToolsOnly: true, database: database, failureObserver: observer
            ).isEmpty)
            XCTAssertTrue(observer.didFail)
        }
    }

    func testInterruptedStatementMarksObserverAndReturnsNoPartialTotals() throws {
        try withStore { store in
            try store.appendEvent(event(0, timestamp: "2026-06-05T12:00:00.000Z"))
            let database = try store.openDatabase()
            defer { sqlite3_close(database) }
            sqlite3_progress_handler(database, 1, { _ in 1 }, nil)
            defer { sqlite3_progress_handler(database, 0, nil, nil) }
            let observer = TokenUsageQueryFailureObserver()
            XCTAssertTrue(store.loadDashboardDayTokenTotals(
                startingAt: try date("2026-06-05T00:00:00.000Z"),
                endingBefore: try date("2026-06-07T00:00:00.000Z"), calendar: try calendar("UTC"),
                dashboardToolsOnly: true, database: database, failureObserver: observer
            ).isEmpty)
            XCTAssertTrue(observer.didFail)
        }
    }

    private func assertTotals(
        timestamps: [String], start: Date, end: Date, calendar: Calendar,
        expected: [String: TokenUsageInputScopeTotals]
    ) throws {
        try withStore { store in
            let events = timestamps.enumerated().map { event($0.offset, timestamp: $0.element) }
            _ = try store.appendEventsWithoutLoading(events)
            let actual = store.dashboardDayInputScopeTotals(startingAt: start, endingBefore: end, calendar: calendar)
            XCTAssertEqual(actual, expected)
            var reference = [String: TokenUsageInputScopeTotals]()
            for event in events {
                let createdAt = try date(event.createdAt)
                guard createdAt >= start, createdAt < end else { continue }
                let key = TokenUsageDashboardSnapshot.dayID(for: createdAt, calendar: calendar)
                let current = reference[key, default: .zero]
                reference[key] = .init(
                    includeCache: current.includeCache + event.totalTokens,
                    freshOnly: current.freshOnly + event.outputTokens + (event.tokenAccounting?.uncachedInputTokens ?? 0)
                )
            }
            XCTAssertEqual(actual, reference)
        }
    }

    private func withStore(_ body: (TokenUsageStore) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(TokenUsageStore(fileURL: directory.appendingPathComponent("events.json")))
    }

    private func calendar(_ zone: String) throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: zone))
        return calendar
    }

    private func date(_ value: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter.parseTokenUsageDate(from: value))
    }

    private func event(
        _ index: Int, timestamp: String, tool: TokenUsageAITool = .codex, output: Int = 2,
        accounting: TokenUsageAccounting? = TokenUsageAccounting(uncachedInputTokens: 3, cacheReadInputTokens: 5)
    ) -> TokenUsageEvent {
        TokenUsageEvent(
            schemaVersion: 1, deviceID: "device_calendar", projectID: "project_calendar",
            artifactID: "artifact_calendar", runID: "run_calendar", spanID: "span_calendar_\(index)",
            aiTool: tool, taskType: .testing, stage: .verify, model: "test-model",
            inputTokens: 8, outputTokens: output, totalTokens: 8 + output,
            tokenBreakdown: TokenUsageBreakdown(
                system: 0, user: 0, history: 0, repoContext: 0, toolOutput: 0,
                generatedOutput: output, unknown: 8
            ),
            tokenAccounting: accounting, latencyMS: 0, createdAt: timestamp
        )
    }
}
