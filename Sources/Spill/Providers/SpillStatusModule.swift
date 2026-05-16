import Foundation

enum SpillStatusModule: String, CaseIterable, Identifiable, Sendable {
    case cpu
    case memory
    case gpu
    case network

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .cpu:
            return "CPU"
        case .memory:
            return "Memory"
        case .gpu:
            return "GPU"
        case .network:
            return "Network"
        }
    }

    var meterTitle: String {
        switch self {
        case .gpu:
            return "GPU"
        case .network:
            return "NET"
        case .cpu, .memory:
            return title.uppercased()
        }
    }

    var symbolName: String {
        switch self {
        case .cpu:
            return "cpu"
        case .memory:
            return "memorychip"
        case .gpu:
            return "display"
        case .network:
            return "network"
        }
    }

    var preferenceSubtitle: String {
        switch self {
        case .cpu:
            return "Processor activity"
        case .memory:
            return "Used and available physical memory"
        case .gpu:
            return "Metal device availability"
        case .network:
            return "Default route availability"
        }
    }

    static let defaultOrder: [SpillStatusModule] = [.cpu, .memory, .gpu, .network]
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
