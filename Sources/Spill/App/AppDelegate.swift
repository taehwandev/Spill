import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SpillSettings.shared
    private let scanner = AXMenuBarItemScanner()
    private lazy var scanCoordinator = MenuBarScanCoordinator(scanner: scanner, settings: settings)
    private lazy var hotKeyController = HotKeyController(action: { [weak self] in
        self?.toggleSpillBar()
    })
    private lazy var spillPanelController = SpillPanelController(
        settings: settings,
        scanner: scanner,
        visibilityChanged: { [weak self] isVisible in
            self?.statusItemController?.refresh(isSpillBarVisible: isVisible)
        }
    )
    private lazy var preferencesWindowController = PreferencesWindowController(settings: settings, scanner: scanner)
    private var statusItemController: StatusItemController?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemController = StatusItemController(
            settings: settings,
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

        if isSmokeTest {
            startSmokeTestExitTimer()
        } else {
            scanCoordinator.start()
            configureHotKey()
            showStartupUI()
        }
    }

    private func showStartupUI() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            showPreferences()

            if !AccessibilityPermission.isTrusted {
                _ = AccessibilityPermission.request()
            }
        }
    }

    private var isSmokeTest: Bool {
        ProcessInfo.processInfo.environment["SPILL_SMOKE_TEST"] == "1"
    }

    private func startSmokeTestExitTimer() {
        print("SPILL_SMOKE_READY")

        let configuredDelay = ProcessInfo.processInfo.environment["SPILL_SMOKE_TEST_EXIT_AFTER"]
            .flatMap(TimeInterval.init)
        let exitDelay = max(configuredDelay ?? 1.0, 0.2)

        DispatchQueue.main.asyncAfter(deadline: .now() + exitDelay) {
            print("SPILL_SMOKE_EXIT")
            NSApp.terminate(nil)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showPreferences()
        }

        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyController.stop()
        scanCoordinator.stop()
        spillPanelController.hide(animated: false)
    }

    private func toggleSpillBar() {
        if !AccessibilityPermission.isTrusted {
            _ = AccessibilityPermission.request()
        }

        spillPanelController.toggle()

        if AccessibilityPermission.isTrusted && scanner.items.isEmpty {
            scanner.refresh()
        }

        statusItemController?.refresh(isSpillBarVisible: spillPanelController.isVisible)
    }

    private func refreshMenuBarItems() {
        scanCoordinator.refreshNow()
        statusItemController?.refresh()
    }

    private func showPreferences() {
        preferencesWindowController.show()
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
    }
}
