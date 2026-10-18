import Foundation

enum PrivateUsageWebConnection {
    static let webURLOverrideEnvironmentKey = "SPILL_PRIVATE_USAGE_WEB_URL"
    static let webURLInfoDictionaryKey = "SPILLPrivateUsageWebURL"
    static let callbackURL = "spill://private-usage/connect"

}

extension PrivateUsageWebConnection {
    static func connectDeviceURL(
        processEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        bundleInfo: [String: Any]? = Bundle.main.infoDictionary
    ) -> URL? {
        guard let url = configuredWebURL(
            processEnvironment: processEnvironment,
            bundleInfo: bundleInfo
        ) else {
            return nil
        }

        return appendingConnectionParameters(to: appendingPath("/connect-device", to: url))
    }

    static func dashboardURL(
        processEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        bundleInfo: [String: Any]? = Bundle.main.infoDictionary
    ) -> URL? {
        guard let url = configuredWebURL(
            processEnvironment: processEnvironment,
            bundleInfo: bundleInfo
        ) else {
            return nil
        }

        return appendingPath("/spill/dashboard", to: url)
    }

    static func configuredWebURL(
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

}

private extension PrivateUsageWebConnection {
    private static func sanitizedConnectDeviceURL(_ rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(),
              !host.isEmpty
        else {
            return nil
        }

        if scheme == "https" {
            if host == "spill.thdev.app", components.port == nil || components.port == 443 {
                components.host = "getmoru.com"
                components.port = nil
            }
            return components.url
        }

        if scheme == "http", ["localhost", "127.0.0.1"].contains(host) {
            components.host = "127.0.0.1"
            return components.url
        }

        return nil
    }

    private static func appendingPath(_ path: String, to url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        components.percentEncodedQuery = nil
        components.percentEncodedFragment = nil
        components.path = path
        return components.url ?? url
    }

    private static func appendingConnectionParameters(to url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        let connectionItems = [
            URLQueryItem(name: "source", value: "macos"),
            URLQueryItem(name: "callback_url", value: callbackURL)
        ]

        components.queryItems = connectionItems

        return components.url ?? url
    }
}
