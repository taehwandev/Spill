import AppKit

@MainActor
final class TokenMeteringDashboardLauncher {
    private let workspace: NSWorkspace
    private let helperURLProvider: () -> URL?

    init(
        workspace: NSWorkspace = .shared,
        helperURLProvider: @escaping () -> URL? = {
            TokenMeteringDashboardProcess.helperAppURL()
        }
    ) {
        self.workspace = workspace
        self.helperURLProvider = helperURLProvider
    }

    func open(fallback: @escaping @MainActor () -> Void) {
        guard let helperURL = helperURLProvider() else {
            fallback()
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
        configuration.environment = environment

        workspace.openApplication(at: helperURL, configuration: configuration) { _, error in
            guard error != nil else {
                return
            }

            DispatchQueue.main.async {
                fallback()
            }
        }
    }
}
