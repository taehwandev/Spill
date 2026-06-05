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
            return .teal
        case .empty:
            return .secondary
        case .ready:
            return .mint
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .permissionRequired:
            return AppL10n.text(.accessibilityRequired)
        case .scanning:
            return AppL10n.text(.scanning)
        case .empty:
            return AppL10n.text(.noActionsReady)
        case .ready:
            return AppL10n.text(.ready)
        }
    }

    func subtitle(count: Int, pinnedCount: Int) -> String {
        switch self {
        case .permissionRequired:
            return AppL10n.text(.permissionNeeded)
        case .scanning:
            return AppL10n.text(.refreshingActions)
        case .empty:
            return pinnedCount > 0 ? AppL10n.pinnedCount(pinnedCount) : AppL10n.text(.noActionsReady)
        case .ready:
            if pinnedCount > 0 {
                return "\(AppL10n.pinnedCount(pinnedCount)), \(AppL10n.actionsReady(count))"
            }

            return AppL10n.actionsReady(count)
        }
    }
}
