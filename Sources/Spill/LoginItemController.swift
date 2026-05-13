import Foundation
import ServiceManagement

enum LoginItemController {
    static var isAvailable: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    static var isEnabled: Bool {
        guard isAvailable else {
            return false
        }

        return SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        guard isAvailable else {
            throw LoginItemError.requiresAppBundle
        }

        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

enum LoginItemError: LocalizedError {
    case requiresAppBundle

    var errorDescription: String? {
        switch self {
        case .requiresAppBundle:
            "Launch at Login requires running Spill as an app bundle."
        }
    }
}
