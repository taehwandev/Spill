import AppKit

@MainActor
final class TokenMeteringDashboardAppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SpillSettings.shared
    private let cloudServiceStatusStore = CloudServiceStatusStore()
    private let tokenUsageStore: TokenUsageStore
    private lazy var tokenUsageInboxMonitor = TokenUsageInboxMonitor(store: tokenUsageStore)
    private lazy var tokenUsageCollectorCoordinator = TokenUsageCollectorCoordinator(
        store: tokenUsageStore
    )
    private lazy var tokenUsageDashboardStore = TokenUsageDashboardStore(
        usageStore: tokenUsageStore,
        collectionCoordinator: tokenUsageCollectorCoordinator
    )
    private var windowController: TokenMeteringDashboardWindowController?

    override init() {
        tokenUsageStore = Self.makeTokenUsageStore()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        configureMainMenu()
        observeSettingsChanges()
        launchMainAppIfNeeded()
        tokenUsageInboxMonitor.start()
        requestTokenUsageCollection(reason: "dashboard_launch")
        dashboardWindowController().show()

        if isSmokeTest {
            startSmokeTestExitTimer()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        tokenUsageInboxMonitor.stop()
        DistributedNotificationCenter.default().removeObserver(
            self,
            name: TokenMeteringDashboardProcess.settingsDidChangeNotification,
            object: nil
        )
    }

    private static func makeTokenUsageStore() -> TokenUsageStore {
        let environment = ProcessInfo.processInfo.environment
        guard environment["SPILL_SMOKE_TEST"] == "1",
              let eventsFile = environment["SPILL_TOKEN_USAGE_EVENTS_FILE"],
              !eventsFile.isEmpty
        else {
            return TokenUsageStore.live()
        }

        let inboxURL = environment["SPILL_TOKEN_USAGE_INBOX_DIR"]
            .flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0) }
        return TokenUsageStore(
            fileURL: URL(fileURLWithPath: eventsFile),
            inboxURL: inboxURL
        )
    }

    private var isSmokeTest: Bool {
        ProcessInfo.processInfo.environment["SPILL_SMOKE_TEST"] == "1"
    }

    private func dashboardWindowController() -> TokenMeteringDashboardWindowController {
        if let windowController {
            return windowController
        }

        let controller = TokenMeteringDashboardWindowController(
            store: tokenUsageDashboardStore,
            cloudServiceStatusStore: cloudServiceStatusStore,
            settings: settings,
            refreshAction: { [weak self] in
                self?.requestTokenUsageCollection(reason: "dashboard_refresh")
            },
            settingsAction: { [weak self] in
                self?.openMainAppTokenMeteringSettings()
            },
            closeAction: {
                NSApp.terminate(nil)
            }
        )
        windowController = controller
        return controller
    }

    private func requestTokenUsageCollection(reason: String) {
        if isSmokeTest,
           ProcessInfo.processInfo.environment["SPILL_SMOKE_ENABLE_TOKEN_COLLECTORS"] != "1" {
            return
        }

        tokenUsageCollectorCoordinator.requestCollection(reason: reason)
    }

    private func openMainAppTokenMeteringSettings() {
        TokenMeteringDashboardProcess.postOpenPreferencesRequest()

        guard let mainAppURL = TokenMeteringDashboardProcess.mainAppURLForDashboardHelper() else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: mainAppURL, configuration: configuration) { _, _ in
            TokenMeteringDashboardProcess.postOpenPreferencesRequest()
        }
    }

    private func launchMainAppIfNeeded() {
        guard !isSmokeTest,
              let mainAppURL = TokenMeteringDashboardProcess.mainAppURLForDashboardHelper(),
              let mainBundleIdentifier = TokenMeteringDashboardProcess.mainBundleIdentifierForDashboardHelper()
        else {
            return
        }

        let isRunning = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == mainBundleIdentifier
        }
        guard !isRunning else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: mainAppURL, configuration: configuration)
    }

    private func observeSettingsChanges() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(settingsDidChangeFromMainApp(_:)),
            name: TokenMeteringDashboardProcess.settingsDidChangeNotification,
            object: nil
        )
    }

    @objc private func settingsDidChangeFromMainApp(_ notification: Notification) {
        let settingsKey = notification.userInfo?[TokenMeteringDashboardProcess.settingsKeyUserInfoKey] as? String
        guard settingsKey == nil || settingsKey == TokenMeteringDashboardProcess.appLanguageSettingsKey else {
            return
        }

        settings.reloadAppLanguageFromDefaults()
    }

    private func startSmokeTestExitTimer() {
        print("SPILL_TOKEN_DASHBOARD_SMOKE_READY")

        let configuredDelay = ProcessInfo.processInfo.environment["SPILL_SMOKE_TEST_EXIT_AFTER"]
            .flatMap(TimeInterval.init)
        let exitDelay = max(configuredDelay ?? 1.0, 0.2)

        DispatchQueue.main.asyncAfter(deadline: .now() + exitDelay) {
            print("SPILL_TOKEN_DASHBOARD_SMOKE_EXIT")
            NSApp.terminate(nil)
        }
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu(title: "Spill Token Dashboard")
        appMenuItem.submenu = appMenu
        appMenu.addItem(
            NSMenuItem(
                title: "Quit Spill Token Dashboard",
                action: #selector(quitDashboard),
                keyEquivalent: "q"
            )
        )
        NSApp.mainMenu = mainMenu
    }

    @objc private func quitDashboard() {
        NSApp.terminate(nil)
    }
}
