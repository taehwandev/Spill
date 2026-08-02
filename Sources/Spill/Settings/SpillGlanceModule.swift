import Foundation

enum SpillGlanceModule: String, CaseIterable, Identifiable, Sendable {
    case allToday
    case codexToday
    case claudeToday
    case antigravityToday
    case workType

    var id: String {
        rawValue
    }

    static let defaultOrder: [SpillGlanceModule] = [
        .allToday,
        .codexToday,
        .claudeToday,
        .antigravityToday,
        .workType
    ]

    static let configurableToolModules: [SpillGlanceModule] = [
        .codexToday,
        .claudeToday,
        .antigravityToday
    ]

    static let fixedModules: Set<SpillGlanceModule> = [
        .allToday,
        .workType
    ]

    var isTool: Bool {
        Self.configurableToolModules.contains(self)
    }

    /// Two-letter label used by the dense `all` layout, where a full tool name
    /// does not fit the fixed cell width. `nil` means the item title already fits.
    var compactTitle: String? {
        switch self {
        case .codexToday:
            return "CX"
        case .claudeToday:
            return "CL"
        case .antigravityToday:
            return "AG"
        case .allToday, .workType:
            return nil
        }
    }

    static func normalizedEnabled(from rawValues: [String]?) -> Set<SpillGlanceModule> {
        guard let rawValues else {
            return []
        }

        let configuredTools = Set(
            rawValues
                .compactMap(SpillGlanceModule.init(rawValue:))
                .filter { configurableToolModules.contains($0) }
        )
        if !configuredTools.isEmpty {
            return configuredTools
        }

        let legacyModules = Set(["aiStatus", "topTask", "todayTokens"])
        if rawValues.contains(where: legacyModules.contains) {
            return Set(configurableToolModules)
        }

        return []
    }
}
