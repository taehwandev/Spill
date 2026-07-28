import AppKit

@MainActor
final class TokenMeteringDashboardAppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SpillSettings.shared
    private lazy var cloudServiceStatusStore = CloudServiceStatusStore(
        remoteRefreshRequest: { [weak self] force in
            self?.requestCloudServiceStatusRefresh(force: force)
        }
    )
    private let aiStatusStore = AIStatusStore()
    private let tokenUsageStore: TokenUsageStore
    private lazy var tokenUsageDashboardStore = TokenUsageDashboardStore(
        usageStore: tokenUsageStore,
        collectionCoordinator: nil,
        loadsInitialPanelSummary: false,
        loadsGlanceSummary: false
    )
    private var windowController: TokenMeteringDashboardWindowController?
    private var hasRequestedMainAppLaunch = false

    override init() {
        tokenUsageStore = Self.makeTokenUsageStore()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let renderStartedAt = isRenderPerformanceSmokeTest
            ? ProcessInfo.processInfo.systemUptime
            : nil
        NSApp.setActivationPolicy(.regular)
        NSApp.appearance = settings.appearanceTheme.nsAppearance
        configureMainMenu()
        observeSettingsChanges()
        observeCloudServiceStatusChanges()
        launchMainAppIfNeeded()
        if !shouldHideWindowInSmokeTest {
            dashboardWindowController().show()
        }

        if isSmokeTest {
            startSmokeTestExitTimer(renderStartedAt: renderStartedAt)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        SpillCrashReporter.markCleanShutdown(processRole: "token_dashboard")
        aiStatusStore.cancelRefresh()
        cloudServiceStatusStore.cancelRefresh()
        windowController?.prepareForTermination()
        DistributedNotificationCenter.default().removeObserver(
            self,
            name: TokenMeteringDashboardProcess.settingsDidChangeNotification,
            object: nil
        )
        DistributedNotificationCenter.default().removeObserver(
            self,
            name: TokenMeteringDashboardProcess.cloudServiceStatusDidChangeNotification,
            object: nil
        )
    }

}

extension TokenMeteringDashboardAppDelegate {
    private static func makeTokenUsageStore() -> TokenUsageStore {
        TokenUsageStoreEnvironment.store() ?? TokenUsageStore.live()
    }

    private var isSmokeTest: Bool {
        ProcessInfo.processInfo.environment["SPILL_SMOKE_TEST"] == "1"
    }

    private var shouldHideWindowInSmokeTest: Bool {
        isSmokeTest && ProcessInfo.processInfo.environment["SPILL_TOKEN_DASHBOARD_SMOKE_NO_WINDOW"] == "1"
    }

    private var isRenderPerformanceSmokeTest: Bool {
        isSmokeTest && ProcessInfo.processInfo.environment["SPILL_TOKEN_DASHBOARD_RENDER_SMOKE"] == "1"
    }

    private func dashboardWindowController() -> TokenMeteringDashboardWindowController {
        if let windowController {
            return windowController
        }

        let controller = TokenMeteringDashboardWindowController(
            store: tokenUsageDashboardStore,
            cloudServiceStatusStore: cloudServiceStatusStore,
            aiStatusStore: aiStatusStore,
            settings: settings,
            refreshAction: { [weak self] in
                self?.requestTokenUsageCollection(reason: "dashboard_refresh")
            },
            settingsAction: { [weak self] in
                self?.openMainAppTokenMeteringSettings()
            },
            developerOptionsAction: { [weak self] in
                self?.openMainAppDeveloperOptions()
            },
            closeAction: {
                TokenMeteringDashboardLifecycle.shared.terminateCurrentDashboardProcess()
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

        postTokenUsageCollectionRequest(reason: reason)
    }

    private func openMainAppTokenMeteringSettings() {
        openMainAppPreferences(tab: TokenMeteringDashboardProcess.tokenMeteringPreferencesTab)
    }

    private func openMainAppDeveloperOptions() {
        openMainAppPreferences(tab: TokenMeteringDashboardProcess.developerOptionsPreferencesTab)
    }

    private func openMainAppPreferences(tab: String) {
        TokenMeteringDashboardProcess.postOpenPreferencesRequest(tab: tab)

        guard let mainAppURL = TokenMeteringDashboardProcess.mainAppURLForDashboardHelper() else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        let completion = TokenMeteringWorkspaceOpenCompletion.postOpenPreferencesRequest(tab: tab)
        NSWorkspace.shared.openApplication(at: mainAppURL, configuration: configuration, completionHandler: completion)
    }

    private func launchMainAppIfNeeded() {
        openMainAppIfNeeded()
    }

    private func postTokenUsageCollectionRequest(reason: String) {
        openMainAppIfNeeded {
            TokenMeteringDashboardProcess.postTokenUsageCollectionRequest(reason: reason)
        }
    }

    private func requestCloudServiceStatusRefresh(force: Bool) {
        openMainAppIfNeeded {
            TokenMeteringDashboardProcess.postCloudServiceStatusRefreshRequest(force: force)
        }
    }

}

extension TokenMeteringDashboardAppDelegate {
    private func openMainAppIfNeeded(completion: (@MainActor @Sendable () -> Void)? = nil) {
        guard !isSmokeTest else {
            completion?()
            return
        }

        guard TokenMeteringDashboardProcess.shouldRequestMainAppLaunch(
            hasRequestedLaunch: hasRequestedMainAppLaunch
        ) else {
            completion?()
            return
        }

        guard let mainAppURL = TokenMeteringDashboardProcess.mainAppURLForDashboardHelper() else {
            completion?()
            return
        }

        hasRequestedMainAppLaunch = true

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        let completionHandler = TokenMeteringWorkspaceOpenCompletion.runOnMainActor(completion)
        NSWorkspace.shared.openApplication(at: mainAppURL, configuration: configuration, completionHandler: completionHandler)
    }

    private func observeSettingsChanges() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(settingsDidChangeFromMainApp(_:)),
            name: TokenMeteringDashboardProcess.settingsDidChangeNotification,
            object: nil
        )
    }

