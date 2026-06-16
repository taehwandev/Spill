import Foundation

enum AppTextKey: String {
    case showSpillPanel
    case hideSpillPanel
    case openLocalTokenDashboard
    case refreshMenuBarItems
    case checkForUpdates
    case preferences
    case quitSpill
    case shortcut
    case tokenMeteringLocalDashboard
    case menuBarItemCount
    case triggerLoad
    case caffeineChipStart
    case caffeineChipStop
    case caffeineOnUntilStopped
    case caffeineOnUntilStoppedDisplayMaySleep
    case caffeineRemaining
    case caffeineRemainingDisplayMaySleep
    case accessibilityRequired
    case scanning
    case noActionsReady
    case onboardingPreviewTitle
    case onboardingPreviewDetail
    case ready
    case permissionNeeded
    case refreshingActions
    case pinned
    case actionsReady
    case ax
    case ok
    case need
    case scan
    case on
    case idle
    case items
    case time
    case off
    case chooseCaffeineDuration
    case stopCaffeine
    case startDuration
    case power
    case caffeine
    case caffeineOff
    case caffeineUntilStopped
    case caffeineUntilStoppedDisplayMaySleep
    case caffeineRemainingHelp
    case caffeineRemainingDisplayMaySleepHelp
    case couldNotStartCaffeine
    case couldNotKeepDisplayAwake
    case statusDetails
    case refreshForceHelp
    case checkingOfficialSources
    case fetchedWhenOpen
    case servicesFromOfficialSources
    case openDashboardToFetchStatus
    case notFetched
    case officialStatusFetchedOnOpen
    case lastChecked
    case justNow
    case minutesAgo
    case hoursAgo
    case operational
    case degraded
    case outage
    case maintenance
    case unknown
    case serverOK
    case maint
    case checking
    case serverStatus
    case server
    case serverStatusPendingHelp
    case fetchOfficialServiceStatus
    case serverStatusNoIssues
    case serverStatusWithIssues
    case clickForPerServiceDetails
    case tokenMetering
    case local
    case tokens
    case details
    case openLocalTokenMeteringDetails
    case tokenMeteringAccessibility
    case tokenMeteringSetupTitle
    case tokenMeteringSetupDetail
    case tokenMeteringSettings
    case menuBarTokenDisplayModeDaily
    case menuBarTokenDisplayModeTotal
    case menuBarTokenDisplayModeDailyAndTotal
    case menuBarTokenDisplayModeCycle
    case openSetupPrompt
    case noTaskSplit
    case noSourceSplit
    case eventsSummary
    case aiProcessSummary
    case windows
    case menuBar
    case noFocusedWindow
    case positions
    case utilities
    case showInMenuBar
    case noItemsDetected
    case selectedHiddenSummary
    case activeSavedSummary
    case selectedSummary
    case clear
    case usage
    case available
    case user
    case system
    case nice
    case idleLabel
    case cores
    case peakCore
    case sample
    case state
    case used
    case free
    case active
    case inactive
    case wired
    case compressed
    case total
    case budget
    case unified
    case lowPower
    case headless
    case removable
    case receive
    case upload
    case interfaces
    case receivedTotal
    case uploadedTotal
    case status
    case detail
    case next
    case model
    case version
    case source
    case yes
    case no
    case normal
    case warning
    case unavailable
    case cpuActiveIdle
    case waitingForSample
    case availableOfTotal
    case externalPower
    case charging
    case onPower
    case onBattery
    case updateCheckingTitle
    case updateUpToDateTitle
    case updateAvailableTitle
    case updateRequiresMacOSTitle
    case updateTitle
    case updateNow
    case copyInstallCommand
    case copied
    case settings
    case close
    case lookingForLatestRelease
    case spillVersionCurrent
    case inAppUpdateReady
    case signedInstallerPackage
    case manualInstaller
    case versionNeedsMacOS
    case updateHTTPFailedFormat
    case invalidLatestVersionFormat
    case invalidMacOSVersionFormat
    case updateDecodingFailedFormat
    case missingMacOSDownloadAsset
    case triggerDrop
    case triggerDropSubtitle
    case serviceStatusAccessibility
    case noDetail
    case noNotchCandidates
    case nearNotchEstimate
    case notScannedYet
    case accessibilityNotTrusted
    case refreshQueued
    case scanningMenuBarItems
    case refreshingMenuBarItems
    case selectedItemUnavailable
    case performedPrimaryAction
    case pressFailedFormat
    case cachedResultUnchanged
    case noMenuBarItemsFoundFormat
    case detectedNoNotchFormat
    case detectedNearNotchFormat
    case pin
    case unpin
    case pinnedFormat
    case unpinnedFormat
    case pinInSpill
    case unpinFromSpill
    case showInSpill
    case hideInSpill
    case openedFormat
    case unavailableFormat
    case permissionRequiredFormat
    case unsupportedFormat
    case windowLeft
    case windowRight
    case windowTop
    case windowBottom
    case windowCenter
    case windowMaximize
    case windowTopLeft
    case windowTopRight
    case windowBottomLeft
    case windowBottomRight
    case windowPreviousDisplay
    case windowNextDisplay
    case windowRestore
}

enum AppL10n {
    static func text(
        _ key: AppTextKey,
        appLanguage: SpillAppLanguage = .persisted(),
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        let language = resolvedLanguage(appLanguage: appLanguage, preferredLanguages: preferredLanguages)
        return table[language]?[key] ?? table[.english]?[key] ?? key.rawValue
    }

