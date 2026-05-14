import Foundation

struct SpillAction: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String?
    let symbolName: String?
    let iconData: Data?
    let kind: SpillActionKind
    let role: SpillActionRole
    let state: SpillActionState

    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        symbolName: String? = nil,
        iconData: Data? = nil,
        kind: SpillActionKind,
        role: SpillActionRole = .primary,
        state: SpillActionState = .enabled
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.symbolName = symbolName
        self.iconData = iconData
        self.kind = kind
        self.role = role
        self.state = state
    }
}

enum SpillActionKind: Hashable, Sendable {
    case menuBarItem(stableKey: String)
    case app(bundleIdentifier: String)
    case window(WindowActionKind)
    case command(String)
}

enum SpillActionState: Hashable, Sendable {
    case enabled
    case disabled(reason: String)
    case permissionRequired(String)

    var isEnabled: Bool {
        self == .enabled
    }

    var disabledReason: String? {
        switch self {
        case .enabled:
            return nil
        case let .disabled(reason):
            return reason
        case let .permissionRequired(permission):
            return "\(permission) permission required"
        }
    }
}

enum SpillActionRole: Hashable, Sendable {
    case primary
    case secondary
    case destructive
}

enum WindowActionKind: String, Hashable, Sendable {
    case leftHalf
    case rightHalf
    case center
    case maximize
    case nextDisplay
    case restore
}

protocol SpillActionProvider: Sendable {
    var id: String { get }
    var title: String { get }

    func actions() async -> [SpillAction]
}

protocol SpillActionHandler: Sendable {
    func perform(_ action: SpillAction) async -> SpillActionResult
}

enum SpillActionResult: Hashable, Sendable {
    case success
    case unavailable
    case permissionRequired(String)
    case unsupported
    case failed(message: String)
}
