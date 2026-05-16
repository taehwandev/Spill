import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SpillSettings.shared
    private let scanner = AXMenuBarItemScanner()
    private let sleepGuard = SleepGuardController()
    private let statusStore = SystemStatusStore()
    private let aiStatusStore = AIStatusStore()
    private let windowActionStore = WindowActionStore()
    private lazy var scanCoordinator = MenuBarScanCoordinator(scanner: scanner, settings: settings)
    private lazy var hotKeyController = HotKeyController(
        registrations: HotKeyRegistration.spillDefaults(
            toggleAction: { [weak self] in
                self?.toggleSpillBar()
            },
            windowAction: { [weak self] kind in
                self?.performWindowAction(kind)
            }
        )
    )
    private lazy var spillPanelController = SpillPanelController(
        settings: settings,
        scanner: scanner,
        statusStore: statusStore,
        aiStatusStore: aiStatusStore,
        windowActionStore: windowActionStore,
        sleepGuard: sleepGuard,
        visibilityChanged: { [weak self] isVisible in
            self?.isSpillPanelVisible = isVisible
            self?.statusItemController?.refresh(isSpillBarVisible: isVisible)
        }
    )
    private lazy var preferencesWindowController = PreferencesWindowController(
        settings: settings,
        scanner: scanner,
        showPanelAction: { [weak self] in
            self?.showSpillBar()
        }
    )
    private var statusItemController: StatusItemController?
    private var statusRefreshTask: Task<Void, Never>?
    private var isSpillPanelVisible = false
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMainMenu()

        statusItemController = StatusItemController(
            settings: settings,
            statusStore: statusStore,
            hiddenItemCountProvider: { [weak scanner] in
                guard let scanner else { return 0 }
                return SpillSettings.shared.displayMode.items(from: scanner, settings: SpillSettings.shared).count
            },
            toggleAction: { [weak self] in
                self?.toggleSpillBar()
            },
            refreshAction: { [weak self] in
                self?.refreshMenuBarItems()
            },
            preferencesAction: { [weak self] in
                self?.showPreferences()
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
        }
    }

    private var isSmokeTest: Bool {
        ProcessInfo.processInfo.environment["SPILL_SMOKE_TEST"] == "1"
    }

    private var shouldOpenPanelInSmokeTest: Bool {
        ProcessInfo.processInfo.environment["SPILL_SMOKE_OPEN_PANEL"] == "1"
    }

    private var shouldValidatePanelLayoutInSmokeTest: Bool {
        ProcessInfo.processInfo.environment["SPILL_SMOKE_VALIDATE_PANEL_LAYOUT"] == "1"
    }

    private func startSmokeTestExitTimer() {
        print("SPILL_SMOKE_READY")

        if shouldOpenPanelInSmokeTest {
            openPanelForSmokeTest()
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
        spillPanelController.show(anchorFrame: statusItemController?.buttonScreenFrame)
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

    private func reportPanelLayoutForSmokeTest() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }

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
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showSpillBar()
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
            statusItemController?.refresh(isSpillBarVisible: false)
            return
        }

        showSpillBar()
    }

    private func showSpillBar() {
        if !AccessibilityPermission.isTrusted {
            _ = AccessibilityPermission.request()
        }

        spillPanelController.show(anchorFrame: statusItemController?.buttonScreenFrame)

        if AccessibilityPermission.isTrusted && scanner.items.isEmpty {
            scanner.refresh()
        }

        statusItemController?.refresh(isSpillBarVisible: spillPanelController.isVisible)
    }

    private func refreshMenuBarItems() {
        scanCoordinator.refreshNow()
        statusItemController?.refresh()
        Task { @MainActor [weak self] in
            await self?.refreshStatusData()
        }
    }

    private func showPreferences() {
        preferencesWindowController.show()
    }

    private func performWindowAction(_ kind: WindowActionKind) {
        if !AccessibilityPermission.isTrusted {
            _ = AccessibilityPermission.request()
            return
        }

        let result = windowActionStore.perform(kind)
        if case .permissionRequired = result {
            _ = AccessibilityPermission.request()
        }
    }

    private func configureHotKey() {
        if settings.hotKeyEnabled {
            hotKeyController.register()
        } else {
            hotKeyController.unregister()
        }
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

        settings.$hotKeyEnabled
            .dropFirst()
            .sink { [weak self] _ in
                self?.configureHotKey()
            }
            .store(in: &cancellables)

        settings.$showCountBadge
            .dropFirst()
            .sink { [weak self] _ in
                self?.statusItemController?.refresh()
            }
            .store(in: &cancellables)

        settings.$displayMode
            .dropFirst()
            .sink { [weak self] _ in
                self?.statusItemController?.refresh()
            }
            .store(in: &cancellables)

        settings.$selectedItemKeys
            .dropFirst()
            .sink { [weak self] _ in
                self?.statusItemController?.refresh()
            }
            .store(in: &cancellables)

        settings.$enabledMenuBarStatusItems
            .dropFirst()
            .sink { [weak self] _ in
                self?.statusItemController?.refresh()
                self?.configureStatusRefreshLoop()
            }
            .store(in: &cancellables)

        settings.$menuBarStatusDisplayStyle
            .dropFirst()
            .sink { [weak self] _ in
                self?.statusItemController?.refresh()
            }
            .store(in: &cancellables)

        settings.$menuBarStatusPrecision
            .dropFirst()
            .sink { [weak self] _ in
                self?.statusItemController?.refresh()
            }
            .store(in: &cancellables)

        settings.$menuBarStatusHighlightThreshold
            .dropFirst()
            .sink { [weak self] _ in
                self?.statusItemController?.refresh()
            }
            .store(in: &cancellables)

        settings.$refreshInterval
            .dropFirst()
            .sink { [weak self] _ in
                self?.configureStatusRefreshLoop()
            }
            .store(in: &cancellables)
    }

    private func configureStatusRefreshLoop() {
        statusRefreshTask?.cancel()

        guard !settings.enabledMenuBarStatusItems.isEmpty else {
            statusItemController?.refresh()
            return
        }

        statusRefreshTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await refreshMenuBarStatusData()

                let delay = UInt64(max(settings.refreshInterval, 5) * 1_000_000_000)
                do {
                    try await Task.sleep(nanoseconds: delay)
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
        let readsPower = isSpillPanelVisible && settings.showPowerFooter

        await statusStore.refresh(
            enabledModules: enabledModules,
            readsPower: readsPower
        )
        statusItemController?.refresh()
    }

    private func refreshStatusData() async {
        if isSpillPanelVisible {
            aiStatusStore.refresh()
        }

        await statusStore.refresh(
            enabledModules: isSpillPanelVisible ? settings.statusModulesRequiredForRefresh : menuBarStatusModules,
            readsPower: isSpillPanelVisible && settings.showPowerFooter
        )
        statusItemController?.refresh()
    }

    private var menuBarStatusModules: Set<SpillStatusModule> {
        Set(settings.enabledMenuBarStatusItems.compactMap(\.systemModule))
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
        showSpillBar()
    }

    @objc private func refreshMenuBarItemsFromMainMenu() {
        refreshMenuBarItems()
    }

    @objc private func showPreferencesFromMainMenu() {
        showPreferences()
    }

    @objc private func quitFromMainMenu() {
        NSApp.terminate(nil)
    }
}
