import Foundation

enum SpillStatusModule: String, CaseIterable, Identifiable, Sendable {
    case cpu
    case memory

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .cpu:
            return "CPU"
        case .memory:
            return "Memory"
        }
    }

    var meterTitle: String {
        title.uppercased()
    }

    var symbolName: String {
        switch self {
        case .cpu:
            return "cpu"
        case .memory:
            return "memorychip"
        }
    }

    var preferenceSubtitle: String {
        switch self {
        case .cpu:
            return "Processor activity"
        case .memory:
            return "Used physical memory"
        }
    }

    static let defaultOrder: [SpillStatusModule] = [.cpu, .memory]
    static let defaultEnabled: Set<SpillStatusModule> = Set(defaultOrder)

    static func normalizedOrder(from rawValues: [String]?) -> [SpillStatusModule] {
        guard let rawValues else {
            return defaultOrder
        }

        return normalizedOrder(rawValues.compactMap(SpillStatusModule.init(rawValue:)))
    }

    static func normalizedOrder(_ modules: [SpillStatusModule]) -> [SpillStatusModule] {
        var seen = Set<SpillStatusModule>()
        var result: [SpillStatusModule] = []

        for module in modules where !seen.contains(module) {
            seen.insert(module)
            result.append(module)
        }

        for module in defaultOrder where !seen.contains(module) {
            result.append(module)
        }

        return result
    }

    static func normalizedEnabled(from rawValues: [String]?) -> Set<SpillStatusModule> {
        guard let rawValues else {
            return defaultEnabled
        }

        return Set(rawValues.compactMap(SpillStatusModule.init(rawValue:)))
    }
}
