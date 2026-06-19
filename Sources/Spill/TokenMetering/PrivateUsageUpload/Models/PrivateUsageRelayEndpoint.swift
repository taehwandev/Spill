import Foundation

enum PrivateUsageRelayEndpoint {
    static let relayURLOverrideEnvironmentKey = "SPILL_PRIVATE_USAGE_RELAY_URL"
    static let relayURLInfoDictionaryKey = "SPILLPrivateUsageRelayURL"

    static func relayURL(
        environment: PrivateUsageUploadEnvironment,
        processEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        bundleInfo: [String: Any]? = Bundle.main.infoDictionary
    ) -> URL? {
        if let override = processEnvironment[relayURLOverrideEnvironmentKey],
           let url = sanitizedRelayURL(override)
        {
            return url
        }
        if let configuredURL = bundleInfo?[relayURLInfoDictionaryKey] as? String,
           let url = sanitizedRelayURL(configuredURL)
        {
            return url
        }

        return nil
    }

    static func isSafeRelayURL(_ url: URL) -> Bool {
        if url.scheme == "https" {
            return true
        }

        if url.scheme == "http", url.host == "localhost" {
            return true
        }

        return false
    }

    private static func sanitizedRelayURL(_ rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              isSafeRelayURL(url)
        else {
            return nil
        }

        return url
    }
}
