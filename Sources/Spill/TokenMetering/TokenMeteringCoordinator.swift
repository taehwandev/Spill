import AppKit
import Carbon.HIToolbox
import Combine

@MainActor
final class TokenMeteringCoordinator: NSObject {
    private static let menuBarTokenCollectionInterval: TimeInterval = 60

    let usageStore: TokenUsageStore

    private let settings: SpillSettings
    private let cloudServiceStatusStore: CloudServiceStatusStore
    private let aiStatusStore: AIStatusStore
    private let bridgePort: UInt16
    private lazy var bridgeServer = TokenUsageBridgeServer(
        store: usageStore,
        port: bridgePort
    )
    private lazy var inboxMonitor = TokenUsageInboxMonitor(store: usageStore)
    private lazy var collectorCoordinator = TokenUsageCollectorCoordinator(store: usageStore)
    private(set) lazy var historyImportCoordinator = TokenUsageHistoryImportCoordinator(store: usageStore)
    private lazy var dashboardLauncher = TokenMeteringDashboardLauncher()
    private(set) lazy var dashboardStore = TokenUsageDashboardStore(
        usageStore: usageStore,
        collectionCoordinator: collectorCoordinator
    )
    private var dashboardWindowController: TokenMeteringDashboardWindowController?
    private var privateUsageUploadTask: Task<Void, Never>?
    private var isDashboardLaunchInProgress = false
    private var isSmokeTest = false
    private var isSpillPanelVisible = false
    private var menuBarTokenDayStart: Date?
    private var lastMenuBarTokenCollectionAt: Date?
    private var usageEventsDidChange: (@MainActor () -> Void)?
    private var cancellables = Set<AnyCancellable>()
    private var visibleAIToolsSyncTask: Task<Void, Never>?
    private var hasStarted = false
    private var isStopped = false

    private(set) var menuBarTokenTotal = 0
    private(set) var menuBarAllTimeTokenTotal = 0

