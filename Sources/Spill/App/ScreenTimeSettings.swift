import AppKit
import Foundation

enum ScreenTimeSettings {
    static func open() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Screen-Time-Settings.extension") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
