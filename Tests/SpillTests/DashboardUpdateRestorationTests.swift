import XCTest
@testable import Spill

@MainActor
final class DashboardUpdateRestorationTests: XCTestCase {
    func testUpdateReopensOnceAndRestoresFiltersAcrossInstances() {
        let suite = "SpillTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let date = Date(timeIntervalSince1970: 10_000)
        let previous = DashboardUpdateRestoration(defaults: defaults, now: { date })
        let filters = DashboardRestoredFilters(tool: "codex", period: "sevenDays", offset: -1,
            day: nil, project: "project_global", session: nil, month: date)
        previous.save(filters)
        XCTAssertNil(previous.consumeFilters(), "Ordinary launch must not restore update state")
        previous.prepare(isDashboardOpen: true)
        let next = DashboardUpdateRestoration(defaults: defaults, now: { date.addingTimeInterval(20) })
        XCTAssertTrue(next.consumeReopenRequest())
        XCTAssertFalse(next.consumeReopenRequest())
        XCTAssertEqual(next.consumeFilters(), filters)
        XCTAssertNil(next.consumeFilters())
    }

    func testClosedExpiredAndFutureRequestsDoNotReopen() {
        let suite = "SpillTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let date = Date(timeIntervalSince1970: 10_000)
        let state = DashboardUpdateRestoration(defaults: defaults, now: { date })
        state.prepare(isDashboardOpen: false)
        XCTAssertFalse(state.consumeReopenRequest())
        state.prepare(isDashboardOpen: true)
        let late = DashboardUpdateRestoration(defaults: defaults, now: { date.addingTimeInterval(600) })
        XCTAssertFalse(late.consumeReopenRequest())
        state.prepare(isDashboardOpen: true)
        let early = DashboardUpdateRestoration(defaults: defaults, now: { date.addingTimeInterval(-1) })
        XCTAssertFalse(early.consumeReopenRequest())
    }

    func testRestoringUnknownFiltersFallsBackSafely() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = TokenUsageDashboardStore(
            usageStore: TokenUsageStore(fileURL: directory.appendingPathComponent("events.json")),
            loadsInitialPanelSummary: false
        )
        store.restoreFilters(DashboardRestoredFilters(tool: "removed", period: "removed", offset: 100,
            day: nil, project: nil, session: nil, month: nil))
        XCTAssertNil(store.selectedTool)
        XCTAssertEqual(store.selectedPeriod, .today)
        XCTAssertEqual(store.periodOffset, 0)
    }
}
