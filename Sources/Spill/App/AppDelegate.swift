import AppKit
import Carbon.HIToolbox
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let statusRefreshDelayNanoseconds: UInt64 = 1_000_000_000

    private let settings = SpillSettings.shared
    private let scanner = AXMenuBarItemScanner()
    private let sleepGuard = SleepGuardController()
    private let statusStore = SystemStatusStore(cpuInitialSampleIntervalNanoseconds: 250_000_000)
    private let aiStatusStore = AIStatusStore()
    private let cloudServiceStatusStore = CloudServiceStatusStore()
    private let tokenMeteringCoordinator: TokenMeteringCoordinator
    private let windowActionStore = WindowActionStore()
    private let sparkleUpdateController: SparkleUpdateController
    private let updateCheckStore: UpdateCheckStore
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
        cloudServiceStatusStore: cloudServiceStatusStore,
        tokenUsageDashboardStore: tokenMeteringCoordinator.dashboardStore,
        windowActionStore: windowActionStore,
        updateStore: updateCheckStore,
        sleepGuard: sleepGuard,
        visibilityChanged: { [weak self] isVisible in
            self?.isSpillPanelVisible = isVisible
            self?.tokenMeteringCoordinator.setSpillPanelVisible(isVisible)
            self?.statusItemController?.refresh(isSpillBarVisible: isVisible)
            self?.configureStatusRefreshLoop()
        },
        settingsAction: { [weak self] in
            self?.showPreferencesFromPanel()
        },
        tokenMeteringDetailAction: { [weak self] in
            self?.openTokenDashboard(source: "panel_ai_section")
        }
    )
    private lazy var preferencesWindowController = PreferencesWindowController(
        settings: settings,
        scanner: scanner,
        updateStore: updateCheckStore,
        tokenUsageStore: tokenMeteringCoordinator.usageStore,
        showPanelAction: { [weak self] in
            self?.showSpillBar(source: "preferences")
        },
        openTokenDashboardAction: { [weak self] in
            self?.openTokenDashboard(source: "preferences")
        }
    )
    private var statusItemController: StatusItemController?
    private var statusRefreshTask: Task<Void, Never>?
    private var isSpillPanelVisible = false
    private var cancellables = Set<AnyCancellable>()

    override init() {
        tokenMeteringCoordinator = TokenMeteringCoordinator(
            settings: settings,
            cloudServiceStatusStore: cloudServiceStatusStore
        )

        let sparkleUpdateController = SparkleUpdateController()
        self.sparkleUpdateController = sparkleUpdateController
        updateCheckStore = UpdateCheckStore(
            isInAppUpdaterAvailable: {
                sparkleUpdateController.isAvailable
            },
            runInAppUpdateCheck: { _ in
                sparkleUpdateController.checkForUpdates()
            }
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMainMenu()
        SpillTelemetry.shared.track("app_started", props: ["source": "mac_app"])
        tokenMeteringCoordinator.refreshMenuBarTokenTotal(force: true)

        statusItemController = StatusItemController(
            settings: settings,
            statusStore: statusStore,
            sleepGuard: sleepGuard,
            hiddenItemCountProvider: { [weak scanner] in
                guard let scanner else { return 0 }
                return SpillDisplayMode.notchCandidateItems(from: scanner, settings: SpillSettings.shared).count
            },
            aiTokenCountProvider: { [weak self] in
                self?.tokenMeteringCoordinator.menuBarTokenTotal ?? 0
            },
            aiServerHealthProvider: { [weak self] in
                self?.tokenMeteringCoordinator.menuBarServerHealth
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
            tokenDashboardAction: { [weak self] in
                self?.openTokenDashboard(source: "status_menu")
            },
            updateAction: { [weak self] in
                self?.checkForUpdates(source: "status_menu")
            },
            quitAction: {
                NSApp.terminate(nil)
            }
        )

        observeStateChanges()
        observeDashboardPreferenceRequests()
        tokenMeteringCoordinator.start(isSmokeTest: isSmokeTest) { [weak self] in
            self?.statusItemController?.refresh()
        }
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

    private var shouldOpenTokenDashboardInSmokeTest: Bool {
        ProcessInfo.processInfo.environment["SPILL_SMOKE_OPEN_TOKEN_DASHBOARD"] == "1"
    }

    private var shouldValidatePanelLayoutInSmokeTest: Bool {
        ProcessInfo.processInfo.environment["SPILL_SMOKE_VALIDATE_PANEL_LAYOUT"] == "1"
    }

    private var shouldStartSleepGuardInSmokeTest: Bool {
        ProcessInfo.processInfo.environment["SPILL_SMOKE_START_SLEEP_GUARD"] == "1"
    }

    private func startSmokeTestExitTimer() {
        print("SPILL_SMOKE_READY")

        if shouldStartSleepGuardInSmokeTest {
            startSleepGuardForSmokeTest()
        }

        if shouldOpenPanelInSmokeTest {
            openPanelForSmokeTest()
        }

        if shouldClickStatusItemInSmokeTest {
            clickStatusItemForSmokeTest()
        }

        if shouldOpenTokenDashboardInSmokeTest {
            openTokenDashboardForSmokeTest()
        }

        let configuredDelay = ProcessInfo.processInfo.environment["SPILL_SMOKE_TEST_EXIT_AFTER"]
            .flatMap(TimeInterval.init)
        let exitDelay = max(configuredDelay ?? 1.0, 0.2)

        DispatchQueue.main.asyncAfter(deadline: .now() + exitDelay) {
            print("SPILL_SMOKE_EXIT")
            NSApp.terminate(nil)
        }
    }

    private func startSleepGuardForSmokeTest() {
        let didStart = sleepGuard.start(duration: .fifteenMinutes, keepDisplayAwake: true)
        statusItemController?.refresh(isSpillBarVisible: spillPanelController.isVisible)

        if didStart {
            print("SPILL_SLEEP_GUARD_SMOKE_STARTED keepDisplayAwake=\(sleepGuard.keepsDisplayAwake)")
        } else {
            print("SPILL_SLEEP_GUARD_SMOKE_FAILED \(sleepGuard.errorMessage ?? "unknown error")")
        }
    }

    private func openPanelForSmokeTest() {
        NSApp.activate()
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

    private func openTokenDashboardForSmokeTest() {
        openTokenDashboard(source: "smoke")
        openTokenDashboard(source: "smoke_duplicate")
        print("SPILL_TOKEN_DASHBOARD_LAUNCH_SMOKE_REQUESTED")
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
        tokenMeteringCoordinator.stop()
        DistributedNotificationCenter.default().removeObserver(
            self,
            name: TokenMeteringDashboardProcess.openPreferencesNotification,
            object: nil
        )
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
        tokenMeteringCoordinator.requestCollection(reason: "panel_open")
        tokenMeteringCoordinator.refreshPanelSummary()
        spillPanelController.show(
            anchorFrame: statusItemController?.buttonScreenFrame,
            tokenUsageAlreadyRefreshed: true
        )
        statusItemController?.refresh(isSpillBarVisible: spillPanelController.isVisible)

        if spillPanelController.isVisible {
            SpillTelemetry.shared.track("panel_opened", props: ["source": source])
            updateCheckStore.checkForUpdatesIfNeeded(source: "panel_open")
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
        tokenMeteringCoordinator.requestCollection(reason: "manual_refresh")
        scanCoordinator.refreshNow()
        statusItemController?.refresh()
        Task { @MainActor [weak self] in
            await self?.refreshStatusData()
        }
    }

    private func showPreferences(source: String = "unknown", selectedTab: String? = nil) {
        SpillTelemetry.shared.track("settings_opened", props: ["source": source])
        preferencesWindowController.show(selectedTab: selectedTab)
    }

    private func openTokenDashboard(source: String = "unknown") {
        let wasPanelVisible = spillPanelController.isVisible
        if wasPanelVisible {
            spillPanelController.hide(animated: false)
            SpillTelemetry.shared.track("panel_closed", props: ["source": "token_dashboard_\(source)"])
        }

        tokenMeteringCoordinator.openDashboard(
            deferLaunch: wasPanelVisible,
            refreshStatusItem: { [weak self] in
                self?.statusItemController?.refresh()
            },
            showPreferences: { [weak self] source, selectedTab in
                self?.showPreferences(source: source, selectedTab: selectedTab)
            }
        )
    }

    private func showPreferencesFromPanel() {
        if spillPanelController.isVisible {
            spillPanelController.hide(animated: true)
            SpillTelemetry.shared.track("panel_closed", props: ["source": "settings_from_panel"])
        }

        showPreferences(source: "panel")
    }

    private func checkForUpdates(source: String = "unknown") {
        if updateCheckStore.usesInAppUpdater {
            updateCheckStore.checkForUpdates(source: source)
            return
        }

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

        cloudServiceStatusStore.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
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

        settings.$sleepGuardDefaultDuration
            .dropFirst()
            .sink { [weak self] _ in
                SpillTelemetry.shared.track("preference_changed", props: ["name": "sleep_guard_default_duration"])
                self?.statusItemController?.refresh()
            }
            .store(in: &cancellables)

        settings.$sleepGuardKeepsDisplayAwake
            .dropFirst()
            .sink { [weak self] _ in
                SpillTelemetry.shared.track("preference_changed", props: ["name": "sleep_guard_keep_display_awake"])
                self?.statusItemController?.refresh()
            }
            .store(in: &cancellables)

        settings.$menuBarStatusLayoutStyle
            .dropFirst()
            .sink { [weak self] _ in
                SpillTelemetry.shared.track("preference_changed", props: ["name": "menu_bar_status_layout_style"])
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

        settings.$appLanguage
            .dropFirst()
            .sink { [weak self] _ in
                SpillTelemetry.shared.track("preference_changed", props: ["name": "app_language"])
                DispatchQueue.main.async { [weak self] in
                    self?.configureMainMenu()
                    self?.statusItemController?.refresh()
                    TokenMeteringDashboardProcess.postAppLanguageDidChange()
                }
            }
            .store(in: &cancellables)
    }

    private func observeDashboardPreferenceRequests() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(showPreferencesFromDashboardRequest(_:)),
            name: TokenMeteringDashboardProcess.openPreferencesNotification,
            object: nil
        )
    }

    @objc private func showPreferencesFromDashboardRequest(_ notification: Notification) {
        let selectedTab = notification.userInfo?[TokenMeteringDashboardProcess.preferencesTabUserInfoKey] as? String
        showPreferences(source: "token_dashboard", selectedTab: selectedTab)
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
        tokenMeteringCoordinator.requestMenuBarTokenUsageCollectionIfNeeded()
        tokenMeteringCoordinator.refreshMenuBarTokenTotal()
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
        tokenMeteringCoordinator.requestMenuBarTokenUsageCollectionIfNeeded()
        tokenMeteringCoordinator.refreshMenuBarTokenTotal()
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
        appMenu.addItem(mainMenuItem(title: AppL10n.text(.showSpillPanel, appLanguage: settings.appLanguage), action: #selector(showSpillPanelFromMainMenu), keyEquivalent: ""))
        appMenu.addItem(mainMenuItem(title: AppL10n.text(.openLocalTokenDashboard, appLanguage: settings.appLanguage), action: #selector(openTokenDashboardFromMainMenu), keyEquivalent: ""))
        appMenu.addItem(mainMenuItem(title: AppL10n.text(.refreshMenuBarItems, appLanguage: settings.appLanguage), action: #selector(refreshMenuBarItemsFromMainMenu), keyEquivalent: "r"))
        appMenu.addItem(.separator())
        appMenu.addItem(mainMenuItem(title: AppL10n.text(.checkForUpdates, appLanguage: settings.appLanguage), action: #selector(checkForUpdatesFromMainMenu), keyEquivalent: ""))
        appMenu.addItem(mainMenuItem(title: AppL10n.text(.preferences, appLanguage: settings.appLanguage), action: #selector(showPreferencesFromMainMenu), keyEquivalent: ","))
        appMenu.addItem(.separator())
        appMenu.addItem(mainMenuItem(title: AppL10n.text(.quitSpill, appLanguage: settings.appLanguage), action: #selector(quitFromMainMenu), keyEquivalent: ""))
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

    @objc private func openTokenDashboardFromMainMenu() {
        openTokenDashboard(source: "main_menu")
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
