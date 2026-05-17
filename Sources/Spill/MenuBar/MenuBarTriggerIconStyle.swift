import Foundation

enum MenuBarTriggerIconStyle: String, CaseIterable, Identifiable, Sendable {
    case spill
    case cat
    case liquid

    static let defaultStyle: MenuBarTriggerIconStyle = .spill
    static let selectableCases: [MenuBarTriggerIconStyle] = [.spill, .cat, .liquid]

    static func normalized(rawValue: String?) -> MenuBarTriggerIconStyle {
        guard let rawValue,
              let style = MenuBarTriggerIconStyle(rawValue: rawValue),
              selectableCases.contains(style)
        else {
            return defaultStyle
        }

        return style
    }

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .spill:
            return "Drop"
        case .cat:
            return "Cat"
        case .liquid:
            return "Liquid"
        }
    }

    var subtitle: String {
        switch self {
        case .spill:
            return "Uses the compact droplet symbol."
        case .cat:
            return "Uses a compact tail-wagging panel trigger."
        case .liquid:
            return "Uses a soft load-reactive trigger."
        }
    }

    var usesPerformanceEffect: Bool {
        self == .liquid
    }

    var animates: Bool {
        switch self {
        case .spill:
            return false
        case .cat, .liquid:
            return true
        }
    }

    var requiredStatusModules: Set<SpillStatusModule> {
        usesPerformanceEffect ? [.cpu, .memory, .network] : []
    }

    func symbolName(isActive: Bool) -> String {
        switch self {
        case .spill:
            return isActive ? "drop.circle.fill" : "drop.fill"
        case .cat:
            return isActive ? "pawprint.circle.fill" : "pawprint.fill"
        case .liquid:
            return isActive ? "drop.circle.fill" : "drop.fill"
        }
    }
}
