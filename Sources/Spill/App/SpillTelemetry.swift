import Foundation

final class SpillTelemetry: @unchecked Sendable {
    static let shared = SpillTelemetry(appKey: SpillTelemetry.resolveAppKey())

    private let appKey: String?
    private let endpoint: URL?
    private let sessionID: String

    init(appKey: String?) {
        self.appKey = appKey
        if let appKey {
            let host = appKey.contains("-EU-") ? "https://eu.aptabase.com" : "https://us.aptabase.com"
            endpoint = URL(string: "\(host)/api/v0/events")
        } else {
            endpoint = nil
        }
        sessionID = "\(Int(Date().timeIntervalSince1970))\(Int.random(in: 10_000_000...99_999_999))"
    }

    func track(_ eventName: String, props: [String: String] = [:]) {
        guard let appKey,
              let endpoint,
              ProcessInfo.processInfo.environment["SPILL_TELEMETRY_DISABLED"] != "1",
              ProcessInfo.processInfo.environment["SPILL_SMOKE_TEST"] != "1"
        else {
            return
        }

        let payload: [[String: Any]] = [
            [
                "timestamp": ISO8601DateFormatter.aptabase.string(from: Date()),
                "sessionId": sessionID,
                "eventName": eventName,
                "systemProps": systemProps(),
                "props": props
            ]
        ]

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(appKey, forHTTPHeaderField: "App-Key")
        request.httpBody = body
        request.timeoutInterval = 3

        URLSession.shared.dataTask(with: request).resume()
    }

    private func systemProps() -> [String: Any] {
        [
            "locale": "unknown",
            "osName": "macOS",
            "osVersion": "unknown",
            "deviceModel": "Mac",
            "isDebug": isDebugBuild,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev",
            "sdkVersion": "spill-aptabase-lite@1.0.0"
        ]
    }

    private var isDebugBuild: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    private static func resolveAppKey() -> String? {
        if let envKey = ProcessInfo.processInfo.environment["SPILL_APTABASE_APP_KEY"],
           let resolvedKey = normalizedAppKey(envKey)
        {
            return resolvedKey
        }

        if let bundleKey = Bundle.main.object(forInfoDictionaryKey: "SPILLAptabaseAppKey") as? String,
           let resolvedKey = normalizedAppKey(bundleKey)
        {
            return resolvedKey
        }

        return nil
    }

    private static func normalizedAppKey(_ value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty,
              !trimmedValue.hasPrefix("__"),
              trimmedValue.hasPrefix("A-US-") || trimmedValue.hasPrefix("A-EU-")
        else {
            return nil
        }

        return trimmedValue
    }
}

private extension ISO8601DateFormatter {
    static var aptabase: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
}
