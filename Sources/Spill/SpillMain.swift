import AppKit

@main
enum SpillMain {
    @MainActor private static var appDelegate: AppDelegate?

    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()

        appDelegate = delegate
        application.delegate = delegate
        application.setActivationPolicy(.regular)
        application.run()
    }
}
