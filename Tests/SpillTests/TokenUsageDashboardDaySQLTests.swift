import Foundation
import XCTest
@testable import Spill

final class TokenUsageDashboardDaySQLTests: XCTestCase {
    func testSelectedDaySQLMatchesBoundedEventSnapshotAcrossScopes() throws {
        let fixture = try TokenUsageDashboardLargeFixture(eventCount: 20)
        defer { fixture.remove() }
        let store = fixture.usageStore
        let calendar = fixture.calendar
        let locale = Locale(identifier: "en_US")
        for dayID in [fixture.selectedDayID, "2026-09-15", "2026-09-10"] {
            let day = try XCTUnwrap(TokenUsageDashboardSnapshot.date(forDayID: dayID, calendar: calendar))
            let dayEnd = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: day))
            let events = store.loadEvents(startingAt: day, endingBefore: dayEnd)
            let month = TokenUsageDashboardSnapshot.monthStart(for: day, calendar: calendar)
            let monthEnd = try XCTUnwrap(calendar.date(byAdding: .month, value: 1, to: month))
            for visibleTools: Set<TokenUsageAITool>? in [nil, [.codex], []] {
                let bounds = store.dashboardDateBounds(visibleTools: visibleTools)
                let periods = store.allPeriodInputScopeTotals(now: fixture.now, calendar: calendar, visibleTools: visibleTools)
                let days = store.dashboardDayInputScopeTotals(
                    startingAt: month, endingBefore: monthEnd, calendar: calendar, visibleTools: visibleTools
                )
                for period: TokenUsageDashboardPeriod in [.today, .sevenDays, .all] {
                    for tool: TokenUsageAITool? in [nil, .codex, .claude] {
                        for scope: TokenUsageInputScope in [.includeCache, .freshOnly] {
                            let expected = TokenUsageDashboardSnapshot.buildPair(
                                events: events, selectedTool: tool, selectedPeriod: period,
                                selectedCalendarDayID: dayID, selectedProjectID: nil, selectedSessionID: nil,
                                language: .english, localAliases: [:], showAdvancedTools: false,
                                visibleTools: visibleTools, now: fixture.now,
                                proposedCalendarMonthStart: month, calendar: calendar,
                                periodFilterTotals: periods, availableDateBounds: bounds,
                                calendarDayTotals: days, inputScope: scope,
                                locale: locale, timeZone: calendar.timeZone
                            ).filtered
                            let actual = try XCTUnwrap(TokenUsageDashboardSnapshot.buildFromSQLAggregates(
                                usageStore: store, selectedTool: tool, selectedPeriod: period,
                                selectedCalendarDayID: dayID, inputScope: scope, language: .english,
                                visibleTools: visibleTools, now: fixture.now, calendarMonthStart: month,
                                calendar: calendar, locale: locale, timeZone: calendar.timeZone,
                                preloadedPeriodFilterTotals: periods
                            ))
                            XCTAssertEqual(actual, expected, "\(dayID), \(period), \(String(describing: tool)), \(scope)")
                        }
                    }
                }
            }
        }
    }

    @MainActor
    func testMonthNavigationUsesEveryVisibleToolEvenWithOneToolSelected() async throws {
        let fixture = try TokenUsageDashboardLargeFixture(eventCount: 20)
        defer { fixture.remove() }
        let oldDate = try XCTUnwrap(fixture.calendar.date(from: DateComponents(year: 2026, month: 8, day: 15, hour: 12)))
        try fixture.usageStore.appendEvent(event(spanID: "span_old_visible_tool", date: oldDate))
        let store = TokenUsageDashboardStore(
            usageStore: fixture.usageStore, loadsInitialPanelSummary: false, notificationCenter: NotificationCenter()
        )
        store.restoreFilters(DashboardRestoredFilters(tool: "codex", period: "all", offset: 0,
            day: nil, project: nil, session: nil, month: fixture.currentMonthStart))
        store.refreshAsync(trackLiveUpdates: false, refreshesPanelSummary: false)
        try await wait(store)
        store.showPreviousCalendarMonth()
        try await wait(store)
        XCTAssertTrue(store.snapshot.canNavigatePreviousCalendarMonth)
        store.showPreviousCalendarMonth()
        try await wait(store)
        XCTAssertTrue(store.snapshot.calendarDays.contains { $0.id == "2026-08-15" && $0.hasEvents })
        XCTAssertEqual(store.snapshot.eventCount, 10)
    }

    @MainActor
    func testMonthNavigationRefreshesAnalyticsAfterStoreMutation() async throws {
        let fixture = try TokenUsageDashboardLargeFixture(eventCount: 20)
        defer { fixture.remove() }
        let store = TokenUsageDashboardStore(
            usageStore: fixture.usageStore, loadsInitialPanelSummary: false, notificationCenter: NotificationCenter()
        )
        store.restoreFilters(DashboardRestoredFilters(tool: nil, period: "all", offset: 0,
            day: nil, project: nil, session: nil, month: fixture.currentMonthStart))
        store.refreshAsync(trackLiveUpdates: false, refreshesPanelSummary: false)
        try await wait(store)
        XCTAssertEqual(store.snapshot.totalTokens, 20_000)
        try fixture.usageStore.appendEvent(event(spanID: "span_month_mutation", date: fixture.previousMonthStart))
        store.showPreviousCalendarMonth()
        try await wait(store)
        XCTAssertEqual(store.snapshot.eventCount, 21)
        XCTAssertEqual(store.snapshot.totalTokens, 20_100)
        XCTAssertTrue(store.snapshot.calendarDays.contains { $0.id == "2026-09-01" && $0.hasEvents })
    }

    @MainActor
    func testRapidMonthAndFilterChangesPublishLatestScope() async throws {
        let fixture = try TokenUsageDashboardLargeFixture(eventCount: 20)
        defer { fixture.remove() }
        let store = TokenUsageDashboardStore(
            usageStore: fixture.usageStore, loadsInitialPanelSummary: false, notificationCenter: NotificationCenter()
        )
        store.restoreFilters(DashboardRestoredFilters(
            tool: nil, period: "all", offset: 0, day: nil, project: nil, session: nil, month: fixture.currentMonthStart
        ))
        store.refreshAsync(trackLiveUpdates: false, refreshesPanelSummary: false)
        try await wait(store)
        store.showPreviousCalendarMonth()
        store.showNextCalendarMonth()
        try await wait(store)
        XCTAssertEqual(store.snapshot.eventCount, 20)
        XCTAssertEqual(store.calendarMonthStart, fixture.currentMonthStart)

        // A month click must not replace an in-flight day/tool request with old All analytics.
        store.selectCalendarDay(fixture.selectedDayID)
        store.setSelectedTool(.codex)
        store.showPreviousCalendarMonth()
        try await wait(store)
        XCTAssertEqual(store.snapshot.selectedCalendarDayID, fixture.selectedDayID)
        XCTAssertEqual(store.snapshot.eventCount, 8)
        XCTAssertEqual(store.snapshot.toolRows.map(\.id), ["codex"])
        XCTAssertEqual(store.calendarMonthStart, fixture.previousMonthStart)
        XCTAssertNil(store.snapshot.comparisonTotalTokens)
    }

    private func event(spanID: String, date: Date) -> TokenUsageEvent {
        TokenUsageEvent(
            schemaVersion: 1, deviceID: "device_fixture", projectID: "project_fixture",
            artifactID: "artifact_fixture", runID: "run_old_fixture", spanID: spanID,
            aiTool: .claude, taskType: .testing, stage: .verify, model: "fixture-model",
            inputTokens: 100, outputTokens: 0, totalTokens: 100,
            tokenBreakdown: TokenUsageBreakdown(system: 0, user: 0, history: 0, repoContext: 0,
                toolOutput: 0, generatedOutput: 0, unknown: 100),
            latencyMS: 0, createdAt: ISO8601DateFormatter.tokenUsage.string(from: date)
        )
    }

    @MainActor
    private func wait(_ store: TokenUsageDashboardStore) async throws {
        let deadline = ProcessInfo.processInfo.systemUptime + 10
        while store.isDashboardRefreshInProgress || store.loadState != .loaded {
            if ProcessInfo.processInfo.systemUptime > deadline {
                throw NSError(domain: "SpillTests.DashboardWait", code: 1)
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}
