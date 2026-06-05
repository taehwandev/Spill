import Foundation

enum MenuBarTriggerIconStyle: String, CaseIterable, Identifiable, Sendable {
    case spill

    static let defaultStyle: MenuBarTriggerIconStyle = .spill
    static let selectableCases: [MenuBarTriggerIconStyle] = [.spill]

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
        }
    }

    var subtitle: String {
        switch self {
        case .spill:
            return AppL10n.text(.triggerDropSubtitle)
        }
    }

    var usesPerformanceEffect: Bool {
        false
    }

    var animates: Bool {
        false
    }

    var requiredStatusModules: Set<SpillStatusModule> {
        usesPerformanceEffect ? [.cpu, .memory, .network] : []
    }

    func symbolName(isActive: Bool) -> String {
        switch self {
        case .spill:
            return isActive ? "drop.circle.fill" : "drop.fill"
        }
    }
}