    init(
        settings: SpillSettings,
        cloudServiceStatusStore: CloudServiceStatusStore,
        aiStatusStore: AIStatusStore = AIStatusStore(),
        usageStore: TokenUsageStore = TokenUsageStoreEnvironment.store() ?? TokenUsageStore.live(),
        bridgePort: UInt16 = TokenMeteringCoordinator.makeTokenUsageBridgePort()
    ) {
        self.settings = settings
        self.cloudServiceStatusStore = cloudServiceStatusStore
        self.aiStatusStore = aiStatusStore
        self.usageStore = usageStore
        self.bridgePort = bridgePort
        super.init()
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
        NSAppleEventManager.shared().removeEventHandler(
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func start(
        isSmokeTest: Bool,
        usageEventsDidChange: @escaping @MainActor () -> Void
    ) {
        hasStarted = true
        isStopped = false
        self.isSmokeTest = isSmokeTest
        self.usageEventsDidChange = usageEventsDidChange
        TokenMeteringSetupInstaller.refreshInstalledFilesIfPresent()
        syncVisibleAIToolsFromStatusStore()
        observeUsageEvents()
        observeAIToolVisibility()
        inboxMonitor.start()
        requestCollection(reason: "app_launch")
        configureBridge()
        registerPrivateUsageConnectionURLHandler()
        observePrivateUsageUploadOpportunities()
        schedulePrivateUsageUploadIfNeeded()
    }

    func stop() {
        guard hasStarted, !isStopped else {
            return
        }
        isStopped = true
        inboxMonitor.stop()
        collectorCoordinator.stop()
        bridgeServer.stop()
        historyImportCoordinator.cancelImport()
        aiStatusStore.cancelRefresh()
        visibleAIToolsSyncTask?.cancel()
        visibleAIToolsSyncTask = nil
        privateUsageUploadTask?.cancel()
        privateUsageUploadTask = nil
        cancellables.removeAll()
        DistributedNotificationCenter.default().removeObserver(
            self,
            name: TokenUsageStore.distributedEventsDidChangeNotification,
            object: nil
        )
        NSAppleEventManager.shared().removeEventHandler(
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func setSpillPanelVisible(_ isVisible: Bool) {
        isSpillPanelVisible = isVisible
    }

    func requestCollection(reason: String) {
        if isSmokeTest,
           ProcessInfo.processInfo.environment["SPILL_SMOKE_ENABLE_TOKEN_COLLECTORS"] != "1" {
            return
        }

        collectorCoordinator.requestCollection(reason: reason)
    }

    func preparePrivateUsageUpload() async {
        if isSmokeTest,
           ProcessInfo.processInfo.environment["SPILL_SMOKE_ENABLE_TOKEN_COLLECTORS"] != "1" {
            return
        }

        await collectorCoordinator.requestCollectionAndWait(reason: "private_usage_upload")
    }

    func refreshPanelSummary() {
        syncVisibleAIToolsFromStatusStore()
        dashboardStore.refreshPanelSummary()
    }

    func refreshMenuBarTokenTotal(now: Date = Date(), force: Bool = false) {
        let calendar = Calendar.autoupdatingCurrent
        let dayStart = calendar.startOfDay(for: now)
        guard force || shouldRefreshMenuBarTokenTotal else {
            return
        }
        guard force || menuBarTokenDayStart != dayStart else {
            return
        }

        menuBarTokenDayStart = dayStart
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? now
        menuBarTokenTotal = usageStore.totalTokens(
            startingAt: dayStart,
            endingBefore: dayEnd
        )
        menuBarAllTimeTokenTotal = usageStore.allTimeTotalTokens()
    }

    func requestMenuBarTokenUsageCollectionIfNeeded(now: Date = Date()) {
        guard shouldRefreshMenuBarTokenTotal else {
            return
        }

        if let lastMenuBarTokenCollectionAt,
           now.timeIntervalSince(lastMenuBarTokenCollectionAt) < Self.menuBarTokenCollectionInterval {
            return
        }

        lastMenuBarTokenCollectionAt = now
        requestCollection(reason: "menu_bar_status")
    }

    var menuBarServerHealth: CloudServiceHealth? {
        guard let snapshot = cloudServiceStatusStore.snapshot else {
            return nil
        }

        let dashboardToolStatuses = TokenUsageAITool.dashboardTools.compactMap { tool in
            CloudServiceStatusPresentation.serviceStatus(for: tool, in: snapshot)
        }
        guard !dashboardToolStatuses.isEmpty else {
            return nil
        }

        return CloudServiceStatusPresentation.aggregateHealth(for: dashboardToolStatuses)
    }

    func openDashboard(
        deferLaunch: Bool,
        refreshStatusItem: @escaping @MainActor () -> Void,
        showPreferences: @escaping @MainActor (_ source: String, _ selectedTab: String?) -> Void
    ) {
        let launch = { [weak self] in
            self?.openDashboardProcessOrFallback(
                refreshStatusItem: refreshStatusItem,
                showPreferences: showPreferences
            )
        }

        if deferLaunch {
            Task { @MainActor in
                launch()
            }
        } else {
            launch()
        }
    }

    private static func makeTokenUsageBridgePort() -> UInt16 {
        let environment = ProcessInfo.processInfo.environment
        guard environment["SPILL_SMOKE_TEST"] == "1",
              let rawPort = environment["SPILL_TOKEN_USAGE_BRIDGE_PORT"],
              let port = UInt16(rawPort)
        else {
            return TokenUsageBridgeServer.defaultPort
        }

        return port
    }

    private var shouldRefreshMenuBarTokenTotal: Bool {
        isSpillPanelVisible || settings.enabledMenuBarStatusItems.contains(.ai)
    }

    private var isBridgeEnabled: Bool {
        guard ProcessInfo.processInfo.environment["SPILL_TOKEN_USAGE_BRIDGE_DISABLED"] != "1" else {
            return false
        }

        return isSmokeTest
    }

    private func configureBridge() {
        guard isBridgeEnabled else {
            bridgeServer.stop()
            return
        }

        do {
            try bridgeServer.start()
        } catch {
            // The native app dashboard reads the app-owned store directly.
            return
        }
    }

    private func observeUsageEvents() {
        NotificationCenter.default.publisher(
            for: TokenUsageStore.eventsDidChangeNotification,
            object: usageStore
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
            self?.refreshMenuBarTokenTotal(force: true)
            self?.usageEventsDidChange?()
        }
        .store(in: &cancellables)

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(tokenUsageEventsDidChangeFromDistributedNotification(_:)),
            name: TokenUsageStore.distributedEventsDidChangeNotification,
            object: nil
        )
    }

    private func observeAIToolVisibility() {
        settings.$hiddenTokenUsageAITools
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleVisibleAIToolsSync()
            }
            .store(in: &cancellables)

        settings.$hiddenLocalAIToolKinds
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleVisibleAIToolsSync()
            }
            .store(in: &cancellables)

        aiStatusStore.$statuses
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleVisibleAIToolsSync()
            }
            .store(in: &cancellables)

        aiStatusStore.$hasCompletedRefresh
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleVisibleAIToolsSync()
            }
            .store(in: &cancellables)
    }

    private func observePrivateUsageUploadOpportunities() {
        guard !isSmokeTest else {
            return
        }

        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.schedulePrivateUsageUploadIfNeeded()
            }
            .store(in: &cancellables)

        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.schedulePrivateUsageUploadIfNeeded()
            }
            .store(in: &cancellables)
    }

    private func scheduleVisibleAIToolsSync() {
        visibleAIToolsSyncTask?.cancel()
        visibleAIToolsSyncTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, !Task.isCancelled else {
                return
            }

            self.visibleAIToolsSyncTask = nil
            self.syncVisibleAIToolsFromStatusStore()
        }
    }

    private func syncVisibleAIToolsFromStatusStore() {
        let baseTools: Set<TokenUsageAITool>
        if aiStatusStore.hasCompletedRefresh || !aiStatusStore.statuses.isEmpty {
            baseTools = Set(aiStatusStore.statuses.compactMap(\.kind.tokenUsageDashboardTool))
        } else {
            baseTools = Set(TokenUsageAITool.dashboardTools)
        }
        dashboardStore.setVisibleAITools(baseTools.subtracting(settings.hiddenTokenUsageAITools))
    }

    private func registerPrivateUsageConnectionURLHandler() {
        guard PrivateUsageUploadFeatureAvailability.isEnabledInCurrentBuild else {
            return
        }

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handlePrivateUsageConnectionURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handlePrivateUsageConnectionURLEvent(
        _ event: NSAppleEventDescriptor,
        withReplyEvent replyEvent: NSAppleEventDescriptor
    ) {
        guard PrivateUsageUploadFeatureAvailability.isEnabledInCurrentBuild,
              let rawURL = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: rawURL),
              let connectionCode = PrivateUsageConnectionDeepLink.connectionCode(from: url)
        else {
            return
        }

        Task { @MainActor [weak self] in
            await self?.connectPrivateUsageFromDeepLink(connectionCode: connectionCode)
        }
    }

    private func connectPrivateUsageFromDeepLink(connectionCode: String) async {
        guard PrivateUsageUploadFeatureAvailability.isEnabledInCurrentBuild else {
            return
        }

        let environment = settings.privateUsageUploadEnvironment
        let coordinator = PrivateUsageUploadCoordinator.live(
            usageStore: usageStore,
            environment: environment
        )

        do {
            _ = try await coordinator.exchangeGrantCode(connectionCode)
            settings.privateUsageUploadEnabled = true
            PrivateUsageConnectionResultNotification.postSuccess(environment: environment)
            schedulePrivateUsageUploadIfNeeded()
        } catch {
            SpillCrashReporter.capturePrivateUsageUploadFailure(operation: .connectDeepLink, error: error)
            PrivateUsageConnectionResultNotification.postFailure(
                environment: environment,
                error: error
            )
        }
    }

    private func schedulePrivateUsageUploadIfNeeded() {
        guard !isSmokeTest else {
            return
        }
        guard PrivateUsageUploadFeatureAvailability.isEnabledInCurrentBuild else {
            privateUsageUploadTask?.cancel()
            privateUsageUploadTask = nil
            return
        }

        privateUsageUploadTask?.cancel()
        privateUsageUploadTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: 2_000_000_000)
            } catch {
                return
            }

            guard let self else {
                return
            }

            let coordinator = PrivateUsageUploadCoordinator.live(
                usageStore: usageStore,
                environment: settings.privateUsageUploadEnvironment
            )
            guard coordinator.automaticUploadIsDue(
                isEnabled: settings.privateUsageUploadEnabled,
                now: Date()
            ) else {
                return
            }

            await preparePrivateUsageUpload()
            guard !Task.isCancelled else {
                return
            }

            _ = await coordinator.runAutomaticUploadIfNeeded(
                isEnabled: settings.privateUsageUploadEnabled
            )
        }
    }

    @objc private func tokenUsageEventsDidChangeFromDistributedNotification(_ notification: Notification) {
        refreshMenuBarTokenTotal(force: true)
        usageEventsDidChange?()
    }

    private func openDashboardProcessOrFallback(
        refreshStatusItem: @escaping @MainActor () -> Void,
        showPreferences: @escaping @MainActor (_ source: String, _ selectedTab: String?) -> Void
    ) {
        guard !isDashboardLaunchInProgress else {
            if isSmokeTest {
                print("SPILL_TOKEN_DASHBOARD_LAUNCH_SMOKE_DUPLICATE_IGNORED")
            }
            return
        }

        isDashboardLaunchInProgress = true
        dashboardLauncher.open(
            fallback: { [weak self] in
                self?.presentDashboardWindow(
                    refreshStatusItem: refreshStatusItem,
                    showPreferences: showPreferences
                )
            },
            completion: { [weak self] in
                self?.scheduleDashboardLaunchReset()
            }
        )
        scheduleDashboardLaunchReset(after: 2.0)
    }

    private func scheduleDashboardLaunchReset(after delay: TimeInterval = 0.75) {
        Task { @MainActor [weak self] in
            let nanoseconds = UInt64(delay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            self?.isDashboardLaunchInProgress = false
        }
    }

    private func presentDashboardWindow(
        refreshStatusItem: @escaping @MainActor () -> Void,
        showPreferences: @escaping @MainActor (_ source: String, _ selectedTab: String?) -> Void
    ) {
        refreshMenuBarTokenTotal(force: true)
        refreshStatusItem()
        dashboardWindowController(showPreferences: showPreferences).show()
    }

    private func dashboardWindowController(
        showPreferences: @escaping @MainActor (_ source: String, _ selectedTab: String?) -> Void
    ) -> TokenMeteringDashboardWindowController {
        if let dashboardWindowController {
            return dashboardWindowController
        }

        let controller = TokenMeteringDashboardWindowController(
            store: dashboardStore,
            cloudServiceStatusStore: cloudServiceStatusStore,
            aiStatusStore: aiStatusStore,
            settings: settings,
            refreshAction: { [weak self] in
                self?.requestCollection(reason: "dashboard_refresh")
            },
            settingsAction: {
                showPreferences(
                    "token_dashboard",
                    TokenMeteringDashboardProcess.tokenMeteringPreferencesTab
                )
            },
            syncsVisibleAIToolsInView: false
        )
        dashboardWindowController = controller
        return controller
    }
}