    static func sleepDurationTitle(
        _ duration: SleepGuardDuration,
        appLanguage: SpillAppLanguage = .persisted(),
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        let language = resolvedLanguage(appLanguage: appLanguage, preferredLanguages: preferredLanguages)
        switch (language, duration) {
        case (.english, .fiveMinutes): return "5 Minutes"
        case (.english, .tenMinutes): return "10 Minutes"
        case (.english, .fifteenMinutes): return "15 Minutes"
        case (.english, .thirtyMinutes): return "30 Minutes"
        case (.english, .fortyFiveMinutes): return "45 Minutes"
        case (.english, .oneHour): return "1 Hour"
        case (.english, .twoHours): return "2 Hours"
        case (.english, .fourHours): return "4 Hours"
        case (.english, .eightHours): return "8 Hours"
        case (.english, .indefinitely): return "Never"
        case (.korean, .fiveMinutes): return "5분"
        case (.korean, .tenMinutes): return "10분"
        case (.korean, .fifteenMinutes): return "15분"
        case (.korean, .thirtyMinutes): return "30분"
        case (.korean, .fortyFiveMinutes): return "45분"
        case (.korean, .oneHour): return "1시간"
        case (.korean, .twoHours): return "2시간"
        case (.korean, .fourHours): return "4시간"
        case (.korean, .eightHours): return "8시간"
        case (.korean, .indefinitely): return "Never"
        case (.japanese, .fiveMinutes): return "5分"
        case (.japanese, .tenMinutes): return "10分"
        case (.japanese, .fifteenMinutes): return "15分"
        case (.japanese, .thirtyMinutes): return "30分"
        case (.japanese, .fortyFiveMinutes): return "45分"
        case (.japanese, .oneHour): return "1時間"
        case (.japanese, .twoHours): return "2時間"
        case (.japanese, .fourHours): return "4時間"
        case (.japanese, .eightHours): return "8時間"
        case (.japanese, .indefinitely): return "Never"
        }
    }

    static func statusModuleTitle(
        _ module: SpillStatusModule,
        appLanguage: SpillAppLanguage = .persisted(),
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        let language = resolvedLanguage(appLanguage: appLanguage, preferredLanguages: preferredLanguages)
        switch (language, module) {
        case (_, .cpu): return "CPU"
        case (.english, .memory): return "Memory"
        case (.english, .storage): return "Storage"
        case (_, .gpu): return "GPU"
        case (.english, .network): return "Network"
        case (.korean, .memory): return "메모리"
        case (.korean, .storage): return "저장 공간"
        case (.korean, .network): return "네트워크"
        case (.japanese, .memory): return "メモリ"
        case (.japanese, .storage): return "ストレージ"
        case (.japanese, .network): return "ネットワーク"
        }
    }

