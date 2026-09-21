import Combine
import XCTest
@testable import Spill

final class PanelStoreTests: XCTestCase {
    @MainActor
    func testSettingsRefreshWithoutAccessibilityAndPreserveWindowFeedback() async {
        let settings = makeSettings()
        let store = PanelStore(settings: settings, windowActionPerformer: { _ in .permissionRequired("Accessibility") })
        store.send(.performWindowAction(SpillAction(id: "left", title: "Left", kind: .window(.leftHalf), role: .secondary)))
        store.send(.setStatusDetailTarget(.system(.cpu)))
        let refreshed = expectation(description: "Settings propagate")
        let subscription = store.$state.dropFirst().sink { state in
            if state.visibleStatusModules == [.storage, .cpu, .network, .gpu] { refreshed.fulfill() }
        }
        settings.setStatusModuleOrder([.storage, .memory, .cpu])
        settings.setStatusModule(.memory, enabled: false)
        await fulfillment(of: [refreshed], timeout: 1)
        XCTAssertEqual(store.state.actionFeedback?.result, .permissionRequired("Accessibility"))
        XCTAssertEqual(store.state.statusDetailTarget, .system(.cpu))
        subscription.cancel()
    }

    @MainActor
    func testWindowActionUsesInjectedPerformerAndStoresFeedback() {
        let settings = makeSettings()
        let action = SpillAction(
            id: "window.leftHalf",
            title: "Left",
            kind: .window(.leftHalf),
            role: .secondary
        )
        var performedAction: SpillAction?
        let store = PanelStore(
            settings: settings,
            windowActionPerformer: { action in
                performedAction = action
                return .failed(message: "Could not move window")
            }
        )

        store.send(.performWindowAction(action))

        XCTAssertEqual(performedAction, action)
        XCTAssertEqual(store.state.actionFeedback?.message, "Could not move window")
    }

    @MainActor
    func testStatusDetailTargetIsPanelStateAndSurvivesRefresh() {
        let settings = makeSettings()
        let store = PanelStore(
            settings: settings
        )

        store.send(.setStatusDetailTarget(.system(.cpu)))
        XCTAssertEqual(store.state.statusDetailTarget, .system(.cpu))

        store.send(.refreshDerivedState)
        XCTAssertEqual(store.state.statusDetailTarget, .system(.cpu))

        store.send(.setStatusDetailTarget(nil))
        XCTAssertNil(store.state.statusDetailTarget)
    }

    @MainActor
    private func makeSettings() -> SpillSettings {
        let defaultsName = "PanelStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defaults.removePersistentDomain(forName: defaultsName)
        return SpillSettings(defaults: defaults)
    }

}
