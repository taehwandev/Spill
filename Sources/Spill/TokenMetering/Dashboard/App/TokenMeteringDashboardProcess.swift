import Foundation

enum TokenMeteringDashboardProcess {
    static let helperBundleName = "Spill Token Dashboard.app"
    static let helperBundleIdentifierSuffix = ".TokenDashboard"
    static let standaloneEnvironmentKey = "SPILL_TOKEN_DASHBOARD_STANDALONE"
    static let mainBundleIdentifierEnvironmentKey = "SPILL_MAIN_BUNDLE_ID"
    static let standaloneArgument = "--token-dashboard"
    static let openPreferencesNotification = Notification.Name("app.spill.open-preferences")
    static let settingsDidChangeNotification = Notification.Name("app.spill.settings-did-change")
    static let collectionRequestNotification = Notification.Name("app.spill.token-usage.collection-request")
    static let cloudServiceStatusRefreshRequestNotification = Notification.Name(
        "app.spill.cloud-service-status.refresh-request"
    )
    static let cloudServiceStatusDidChangeNotification = Notification.Name(
        "app.spill.cloud-service-status.did-change"
    )
    static let preferencesTabUserInfoKey = "tab"
    static let settingsKeyUserInfoKey = "key"
    static let collectionReasonUserInfoKey = "reason"
    static let forceRefreshUserInfoKey = "force"
    static let tokenMeteringPreferencesTab = "tokens"
    static let developerOptionsPreferencesTab = "developer"
    static let appLanguageSettingsKey = "appLanguage"
    static let appearanceThemeSettingsKey = "appearanceTheme"
    static let tokenUsageDashboardOnboardingPreviewSettingsKey = "tokenUsageDashboardOnboardingPreviewEnabled"
    static let tokenUsageInputScopeSettingsKey = "tokenUsageInputScope"
    static let glanceEnabledSettingsKey = "glanceEnabled"

    static var isDashboardProcess: Bool {
        let processInfo = ProcessInfo.processInfo
        return processInfo.environment[standaloneEnvironmentKey] == "1"
            || processInfo.arguments.contains(standaloneArgument)
            || isDashboardBundleIdentifier(Bundle.main.bundleIdentifier)
    }

    static func isDashboardBundleIdentifier(_ identifier: String?) -> Bool {
        identifier?.hasSuffix(helperBundleIdentifierSuffix) == true
    }

    static func shouldRequestMainAppLaunch(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        hasRequestedLaunch: Bool
    ) -> Bool {
        let wasLaunchedByMainApp = environment[mainBundleIdentifierEnvironmentKey]?.isEmpty == false
        return !wasLaunchedByMainApp && !hasRequestedLaunch
    }

    static func mainBundleIdentifierForDashboardHelper(
        helperBundleIdentifier: String? = Bundle.main.bundleIdentifier,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String? {
        if let mainBundleIdentifier = environment[mainBundleIdentifierEnvironmentKey],
           !mainBundleIdentifier.isEmpty {
            return mainBundleIdentifier
        }

        guard let helperBundleIdentifier,
              isDashboardBundleIdentifier(helperBundleIdentifier)
        else {
            return nil
        }

        return String(helperBundleIdentifier.dropLast(helperBundleIdentifierSuffix.count))
    }

    static func helperAppURL(
        mainBundleURL: URL = Bundle.main.bundleURL,
        fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) -> URL? {
        let candidate = mainBundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Applications", isDirectory: true)
            .appendingPathComponent(helperBundleName, isDirectory: true)

        return fileExists(candidate.path) ? candidate : nil
    }

    static func mainAppURLForDashboardHelper(
        helperBundleURL: URL = Bundle.main.bundleURL,
        fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) -> URL? {
        guard helperBundleURL.lastPathComponent == helperBundleName else {
            return nil
        }

        let candidate = helperBundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return candidate.pathExtension == "app" && fileExists(candidate.path) ? candidate : nil
    }
}

extension TokenMeteringDashboardProcess {
    static func postOpenPreferencesRequest(tab: String = tokenMeteringPreferencesTab) {
        DistributedNotificationCenter.default().postNotificationName(
            openPreferencesNotification,
            object: nil,
            userInfo: [preferencesTabUserInfoKey: tab],
            deliverImmediately: true
        )
    }

    static func postTokenUsageCollectionRequest(reason: String) {
        DistributedNotificationCenter.default().postNotificationName(
            collectionRequestNotification,
            object: nil,
            userInfo: [collectionReasonUserInfoKey: reason],
            deliverImmediately: true
        )
    }

    static func postCloudServiceStatusRefreshRequest(force: Bool) {
        DistributedNotificationCenter.default().postNotificationName(
            cloudServiceStatusRefreshRequestNotification,
            object: nil,
            userInfo: [forceRefreshUserInfoKey: force],
            deliverImmediately: true
        )
    }

    static func postCloudServiceStatusDidChange() {
        DistributedNotificationCenter.default().postNotificationName(
            cloudServiceStatusDidChangeNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    static func postAppLanguageDidChange() {
        DistributedNotificationCenter.default().postNotificationName(
            settingsDidChangeNotification,
            object: nil,
            userInfo: [settingsKeyUserInfoKey: appLanguageSettingsKey],
            deliverImmediately: true
        )
    }

    static func postAppearanceThemeDidChange() {
        DistributedNotificationCenter.default().postNotificationName(
            settingsDidChangeNotification,
            object: nil,
            userInfo: [settingsKeyUserInfoKey: appearanceThemeSettingsKey],
            deliverImmediately: true
        )
    }

    static func postTokenUsageDashboardOnboardingPreviewDidChange() {
        DistributedNotificationCenter.default().postNotificationName(
            settingsDidChangeNotification,
            object: nil,
            userInfo: [settingsKeyUserInfoKey: tokenUsageDashboardOnboardingPreviewSettingsKey],
            deliverImmediately: true
        )
    }

    static func postTokenUsageInputScopeDidChange() {
        DistributedNotificationCenter.default().postNotificationName(
            settingsDidChangeNotification,
            object: nil,
            userInfo: [settingsKeyUserInfoKey: tokenUsageInputScopeSettingsKey],
            deliverImmediately: true
        )
    }

    static func postGlanceEnabledDidChange() {
        DistributedNotificationCenter.default().postNotificationName(
            settingsDidChangeNotification,
            object: nil,
            userInfo: [settingsKeyUserInfoKey: glanceEnabledSettingsKey],
            deliverImmediately: true
        )
    }
}
