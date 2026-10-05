import Foundation

enum SpillStatusModule: String, CaseIterable, Identifiable, Sendable {
    case cpu
    case memory
    case storage
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
        case .storage:
            return "Storage"
        case .gpu:
            return "GPU"
        case .network:
            return "Network"
        }
    }

    var symbolName: String {
        switch self {
        case .cpu:
            return "cpu"
        case .memory:
            return "memorychip"
        case .storage:
            return "internaldrive"
        case .gpu:
            return "display"
        case .network:
            return "network"
        }
    }

    static let defaultOrder: [SpillStatusModule] = [.cpu, .memory, .storage, .network, .gpu]
    static let primaryPanelModules: [SpillStatusModule] = defaultOrder
    static let defaultEnabled: Set<SpillStatusModule> = Set(primaryPanelModules)

    static func normalizedOrder(from rawValues: [String]?) -> [SpillStatusModule] {
        guard let rawValues else {
            return defaultOrder
        }

        return normalizedOrder(rawValues.compactMap(SpillStatusModule.init(rawValue:)))
    }

    static func normalizedOrder(_ modules: [SpillStatusModule]) -> [SpillStatusModule] {
        var seen = Set<SpillStatusModule>()
        var result: [SpillStatusModule] = []

        for module in modules where defaultOrder.contains(module) && !seen.contains(module) {
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

        var result = Set(
            rawValues
                .compactMap(SpillStatusModule.init(rawValue:))
                .filter { defaultOrder.contains($0) }
        )
        if rawValues.contains("gpu") {
            result.insert(.storage)
        }
        return result
    }
}
