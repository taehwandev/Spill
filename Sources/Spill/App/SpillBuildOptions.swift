import Foundation

enum SpillBuildOptions {
    private static let developerOptionsInfoKey = "SPILLDeveloperOptionsEnabled"
    private static let developerOptionsEnvironmentKey = "SPILL_DEVELOPER_OPTIONS_ENABLED"

    static var developerOptionsEnabled: Bool {
        #if DEBUG
        return true
        #else
        if let rawValue = ProcessInfo.processInfo.environment[developerOptionsEnvironmentKey] {
            return boolValue(rawValue)
        }
        return Bundle.main.object(forInfoDictionaryKey: developerOptionsInfoKey) as? Bool == true
        #endif
    }

    private static func boolValue(_ rawValue: String) -> Bool {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "on":
            return true
        default:
            return false
        }
    }
}