    static func itemCount(_ count: Int, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.menuBarItemCount, appLanguage: appLanguage), count)
    }

    static func pinnedCount(_ count: Int, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.pinned, appLanguage: appLanguage), count)
    }

    static func actionsReady(_ count: Int, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.actionsReady, appLanguage: appLanguage), count)
    }

    static func servicesFromOfficialSources(_ count: Int, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.servicesFromOfficialSources, appLanguage: appLanguage), count)
    }

    static func minutesAgo(_ minutes: Int, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.minutesAgo, appLanguage: appLanguage), minutes)
    }

    static func hoursAgo(_ hours: Int, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.hoursAgo, appLanguage: appLanguage), hours)
    }

    static func lastChecked(_ time: String, age: String, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.lastChecked, appLanguage: appLanguage), time, age)
    }

    static func serverStatusWithIssues(
        status: String,
        issueCount: Int,
        appLanguage: SpillAppLanguage = .persisted()
    ) -> String {
        String(format: text(.serverStatusWithIssues, appLanguage: appLanguage), status, issueCount)
    }

    static func eventsSummary(
        eventCount: Int,
        task: String,
        source: String,
        appLanguage: SpillAppLanguage = .persisted()
    ) -> String {
        String(format: text(.eventsSummary, appLanguage: appLanguage), eventCount, task, source)
    }

    static func aiProcessSummary(
        activeCount: Int,
        totalCount: Int,
        appLanguage: SpillAppLanguage = .persisted()
    ) -> String {
        String(format: text(.aiProcessSummary, appLanguage: appLanguage), activeCount, totalCount)
    }

    static func tokenMeteringAccessibility(
        tokenCount: String,
        appLanguage: SpillAppLanguage = .persisted()
    ) -> String {
        String(format: text(.tokenMeteringAccessibility, appLanguage: appLanguage), tokenCount)
    }

    static func activeIdle(
        active: String,
        idle: String,
        appLanguage: SpillAppLanguage = .persisted()
    ) -> String {
        String(format: text(.cpuActiveIdle, appLanguage: appLanguage), active, idle)
    }

    static func availableOfTotal(
        available: String,
        total: String,
        appLanguage: SpillAppLanguage = .persisted()
    ) -> String {
        String(format: text(.availableOfTotal, appLanguage: appLanguage), available, total)
    }

    static func updateAvailableTitle(version: String, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.updateAvailableTitle, appLanguage: appLanguage), version)
    }

    static func spillVersionCurrent(version: String, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.spillVersionCurrent, appLanguage: appLanguage), version)
    }

    static func versionNeedsMacOS(
        version: String,
        requirement: String,
        appLanguage: SpillAppLanguage = .persisted()
    ) -> String {
        String(format: text(.versionNeedsMacOS, appLanguage: appLanguage), version, requirement)
    }

    static func updateHTTPFailed(statusCode: Int, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.updateHTTPFailedFormat, appLanguage: appLanguage), statusCode)
    }

    static func invalidLatestVersion(_ version: String, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.invalidLatestVersionFormat, appLanguage: appLanguage), version)
    }

    static func invalidMacOSVersion(_ version: String, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.invalidMacOSVersionFormat, appLanguage: appLanguage), version)
    }

    static func updateDecodingFailed(_ message: String, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.updateDecodingFailedFormat, appLanguage: appLanguage), message)
    }

    static func serviceStatusAccessibility(
        status: String,
        appLanguage: SpillAppLanguage = .persisted()
    ) -> String {
        String(format: text(.serviceStatusAccessibility, appLanguage: appLanguage), status)
    }

    static func opened(_ title: String, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.openedFormat, appLanguage: appLanguage), title)
    }

    static func unavailable(_ title: String, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.unavailableFormat, appLanguage: appLanguage), title)
    }

    static func permissionRequired(
        _ permission: String,
        appLanguage: SpillAppLanguage = .persisted()
    ) -> String {
        String(format: text(.permissionRequiredFormat, appLanguage: appLanguage), permission)
    }

    static func unsupported(_ title: String, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.unsupportedFormat, appLanguage: appLanguage), title)
    }

    static func pressFailed(result: Int, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.pressFailedFormat, appLanguage: appLanguage), result)
    }

    static func noMenuBarItemsFound(
        candidateCount: Int,
        menuBarRootCount: Int,
        extrasRootCount: Int,
        fallbackRootCount: Int,
        representableElementCount: Int,
        suffix: String,
        appLanguage: SpillAppLanguage = .persisted()
    ) -> String {
        String(
            format: text(.noMenuBarItemsFoundFormat, appLanguage: appLanguage),
            candidateCount,
            menuBarRootCount,
            extrasRootCount,
            fallbackRootCount,
            representableElementCount,
            suffix
        )
    }

    static func detectedNoNotch(
        itemCount: Int,
        menuBarRootCount: Int,
        suffix: String,
        appLanguage: SpillAppLanguage = .persisted()
    ) -> String {
        String(
            format: text(.detectedNoNotchFormat, appLanguage: appLanguage),
            itemCount,
            menuBarRootCount,
            suffix
        )
    }

    static func detectedNearNotch(
        itemCount: Int,
        notchCount: Int,
        suffix: String,
        appLanguage: SpillAppLanguage = .persisted()
    ) -> String {
        String(
            format: text(.detectedNearNotchFormat, appLanguage: appLanguage),
            itemCount,
            notchCount,
            suffix
        )
    }

    static func pinned(_ title: String, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.pinnedFormat, appLanguage: appLanguage), title)
    }

    static func unpinned(_ title: String, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.unpinnedFormat, appLanguage: appLanguage), title)
    }

    static func windowActionTitle(
        _ kind: WindowActionKind,
        appLanguage: SpillAppLanguage = .persisted()
    ) -> String {
        switch kind {
        case .leftHalf:
            return text(.windowLeft, appLanguage: appLanguage)
        case .rightHalf:
            return text(.windowRight, appLanguage: appLanguage)
        case .topHalf:
            return text(.windowTop, appLanguage: appLanguage)
        case .bottomHalf:
            return text(.windowBottom, appLanguage: appLanguage)
        case .center:
            return text(.windowCenter, appLanguage: appLanguage)
        case .maximize:
            return text(.windowMaximize, appLanguage: appLanguage)
        case .topLeft:
            return text(.windowTopLeft, appLanguage: appLanguage)
        case .topRight:
            return text(.windowTopRight, appLanguage: appLanguage)
        case .bottomLeft:
            return text(.windowBottomLeft, appLanguage: appLanguage)
        case .bottomRight:
            return text(.windowBottomRight, appLanguage: appLanguage)
        case .previousDisplay:
            return text(.windowPreviousDisplay, appLanguage: appLanguage)
        case .nextDisplay:
            return text(.windowNextDisplay, appLanguage: appLanguage)
        case .restore:
            return text(.windowRestore, appLanguage: appLanguage)
        }
    }

    static func selectedHiddenSummary(
        selected: Int,
        hidden: Int,
        appLanguage: SpillAppLanguage = .persisted()
    ) -> String {
        String(format: text(.selectedHiddenSummary, appLanguage: appLanguage), selected, hidden)
    }

    static func activeSavedSummary(
        active: Int,
        saved: Int,
        appLanguage: SpillAppLanguage = .persisted()
    ) -> String {
        String(format: text(.activeSavedSummary, appLanguage: appLanguage), active, saved)
    }

    static func selectedSummary(_ selected: Int, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.selectedSummary, appLanguage: appLanguage), selected)
    }

    private enum ResolvedLanguage {
        case english
        case korean
        case japanese
    }

    private static func resolvedLanguage(
        appLanguage: SpillAppLanguage,
        preferredLanguages: [String]
    ) -> ResolvedLanguage {
        if let languageCode = appLanguage.languageCode,
           let language = matching(languageCode)
        {
            return language
        }

        for languageID in preferredLanguages {
            if let language = matching(languageID) {
                return language
            }
        }
        return .english
    }

    private static func matching(_ languageID: String) -> ResolvedLanguage? {
        let normalized = languageID.lowercased()
        if normalized.hasPrefix("ko") { return .korean }
        if normalized.hasPrefix("ja") { return .japanese }
        if normalized.hasPrefix("en") { return .english }
        return nil
    }

    private static let table: [ResolvedLanguage: [AppTextKey: String]] = [
        .english: [
            .showSpillPanel: "Show Spill Panel",
            .hideSpillPanel: "Hide Spill Panel",
            .openLocalTokenDashboard: "Open Local Token Dashboard",
            .refreshMenuBarItems: "Refresh Menu Bar Items",
            .checkForUpdates: "Check for Updates...",
            .preferences: "Preferences...",
            .quitSpill: "Quit Spill",
            .shortcut: "Shortcut",
            .tokenMeteringLocalDashboard: "Token Metering: Local app dashboard",
            .menuBarItemCount: "%d menu bar item(s)",
            .triggerLoad: "Trigger load",
            .caffeineChipStart: "Caffeine chip: click to start",
            .caffeineChipStop: "click to stop",
            .caffeineOnUntilStopped: "on until stopped",
            .caffeineOnUntilStoppedDisplayMaySleep: "on until stopped, display may sleep",
            .caffeineRemaining: "%@ remaining",
            .caffeineRemainingDisplayMaySleep: "%@ remaining, display may sleep",
            .accessibilityRequired: "Accessibility required",
            .scanning: "Scanning",
            .noActionsReady: "No actions ready",
            .onboardingPreviewTitle: "Onboarding preview",
            .onboardingPreviewDetail: "Preview the first-run dashboard without changing local actions or usage data.",
            .ready: "Ready",
            .permissionNeeded: "Permission needed",
            .refreshingActions: "Refreshing actions",
            .pinned: "%d pinned",
            .actionsReady: "%d actions ready",
            .ax: "AX",
            .ok: "OK",
            .need: "Need",
            .scan: "Scan",
            .on: "On",
            .idle: "Idle",
            .items: "Items",
            .time: "Time",
            .off: "Off",
            .chooseCaffeineDuration: "Choose Caffeine Duration",
            .stopCaffeine: "Stop Caffeine",
            .startDuration: "Start %@",
            .power: "Power",
            .caffeine: "Caffeine",
            .caffeineOff: "Caffeine Off",
            .caffeineUntilStopped: "Caffeine - on until stopped",
            .caffeineUntilStoppedDisplayMaySleep: "Caffeine - on until stopped - display may sleep",
            .caffeineRemainingHelp: "Caffeine - %@ remaining",
            .caffeineRemainingDisplayMaySleepHelp: "Caffeine - %@ remaining - display may sleep",
            .couldNotStartCaffeine: "Could not start Caffeine.",
            .couldNotKeepDisplayAwake: "Could not keep the display awake.",
            .statusDetails: "Status Details",
            .refreshForceHelp: "Refresh official service status.",
            .checkingOfficialSources: "Checking official sources",
            .fetchedWhenOpen: "Fetched when this opens",
            .servicesFromOfficialSources: "%d services from official sources",
            .openDashboardToFetchStatus: "Open dashboard to fetch official status",
            .notFetched: "Not fetched",
            .officialStatusFetchedOnOpen: "Official status is fetched only when this dashboard opens.",
            .lastChecked: "Last checked %@ (%@).",
            .justNow: "just now",
            .minutesAgo: "%dm ago",
            .hoursAgo: "%dh ago",
            .operational: "Operational",
            .degraded: "Degraded",
            .outage: "Outage",
            .maintenance: "Maintenance",
            .unknown: "Unknown",
            .serverOK: "Server OK",
            .maint: "Maint",
            .checking: "Checking",
            .serverStatus: "Server Status",
            .server: "Server",
            .serverStatusPendingHelp: "Server status will appear after the next official status check.",
            .fetchOfficialServiceStatus: "Click to fetch official service status details.",
            .serverStatusNoIssues: "Server status %@",
            .serverStatusWithIssues: "Server status %@ with %d issue(s)",
            .clickForPerServiceDetails: "Click for per-service details.",
            .tokenMetering: "Token Metering",
            .local: "Local",
            .tokens: "tokens",
            .details: "Details",
            .openLocalTokenMeteringDetails: "Open local token metering details",
            .tokenMeteringAccessibility: "Token Metering, %@ local tokens",
            .tokenMeteringSetupTitle: "Set up Token Metering",
            .tokenMeteringSetupDetail: "Open Settings > Token Metering and follow the setup steps. This preview keeps local data intact.",
            .tokenMeteringSettings: "Token Metering Settings",
            .menuBarTokenDisplayModeDaily: "Daily Only",
            .menuBarTokenDisplayModeTotal: "Total Only",
            .menuBarTokenDisplayModeDailyAndTotal: "Daily & Total",
            .menuBarTokenDisplayModeCycle: "Auto-Cycle",
            .openSetupPrompt: "Open to copy global setup prompt",
            .noTaskSplit: "No task split",
            .noSourceSplit: "No source split",
            .eventsSummary: "%d events / %@ / %@",
            .aiProcessSummary: "%d of %d active",
            .windows: "WINDOWS",
            .menuBar: "MENU BAR",
            .noFocusedWindow: "No Focused Window",
            .positions: "POSITIONS",
            .utilities: "UTILITIES",
            .showInMenuBar: "Show in menu bar",
            .noItemsDetected: "No items detected.",
            .selectedHiddenSummary: "%d selected, %d hidden",
            .activeSavedSummary: "%d active, %d saved",
            .selectedSummary: "%d selected",
            .clear: "Clear",
            .usage: "Usage",
            .available: "Available",
            .user: "User",
            .system: "System",
            .nice: "Nice",
            .idleLabel: "Idle",
            .cores: "Cores",
            .peakCore: "Peak Core",
            .sample: "Sample",
            .state: "State",
            .used: "Used",
            .free: "Free",
            .active: "Active",
            .inactive: "Inactive",
            .wired: "Wired",
            .compressed: "Compressed",
            .total: "Total",
            .budget: "Budget",
            .unified: "Unified",
            .lowPower: "Low Power",
            .headless: "Headless",
            .removable: "Removable",
            .receive: "Receive",
            .upload: "Upload",
            .interfaces: "Interfaces",
            .receivedTotal: "Received Total",
            .uploadedTotal: "Uploaded Total",
            .status: "Status",
            .detail: "Detail",
            .next: "Next",
            .model: "Model",
            .version: "Version",
            .source: "Source",
            .yes: "Yes",
            .no: "No",
            .normal: "Normal",
            .warning: "Warning",
            .unavailable: "Unavailable",
            .cpuActiveIdle: "%@ active / %@ idle",
            .waitingForSample: "Waiting for sample",
            .availableOfTotal: "%@ available of %@",
            .externalPower: "External Power",
            .charging: "Charging",
            .onPower: "On Power",
            .onBattery: "On Battery",
            .updateCheckingTitle: "Checking Updates",
            .updateUpToDateTitle: "Up to Date",
            .updateAvailableTitle: "Update %@",
            .updateRequiresMacOSTitle: "Update Requires macOS",
            .updateTitle: "Update",
            .updateNow: "Update now",
            .copyInstallCommand: "Copy install command",
            .copied: "Copied",
            .settings: "Settings",
            .close: "Close",
            .lookingForLatestRelease: "Looking for the latest release",
            .spillVersionCurrent: "Spill %@ is current",
            .inAppUpdateReady: "In-app update ready",
            .signedInstallerPackage: "Signed installer package",
            .manualInstaller: "Manual installer",
            .versionNeedsMacOS: "Version %@ needs macOS %@",
            .updateHTTPFailedFormat: "Update manifest request failed with HTTP %d.",
            .invalidLatestVersionFormat: "Update manifest has an invalid latest version: %@.",
            .invalidMacOSVersionFormat: "Update manifest has an invalid macOS version: %@.",
            .updateDecodingFailedFormat: "Update manifest could not be decoded: %@",
            .missingMacOSDownloadAsset: "Latest GitHub release does not include a Spill macOS download asset.",
            .triggerDrop: "Drop",
            .triggerDropSubtitle: "Uses the compact droplet symbol.",
            .serviceStatusAccessibility: "Service status %@",
            .noDetail: "No detail",
            .noNotchCandidates: "No Notch Candidates",
            .nearNotchEstimate: "near notch estimate",
            .notScannedYet: "Not scanned yet.",
            .accessibilityNotTrusted: "Accessibility is not trusted for this Spill build. Recheck after granting it, or remove and re-add this app in Privacy settings.",
            .refreshQueued: "Refresh queued while the current scan finishes.",
            .scanningMenuBarItems: "Scanning menu bar items...",
            .refreshingMenuBarItems: "Refreshing menu bar items...",
            .selectedItemUnavailable: "The selected menu bar item is no longer available.",
            .performedPrimaryAction: "Performed primary action for the selected menu bar item.",
            .pressFailedFormat: "Could not press the selected menu bar item. AX returned %d.",
            .cachedResultUnchanged: " Cached result unchanged.",
            .noMenuBarItemsFoundFormat: "No menu bar items found. Scanned %d apps, %d menu bar roots (%d extras, %d fallback), %d candidate elements.%@",
            .detectedNoNotchFormat: "Detected %d menu bar item(s). Scanned %d menu bar roots; no notch overlap candidate found.%@",
            .detectedNearNotchFormat: "Detected %d menu bar item(s), %d near the notch estimate.%@",
            .pin: "Pin",
            .unpin: "Unpin",
            .pinnedFormat: "Pinned %@",
            .unpinnedFormat: "Unpinned %@",
            .pinInSpill: "Pin in Spill",
            .unpinFromSpill: "Unpin from Spill",
            .showInSpill: "Show in Spill",
            .hideInSpill: "Hide in Spill",
            .openedFormat: "Opened %@",
            .unavailableFormat: "%@ unavailable",
            .permissionRequiredFormat: "%@ permission required",
            .unsupportedFormat: "%@ unsupported",
            .windowLeft: "Left",
            .windowRight: "Right",
            .windowTop: "Top",
            .windowBottom: "Bottom",
            .windowCenter: "Center",
            .windowMaximize: "Max",
            .windowTopLeft: "Top L",
            .windowTopRight: "Top R",
            .windowBottomLeft: "Bot L",
            .windowBottomRight: "Bot R",
            .windowPreviousDisplay: "Disp L",
            .windowNextDisplay: "Disp R",
            .windowRestore: "Restore"
        ],
        .korean: [
            .showSpillPanel: "Spill 패널 보기",
            .hideSpillPanel: "Spill 패널 숨기기",
            .openLocalTokenDashboard: "로컬 토큰 대시보드 열기",
            .refreshMenuBarItems: "메뉴 막대 항목 새로고침",
            .checkForUpdates: "업데이트 확인...",
            .preferences: "설정...",
            .quitSpill: "Spill 종료",
            .shortcut: "단축키",
            .tokenMeteringLocalDashboard: "토큰 미터링: 로컬 앱 대시보드",
            .menuBarItemCount: "메뉴 막대 항목 %d개",
            .triggerLoad: "트리거 부하",
            .caffeineChipStart: "카페인 칩: 클릭해서 시작",
            .caffeineChipStop: "클릭해서 중지",
            .caffeineOnUntilStopped: "중지할 때까지 켬",
            .caffeineOnUntilStoppedDisplayMaySleep: "중지할 때까지 켬, 디스플레이는 잠들 수 있음",
            .caffeineRemaining: "%@ 남음",
            .caffeineRemainingDisplayMaySleep: "%@ 남음, 디스플레이는 잠들 수 있음",
            .accessibilityRequired: "손쉬운 사용 필요",
            .scanning: "스캔 중",
            .noActionsReady: "준비된 액션 없음",
            .onboardingPreviewTitle: "온보딩 미리보기",
            .onboardingPreviewDetail: "로컬 액션과 사용량 데이터는 유지한 채 첫 실행 대시보드를 확인합니다.",
            .ready: "준비됨",
            .permissionNeeded: "권한 필요",
            .refreshingActions: "액션 새로고침 중",
            .pinned: "고정 %d개",
            .actionsReady: "액션 %d개 준비됨",
            .ax: "AX",
            .ok: "정상",
            .need: "필요",
            .scan: "스캔",
            .on: "켬",
            .idle: "대기",
            .items: "항목",
            .time: "시간",
            .off: "끔",
            .chooseCaffeineDuration: "카페인 지속 시간 선택",
            .stopCaffeine: "카페인 중지",
            .startDuration: "%@ 시작",
            .power: "전원",
            .caffeine: "카페인",
            .caffeineOff: "카페인 꺼짐",
            .caffeineUntilStopped: "카페인 - 중지할 때까지 켬",
            .caffeineUntilStoppedDisplayMaySleep: "카페인 - 중지할 때까지 켬 - 디스플레이는 잠들 수 있음",
            .caffeineRemainingHelp: "카페인 - %@ 남음",
            .caffeineRemainingDisplayMaySleepHelp: "카페인 - %@ 남음 - 디스플레이는 잠들 수 있음",
            .couldNotStartCaffeine: "카페인을 시작할 수 없습니다.",
            .couldNotKeepDisplayAwake: "디스플레이를 깨어 있게 유지할 수 없습니다.",
            .statusDetails: "상태 상세",
            .refreshForceHelp: "공식 서비스 상태를 새로 확인합니다.",
            .checkingOfficialSources: "공식 소스 확인 중",
            .fetchedWhenOpen: "열 때 가져옴",
            .servicesFromOfficialSources: "공식 소스 서비스 %d개",
            .openDashboardToFetchStatus: "대시보드를 열어 공식 상태 가져오기",
            .notFetched: "가져오지 않음",
            .officialStatusFetchedOnOpen: "공식 상태는 이 대시보드를 열 때만 가져옵니다.",
            .lastChecked: "마지막 확인 %@ (%@).",
            .justNow: "방금",
            .minutesAgo: "%d분 전",
            .hoursAgo: "%d시간 전",
            .operational: "정상",
            .degraded: "저하",
            .outage: "장애",
            .maintenance: "점검",
            .unknown: "알 수 없음",
            .serverOK: "서버 정상",
            .maint: "점검",
            .checking: "확인 중",
            .serverStatus: "서버 상태",
            .server: "서버",
            .serverStatusPendingHelp: "다음 공식 상태 확인 후 서버 상태가 표시됩니다.",
            .fetchOfficialServiceStatus: "클릭해서 공식 서비스 상태 상세를 가져옵니다.",
            .serverStatusNoIssues: "서버 상태 %@",
            .serverStatusWithIssues: "서버 상태 %@, 이슈 %d개",
            .clickForPerServiceDetails: "서비스별 상세를 보려면 클릭하세요.",
            .tokenMetering: "토큰 미터링",
            .local: "로컬",
            .tokens: "토큰",
            .details: "상세",
            .openLocalTokenMeteringDetails: "로컬 토큰 미터링 상세 열기",
            .tokenMeteringAccessibility: "토큰 미터링, 로컬 토큰 %@개",
            .tokenMeteringSetupTitle: "토큰 미터링 설정",
            .tokenMeteringSetupDetail: "설정 > 토큰 미터링에서 안내를 따라 연결하세요. 이 미리보기는 로컬 데이터를 유지합니다.",
            .tokenMeteringSettings: "토큰 미터링 설정",
            .menuBarTokenDisplayModeDaily: "일간만 표시",
            .menuBarTokenDisplayModeTotal: "토탈만 표시",
            .menuBarTokenDisplayModeDailyAndTotal: "일간/토탈 모두 표시",
            .menuBarTokenDisplayModeCycle: "자동 전환",
            .openSetupPrompt: "열어서 전역 설정 프롬프트 복사",
            .noTaskSplit: "작업 분류 없음",
            .noSourceSplit: "소스 분류 없음",
            .eventsSummary: "이벤트 %d개 / %@ / %@",
            .aiProcessSummary: "%d/%d 활성",
            .windows: "윈도우",
            .menuBar: "메뉴 막대",
            .noFocusedWindow: "포커스된 윈도우 없음",
            .positions: "위치",
            .utilities: "유틸리티",
            .showInMenuBar: "메뉴 막대에 표시",
            .noItemsDetected: "감지된 항목 없음",
            .selectedHiddenSummary: "선택 %d개, 숨김 %d개",
            .activeSavedSummary: "활성 %d개, 저장됨 %d개",
            .selectedSummary: "선택 %d개",
            .clear: "지우기",
            .usage: "사용량",
            .available: "사용 가능",
            .user: "사용자",
            .system: "시스템",
            .nice: "Nice",
            .idleLabel: "유휴",
            .cores: "코어",
            .peakCore: "피크 코어",
            .sample: "샘플",
            .state: "상태",
            .used: "사용됨",
            .free: "여유",
            .active: "활성",
            .inactive: "비활성",
            .wired: "Wired",
            .compressed: "압축됨",
            .total: "합계",
            .budget: "예산",
            .unified: "통합",
            .lowPower: "저전력",
            .headless: "헤드리스",
            .removable: "분리 가능",
            .receive: "수신",
            .upload: "업로드",
            .interfaces: "인터페이스",
            .receivedTotal: "총 수신",
            .uploadedTotal: "총 업로드",
            .status: "상태",
            .detail: "상세",
            .next: "다음",
            .model: "모델",
            .version: "버전",
            .source: "소스",
            .yes: "예",
            .no: "아니오",
            .normal: "정상",
            .warning: "경고",
            .unavailable: "사용 불가",
            .cpuActiveIdle: "%@ 활성 / %@ 유휴",
            .waitingForSample: "샘플 대기 중",
            .availableOfTotal: "%@ 사용 가능 / 전체 %@",
            .externalPower: "외부 전원",
            .charging: "충전 중",
            .onPower: "전원 연결",
            .onBattery: "배터리 사용",
            .updateCheckingTitle: "업데이트 확인 중",
            .updateUpToDateTitle: "최신 상태",
            .updateAvailableTitle: "%@ 업데이트",
            .updateRequiresMacOSTitle: "macOS 업데이트 필요",
            .updateTitle: "업데이트",
            .updateNow: "지금 업데이트",
            .copyInstallCommand: "설치 명령 복사",
            .copied: "복사됨",
            .settings: "설정",
            .close: "닫기",
            .lookingForLatestRelease: "최신 릴리스 확인 중",
            .spillVersionCurrent: "Spill %@ 최신 상태",
            .inAppUpdateReady: "앱 내 업데이트 준비됨",
            .signedInstallerPackage: "서명된 설치 패키지",
            .manualInstaller: "수동 설치 프로그램",
            .versionNeedsMacOS: "버전 %@은 macOS %@ 필요",
            .updateHTTPFailedFormat: "업데이트 매니페스트 요청이 HTTP %d로 실패했습니다.",
            .invalidLatestVersionFormat: "업데이트 매니페스트의 최신 버전이 올바르지 않습니다: %@.",
            .invalidMacOSVersionFormat: "업데이트 매니페스트의 macOS 버전이 올바르지 않습니다: %@.",
            .updateDecodingFailedFormat: "업데이트 매니페스트를 해석할 수 없습니다: %@",
            .missingMacOSDownloadAsset: "최신 GitHub 릴리스에 Spill macOS 다운로드 에셋이 없습니다.",
            .triggerDrop: "물방울",
            .triggerDropSubtitle: "작은 물방울 심볼을 사용합니다.",
            .serviceStatusAccessibility: "서비스 상태 %@",
            .noDetail: "상세 없음",
            .noNotchCandidates: "노치 후보 없음",
            .nearNotchEstimate: "노치 근처 추정",
            .notScannedYet: "아직 스캔하지 않음",
            .accessibilityNotTrusted: "이 Spill 빌드에 손쉬운 사용 권한이 없습니다. 권한을 부여한 뒤 다시 확인하거나 개인정보 보호 설정에서 이 앱을 제거한 뒤 다시 추가하세요.",
            .refreshQueued: "현재 스캔이 끝나면 새로고침합니다.",
            .scanningMenuBarItems: "메뉴 막대 항목 스캔 중...",
            .refreshingMenuBarItems: "메뉴 막대 항목 새로고침 중...",
            .selectedItemUnavailable: "선택한 메뉴 막대 항목을 더 이상 사용할 수 없습니다.",
            .performedPrimaryAction: "선택한 메뉴 막대 항목의 기본 액션을 실행했습니다.",
            .pressFailedFormat: "선택한 메뉴 막대 항목을 누를 수 없습니다. AX 결과: %d.",
            .cachedResultUnchanged: " 캐시 결과가 바뀌지 않았습니다.",
            .noMenuBarItemsFoundFormat: "메뉴 막대 항목을 찾지 못했습니다. 앱 %d개, 메뉴 막대 루트 %d개(추가 %d개, 대체 %d개), 후보 요소 %d개를 스캔했습니다.%@",
            .detectedNoNotchFormat: "메뉴 막대 항목 %d개를 감지했습니다. 메뉴 막대 루트 %d개를 스캔했으며 노치 겹침 후보는 없습니다.%@",
            .detectedNearNotchFormat: "메뉴 막대 항목 %d개를 감지했고, 노치 근처 추정 항목은 %d개입니다.%@",
            .pin: "고정",
            .unpin: "고정 해제",
            .pinnedFormat: "%@ 고정됨",
            .unpinnedFormat: "%@ 고정 해제됨",
            .pinInSpill: "Spill에 고정",
            .unpinFromSpill: "Spill에서 고정 해제",
            .showInSpill: "Spill에 표시",
            .hideInSpill: "Spill에서 숨김",
            .openedFormat: "%@ 열림",
            .unavailableFormat: "%@ 사용 불가",
            .permissionRequiredFormat: "%@ 권한 필요",
            .unsupportedFormat: "%@ 지원 안 함",
            .windowLeft: "왼쪽",
            .windowRight: "오른쪽",
            .windowTop: "위",
            .windowBottom: "아래",
            .windowCenter: "가운데",
            .windowMaximize: "최대화",
            .windowTopLeft: "좌상",
            .windowTopRight: "우상",
            .windowBottomLeft: "좌하",
            .windowBottomRight: "우하",
            .windowPreviousDisplay: "이전 화면",
            .windowNextDisplay: "다음 화면",
            .windowRestore: "복원"
        ],
        .japanese: [
            .showSpillPanel: "Spill パネルを表示",
            .hideSpillPanel: "Spill パネルを隠す",
            .openLocalTokenDashboard: "ローカルトークンダッシュボードを開く",
            .refreshMenuBarItems: "メニューバー項目を更新",
            .checkForUpdates: "アップデートを確認...",
            .preferences: "設定...",
            .quitSpill: "Spill を終了",
            .shortcut: "ショートカット",
            .tokenMeteringLocalDashboard: "トークン計測: ローカルアプリダッシュボード",
            .menuBarItemCount: "メニューバー項目 %d件",
            .triggerLoad: "トリガー負荷",
            .caffeineChipStart: "カフェインチップ: クリックして開始",
            .caffeineChipStop: "クリックして停止",
            .caffeineOnUntilStopped: "停止するまでオン",
            .caffeineOnUntilStoppedDisplayMaySleep: "停止するまでオン、ディスプレイはスリープ可能",
            .caffeineRemaining: "残り %@",
            .caffeineRemainingDisplayMaySleep: "残り %@、ディスプレイはスリープ可能",
            .accessibilityRequired: "アクセシビリティが必要",
            .scanning: "スキャン中",
            .noActionsReady: "準備済みアクションなし",
            .onboardingPreviewTitle: "オンボーディングプレビュー",
            .onboardingPreviewDetail: "ローカルのアクションと使用量データを変えずに初回ダッシュボードを確認します。",
            .ready: "準備完了",
            .permissionNeeded: "権限が必要",
            .refreshingActions: "アクションを更新中",
            .pinned: "固定 %d件",
            .actionsReady: "アクション %d件が準備完了",
            .ax: "AX",
            .ok: "OK",
            .need: "必要",
            .scan: "スキャン",
            .on: "オン",
            .idle: "待機",
            .items: "項目",
            .time: "時刻",
            .off: "オフ",
            .chooseCaffeineDuration: "カフェイン時間を選択",
            .stopCaffeine: "カフェインを停止",
            .startDuration: "%@ を開始",
            .power: "電源",
            .caffeine: "カフェイン",
            .caffeineOff: "カフェイン オフ",
            .caffeineUntilStopped: "カフェイン - 停止するまでオン",
            .caffeineUntilStoppedDisplayMaySleep: "カフェイン - 停止するまでオン - ディスプレイはスリープ可能",
            .caffeineRemainingHelp: "カフェイン - 残り %@",
            .caffeineRemainingDisplayMaySleepHelp: "カフェイン - 残り %@ - ディスプレイはスリープ可能",
            .couldNotStartCaffeine: "カフェインを開始できませんでした。",
            .couldNotKeepDisplayAwake: "ディスプレイを起動状態に保てませんでした。",
            .statusDetails: "状態詳細",
            .refreshForceHelp: "公式サービス状態を更新します。",
            .checkingOfficialSources: "公式ソースを確認中",
            .fetchedWhenOpen: "開いたときに取得",
            .servicesFromOfficialSources: "公式ソースのサービス %d件",
            .openDashboardToFetchStatus: "ダッシュボードを開いて公式状態を取得",
            .notFetched: "未取得",
            .officialStatusFetchedOnOpen: "公式状態はこのダッシュボードを開いたときだけ取得します。",
            .lastChecked: "最終確認 %@ (%@)。",
            .justNow: "たった今",
            .minutesAgo: "%d分前",
            .hoursAgo: "%d時間前",
            .operational: "正常",
            .degraded: "低下",
            .outage: "障害",
            .maintenance: "メンテナンス",
            .unknown: "不明",
            .serverOK: "サーバー正常",
            .maint: "メンテ",
            .checking: "確認中",
            .serverStatus: "サーバー状態",
            .server: "サーバー",
            .serverStatusPendingHelp: "次の公式状態確認後にサーバー状態が表示されます。",
            .fetchOfficialServiceStatus: "クリックして公式サービス状態の詳細を取得します。",
            .serverStatusNoIssues: "サーバー状態 %@",
            .serverStatusWithIssues: "サーバー状態 %@、問題 %d件",
            .clickForPerServiceDetails: "サービス別詳細を見るにはクリックしてください。",
            .tokenMetering: "トークン計測",
            .local: "ローカル",
            .tokens: "トークン",
            .details: "詳細",
            .openLocalTokenMeteringDetails: "ローカルトークン計測の詳細を開く",
            .tokenMeteringAccessibility: "トークン計測、ローカルトークン %@",
            .tokenMeteringSetupTitle: "トークン計測を設定",
            .tokenMeteringSetupDetail: "設定 > トークン計測を開き、手順に従って接続します。このプレビューはローカルデータを保持します。",
            .tokenMeteringSettings: "トークン計測設定",
            .menuBarTokenDisplayModeDaily: "日間のみ表示",
            .menuBarTokenDisplayModeTotal: "合計のみ表示",
            .menuBarTokenDisplayModeDailyAndTotal: "日間と合計両方表示",
            .menuBarTokenDisplayModeCycle: "自動切り替え",
            .openSetupPrompt: "開いてグローバル設定プロンプトをコピー",
            .noTaskSplit: "タスク分類なし",
            .noSourceSplit: "ソース分類なし",
            .eventsSummary: "イベント %d件 / %@ / %@",
            .aiProcessSummary: "%d/%d アクティブ",
            .windows: "ウィンドウ",
            .menuBar: "メニューバー",
            .noFocusedWindow: "フォーカス中のウィンドウなし",
            .positions: "位置",
            .utilities: "ユーティリティ",
            .showInMenuBar: "メニューバーに表示",
            .noItemsDetected: "検出項目はありません。",
            .selectedHiddenSummary: "選択 %d件、非表示 %d件",
            .activeSavedSummary: "有効 %d件、保存済み %d件",
            .selectedSummary: "選択 %d件",
            .clear: "消去",
            .usage: "使用量",
            .available: "利用可能",
            .user: "ユーザー",
            .system: "システム",
            .nice: "Nice",
            .idleLabel: "アイドル",
            .cores: "コア",
            .peakCore: "ピークコア",
            .sample: "サンプル",
            .state: "状態",
            .used: "使用中",
            .free: "空き",
            .active: "アクティブ",
            .inactive: "非アクティブ",
            .wired: "Wired",
            .compressed: "圧縮済み",
            .total: "合計",
            .budget: "予算",
            .unified: "統合",
            .lowPower: "低電力",
            .headless: "ヘッドレス",
            .removable: "取り外し可能",
            .receive: "受信",
            .upload: "アップロード",
            .interfaces: "インターフェイス",
            .receivedTotal: "総受信",
            .uploadedTotal: "総アップロード",
            .status: "状態",
            .detail: "詳細",
            .next: "次",
            .model: "モデル",
            .version: "バージョン",
            .source: "ソース",
            .yes: "はい",
            .no: "いいえ",
            .normal: "通常",
            .warning: "警告",
            .unavailable: "利用不可",
            .cpuActiveIdle: "%@ アクティブ / %@ アイドル",
            .waitingForSample: "サンプル待機中",
            .availableOfTotal: "%@ 利用可能 / 合計 %@",
            .externalPower: "外部電源",
            .charging: "充電中",
            .onPower: "電源接続中",
            .onBattery: "バッテリー使用中",
            .updateCheckingTitle: "アップデート確認中",
            .updateUpToDateTitle: "最新",
            .updateAvailableTitle: "%@ を更新",
            .updateRequiresMacOSTitle: "macOS アップデートが必要",
            .updateTitle: "アップデート",
            .updateNow: "今すぐ更新",
            .copyInstallCommand: "インストールコマンドをコピー",
            .copied: "コピー済み",
            .settings: "設定",
            .close: "閉じる",
            .lookingForLatestRelease: "最新リリースを確認中",
            .spillVersionCurrent: "Spill %@ は最新です",
            .inAppUpdateReady: "アプリ内アップデート準備完了",
            .signedInstallerPackage: "署名済みインストーラーパッケージ",
            .manualInstaller: "手動インストーラー",
            .versionNeedsMacOS: "バージョン %@ には macOS %@ が必要",
            .updateHTTPFailedFormat: "アップデートマニフェストのリクエストが HTTP %d で失敗しました。",
            .invalidLatestVersionFormat: "アップデートマニフェストの最新バージョンが無効です: %@。",
            .invalidMacOSVersionFormat: "アップデートマニフェストの macOS バージョンが無効です: %@。",
            .updateDecodingFailedFormat: "アップデートマニフェストをデコードできませんでした: %@",
            .missingMacOSDownloadAsset: "最新の GitHub リリースに Spill macOS ダウンロードアセットがありません。",
            .triggerDrop: "ドロップ",
            .triggerDropSubtitle: "コンパクトなしずくシンボルを使用します。",
            .serviceStatusAccessibility: "サービス状態 %@",
            .noDetail: "詳細なし",
            .noNotchCandidates: "ノッチ候補なし",
            .nearNotchEstimate: "ノッチ付近の推定",
            .notScannedYet: "まだスキャンしていません。",
            .accessibilityNotTrusted: "この Spill ビルドはアクセシビリティ権限を信頼されていません。権限を付与した後に再確認するか、プライバシー設定でこのアプリを削除して再追加してください。",
            .refreshQueued: "現在のスキャンが完了したら更新します。",
            .scanningMenuBarItems: "メニューバー項目をスキャン中...",
            .refreshingMenuBarItems: "メニューバー項目を更新中...",
            .selectedItemUnavailable: "選択したメニューバー項目は利用できなくなりました。",
            .performedPrimaryAction: "選択したメニューバー項目の主要アクションを実行しました。",
            .pressFailedFormat: "選択したメニューバー項目を押せませんでした。AX の戻り値: %d。",
            .cachedResultUnchanged: " キャッシュ結果は変わりません。",
            .noMenuBarItemsFoundFormat: "メニューバー項目が見つかりません。アプリ %d件、メニューバールート %d件（追加 %d件、代替 %d件）、候補要素 %d件をスキャンしました。%@",
            .detectedNoNotchFormat: "メニューバー項目 %d件を検出しました。メニューバールート %d件をスキャンし、ノッチ重なり候補はありません。%@",
            .detectedNearNotchFormat: "メニューバー項目 %d件を検出し、ノッチ付近の推定項目は %d件です。%@",
            .pin: "固定",
            .unpin: "固定解除",
            .pinnedFormat: "%@ を固定しました",
            .unpinnedFormat: "%@ の固定を解除しました",
            .pinInSpill: "Spill に固定",
            .unpinFromSpill: "Spill から固定解除",
            .showInSpill: "Spill に表示",
            .hideInSpill: "Spill で非表示",
            .openedFormat: "%@ を開きました",
            .unavailableFormat: "%@ は利用不可",
            .permissionRequiredFormat: "%@ 権限が必要",
            .unsupportedFormat: "%@ は未対応",
            .windowLeft: "左",
            .windowRight: "右",
            .windowTop: "上",
            .windowBottom: "下",
            .windowCenter: "中央",
            .windowMaximize: "最大化",
            .windowTopLeft: "左上",
            .windowTopRight: "右上",
            .windowBottomLeft: "左下",
            .windowBottomRight: "右下",
            .windowPreviousDisplay: "前の画面",
            .windowNextDisplay: "次の画面",
            .windowRestore: "復元"
        ]
    ]
}
