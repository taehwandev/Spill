import SwiftUI

extension SpillStatusState {
    var panelTint: Color {
        switch self {
        case .normal:
            return .green
        case .active:
            return .accentColor
        case .warning:
            return .orange
        case .unavailable:
            return .secondary
        case .refreshing:
            return .accentColor
        }
    }
}
