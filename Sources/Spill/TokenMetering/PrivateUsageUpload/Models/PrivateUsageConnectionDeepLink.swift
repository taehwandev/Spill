import Foundation

enum PrivateUsageConnectionDeepLink {
    static func connectionCode(from url: URL) -> String? {
        guard url.scheme == "spill",
              url.host == "private-usage",
              url.path == "/connect",
              let code = connectionCodeQueryValue(from: url),
              isAllowedConnectionCodeQueryValue(code)
        else {
            return nil
        }

        return code.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func connectionCodeQueryValue(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        return connectionCodeQueryValue(from: components.queryItems ?? [])
            ?? connectionCodeQueryValue(from: queryItems(fromFragment: components.percentEncodedFragment))
    }

    private static func connectionCodeQueryValue(from queryItems: [URLQueryItem]) -> String? {
        let allowedNames = Set(["code", "connection_code"])
        return queryItems.first { allowedNames.contains($0.name) }?.value
    }

    private static func queryItems(fromFragment fragment: String?) -> [URLQueryItem] {
        guard let fragment, !fragment.isEmpty else {
            return []
        }

        let query: String
        if let queryStart = fragment.firstIndex(of: "?") {
            query = String(fragment[fragment.index(after: queryStart)...])
        } else {
            query = fragment
        }

        var components = URLComponents()
        components.percentEncodedQuery = query
        return components.queryItems ?? []
    }

    private static func isAllowedConnectionCodeQueryValue(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 512 else {
            return false
        }

        return trimmed.range(of: #"^[A-Za-z0-9._:-]+$"#, options: .regularExpression) != nil
    }
}
