import Foundation

enum PrivateUsageUploadFeatureAvailability {
    static let featureEnabledEnvironmentKey = "SPILL_PRIVATE_USAGE_FEATURE_ENABLED"
    static let featureEnabledInfoDictionaryKey = "SPILLPrivateUsageFeatureEnabled"

    static var isEnabledInCurrentBuild: Bool {
        isEnabled()
    }

    static let isWebConnectionEntryPointEnabledInCurrentBuild = false

    static func isEnabled(
        processEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        bundleInfo: [String: Any]? = Bundle.main.infoDictionary
    ) -> Bool {
        if let override = processEnvironment[featureEnabledEnvironmentKey],
           let value = normalizedBool(override)
        {
            return value
        }

        if let configured = bundleInfo?[featureEnabledInfoDictionaryKey] {
            if let value = configured as? Bool {
                return value
            }
            if let value = configured as? NSNumber {
                return value.boolValue
            }
            if let value = configured as? String,
               let normalized = normalizedBool(value)
            {
                return normalized
            }
        }

        return false
    }

    private static func normalizedBool(_ rawValue: String) -> Bool? {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "on":
            return true
        case "0", "false", "no", "off", "":
            return false
        default:
            return nil
        }
    }
}
