import Darwin
import Foundation

enum SystemMemoryPressure: Int32, Hashable, Sendable {
    case normal = 1
    case elevated = 2
    case critical = 4

    static func current() -> Self? {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0,
              size == MemoryLayout<Int32>.size else {
            return nil
        }
        return Self(rawValue: level)
    }

    var localizationKey: AppTextKey {
        switch self {
        case .normal: .normal
        case .elevated: .pressureElevated
        case .critical: .pressureCritical
        }
    }

}
