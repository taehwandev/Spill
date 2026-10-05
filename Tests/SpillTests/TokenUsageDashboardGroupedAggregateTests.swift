import Foundation
import SQLite3
import XCTest
@testable import Spill

/// The grouped dashboard scan replaces one statement per dimension, so it must reproduce what
/// the per-event Swift aggregation yields, including how legacy rows with blank values count.
final class TokenUsageDashboardGroupedAggregateTests: XCTestCase {
    func testSQLSnapshotMatchesEventSnapshotForVariedEvents() throws {
        let store = try makeStore()
        let base = try XCTUnwrap(ISO8601DateFormatter.parseTokenUsageDate(from: "2026-10-01T00:00:00Z"))
        try seedVariedEvents(store, base: base)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let now = base.addingTimeInterval(12 * 3_600)
        let locale = Locale(identifier: "en_US")
        let month = TokenUsageDashboardSnapshot.monthStart(for: base, calendar: calendar)
        let monthEnd = try XCTUnwrap(calendar.date(byAdding: .month, value: 1, to: month))

        var comparedSnapshots = 0
        for dayID: String? in [nil, "2026-10-01"] {
            let events: [TokenUsageEvent]
            if let dayID {
                let day = try XCTUnwrap(TokenUsageDashboardSnapshot.date(forDayID: dayID, calendar: calendar))
                let dayEnd = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: day))
                events = store.loadEvents(startingAt: day, endingBefore: dayEnd)
            } else {
                events = store.loadEvents()
            }
            for showAdvancedTools in [false, true] {
                for visibleTools: Set<TokenUsageAITool>? in [nil, [.codex], [.claude, .antigravity]] {
                    let bounds = store.dashboardDateBounds(
                        dashboardToolsOnly: !showAdvancedTools, visibleTools: visibleTools
                    )
                    let periods = store.allPeriodInputScopeTotals(
                        now: now, calendar: calendar,
                        dashboardToolsOnly: !showAdvancedTools, visibleTools: visibleTools
                    )
                    let days = store.dashboardDayInputScopeTotals(
                        startingAt: month, endingBefore: monthEnd, calendar: calendar,
                        dashboardToolsOnly: !showAdvancedTools, visibleTools: visibleTools
                    )
                    for tool: TokenUsageAITool? in [nil, .codex, .claude] {
                        for scope: TokenUsageInputScope in [.includeCache, .freshOnly] {
                            let expected = TokenUsageDashboardSnapshot.buildPair(
                                events: events, selectedTool: tool, selectedPeriod: .all,
                                selectedCalendarDayID: dayID, selectedProjectID: nil, selectedSessionID: nil,
                                language: .english, localAliases: [:], showAdvancedTools: showAdvancedTools,
                                visibleTools: visibleTools, now: now, proposedCalendarMonthStart: month,
                                calendar: calendar, periodFilterTotals: periods, availableDateBounds: bounds,
                                calendarDayTotals: days, inputScope: scope,
                                locale: locale, timeZone: calendar.timeZone
                            ).filtered
                            let actual = try XCTUnwrap(TokenUsageDashboardSnapshot.buildFromSQLAggregates(
                                usageStore: store, selectedTool: tool, selectedPeriod: .all,
                                selectedCalendarDayID: dayID, inputScope: scope, language: .english,
                                showAdvancedTools: showAdvancedTools, visibleTools: visibleTools,
                                now: now, calendarMonthStart: month, calendar: calendar,
                                locale: locale, timeZone: calendar.timeZone,
                                preloadedPeriodFilterTotals: periods
                            ))
                            XCTAssertEqual(
                                actual, expected,
                                "day=\(String(describing: dayID)) advanced=\(showAdvancedTools) tools=\(String(describing: visibleTools)) tool=\(String(describing: tool)) scope=\(scope)"
                            )
                            comparedSnapshots += 1
                        }
                    }
                }
            }
        }
        XCTAssertEqual(comparedSnapshots, 2 * 2 * 3 * 3 * 2)
        XCTAssertEqual(store.loadEvents().count, 121)
    }

    func testRollupsSkipBlankGroupingValuesAndKeepLegacyLabels() throws {
        let store = try makeStore()
        let base = try XCTUnwrap(ISO8601DateFormatter.parseTokenUsageDate(from: "2026-10-01T00:00:00Z"))
        try seedVariedEvents(store, base: base)
        store.withDatabaseConnection(nil, default: ()) { database in
            for statement in [
                "UPDATE token_usage_events SET project_id = NULL WHERE span_id = 'span_grouped_0001'",
                "UPDATE token_usage_events SET project_id = '' WHERE span_id = 'span_grouped_0007'",
                "UPDATE token_usage_events SET task_type = NULL WHERE span_id = 'span_grouped_0002'",
                "UPDATE token_usage_events SET stage = NULL WHERE span_id = 'span_grouped_0003'",
                "UPDATE token_usage_events SET model = NULL WHERE span_id = 'span_grouped_0004'",
                "UPDATE token_usage_events SET model = '  Unknown ' WHERE span_id = 'span_grouped_0005'",
                "UPDATE token_usage_events SET model = '' WHERE span_id = 'span_grouped_0006'",
                "UPDATE token_usage_events SET ai_tool = 'agy' WHERE span_id = 'span_grouped_0010'"
            ] {
                XCTAssertEqual(sqlite3_exec(database, statement, nil, nil, nil), SQLITE_OK, statement)
            }
        }
        let aggregate = store.groupedAggregate(dashboardToolsOnly: false)
        let rows = aggregate.rows

        XCTAssertEqual(rows.reduce(0) { $0 + $1.eventCount }, 121)
        XCTAssertNil(aggregate.projectTotals()[""])
        XCTAssertEqual(
            aggregate.projectTotals().values.reduce(0) { $0 + $1.eventCount },
            121 - 2,
            "NULL and blank project ids are not projects"
        )
        XCTAssertEqual(
            aggregate.totalsByTool(key: \.taskType).values.flatMap(\.values).reduce(0) { $0 + $1.includeCache },
            rows.filter { $0.taskType != nil }.reduce(0) { $0 + $1.totalTokens }
        )
        XCTAssertEqual(
            aggregate.totalsByTool(key: \.stage).values.flatMap(\.values).reduce(0) { $0 + $1.includeCache },
            rows.filter { $0.stage != nil }.reduce(0) { $0 + $1.totalTokens }
        )
        XCTAssertNil(aggregate.modelTotals()[""])
        XCTAssertEqual(
            aggregate.modelTotals().values.reduce(0) { $0 + $1.includeCache },
            rows.filter { $0.modelKey != nil }.reduce(0) { $0 + $1.totalTokens },
            "A NULL model has no model row"
        )
        XCTAssertGreaterThan(aggregate.modelTotals()["model_unavailable"]?.includeCache ?? 0, 0)
        XCTAssertNil(aggregate.modelTotals()["  Unknown "], "Whitespace-padded unknown spellings merge into one row")
        XCTAssertNotNil(aggregate.toolTotals()[.antigravity], "The legacy 'agy' label is Antigravity")

        let nullTask = DashboardGroupedAggregateRow.testRow(taskType: nil, stage: "summarize")
        let nullTaskActiveStage = DashboardGroupedAggregateRow.testRow(taskType: nil, stage: "verify")
        XCTAssertFalse(nullTask.isAssisted, "A NULL column never satisfies its half of the assisted test")
        XCTAssertTrue(nullTaskActiveStage.isAssisted)
    }

    private func makeStore() throws -> TokenUsageStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupedAggregate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return TokenUsageStore(fileURL: directory.appendingPathComponent("events.json"))
    }

    private func seedVariedEvents(_ store: TokenUsageStore, base: Date) throws {
        let tools: [TokenUsageAITool] = [.codex, .claude, .antigravity, .openAI, .unknown]
        let projects = ["project_alpha", "project_beta", "project_gamma"]
        let tasks = ["testing", "uncategorized", "debugging", "code_review"]
        let stages = ["verify", "summarize", "implement"]
        let models = ["model-a", "model-b", "unknown", "model_unknown", "unavailable", "Model-C"]
        var events = [TokenUsageEvent]()
        for index in 0..<120 {
            let input = index % 7 == 0 ? 0 : 40 + index % 13
            let output = 5 + index % 9
            let accounting: TokenUsageAccounting? = switch index % 4 {
            case 0: TokenUsageAccounting(uncachedInputTokens: input / 2, cacheReadInputTokens: input / 4)
            case 1: TokenUsageAccounting(uncachedInputTokens: input)
            default: nil
            }
            events.append(TokenUsageEvent(
                schemaVersion: 1, deviceID: "device_fixture", projectID: projects[index % projects.count],
                artifactID: "artifact_fixture", runID: "run_\(index % 9)_fixture",
                spanID: String(format: "span_grouped_%04d", index),
                aiTool: tools[index % tools.count],
                taskType: try XCTUnwrap(TokenUsageTaskType(rawValue: tasks[index % tasks.count])),
                stage: try XCTUnwrap(TokenUsageStage(rawValue: stages[index % stages.count])),
                model: models[index % models.count],
                inputTokens: input, outputTokens: output, totalTokens: input + output,
                tokenBreakdown: TokenUsageBreakdown(
                    system: 0, user: 0, history: 0, repoContext: 0,
                    toolOutput: 0, generatedOutput: output, unknown: input
                ),
                tokenAccounting: accounting,
                latencyMS: 0,
                createdAt: ISO8601DateFormatter.tokenUsage.string(from: base.addingTimeInterval(Double(index) * 90))
            ))
        }
        // One late event so a bounded range far from the rest still has rows.
        let first = events[0]
        events.append(TokenUsageEvent(
            schemaVersion: 1, deviceID: first.deviceID, projectID: first.projectID, artifactID: first.artifactID,
            runID: first.runID, spanID: "span_grouped_late", aiTool: first.aiTool, taskType: first.taskType,
            stage: first.stage, model: first.model, inputTokens: first.inputTokens,
            outputTokens: first.outputTokens, totalTokens: first.totalTokens,
            tokenBreakdown: first.tokenBreakdown, tokenAccounting: first.tokenAccounting, latencyMS: 0,
            createdAt: ISO8601DateFormatter.tokenUsage.string(from: base.addingTimeInterval(10 * 86_400 + 60))
        ))
        _ = try store.appendEventsWithoutLoading(events)
    }
}

private extension DashboardGroupedAggregateRow {
    static func testRow(taskType: String?, stage: String?) -> DashboardGroupedAggregateRow {
        DashboardGroupedAggregateRow(
            toolLabel: "codex", projectID: "project_alpha", taskType: taskType, stage: stage, modelKey: "m",
            eventCount: 1, totalTokens: 10, freshTokens: 10, inputTokens: 5, outputTokens: 5,
            uncachedInput: 0, cacheCreationInput: 0, cacheReadInput: 0, unclassifiedInput: 5,
            inputEventCount: 1, sources: [:]
        )
    }
}
