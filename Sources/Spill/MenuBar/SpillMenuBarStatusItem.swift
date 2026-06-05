import Foundation

enum SpillMenuBarStatusItem: String, CaseIterable, Identifiable, Sendable {
    case cpu
    case memory
    case caffeine
    case gpu
    case network
    case ai

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .cpu:
            return "CPU"
        case .memory:
            return "Memory"
        case .caffeine:
            return "Caffeine"
        case .gpu:
            return "GPU"
        case .network:
            return "Network"
        case .ai:
            return "AI"
        }
    }

    var shortTitle: String {
        switch self {
        case .cpu:
            return "CPU"
        case .memory:
            return "MEM"
        case .caffeine:
            return "CAF"
        case .gpu:
            return "GPU"
        case .network:
            return "NET"
        case .ai:
            return "AI"
        }
    }

    var symbolName: String {
        switch self {
        case .cpu:
            return "cpu"
        case .memory:
            return "memorychip"
        case .caffeine:
            return "cup.and.saucer.fill"
        case .gpu:
            return "display"
        case .network:
            return "network"
        case .ai:
            return "sparkles"
        }
    }

    var systemModule: SpillStatusModule? {
        switch self {
        case .cpu:
            return .cpu
        case .memory:
            return .memory
        case .caffeine:
            return nil
        case .gpu:
            return .gpu
        case .network:
            return .network
        case .ai:
            return nil
        }
    }

    static let defaultOrder: [SpillMenuBarStatusItem] = [.cpu, .memory, .caffeine, .gpu, .network, .ai]
    static let defaultEnabled: Set<SpillMenuBarStatusItem> = [.cpu, .memory]
    static let glanceSupported: Set<SpillMenuBarStatusItem> = [.cpu, .memory, .caffeine, .ai]

    static func normalizedEnabled(from rawValues: [String]?) -> Set<SpillMenuBarStatusItem> {
        guard let rawValues else {
            return defaultEnabled
        }

        return Set(rawValues.compactMap(SpillMenuBarStatusItem.init(rawValue:)))
            .intersection(glanceSupported)
    }
}
