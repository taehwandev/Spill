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
