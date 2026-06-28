import Foundation

enum PrivateUsageRelayEndpoint {
    static let relayURLOverrideEnvironmentKey = "SPILL_PRIVATE_USAGE_RELAY_URL"
    static let relayURLInfoDictionaryKey = "SPILLPrivateUsageRelayURL"
    private static let defaultRelayPath = "/api/private-usage-relay"

    static func relayURL(
        environment: PrivateUsageUploadEnvironment,
        processEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        bundleInfo: [String: Any]? = Bundle.main.infoDictionary
    ) -> URL? {
        if let override = configuredString(processEnvironment[relayURLOverrideEnvironmentKey]) {
            return sanitizedRelayURL(override)
        }
        if let configuredURL = configuredString(bundleInfo?[relayURLInfoDictionaryKey] as? String) {
            return sanitizedRelayURL(configuredURL)
        }

        guard let webURL = PrivateUsageWebConnection.configuredWebURL(
            processEnvironment: processEnvironment,
            bundleInfo: bundleInfo
        ) else {
            return nil
        }

        return derivedRelayURL(from: webURL)
    }

    static func isSafeRelayURL(_ url: URL) -> Bool {
        if let host = url.host?.lowercased(),
           host == "supabase.co" || host.hasSuffix(".supabase.co")
        {
            return false
        }

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

    private static func derivedRelayURL(from webURL: URL) -> URL? {
        guard let scheme = webURL.scheme,
              let host = webURL.host
        else {
            return nil
        }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = webURL.port
        components.path = defaultRelayPath

        guard let url = components.url, isSafeRelayURL(url) else {
            return nil
        }
        return url
    }

    private static func configuredString(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else {
            return nil
        }
        return value
    }
}
