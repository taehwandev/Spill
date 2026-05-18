import SwiftUI

extension SpillStatusState {
    var panelTint: Color {
        switch self {
        case .normal:
            return .mint
        case .active:
            return .teal
        case .warning:
            return .orange
        case .unavailable:
            return .secondary
        case .refreshing:
            return .teal
        }
    }
}
