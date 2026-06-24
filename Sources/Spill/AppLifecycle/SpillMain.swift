import AppKit

@main
enum SpillMain {
    @MainActor private static var appDelegate: (NSObject & NSApplicationDelegate)?

    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate: NSObject & NSApplicationDelegate

        if TokenMeteringDashboardProcess.isDashboardProcess {
            SpillCrashReporter.start(processRole: "token_dashboard")
            TokenMeteringDashboardLifecycle.shared.observeDashboardMainApplicationTermination(
                mainBundleIdentifier: TokenMeteringDashboardProcess.mainBundleIdentifierForDashboardHelper()
            )
            delegate = TokenMeteringDashboardAppDelegate()
            application.setActivationPolicy(.regular)
        } else {
            SpillCrashReporter.start(processRole: "main_app")
            TokenMeteringDashboardLifecycle.shared.observeMainApplicationTermination(
                mainBundleIdentifier: Bundle.main.bundleIdentifier
            )
            delegate = AppDelegate()
            application.setActivationPolicy(.accessory)
        }

        appDelegate = delegate
        application.delegate = delegate
        application.run()
    }
}
