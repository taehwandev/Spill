import Foundation
import XCTest
@testable import Spill

@MainActor
final class TokenUsageDashboardCalendarPerformanceTests: XCTestCase {
    func testCalendarAndFilterActionsOnOneHundredThousandEvents() async throws {
        let fixture = try TokenUsageDashboardLargeFixture()
        defer { fixture.remove() }
        let store = TokenUsageDashboardStore(
            usageStore: fixture.usageStore, loadsInitialPanelSummary: false, notificationCenter: NotificationCenter()
        )
        store.restoreFilters(DashboardRestoredFilters(
            tool: nil, period: TokenUsageDashboardPeriod.all.rawValue, offset: 0,
            day: nil, project: nil, session: nil, month: fixture.currentMonthStart
        ))

        try await measure("initial-all", store: store) {
            store.refreshAsync(trackLiveUpdates: false, refreshesPanelSummary: false)
        }
        XCTAssertEqual(store.snapshot.eventCount, fixture.eventCount)
        XCTAssertEqual(store.snapshot.totalTokens, 100_000_000)
        XCTAssertEqual(store.snapshot.inputAccounting.rawInputTokens, 98_000_000)
        XCTAssertEqual(store.snapshot.inputAccounting.exactFreshInputTokens, 8_000_000)

        let directMonthStartedAt = ProcessInfo.processInfo.systemUptime
        let monthTotals = fixture.usageStore.dashboardDayInputScopeTotals(
            startingAt: fixture.previousMonthStart, endingBefore: fixture.currentMonthStart,
            calendar: fixture.calendar, dashboardToolsOnly: true
        )
        report("direct-month-summary", startedAt: directMonthStartedAt)
        XCTAssertEqual(monthTotals["2026-09-15"]?.includeCache, 20_000_000)
        XCTAssertEqual(monthTotals["2026-09-15"]?.freshOnly, 2_000_000)

        let initialSessions = store.snapshot.sessions
        try await measure("previous-month", store: store) { store.showPreviousCalendarMonth() }
        XCTAssertEqual(store.snapshot.sessions, initialSessions)
        XCTAssertEqual(store.snapshot.eventCount, fixture.eventCount)
        XCTAssertTrue(store.snapshot.calendarDays.contains { $0.id == "2026-09-15" && $0.hasEvents })

        try await measure("next-month", store: store) { store.showNextCalendarMonth() }
        XCTAssertEqual(store.snapshot.sessions, initialSessions)
        XCTAssertEqual(store.snapshot.eventCount, fixture.eventCount)
        XCTAssertTrue(store.snapshot.calendarDays.contains { $0.id == fixture.selectedDayID && $0.hasEvents })

        try await measure("selected-day", store: store) { store.selectCalendarDay(fixture.selectedDayID) }
        XCTAssertEqual(store.snapshot.selectedCalendarDayID, fixture.selectedDayID)
        XCTAssertEqual(store.snapshot.eventCount, fixture.selectedDayEventCount)
        XCTAssertEqual(store.snapshot.totalTokens, 80_000_000)

        try await measure("selected-day-codex", store: store) { store.setSelectedTool(.codex) }
        XCTAssertEqual(store.snapshot.eventCount, 40_000)
        XCTAssertEqual(store.snapshot.totalTokens, 40_000_000)
        XCTAssertEqual(store.snapshot.toolRows.map(\.id), ["codex"])
    }

    private func measure(_ name: String, store: TokenUsageDashboardStore, action: () -> Void) async throws {
        let startedAt = ProcessInfo.processInfo.systemUptime
        action()
        let deadline = startedAt + 120
        while store.isDashboardRefreshInProgress || store.loadState != .loaded {
            guard ProcessInfo.processInfo.systemUptime < deadline else {
                XCTFail("Synthetic dashboard action did not finish: \(name)")
                throw NSError(domain: "SpillTests.DashboardPerformanceTimeout", code: 1)
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        report(name, startedAt: startedAt)
    }

    private func report(_ name: String, startedAt: TimeInterval) {
        let milliseconds = (ProcessInfo.processInfo.systemUptime - startedAt) * 1_000
        print("SPILL_DASHBOARD_PERF events=100000 action=\(name) duration_ms=\(String(format: "%.2f", milliseconds))")
    }
}
