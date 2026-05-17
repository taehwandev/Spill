import CoreGraphics
import Combine
import XCTest
@testable import Spill

final class PanelStoreTests: XCTestCase {
    func testReadyStateOrdersPinnedActionsBeforeUnpinnedActions() {
        let pinned = Self.item(stableKey: "pinned", title: "Pinned")
        let unpinned = Self.item(stableKey: "unpinned", title: "Unpinned")

        let state = PanelState.derived(
            notchCandidates: [unpinned, pinned],
            selectedItemKeys: ["pinned"],
            hiddenItemKeys: [],
            isScanning: false,
            isAccessibilityTrusted: true
        )

        XCTAssertEqual(state.readiness, .ready)
        XCTAssertEqual(state.displayItems.map(\.stableKey), ["unpinned", "pinned"])
        XCTAssertEqual(state.pinnedItems.map(\.stableKey), ["pinned"])
        XCTAssertEqual(state.displayActionItems.map(\.stableKey), ["unpinned"])
        XCTAssertEqual(state.actionItems.map(\.sourceItem.stableKey), ["pinned", "unpinned"])
        XCTAssertEqual(state.actionItems.map(\.isPinned), [true, false])
        XCTAssertEqual(state.visibleStatusModules, SpillStatusModule.primaryPanelModules)
    }

    func testPermissionRequiredStateTakesPrecedenceOverScanningAndItems() {
        let state = PanelState.derived(
            notchCandidates: [Self.item(stableKey: "item")],
            selectedItemKeys: [],
            hiddenItemKeys: [],
            isScanning: true,
            isAccessibilityTrusted: false
        )

        XCTAssertEqual(state.readiness, .permissionRequired)
        XCTAssertEqual(state.itemCount, 1)
    }

    func testScanningStateWhenTrustedScanningAndEmpty() {
        let state = PanelState.derived(
            notchCandidates: [],
            selectedItemKeys: [],
            hiddenItemKeys: [],
            isScanning: true,
            isAccessibilityTrusted: true
        )

        XCTAssertEqual(state.readiness, .scanning)
        XCTAssertTrue(state.actionItems.isEmpty)
    }

    func testEmptyStateWhenTrustedIdleAndEmpty() {
        let state = PanelState.derived(
            notchCandidates: [],
            selectedItemKeys: [],
            hiddenItemKeys: [],
            isScanning: false,
            isAccessibilityTrusted: true
        )

        XCTAssertEqual(state.readiness, .empty)
        XCTAssertEqual(state.itemCount, 0)
        XCTAssertEqual(state.pinnedItemCount, 0)
    }

    func testHiddenItemsAreExcludedFromDisplayedAndPinnedActions() {
        let hiddenPinned = Self.item(stableKey: "hidden-pinned", title: "Hidden")
        let visible = Self.item(stableKey: "visible", title: "Visible")

        let state = PanelState.derived(
            notchCandidates: [hiddenPinned, visible],
            selectedItemKeys: ["hidden-pinned"],
            hiddenItemKeys: ["hidden-pinned"],
            isScanning: false,
            isAccessibilityTrusted: true
        )

        XCTAssertEqual(state.readiness, .ready)
        XCTAssertEqual(state.displayItems.map(\.stableKey), ["visible"])
        XCTAssertTrue(state.pinnedItems.isEmpty)
        XCTAssertEqual(state.actionItems.map(\.sourceItem.stableKey), ["visible"])
    }

    @MainActor
    func testPanelStoreRefreshUsesInjectedTrustReader() {
        let settings = makeSettings()
        let scanner = AXMenuBarItemScanner()
        var isTrusted = false
        let store = PanelStore(
            settings: settings,
            scanner: scanner,
            isAccessibilityTrusted: { isTrusted },
            stateBuilder: { _, _, isAccessibilityTrusted in
                PanelState.derived(
                    notchCandidates: [Self.item(stableKey: "item")],
                    selectedItemKeys: [],
                    hiddenItemKeys: [],
                    isScanning: false,
                    isAccessibilityTrusted: isAccessibilityTrusted
                )
            }
        )

        XCTAssertEqual(store.state.readiness, .permissionRequired)

        isTrusted = true
        store.send(.refreshDerivedState)

        XCTAssertEqual(store.state.readiness, .ready)
    }

