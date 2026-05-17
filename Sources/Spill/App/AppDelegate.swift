import AppKit
import Combine
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let statusRefreshDelayNanoseconds: UInt64 = 1_000_000_000

    private let settings = SpillSettings.shared
    private let scanner = AXMenuBarItemScanner()
    private let sleepGuard = SleepGuardController()
    private let statusStore = SystemStatusStore()
    private let aiStatusStore = AIStatusStore()
    private let windowActionStore = WindowActionStore()
    private let updateCheckStore = UpdateCheckStore()
    private lazy var panelStore = PanelStore(
        settings: settings,
        scanner: scanner,
        windowActionPerformer: { [unowned self] action in
            self.windowActionStore.perform(action)
        }
    )
    private lazy var scanCoordinator = MenuBarScanCoordinator(scanner: scanner, settings: settings)
    private lazy var hotKeyController = HotKeyController(
        registrations: makeHotKeyRegistrations()
    )
    private lazy var spillPanelController = SpillPanelController(
        settings: settings,
        scanner: scanner,
        panelStore: panelStore,
        statusStore: statusStore,
        aiStatusStore: aiStatusStore,
        windowActionStore: windowActionStore,
        updateStore: updateCheckStore,
        sleepGuard: sleepGuard,
        visibilityChanged: { [weak self] isVisible in
            self?.isSpillPanelVisible = isVisible
            self?.statusItemController?.refresh(isSpillBarVisible: isVisible)
            self?.configureStatusRefreshLoop()
        },
        settingsAction: { [weak self] in
            self?.showPreferencesFromPanel()
        }
    )
    private lazy var preferencesWindowController = PreferencesWindowController(
        settings: settings,
        scanner: scanner,
        updateStore: updateCheckStore,
        showPanelAction: { [weak self] in
            self?.showSpillBar(source: "preferences")
        }
    )
    private var statusItemController: StatusItemController?
    private var statusRefreshTask: Task<Void, Never>?
    private var isSpillPanelVisible = false
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMainMenu()
        SpillTelemetry.shared.track("app_started", props: ["source": "mac_app"])

        statusItemController = StatusItemController(
            settings: settings,
            statusStore: statusStore,
            sleepGuard: sleepGuard,
            hiddenItemCountProvider: { [weak scanner] in
                guard let scanner else { return 0 }
                return SpillDisplayMode.notchCandidateItems(from: scanner, settings: SpillSettings.shared).count
            },
            toggleAction: { [weak self] in
                self?.toggleSpillBar()
            },
            refreshAction: { [weak self] in
                self?.refreshMenuBarItems(source: "status_menu")
            },
            preferencesAction: { [weak self] in
                self?.showPreferences(source: "status_menu")
            },
            updateAction: { [weak self] in
                self?.checkForUpdates(source: "status_menu")
            },
            quitAction: {
                NSApp.terminate(nil)
            }
        )

        observeStateChanges()
        configureStatusRefreshLoop()

        if isSmokeTest {
            startSmokeTestExitTimer()
        } else {
            scanCoordinator.start()
            configureHotKey()
            prewarmPanel()
        }
    }

    private var isSmokeTest: Bool {
        ProcessInfo.processInfo.environment["SPILL_SMOKE_TEST"] == "1"
    }

    private var shouldOpenPanelInSmokeTest: Bool {
        ProcessInfo.processInfo.environment["SPILL_SMOKE_OPEN_PANEL"] == "1"
    }

    private var shouldClickStatusItemInSmokeTest: Bool {
        ProcessInfo.processInfo.environment["SPILL_SMOKE_CLICK_STATUS_ITEM"] == "1"
    }

    private var shouldValidatePanelLayoutInSmokeTest: Bool {
        ProcessInfo.processInfo.environment["SPILL_SMOKE_VALIDATE_PANEL_LAYOUT"] == "1"
    }

    private func startSmokeTestExitTimer() {
        print("SPILL_SMOKE_READY")

        if shouldOpenPanelInSmokeTest {
            openPanelForSmokeTest()
        }

        if shouldClickStatusItemInSmokeTest {
            clickStatusItemForSmokeTest()
        }

        let configuredDelay = ProcessInfo.processInfo.environment["SPILL_SMOKE_TEST_EXIT_AFTER"]
            .flatMap(TimeInterval.init)
        let exitDelay = max(configuredDelay ?? 1.0, 0.2)

        DispatchQueue.main.asyncAfter(deadline: .now() + exitDelay) {
            print("SPILL_SMOKE_EXIT")
            NSApp.terminate(nil)
        }
    }

    private func openPanelForSmokeTest() {
        NSApp.activate(ignoringOtherApps: true)
        spillPanelController.show(
            anchorFrame: statusItemController?.buttonScreenFrame,
            dismissOnOutsideInteraction: false
        )
        statusItemController?.refresh(isSpillBarVisible: spillPanelController.isVisible)

        if spillPanelController.isVisible {
            print("SPILL_PANEL_SMOKE_VISIBLE")
        } else {
            print("SPILL_PANEL_SMOKE_NOT_VISIBLE")
        }

        if shouldValidatePanelLayoutInSmokeTest {
            reportPanelLayoutForSmokeTest()
        }
    }

    private func clickStatusItemForSmokeTest() {
        statusItemController?.performPrimaryClickForSmokeTest()

        if spillPanelController.isVisible {
            print("SPILL_STATUS_CLICK_SMOKE_VISIBLE")
        } else {
            print("SPILL_STATUS_CLICK_SMOKE_NOT_VISIBLE")
        }
    }

    private func reportPanelLayoutForSmokeTest() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.reportPanelLayoutForSmokeTest(attempt: 1)
        }
    }

    private func reportPanelLayoutForSmokeTest(attempt: Int) {
        guard attempt <= 5 else {
            printPanelLayoutSmokeReport()
            return
        }

        let accessibilityReport = spillPanelController.accessibilityReport
        if accessibilityReport.isValid {
            printPanelLayoutSmokeReport(accessibilityReport: accessibilityReport)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.reportPanelLayoutForSmokeTest(attempt: attempt + 1)
        }
    }

    private func printPanelLayoutSmokeReport(accessibilityReport: SpillPanelAccessibilityReport? = nil) {
        let report = spillPanelController.layoutReport
        print("SPILL_PANEL_LAYOUT \(report.logLine)")

        if report.isValid {
            print("SPILL_PANEL_LAYOUT_OK")
        } else {
            print("SPILL_PANEL_LAYOUT_FAIL")
        }

        let contentReport = spillPanelController.contentReport
        print("SPILL_PANEL_CONTENT \(contentReport.logLine)")

        if contentReport.isValid {
            print("SPILL_PANEL_CONTENT_OK")
        } else {
            print("SPILL_PANEL_CONTENT_FAIL")
        }

        let resolvedReport = accessibilityReport ?? spillPanelController.accessibilityReport
        print("SPILL_PANEL_ACCESSIBILITY \(resolvedReport.logLine)")

        if resolvedReport.isValid {
            print("SPILL_PANEL_ACCESSIBILITY_OK")
        } else {
            print("SPILL_PANEL_ACCESSIBILITY_FAIL")
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showSpillBar(source: "app_reopen")
        }

        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyController.stop()
        scanCoordinator.stop()
        statusRefreshTask?.cancel()
        sleepGuard.stop()
        spillPanelController.hide(animated: false)
    }

    private func toggleSpillBar() {
        if spillPanelController.isVisible {
            spillPanelController.hide(animated: true)
            SpillTelemetry.shared.track("panel_closed", props: ["source": "menu_bar_toggle"])
            statusItemController?.refresh(isSpillBarVisible: false)
            return
        }

        showSpillBar(source: "menu_bar_toggle")
    }

    private func showSpillBar(source: String = "unknown") {
        spillPanelController.show(anchorFrame: statusItemController?.buttonScreenFrame)
        statusItemController?.refresh(isSpillBarVisible: spillPanelController.isVisible)

        if spillPanelController.isVisible {
            SpillTelemetry.shared.track("panel_opened", props: ["source": source])
        }

        if !AccessibilityPermission.isTrusted {
            SpillTelemetry.shared.track("accessibility_prompt_shown", props: ["source": "panel_open"])
            DispatchQueue.main.async {
                _ = AccessibilityPermission.request()
            }
            return
        }

        scheduleDeferredScanIfNeeded()
    }

    private func refreshMenuBarItems(source: String = "status_menu") {
        SpillTelemetry.shared.track("menu_bar_scan_requested", props: ["source": source])
        scanCoordinator.refreshNow()
        statusItemController?.refresh()
        Task { @MainActor [weak self] in
            await self?.refreshStatusData()
        }
    }

    private func showPreferences(source: String = "unknown") {
        SpillTelemetry.shared.track("settings_opened", props: ["source": source])
        preferencesWindowController.show()
    }

    private func showPreferencesFromPanel() {
        if spillPanelController.isVisible {
            spillPanelController.hide(animated: true)
            SpillTelemetry.shared.track("panel_closed", props: ["source": "settings_from_panel"])
        }

        showPreferences(source: "panel")
    }

    private func checkForUpdates(source: String = "unknown") {
        showPreferences(source: "update_check")
        updateCheckStore.checkForUpdates(source: source)
    }

    private func prewarmPanel() {
        DispatchQueue.main.async { [weak self] in
            self?.spillPanelController.prepare()
        }
    }

    private func scheduleDeferredScanIfNeeded() {
        guard !scanner.isScanning else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self,
                  isSpillPanelVisible,
                  AccessibilityPermission.isTrusted,
                  !scanner.isScanning
            else {
                return
            }

            scanner.refreshIfStale(reason: .panelOpen)
        }
    }

    private func performWindowAction(_ kind: WindowActionKind) {
        if !AccessibilityPermission.isTrusted {
            SpillTelemetry.shared.track("accessibility_prompt_shown", props: ["source": "window_action_hotkey"])
            _ = AccessibilityPermission.request()
            return
        }

        let result = windowActionStore.perform(kind)
        SpillTelemetry.shared.track(
            "window_action_performed",
            props: [
                "source": "hotkey",
                "kind": kind.rawValue,
                "result": telemetryResult(result)
            ]
        )
        if case .permissionRequired = result {
            SpillTelemetry.shared.track("accessibility_prompt_shown", props: ["source": "window_action_hotkey_result"])
            _ = AccessibilityPermission.request()
        }
    }

    private func configureHotKey() {
        hotKeyController.updateRegistrations(makeHotKeyRegistrations())

        if settings.hotKeyEnabled {
            hotKeyController.register()
        } else {
            hotKeyController.unregister()
        }
    }

    private func makeHotKeyRegistrations() -> [HotKeyRegistration] {
        HotKeyRegistration.spillDefaults(
            windowActionShortcutKeys: settings.windowActionShortcutKeys,
            toggleAction: { [weak self] in
                self?.toggleSpillBar()
            },
            windowAction: { [weak self] kind in
                self?.performWindowAction(kind)
            }
        )
    }

    private func observeStateChanges() {
        scanner.$items
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.statusItemController?.refresh()
                }
            }
            .store(in: &cancellables)

        statusStore.objectWillChange
            .debounce(for: .milliseconds(80), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.statusItemController?.refresh()
            }
            .store(in: &cancellables)

        sleepGuard.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.statusItemController?.refresh()
                }
            }
            .store(in: &cancellables)

        settings.$hotKeyEnabled
            .dropFirst()
            .sink { [weak self] _ in
                SpillTelemetry.shared.track("preference_changed", props: ["name": "hot_key_enabled"])
                self?.configureHotKey()
            }
            .store(in: &cancellables)

        settings.$windowActionShortcutKeys
            .dropFirst()
            .sink { [weak self] _ in
                SpillTelemetry.shared.track("preference_changed", props: ["name": "window_action_shortcuts"])
                self?.configureHotKey()
            }
            .store(in: &cancellables)

        settings.$displayMode
            .dropFirst()
            .sink { [weak self] _ in
                SpillTelemetry.shared.track("preference_changed", props: ["name": "display_mode"])
                self?.statusItemController?.refresh()
            }
            .store(in: &cancellables)

        settings.$selectedItemKeys
            .dropFirst()
            .sink { [weak self] _ in
                SpillTelemetry.shared.track("preference_changed", props: ["name": "selected_items"])
                self?.statusItemController?.refresh()
            }
            .store(in: &cancellables)

        settings.$hiddenItemKeys
            .dropFirst()
            .sink { [weak self] _ in
                SpillTelemetry.shared.track("preference_changed", props: ["name": "hidden_items"])
                self?.statusItemController?.refresh()
            }
            .store(in: &cancellables)

        settings.$enabledMenuBarStatusItems
            .dropFirst()
            .sink { [weak self] _ in
                SpillTelemetry.shared.track("preference_changed", props: ["name": "menu_bar_status_items"])
                self?.statusItemController?.refresh()
                self?.configureStatusRefreshLoop()
            }
            .store(in: &cancellables)

        settings.$sleepGuardShowsRemainingInMenuBar
            .dropFirst()
            .sink { [weak self] _ in
                SpillTelemetry.shared.track("preference_changed", props: ["name": "sleep_guard_menu_bar_remaining"])
                self?.statusItemController?.refresh()
            }
            .store(in: &cancellables)

        settings.$menuBarStatusDisplayStyle
            .dropFirst()
            .sink { [weak self] _ in
                SpillTelemetry.shared.track("preference_changed", props: ["name": "menu_bar_status_display_style"])
                self?.statusItemController?.refresh()
            }
            .store(in: &cancellables)

        settings.$menuBarStatusPrecision
            .dropFirst()
            .sink { [weak self] _ in
                SpillTelemetry.shared.track("preference_changed", props: ["name": "menu_bar_status_precision"])
                self?.statusItemController?.refresh()
            }
            .store(in: &cancellables)

        settings.$menuBarStatusHighlightThreshold
            .dropFirst()
            .sink { [weak self] _ in
                SpillTelemetry.shared.track("preference_changed", props: ["name": "menu_bar_status_highlight_threshold"])
                self?.statusItemController?.refresh()
            }
            .store(in: &cancellables)

        settings.$menuBarTriggerIconStyle
            .dropFirst()
            .sink { [weak self] _ in
                SpillTelemetry.shared.track("preference_changed", props: ["name": "menu_bar_trigger_icon_style"])
                self?.statusItemController?.refresh()
                self?.configureStatusRefreshLoop()
            }
            .store(in: &cancellables)

        settings.$refreshInterval
            .dropFirst()
            .sink { [weak self] _ in
                SpillTelemetry.shared.track("preference_changed", props: ["name": "refresh_interval"])
                self?.configureStatusRefreshLoop()
            }
            .store(in: &cancellables)

        updateCheckStore.$state
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] state in
                if case .available(let update) = state {
                    self?.notifyUpdateAvailable(update)
                }
            }
            .store(in: &cancellables)
    }

    private func notifyUpdateAvailable(_ update: AvailableUpdate) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = "Spill Update Available"
            content.body = "Version \(update.latestVersion) is ready to download."
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "spill.update.\(update.latestVersion)",
                content: content,
                trigger: nil
            )

            UNUserNotificationCenter.current().add(request)
        }
    }

    private func configureStatusRefreshLoop() {
        statusRefreshTask?.cancel()

        guard isSpillPanelVisible
            || !settings.enabledMenuBarStatusItems.isEmpty
            || settings.menuBarTriggerIconStyle.usesPerformanceEffect
        else {
            statusItemController?.refresh()
            return
        }

        statusRefreshTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await refreshMenuBarStatusData()

                do {
                    try await Task.sleep(nanoseconds: Self.statusRefreshDelayNanoseconds)
                } catch {
                    return
                }
            }
        }
    }

    private func refreshMenuBarStatusData() async {
        let enabledModules = isSpillPanelVisible
            ? settings.statusModulesRequiredForRefresh
            : menuBarStatusModules
        let readsPower = isSpillPanelVisible

        await statusStore.refresh(
            enabledModules: enabledModules,
            readsPower: readsPower
        )
        statusItemController?.refresh()
    }

    private func refreshStatusData() async {
        if isSpillPanelVisible {
            aiStatusStore.refreshInBackground()
        }

        await statusStore.refresh(
            enabledModules: isSpillPanelVisible ? settings.statusModulesRequiredForRefresh : menuBarStatusModules,
            readsPower: isSpillPanelVisible
        )
        statusItemController?.refresh()
    }

    private var menuBarStatusModules: Set<SpillStatusModule> {
        Set(settings.enabledMenuBarStatusItems.compactMap(\.systemModule))
            .union(settings.menuBarTriggerIconStyle.requiredStatusModules)
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu(title: "Spill")
        appMenuItem.submenu = appMenu
        appMenu.addItem(mainMenuItem(title: "Show Spill Panel", action: #selector(showSpillPanelFromMainMenu), keyEquivalent: ""))
        appMenu.addItem(mainMenuItem(title: "Refresh Menu Bar Items", action: #selector(refreshMenuBarItemsFromMainMenu), keyEquivalent: "r"))
        appMenu.addItem(.separator())
        appMenu.addItem(mainMenuItem(title: "Check for Updates...", action: #selector(checkForUpdatesFromMainMenu), keyEquivalent: ""))
        appMenu.addItem(mainMenuItem(title: "Preferences...", action: #selector(showPreferencesFromMainMenu), keyEquivalent: ","))
        appMenu.addItem(.separator())
        appMenu.addItem(mainMenuItem(title: "Quit Spill", action: #selector(quitFromMainMenu), keyEquivalent: "q"))
        NSApp.mainMenu = mainMenu
    }

    private func mainMenuItem(title: String, action: Selector, keyEquivalent: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    @objc private func showSpillPanelFromMainMenu() {
        showSpillBar(source: "main_menu")
    }

    @objc private func refreshMenuBarItemsFromMainMenu() {
        refreshMenuBarItems(source: "main_menu")
    }

    @objc private func showPreferencesFromMainMenu() {
        showPreferences(source: "main_menu")
    }

    @objc private func checkForUpdatesFromMainMenu() {
        checkForUpdates(source: "main_menu")
    }

    @objc private func quitFromMainMenu() {
        NSApp.terminate(nil)
    }

    private func telemetryResult(_ result: SpillActionResult) -> String {
        switch result {
        case .success:
            return "success"
        case .unavailable:
            return "unavailable"
        case .permissionRequired:
            return "permission_required"
        case .unsupported:
            return "unsupported"
        case .failed:
            return "failed"
        }
    }
}
