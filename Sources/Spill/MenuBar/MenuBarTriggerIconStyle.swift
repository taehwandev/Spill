import Foundation

enum MenuBarTriggerIconStyle: String, CaseIterable, Identifiable, Sendable {
    case spill
    // Droplet characters. The raw values are new on purpose: the retired
    // `cat`, `liquid` and `symbolized_s` styles normalize to the drop, so an
    // old saved choice does not silently turn into one of these.
    case dropCat = "drop_cat"
    case dropBunny = "drop_bunny"
    case dropFish = "drop_fish"

    static let defaultStyle: MenuBarTriggerIconStyle = .spill
    static let selectableCases: [MenuBarTriggerIconStyle] = [.spill, .dropCat, .dropBunny, .dropFish]

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
        case .dropCat:
            return AppL10n.text(.triggerDropCat)
        case .dropBunny:
            return AppL10n.text(.triggerDropBunny)
        case .dropFish:
            return AppL10n.text(.triggerDropFish)
        }
    }

    var subtitle: String {
        switch self {
        case .spill:
            return AppL10n.text(.triggerDropSubtitle)
        case .dropCat:
            return AppL10n.text(.triggerDropCatSubtitle)
        case .dropBunny:
            return AppL10n.text(.triggerDropBunnySubtitle)
        case .dropFish:
            return AppL10n.text(.triggerDropFishSubtitle)
        }
    }

    var usesPerformanceEffect: Bool {
        false
    }

    /// Every style animates, driven by `TriggerIconAnimator`.
    var animates: Bool {
        true
    }

    /// The cat always sways its tail, faster under load; the other styles move in short
    /// bursts separated by idle gaps.
    var loopsContinuously: Bool {
        character == .cat
    }

    var usesCustomRenderer: Bool {
        true
    }

    /// The character drawn by `MenuBarTriggerIconCharacterRenderer`, if any.
    var character: MenuBarTriggerIconCharacterRenderer.Character? {
        switch self {
        case .spill:
            return nil
        case .dropCat:
            return .cat
        case .dropBunny:
            return .bunny
        case .dropFish:
            return .fish
        }
    }

    var requiredStatusModules: Set<SpillStatusModule> {
        usesPerformanceEffect ? [.cpu, .memory, .network] : []
    }

    func symbolName(isActive: Bool) -> String {
        switch self {
        case .spill:
            return isActive ? "drop.circle.fill" : "drop.fill"
        case .dropCat:
            return "cat.fill"
        case .dropBunny:
            return "hare.fill"
        case .dropFish:
            return "fish.fill"
        }
    }
}