    @MainActor
    func testPanelStoreUsesConfiguredStatusModuleOrderAndEnabledState() {
        let settings = makeSettings()
        settings.setStatusModuleOrder([.storage, .memory, .cpu])
        settings.setStatusModule(.memory, enabled: false)
        let scanner = AXMenuBarItemScanner()
        let store = PanelStore(
            settings: settings,
            scanner: scanner,
            isAccessibilityTrusted: { true }
        )

        XCTAssertEqual(store.state.visibleStatusModules, [.storage, .cpu, .network])
    }

    @MainActor
    func testDisplayModeChangesRefreshDerivedState() async {
        let settings = makeSettings()
        let scanner = AXMenuBarItemScanner()
        let notchItem = Self.item(stableKey: "notch", title: "Notch")
        let allItem = Self.item(stableKey: "all", title: "All")
        let store = PanelStore(
            settings: settings,
            scanner: scanner,
            isAccessibilityTrusted: { true },
            stateBuilder: { settings, _, isAccessibilityTrusted in
                let items = settings.displayMode == .allDetected ? [allItem] : [notchItem]
                return PanelState.derived(
                    displayItems: items,
                    selectedItemKeys: settings.selectedItemKeys,
                    visibleStatusModules: settings.visiblePanelStatusModules,
                    isScanning: false,
                    isAccessibilityTrusted: isAccessibilityTrusted
                )
            }
        )
        let refreshed = expectation(description: "Display mode refreshes panel state")
        var cancellable: AnyCancellable?

        XCTAssertEqual(store.state.displayItems.map(\.stableKey), ["notch"])

        cancellable = store.$state
            .dropFirst()
            .sink { state in
                if state.displayItems.map(\.stableKey) == ["all"] {
                    refreshed.fulfill()
                }
            }

        settings.displayMode = .allDetected

        await fulfillment(of: [refreshed], timeout: 1.0)
        cancellable?.cancel()
    }

    @MainActor
    func testTogglePinnedActionUpdatesSettingsAndFeedback() {
        let settings = makeSettings()
        let scanner = AXMenuBarItemScanner()
        let item = Self.item(stableKey: "item", title: "Example")
        let store = PanelStore(
            settings: settings,
            scanner: scanner,
            isAccessibilityTrusted: { true },
            stateBuilder: { settings, _, isAccessibilityTrusted in
                PanelState.derived(
                    notchCandidates: [item],
                    selectedItemKeys: settings.selectedItemKeys,
                    hiddenItemKeys: settings.hiddenItemKeys,
                    isScanning: false,
                    isAccessibilityTrusted: isAccessibilityTrusted
                )
            }
        )

        XCTAssertFalse(settings.selectedItemKeys.contains(item.stableKey))

        store.send(.togglePinned(item))

        XCTAssertTrue(settings.selectedItemKeys.contains(item.stableKey))
        XCTAssertEqual(store.state.actionItems.map(\.isPinned), [true])
        XCTAssertEqual(store.state.actionFeedback?.message, "Pinned Example")

        store.send(.togglePinned(item))

        XCTAssertFalse(settings.selectedItemKeys.contains(item.stableKey))
        XCTAssertEqual(store.state.actionItems.map(\.isPinned), [false])
        XCTAssertEqual(store.state.actionFeedback?.message, "Unpinned Example")
    }

