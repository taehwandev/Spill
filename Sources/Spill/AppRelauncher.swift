import AppKit
import Foundation

enum AppRelauncher {
    @MainActor
    static func relaunch() {
        let bundleURL = Bundle.main.bundleURL
        guard bundleURL.pathExtension == "app" else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = true

        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { _, error in
            if let error {
                NSLog("Spill relaunch failed: \(error.localizedDescription)")
                return
            }

            Task { @MainActor in
                NSApp.terminate(nil)
            }
        }
    }
}
