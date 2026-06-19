import Foundation

enum PrivateUsageConnectionDeepLink {
    static func connectionCode(from url: URL) -> String? {
        guard url.scheme == "spill",
              url.host == "private-usage",
              url.path == "/connect",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              isAllowedConnectionCodeQueryValue(code)
        else {
            return nil
        }

        return code.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isAllowedConnectionCodeQueryValue(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 512 else {
            return false
        }

        return trimmed.range(of: #"^[A-Za-z0-9._:-]+$"#, options: .regularExpression) != nil
    }
}
