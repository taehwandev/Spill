import SwiftUI

enum SpillPanelState: Equatable {
    case permissionRequired
    case scanning
    case empty
    case ready

    static func current(
        isAccessibilityTrusted: Bool,
        isScanning: Bool,
        isEmpty: Bool
    ) -> SpillPanelState {
        if !isAccessibilityTrusted {
            return .permissionRequired
        }

        if isScanning {
            return .scanning
        }

        if isEmpty {
            return .empty
        }

        return .ready
    }

    var logName: String {
        switch self {
        case .permissionRequired:
            return "permissionRequired"
        case .scanning:
            return "scanning"
        case .empty:
            return "empty"
        case .ready:
            return "ready"
        }
    }

    var symbolName: String {
        switch self {
        case .permissionRequired:
            return "lock.fill"
        case .scanning:
            return "arrow.triangle.2.circlepath"
        case .empty:
            return "tray"
        case .ready:
            return "drop.fill"
        }
    }

    var tint: Color {
        switch self {
        case .permissionRequired:
            return .orange
        case .scanning:
            return .accentColor
        case .empty:
            return .secondary
        case .ready:
            return .green
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .permissionRequired:
            return "Accessibility required"
        case .scanning:
            return "Scanning"
        case .empty:
            return "No actions ready"
        case .ready:
            return "Ready"
        }
    }

    func subtitle(count: Int, pinnedCount: Int) -> String {
        switch self {
        case .permissionRequired:
            return "Permission needed"
        case .scanning:
            return "Refreshing actions"
        case .empty:
            return pinnedCount > 0 ? "\(pinnedCount) pinned" : "No actions ready"
        case .ready:
            if pinnedCount > 0 {
                return "\(pinnedCount) pinned, \(count) ready"
            }

            return "\(count) action\(count == 1 ? "" : "s") ready"
        }
    }
}
