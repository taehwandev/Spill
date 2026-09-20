import SwiftUI

struct SpillActionFeedback: Equatable {
    let result: SpillActionResult
    let title: String

    var message: String {
        switch result {
        case .success:
            return AppL10n.opened(title)
        case .unavailable:
            return AppL10n.unavailable(title)
        case let .permissionRequired(permission):
            return AppL10n.permissionRequired(permission)
        case .unsupported:
            return AppL10n.unsupported(title)
        case let .failed(message):
            return message
        }
    }

    var tint: Color {
        switch result {
        case .success:
            return .mint
        case .unavailable, .unsupported:
            return .secondary
        case .permissionRequired, .failed:
            return .orange
        }
    }
}
