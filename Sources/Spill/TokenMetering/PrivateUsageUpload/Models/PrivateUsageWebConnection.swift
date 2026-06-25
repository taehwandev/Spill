import Foundation

enum PrivateUsageWebConnection {
    static let webURLOverrideEnvironmentKey = "SPILL_PRIVATE_USAGE_WEB_URL"
    static let webURLInfoDictionaryKey = "SPILLPrivateUsageWebURL"
    static let callbackURL = "spill://private-usage/connect"

    static func connectDeviceURL(
        processEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        bundleInfo: [String: Any]? = Bundle.main.infoDictionary
    ) -> URL? {
        if let override = processEnvironment[webURLOverrideEnvironmentKey],
           let url = sanitizedConnectDeviceURL(override)
        {
            return appendingConnectionParameters(to: url)
        }
        if let configuredURL = bundleInfo?[webURLInfoDictionaryKey] as? String,
           let url = sanitizedConnectDeviceURL(configuredURL)
        {
            return appendingConnectionParameters(to: url)
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

    private static func appendingConnectionParameters(to url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        let connectionItems = [
            URLQueryItem(name: "source", value: "macos"),
            URLQueryItem(name: "callback_url", value: callbackURL)
        ]

        if let fragment = components.percentEncodedFragment, !fragment.isEmpty {
            components.percentEncodedFragment = fragmentByAppending(connectionItems, to: fragment)
        } else {
            components.queryItems = appending(connectionItems, to: components.queryItems ?? [])
        }

        return components.url ?? url
    }

    private static func fragmentByAppending(
        _ newItems: [URLQueryItem],
        to fragment: String
    ) -> String {
        let path: String
        let query: String?
        if let queryStart = fragment.firstIndex(of: "?") {
            path = String(fragment[..<queryStart])
            query = String(fragment[fragment.index(after: queryStart)...])
        } else {
            path = fragment
            query = nil
        }

        var components = URLComponents()
        components.percentEncodedQuery = query
        components.queryItems = appending(newItems, to: components.queryItems ?? [])

        guard let encodedQuery = components.percentEncodedQuery, !encodedQuery.isEmpty else {
            return path
        }
        return "\(path)?\(encodedQuery)"
    }

    private static func appending(
        _ newItems: [URLQueryItem],
        to existingItems: [URLQueryItem]
    ) -> [URLQueryItem] {
        let newNames = Set(newItems.map(\.name))
        return existingItems.filter { !newNames.contains($0.name) } + newItems
    }
}
