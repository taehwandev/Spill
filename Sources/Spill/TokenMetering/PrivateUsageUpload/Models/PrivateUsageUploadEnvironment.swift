import Foundation

enum PrivateUsageUploadEnvironment: String, CaseIterable, Codable, Identifiable, Sendable {
    static let environmentOverrideEnvironmentKey = "SPILL_PRIVATE_USAGE_ENVIRONMENT"
    static let environmentInfoDictionaryKey = "SPILLPrivateUsageEnvironment"

    case development
    case production

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .development:
            return "Development"
        case .production:
            return "Production"
        }
    }

    var detail: String {
        switch self {
        case .development:
            return "Uses the local Supabase relay and separate development credentials."
        case .production:
            return "Uses the live Spill relay and separate production credentials."
        }
    }

    var keychainService: String {
        "dev.spill.private-usage.\(rawValue)"
    }

    var stateKeyNamespace: String {
        "privateUsageUpload.\(rawValue)"
    }

    static var defaultValue: Self {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }

    static func normalized(rawValue: String?) -> Self {
        guard let rawValue, let environment = Self(rawValue: rawValue) else {
            return defaultValue
        }

        return environment
    }

    static func resolvedFromEnvironment(
        _ processEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Self? {
        normalizedExplicit(rawValue: processEnvironment[environmentOverrideEnvironmentKey])
    }

    static func resolvedFromConfiguration(
        processEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        bundleInfo: [String: Any]? = Bundle.main.infoDictionary
    ) -> Self? {
        resolvedFromEnvironment(processEnvironment)
            ?? normalizedExplicit(rawValue: bundleInfo?[environmentInfoDictionaryKey] as? String)
    }

    private static func normalizedExplicit(rawValue: String?) -> Self? {
        guard let rawValue, !rawValue.isEmpty else {
            return nil
        }

        return Self(rawValue: rawValue.lowercased())
    }
}
