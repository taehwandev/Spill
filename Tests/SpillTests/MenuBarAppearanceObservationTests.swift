import AppKit
import Combine
import XCTest
@testable import Spill

@MainActor
final class MenuBarAppearanceObservationTests: XCTestCase {
    func testEveryPreferenceCallbackReadsTheNewPersistedValue() async {
        await assertChange(\.menuBarStatusLayoutStyle, key: .menuBarStatusLayoutStyle,
                           value: .stacked, name: "menu_bar_status_layout_style")
        await assertChange(\.menuBarMetricPresentationStyles, key: .menuBarMetricPresentationStyles,
                           value: [.cpu: .chart, .memory: .text, .network: .text],
                           name: "menu_bar_metric_presentation_styles")
        await assertChange(\.menuBarStatusCompactMode, key: .menuBarStatusCompactMode,
                           value: true, name: "menu_bar_status_compact_mode")
        await assertChange(\.menuBarStatusSplitGroups, key: .menuBarStatusSplitGroups,
                           value: true, name: "menu_bar_status_split_groups")
        await assertChange(\.menuBarStatusPrecision, key: .menuBarStatusPrecision,
                           value: .whole, name: "menu_bar_status_precision")
        await assertChange(\.menuBarStatusHighlightThreshold, key: .menuBarStatusHighlightThreshold,
                           value: .ninety, name: "menu_bar_status_highlight_threshold")
        await assertChange(\.menuBarTriggerIconStyle, key: .menuBarTriggerIconStyle,
                           value: .symbolizedS, name: "menu_bar_trigger_icon_style")
        await assertChange(\.menuBarTokenDisplayMode, key: .menuBarTokenDisplayMode,
                           value: .total, name: "menu_bar_token_display_mode")
        await assertChange(\.useSpillAnimation, key: .useSpillAnimation,
                           value: false, name: "use_spill_animation")
        await assertChange(\.menuBarStatusFontSize, key: .menuBarStatusFontSize,
                           value: 15, name: "menu_bar_status_font_size")
        await assertChange(\.menuBarStatusTextBold, key: .menuBarStatusTextBold,
                           value: true, name: "menu_bar_status_text_bold")
    }

    func testSubscribingDoesNotEmitAnInitialRefresh() async {
        let settings = SpillSettings(defaults: makeDefaults())
        let unexpected = expectation(description: "No preference was changed")
        unexpected.isInverted = true
        let observation = MenuBarAppearanceObservation.observe(settings: settings) { _ in
            unexpected.fulfill()
        }
        defer { observation.cancel() }

        await fulfillment(of: [unexpected], timeout: 0.03)
    }

    func testRapidChangesReadTheFinalPersistedSettingOnTheMainRunLoop() async {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)
        let delivered = expectation(description: "All pending preference invalidations delivered")
        delivered.expectedFulfillmentCount = 3
        var observed = [Double]()
        let observation = MenuBarAppearanceObservation.observe(settings: settings) { name in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(name, "menu_bar_status_font_size")
            observed.append(settings.menuBarStatusFontSize)
            XCTAssertEqual(defaults.value(for: .menuBarStatusFontSize), 14.5)
            delivered.fulfill()
        }
        defer { observation.cancel() }

