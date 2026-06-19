import Foundation

enum PrivateUsageWebConnection {
    static let webURLOverrideEnvironmentKey = "SPILL_PRIVATE_USAGE_WEB_URL"
    static let webURLInfoDictionaryKey = "SPILLPrivateUsageWebURL"

    static func connectDeviceURL(
        processEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        bundleInfo: [String: Any]? = Bundle.main.infoDictionary
    ) -> URL? {
        if let override = processEnvironment[webURLOverrideEnvironmentKey],
           let url = sanitizedConnectDeviceURL(override)
        {
            return url
        }
        if let configuredURL = bundleInfo?[webURLInfoDictionaryKey] as? String,
           let url = sanitizedConnectDeviceURL(configuredURL)
        {
            return url
        }

        return nil
    }

    private static func sanitizedConnectDeviceURL(_ rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme,
              let host = url.host
        else {
            return nil
        }

        if scheme == "https" {
            return url
        }

        if scheme == "http", host == "localhost" {
            return url
        }

        return nil
    }
}
