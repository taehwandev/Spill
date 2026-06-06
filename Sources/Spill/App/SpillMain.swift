import AppKit

@main
enum SpillMain {
    @MainActor private static var appDelegate: (NSObject & NSApplicationDelegate)?

    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate: NSObject & NSApplicationDelegate

        if TokenMeteringDashboardProcess.isDashboardProcess {
            delegate = TokenMeteringDashboardAppDelegate()
            application.setActivationPolicy(.regular)
        } else {
            delegate = AppDelegate()
            application.setActivationPolicy(.accessory)
        }

        appDelegate = delegate
        application.delegate = delegate
        application.run()
    }
}
