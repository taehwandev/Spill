import Foundation

extension SpillSettings {
    /// The standalone dashboard process reads and writes the main app's defaults suite, so both
    /// processes share one set of preferences.
    static func sharedDefaults(
        bundleIdentifier: String? = Bundle.main.bundleIdentifier,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> UserDefaults {
        guard let suiteName = sharedDefaultsSuiteName(
            bundleIdentifier: bundleIdentifier,
            arguments: arguments,
            environment: environment
        ) else {
            return .standard
        }

        return UserDefaults(suiteName: suiteName) ?? .standard
    }

    static func sharedDefaultsSuiteName(
        bundleIdentifier: String?,
        arguments: [String],
        environment: [String: String]
    ) -> String? {
        let isDashboardProcess = environment[TokenMeteringDashboardProcess.standaloneEnvironmentKey] == "1"
            || arguments.contains(TokenMeteringDashboardProcess.standaloneArgument)
            || TokenMeteringDashboardProcess.isDashboardBundleIdentifier(bundleIdentifier)
        guard isDashboardProcess else {
            return nil
        }

        if let mainBundleIdentifier = environment[TokenMeteringDashboardProcess.mainBundleIdentifierEnvironmentKey],
           !mainBundleIdentifier.isEmpty
        {
            return mainBundleIdentifier
        }

        guard let bundleIdentifier,
              TokenMeteringDashboardProcess.isDashboardBundleIdentifier(bundleIdentifier)
        else {
            return nil
        }

        return String(bundleIdentifier.dropLast(TokenMeteringDashboardProcess.helperBundleIdentifierSuffix.count))
    }
}
