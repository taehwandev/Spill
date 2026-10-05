import Foundation
import XCTest
@testable import Spill

@MainActor
final class TokenUsageDashboardUnfilteredReuseTests: XCTestCase {
    func testToolSwitchKeepsUnfilteredSnapshotAndNarrowsFilteredOne() async throws {
        let fixture = try TokenUsageDashboardLargeFixture(eventCount: 1_000)
        defer { fixture.remove() }
        let store = TokenUsageDashboardStore(
            usageStore: fixture.usageStore, loadsInitialPanelSummary: false, notificationCenter: NotificationCenter()
        )
        store.restoreFilters(DashboardRestoredFilters(
            tool: nil, period: TokenUsageDashboardPeriod.all.rawValue, offset: 0,
            day: nil, project: nil, session: nil, month: fixture.currentMonthStart
        ))
        store.selectCalendarDay(fixture.selectedDayID)
        try await waitUntilLoaded(store)
        let dayUnfiltered = store.unfilteredSnapshot

        store.setSelectedTool(.codex)
        try await waitUntilLoaded(store)

        XCTAssertEqual(store.unfilteredSnapshot, dayUnfiltered)
        XCTAssertEqual(store.snapshot.eventCount, fixture.selectedDayEventCount / 2)
        XCTAssertEqual(store.unfilteredSnapshot.eventCount, fixture.selectedDayEventCount)

        store.setSelectedTool(nil)
        try await waitUntilLoaded(store)
        XCTAssertEqual(store.snapshot.eventCount, fixture.selectedDayEventCount)
    }

    func testScopeAdmitsReuseOnlyForSameScopeFreshDataAndRecentBuild() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let base = Self.request(now: now)
        let scope = try XCTUnwrap(TokenUsageDashboardUnfilteredScope(request: base, dataRevision: 7))

        func admits(_ request: TokenUsageDashboardBuildRequest, revision: UInt64? = 7) -> Bool {
            TokenUsageDashboardUnfilteredScope(request: request, dataRevision: revision)
                .map(scope.admitsReuse) ?? false
        }

        XCTAssertTrue(admits(Self.request(now: now.addingTimeInterval(30), tool: .codex)))
        XCTAssertFalse(admits(Self.request(now: now.addingTimeInterval(60))))
        XCTAssertFalse(admits(Self.request(now: now.addingTimeInterval(-1))))
        XCTAssertFalse(admits(base, revision: 8))
        XCTAssertFalse(admits(Self.request(now: now, period: .all, day: "2026-10-02")))
        XCTAssertFalse(admits(Self.request(now: now, inputScope: .freshOnly)))
        XCTAssertFalse(admits(Self.request(now: now, offset: 1)))
        XCTAssertNil(TokenUsageDashboardUnfilteredScope(request: base, dataRevision: nil))
        XCTAssertNil(TokenUsageDashboardUnfilteredScope(
            request: Self.request(now: now, project: "project-a"), dataRevision: 7
        ))
    }

    private static func request(
        now: Date,
        tool: TokenUsageAITool? = nil,
        period: TokenUsageDashboardPeriod = .all,
        day: String? = nil,
        project: String? = nil,
        offset: Int = 0,
        inputScope: TokenUsageInputScope = .includeCache
    ) -> TokenUsageDashboardBuildRequest {
        TokenUsageDashboardBuildRequest(
            selectedTool: tool, selectedPeriod: period, selectedCalendarDayID: day,
            selectedProjectID: project, selectedSessionID: nil, language: .english,
            localAliases: [:], showAdvancedTools: false, visibleAITools: nil, now: now,
            proposedCalendarMonthStart: nil, calendar: Calendar(identifier: .gregorian),
            periodOffset: offset, inputScope: inputScope, availableDateBounds: .empty
        )
    }

    private func waitUntilLoaded(_ store: TokenUsageDashboardStore) async throws {
        let deadline = ProcessInfo.processInfo.systemUptime + 60
        while store.isDashboardRefreshInProgress || store.loadState != .loaded {
            guard ProcessInfo.processInfo.systemUptime < deadline else {
                XCTFail("Dashboard refresh did not finish")
                throw NSError(domain: "SpillTests.DashboardUnfilteredReuse", code: 1)
            }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
    }
}