    private func observeCloudServiceStatusChanges() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(cloudServiceStatusDidChangeFromMainApp(_:)),
            name: TokenMeteringDashboardProcess.cloudServiceStatusDidChangeNotification,
            object: nil
        )
    }

    @objc private func cloudServiceStatusDidChangeFromMainApp(_ notification: Notification) {
        cloudServiceStatusStore.reloadFromCacheIfNewer()
    }

    @objc private func settingsDidChangeFromMainApp(_ notification: Notification) {
        let settingsKey = notification.userInfo?[TokenMeteringDashboardProcess.settingsKeyUserInfoKey] as? String
        let supportedSettingsKeys = [
            TokenMeteringDashboardProcess.appLanguageSettingsKey,
            TokenMeteringDashboardProcess.appearanceThemeSettingsKey,
            TokenMeteringDashboardProcess.tokenUsageDashboardOnboardingPreviewSettingsKey,
            TokenMeteringDashboardProcess.tokenUsageInputScopeSettingsKey
        ]
        guard settingsKey == nil || supportedSettingsKeys.contains(settingsKey ?? "") else {
            return
        }

        if settingsKey == nil || settingsKey == TokenMeteringDashboardProcess.appLanguageSettingsKey {
            settings.reloadAppLanguageFromDefaults()
        }

        if settingsKey == nil || settingsKey == TokenMeteringDashboardProcess.appearanceThemeSettingsKey {
            settings.reloadAppearanceThemeFromDefaults()
            NSApp.appearance = settings.appearanceTheme.nsAppearance
        }

        if SpillBuildOptions.developerOptionsEnabled,
           settingsKey == nil || settingsKey == TokenMeteringDashboardProcess.tokenUsageDashboardOnboardingPreviewSettingsKey {
            settings.reloadTokenUsageDashboardOnboardingPreviewFromDefaults()
            tokenUsageDashboardStore.setOnboardingPreviewEnabled(
                settings.tokenUsageDashboardOnboardingPreviewEnabled
            )
        }

        if settingsKey == nil || settingsKey == TokenMeteringDashboardProcess.tokenUsageInputScopeSettingsKey {
            settings.reloadTokenUsageInputScopeFromDefaults()
        }
    }

    private func startSmokeTestExitTimer(renderStartedAt: TimeInterval?) {
        print("SPILL_TOKEN_DASHBOARD_SMOKE_READY")
        reportVisibleRenderIfNeeded(renderStartedAt: renderStartedAt)

        let configuredDelay = ProcessInfo.processInfo.environment["SPILL_SMOKE_TEST_EXIT_AFTER"]
            .flatMap(TimeInterval.init)
        let exitDelay = max(configuredDelay ?? 1.0, 0.2)

        DispatchQueue.main.asyncAfter(deadline: .now() + exitDelay) {
            print("SPILL_TOKEN_DASHBOARD_SMOKE_EXIT")
            NSApp.terminate(nil)
        }
    }

    private func reportVisibleRenderIfNeeded(renderStartedAt: TimeInterval?) {
        guard isRenderPerformanceSmokeTest, let renderStartedAt else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let size = self?.windowController?.prepareVisibleRenderForSmokeTest() else {
                print("SPILL_TOKEN_DASHBOARD_RENDER_FAILED")
                return
            }

            let elapsedMilliseconds = max(
                Int((ProcessInfo.processInfo.systemUptime - renderStartedAt) * 1_000),
                0
            )
            print(
                "SPILL_TOKEN_DASHBOARD_RENDER_READY "
                    + "elapsed_ms=\(elapsedMilliseconds) "
                    + "width=\(Int(size.width)) height=\(Int(size.height))"
            )
        }
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu(title: "Spill - AI Token Metering")
        appMenuItem.submenu = appMenu
        appMenu.addItem(
            NSMenuItem(
                title: "Quit Spill - AI Token Metering",
                action: #selector(quitDashboard),
                keyEquivalent: "q"
            )
        )
        NSApp.mainMenu = mainMenu
    }

    @objc private func quitDashboard() {
        TokenMeteringDashboardLifecycle.shared.terminateCurrentDashboardProcess()
    }
}
