import Foundation

enum TokenMeteringDashboardProcess {
    static let helperBundleName = "Spill Token Dashboard.app"
    static let helperBundleIdentifierSuffix = ".TokenDashboard"
    static let standaloneEnvironmentKey = "SPILL_TOKEN_DASHBOARD_STANDALONE"
    static let standaloneArgument = "--token-dashboard"
    static let openPreferencesNotification = Notification.Name("app.spill.open-preferences")
    static let preferencesTabUserInfoKey = "tab"
    static let tokenMeteringPreferencesTab = "tokens"

    static var isDashboardProcess: Bool {
        let processInfo = ProcessInfo.processInfo
        return processInfo.environment[standaloneEnvironmentKey] == "1"
            || processInfo.arguments.contains(standaloneArgument)
            || isDashboardBundleIdentifier(Bundle.main.bundleIdentifier)
    }

    static func isDashboardBundleIdentifier(_ identifier: String?) -> Bool {
        identifier?.hasSuffix(helperBundleIdentifierSuffix) == true
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

    static func postOpenPreferencesRequest(tab: String = tokenMeteringPreferencesTab) {
        DistributedNotificationCenter.default().postNotificationName(
            openPreferencesNotification,
            object: nil,
            userInfo: [preferencesTabUserInfoKey: tab],
            deliverImmediately: true
        )
    }
}
