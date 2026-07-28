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
