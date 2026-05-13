import Foundation

enum PermissionDiagnostics {
    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "No bundle identifier"
    }

    static var bundlePath: String {
        Bundle.main.bundlePath
    }

    static var executablePath: String {
        Bundle.main.executablePath ?? "No executable path"
    }

    static var processIdentifier: String {
        String(ProcessInfo.processInfo.processIdentifier)
    }

    static var isAppBundle: String {
        Bundle.main.bundleURL.pathExtension == "app" ? "true" : "false"
    }
}
