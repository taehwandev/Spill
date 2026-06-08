import AppKit

@MainActor
final class TokenMeteringDashboardLauncher {
    private let workspace: NSWorkspace
    private let helperURLProvider: () -> URL?
    private let runningApplicationsProvider: () -> [NSRunningApplication]

    init(
        workspace: NSWorkspace = .shared,
        helperURLProvider: @escaping () -> URL? = {
            TokenMeteringDashboardProcess.helperAppURL()
        },
        runningApplicationsProvider: @escaping () -> [NSRunningApplication] = {
            NSWorkspace.shared.runningApplications
        }
    ) {
        self.workspace = workspace
        self.helperURLProvider = helperURLProvider
        self.runningApplicationsProvider = runningApplicationsProvider
    }

    func open(
        fallback: @escaping @MainActor @Sendable () -> Void,
        completion: @escaping @MainActor @Sendable () -> Void = {}
    ) {
        guard let helperURL = helperURLProvider() else {
            fallback()
            completion()
            return
        }

        if activateRunningHelper(at: helperURL) {
            completion()
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.arguments = [TokenMeteringDashboardProcess.standaloneArgument]
        var environment = [
            TokenMeteringDashboardProcess.standaloneEnvironmentKey: "1"
        ]
        if let mainBundleIdentifier = Bundle.main.bundleIdentifier {
            environment[TokenMeteringDashboardProcess.mainBundleIdentifierEnvironmentKey] = mainBundleIdentifier
        }
        mergeSmokeTestEnvironment(into: &environment)
        configuration.environment = environment

        let completionHandler = TokenMeteringWorkspaceOpenCompletion.handleOpenResult(
            fallback: fallback,
            completion: completion
        )
        workspace.openApplication(at: helperURL, configuration: configuration, completionHandler: completionHandler)
    }

    private func activateRunningHelper(at helperURL: URL) -> Bool {
        let targetHelperURL = helperURL.standardizedFileURL.resolvingSymlinksInPath()
        guard let helperBundleIdentifier = helperBundleIdentifier(for: helperURL),
              let runningApplication = runningApplicationsProvider().first(where: {
                  guard $0.bundleIdentifier == helperBundleIdentifier,
                        let runningBundleURL = $0.bundleURL?.standardizedFileURL.resolvingSymlinksInPath()
                  else {
                      return false
                  }

                  return runningBundleURL == targetHelperURL
              })
        else {
            return false
        }

        runningApplication.activate(options: [.activateAllWindows])
        return true
    }

    private func helperBundleIdentifier(for helperURL: URL) -> String? {
        if let helperBundleIdentifier = Bundle(url: helperURL)?.bundleIdentifier {
            return helperBundleIdentifier
        }

        guard let mainBundleIdentifier = Bundle.main.bundleIdentifier else {
            return nil
        }
        return "\(mainBundleIdentifier)\(TokenMeteringDashboardProcess.helperBundleIdentifierSuffix)"
    }

    private func mergeSmokeTestEnvironment(into environment: inout [String: String]) {
        let processEnvironment = ProcessInfo.processInfo.environment
        guard processEnvironment["SPILL_SMOKE_TEST"] == "1" else {
            return
        }

        for key in [
            "SPILL_SMOKE_TEST",
            "SPILL_SMOKE_TEST_EXIT_AFTER",
            "SPILL_TOKEN_USAGE_EVENTS_FILE",
            "SPILL_TOKEN_USAGE_INBOX_DIR"
        ] {
            if let value = processEnvironment[key], !value.isEmpty {
                environment[key] = value
            }
        }
    }
}

enum TokenMeteringWorkspaceOpenCompletion {
    nonisolated static func handleOpenResult(
        fallback: @escaping @MainActor @Sendable () -> Void,
        completion: @escaping @MainActor @Sendable () -> Void
    ) -> @Sendable (NSRunningApplication?, Error?) -> Void {
        { runningApplication, error in
            Task { @MainActor in
                if error != nil, runningApplication == nil {
                    fallback()
                }
                completion()
            }
        }
    }

    nonisolated static func postOpenPreferencesRequest() -> @Sendable (NSRunningApplication?, Error?) -> Void {
        { _, _ in
            TokenMeteringDashboardProcess.postOpenPreferencesRequest()
        }
    }
}
