import Foundation

enum MenuBarTriggerIconStyle: String, CaseIterable, Identifiable, Sendable {
    case spill
    case symbolizedS = "symbolized_s"

    static let defaultStyle: MenuBarTriggerIconStyle = .spill
    static let selectableCases: [MenuBarTriggerIconStyle] = [.spill, .symbolizedS]

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
            return AppL10n.text(.triggerDrop)
        case .symbolizedS:
            return AppL10n.text(.triggerSymbolizedS)
        }
    }

    var subtitle: String {
        switch self {
        case .spill:
            return AppL10n.text(.triggerDropSubtitle)
        case .symbolizedS:
            return AppL10n.text(.triggerSymbolizedSSubtitle)
        }
    }

    var usesPerformanceEffect: Bool {
        false
    }

    var animates: Bool {
        switch self {
        case .spill:
            return true
        case .symbolizedS:
            return true
        }
    }

    var usesCustomRenderer: Bool {
        switch self {
        case .spill:
            return true
        case .symbolizedS:
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
        case .symbolizedS:
            return isActive ? "s.circle.fill" : "s.circle"
        }
    }
}