    @MainActor
    func testMenuBarActionUsesInjectedPerformerAndStoresFeedback() {
        let settings = makeSettings()
        let scanner = AXMenuBarItemScanner()
        let item = Self.item(stableKey: "item", title: "Example")
        var performedAction: SpillAction?
        let store = PanelStore(
            settings: settings,
            scanner: scanner,
            isAccessibilityTrusted: { true },
            menuBarActionPerformer: { action in
                performedAction = action
                return .success
            },
            stateBuilder: { _, _, isAccessibilityTrusted in
                PanelState.derived(
                    notchCandidates: [item],
                    selectedItemKeys: [],
                    hiddenItemKeys: [],
                    isScanning: false,
                    isAccessibilityTrusted: isAccessibilityTrusted
                )
            }
        )

        let displayedItem = try! XCTUnwrap(store.state.actionItems.first)
        store.send(.performMenuBarAction(displayedItem))

        XCTAssertEqual(performedAction, displayedItem.action)
        XCTAssertEqual(store.state.actionFeedback?.message, "Opened Example")
        XCTAssertTrue(store.state.pendingDismiss)

        store.send(.dismissRequestHandled)
        XCTAssertFalse(store.state.pendingDismiss)

        store.send(.performMenuBarAction(displayedItem))
        XCTAssertTrue(store.state.pendingDismiss)
    }

    @MainActor
    func testFailedMenuBarActionCancelsPendingDismiss() {
        let settings = makeSettings()
        let scanner = AXMenuBarItemScanner()
        let item = Self.item(stableKey: "item", title: "Example")
        let results = ActionResultSequence([.success, .failed(message: "Menu unavailable")])
        let store = PanelStore(
            settings: settings,
            scanner: scanner,
            isAccessibilityTrusted: { true },
            menuBarActionPerformer: { _ in results.next() },
            stateBuilder: { _, _, isAccessibilityTrusted in
                PanelState.derived(
                    notchCandidates: [item],
                    selectedItemKeys: [],
                    hiddenItemKeys: [],
                    isScanning: false,
                    isAccessibilityTrusted: isAccessibilityTrusted
                )
            }
        )

        let displayedItem = try! XCTUnwrap(store.state.actionItems.first)
        store.send(.performMenuBarAction(displayedItem))
        XCTAssertTrue(store.state.pendingDismiss)

        store.send(.performMenuBarAction(displayedItem))

        XCTAssertFalse(store.state.pendingDismiss)
        XCTAssertEqual(store.state.actionFeedback?.message, "Menu unavailable")
    }

    @MainActor
    func testWindowActionUsesInjectedPerformerAndStoresFeedback() {
        let settings = makeSettings()
        let scanner = AXMenuBarItemScanner()
        let action = SpillAction(
            id: "window.leftHalf",
            title: "Left",
            kind: .window(.leftHalf),
            role: .secondary
        )
        var performedAction: SpillAction?
        let store = PanelStore(
            settings: settings,
            scanner: scanner,
            isAccessibilityTrusted: { true },
            windowActionPerformer: { action in
                performedAction = action
                return .failed(message: "Could not move window")
            }
        )

        store.send(.performWindowAction(action))

        XCTAssertEqual(performedAction, action)
        XCTAssertEqual(store.state.actionFeedback?.message, "Could not move window")
        XCTAssertFalse(store.state.pendingDismiss)
    }

    @MainActor
    func testStatusDetailTargetIsPanelStateAndSurvivesRefresh() {
        let settings = makeSettings()
        let scanner = AXMenuBarItemScanner()
        let store = PanelStore(
            settings: settings,
            scanner: scanner,
            isAccessibilityTrusted: { true }
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

    private static func item(stableKey: String, title: String = "") -> MenuBarItemSnapshot {
        MenuBarItemSnapshot(
            id: stableKey,
            stableKey: stableKey,
            ownerName: "Example",
            bundleIdentifier: "com.example.\(stableKey)",
            processIdentifier: 100,
            title: title,
            role: "AXMenuBarItem",
            subrole: nil,
            frame: CGRect(x: 10, y: 10, width: 22, height: 22),
            imageData: nil,
            isNotchCandidate: true,
            canPress: true
        )
    }
}

@MainActor
private final class ActionResultSequence {
    private var results: [SpillActionResult]

    init(_ results: [SpillActionResult]) {
        self.results = results
    }

    func next() -> SpillActionResult {
        results.isEmpty ? .unavailable : results.removeFirst()
    }
}