        settings.menuBarStatusFontSize = 15
        settings.menuBarStatusFontSize = 10
        settings.menuBarStatusFontSize = 14.5
        XCTAssertTrue(observed.isEmpty, "Refresh must not run in @Published willSet")
        await fulfillment(of: [delivered], timeout: 1)
        XCTAssertEqual(observed, [14.5, 14.5, 14.5])
    }

    func testCancellationDropsPendingAndFutureInvalidations() async {
        let settings = SpillSettings(defaults: makeDefaults())
        let unexpected = expectation(description: "Cancelled subscription must not refresh")
        unexpected.isInverted = true
        let observation = MenuBarAppearanceObservation.observe(settings: settings) { _ in
            unexpected.fulfill()
        }

        settings.menuBarStatusFontSize = 15
        observation.cancel()
        settings.menuBarStatusTextBold = true
        await fulfillment(of: [unexpected], timeout: 0.03)
    }

    #if DEBUG
    func testAnimationToggleStopsAndRestartsWithoutAPeriodicStatusLoop() async {
        let settings = SpillSettings(defaults: makeDefaults())
        settings.enabledMenuBarStatusItems = []
        XCTAssertNil(SystemStatusRefreshCoordinator.interval(
            isPanelVisible: false, hasMenuBarItems: false,
            usesPerformanceEffect: settings.menuBarTriggerIconStyle.usesPerformanceEffect,
            preferredInterval: settings.refreshInterval
        ))
        let animator = TriggerIconAnimator.shared
        animator.stop()
        let controller = makeController(settings: settings)
        defer {
            animator.stop()
            animator.onFrame = nil
            for item in [controller.triggerItem, controller.systemItem, controller.aiItem] {
                NSStatusBar.system.removeStatusItem(item)
            }
        }
        XCTAssertTrue(animator.isRunningForTesting)
        animator.startBurstForTesting()
        animator.advanceFrameForTesting()
        XCTAssertTrue(animator.hasFrameTimerForTesting)

        let stopped = expectation(description: "Animation stopped after the preference committed")
        let restarted = expectation(description: "Animation restarted without periodic refresh")
        let observation = MenuBarAppearanceObservation.observe(settings: settings) { name in
            XCTAssertEqual(name, "use_spill_animation")
            controller.refresh()
            if settings.useSpillAnimation { restarted.fulfill() } else { stopped.fulfill() }
        }
        defer { observation.cancel() }

        settings.useSpillAnimation = false
        await fulfillment(of: [stopped], timeout: 1)
        XCTAssertFalse(animator.isRunningForTesting)
        XCTAssertFalse(animator.hasIdleTimerForTesting)
        XCTAssertFalse(animator.hasFrameTimerForTesting)
        XCTAssertEqual(animator.phase, 0)

        settings.useSpillAnimation = true
        await fulfillment(of: [restarted], timeout: 1)
        XCTAssertTrue(animator.isRunningForTesting)
        XCTAssertTrue(animator.hasIdleTimerForTesting)
    }
    #endif

    private func assertChange<Value: Equatable>(
        _ property: ReferenceWritableKeyPath<SpillSettings, Value>,
        key: SettingKey<Value>,
        value: Value,
        name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let defaults = makeDefaults()
        let settings = SpillSettings(defaults: defaults)
        let delivered = expectation(description: name)
        var callbackCount = 0
        let observation = MenuBarAppearanceObservation.observe(settings: settings) { changedName in
            callbackCount += 1
            XCTAssertTrue(Thread.isMainThread, file: file, line: line)
            XCTAssertEqual(changedName, name, file: file, line: line)
            XCTAssertEqual(settings[keyPath: property], value, file: file, line: line)
            XCTAssertEqual(defaults.value(for: key), value, file: file, line: line)
            let reloaded = SpillSettings(defaults: defaults)
            XCTAssertEqual(reloaded[keyPath: property], value, file: file, line: line)
            delivered.fulfill()
        }
        defer { observation.cancel() }

        settings[keyPath: property] = value
        XCTAssertEqual(callbackCount, 0, "Callback must follow willSet and persistence", file: file, line: line)
        await fulfillment(of: [delivered], timeout: 1)
        XCTAssertEqual(callbackCount, 1, file: file, line: line)
    }

    private func makeController(settings: SpillSettings) -> StatusItemController {
        _ = NSApplication.shared
        let controller = StatusItemController(
            settings: settings,
            statusStore: SystemStatusStore(),
            sleepGuard: SleepGuardController(automaticallySchedulesTimer: false),
            aiTokenCountProvider: { (0, 0) },
            toggleAction: {}, refreshAction: {}, preferencesAction: {},
            tokenDashboardAction: {}, updateAction: {}, quitAction: {}
        )
        controller.pressedMouseButtonsProvider = { 0 }
        controller.refresh()
        return controller
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "dev.spill.tests.menu-bar-observation.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}
