import AppKit
import ApplicationServices
import Foundation

enum AccessibilityPermission {
    static var isTrusted: Bool {
        let options = [promptOptionKey: false] as CFDictionary
        return AXIsProcessTrusted() || AXIsProcessTrustedWithOptions(options)
    }

    @discardableResult
    static func request() -> Bool {
        let options = [promptOptionKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private static let promptOptionKey = "AXTrustedCheckOptionPrompt"
}
