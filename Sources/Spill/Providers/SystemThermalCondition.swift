import Foundation

enum SystemThermalCondition: String, Hashable, Sendable {
    case nominal
    case fair
    case serious
    case critical

    init?(_ state: ProcessInfo.ThermalState) {
        switch state {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default: return nil
        }
    }

    var localizationKey: AppTextKey {
        switch self {
        case .nominal: .thermalNominal
        case .fair: .thermalFair
        case .serious: .thermalSerious
        case .critical: .thermalCritical
        }
    }
}
