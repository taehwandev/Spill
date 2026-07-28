import Combine
import XCTest
@testable import Spill

@MainActor
final class TokenUsageDashboardStoreTests: XCTestCase {
    func testRepeatedIdenticalRefreshDoesNotRepublishSnapshotState() async throws {
        let eventsURL = temporaryEventsURL()
        defer {
            try? FileManager.default.removeItem(at: eventsURL.deletingLastPathComponent())
        }
        let usageStore = TokenUsageStore(fileURL: eventsURL)
        let store = TokenUsageDashboardStore(
            usageStore: usageStore,
            loadsInitialPanelSummary: false
        )

        store.refreshAsync(trackLiveUpdates: false, refreshesPanelSummary: false)
        try await waitForRefresh(store)

        var snapshotPublications = 0
        var unfilteredSnapshotPublications = 0
        var calendarMonthPublications = 0
        var projectPublications = 0
        var sessionPublications = 0
        var scopePublications = 0
        var loadStatePublications = 0
        var cancellables: Set<AnyCancellable> = []

        store.$snapshot.dropFirst().sink { _ in
            snapshotPublications += 1
        }.store(in: &cancellables)
        store.$unfilteredSnapshot.dropFirst().sink { _ in
            unfilteredSnapshotPublications += 1
        }.store(in: &cancellables)
        store.$calendarMonthStart.dropFirst().sink { _ in
            calendarMonthPublications += 1
        }.store(in: &cancellables)
        store.$selectedProjectID.dropFirst().sink { _ in
            projectPublications += 1
        }.store(in: &cancellables)
        store.$selectedSessionID.dropFirst().sink { _ in
            sessionPublications += 1
        }.store(in: &cancellables)
        store.$snapshotInputScope.dropFirst().sink { _ in
            scopePublications += 1
        }.store(in: &cancellables)
        store.$loadState.dropFirst().sink { _ in
            loadStatePublications += 1
        }.store(in: &cancellables)

        store.refreshAsync(trackLiveUpdates: false, refreshesPanelSummary: false)
        try await waitForRefresh(store)

        XCTAssertEqual(snapshotPublications, 0)
        XCTAssertEqual(unfilteredSnapshotPublications, 0)
        XCTAssertEqual(calendarMonthPublications, 0)
        XCTAssertEqual(projectPublications, 0)
        XCTAssertEqual(sessionPublications, 0)
        XCTAssertEqual(scopePublications, 0)
        XCTAssertEqual(loadStatePublications, 0)
        withExtendedLifetime(cancellables) {}
    }

    private func waitForRefresh(_ store: TokenUsageDashboardStore) async throws {
        for _ in 0..<40 {
            if store.loadState == .loaded, !store.isDashboardRefreshInProgress {
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("Dashboard store refresh did not finish")
    }

    private func temporaryEventsURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("events.json")
    }
}
