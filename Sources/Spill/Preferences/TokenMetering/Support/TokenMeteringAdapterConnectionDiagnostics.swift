import Foundation

enum TokenMeteringAdapterConnectionDiagnostics {
    static func status(for adapter: TokenMeteringAdapter) -> TokenMeteringAdapterConnectionStatus {
        let scriptURL = TokenMeteringAdapterKit.defaultInstallURL(for: adapter)
        let scriptInstalled = FileManager.default.fileExists(atPath: scriptURL.path)
        return TokenMeteringAdapterConnectionStatus(
            scriptInstalled: scriptInstalled,
            hookConfigured: hookConfigured(for: adapter, scriptURL: scriptURL)
        )
    }

    private static func hookConfigured(for adapter: TokenMeteringAdapter, scriptURL: URL) -> Bool {
        switch adapter.aiTool {
        case .claude:
            return stopHookConfigured(
                configURL: homeURL(".claude/settings.json"),
                scriptURL: scriptURL
            )
        case .codex:
            return stopHookConfigured(
                configURL: homeURL(".codex/hooks.json"),
                scriptURL: scriptURL
            )
        case .antigravity:
            return false
        case .openAI, .unknown:
            return false
        }
    }

    private static func stopHookConfigured(configURL: URL, scriptURL: URL) -> Bool {
        guard let root = readJSONObject(configURL) as? [String: Any],
              let hooks = root["hooks"] as? [String: Any],
              let stop = hooks["Stop"]
        else {
            return false
        }

        return hookCommands(in: stop).contains { commandMatches($0, scriptURL: scriptURL) }
    }

    private static func hookCommands(in value: Any) -> [String] {
        if let dictionary = value as? [String: Any] {
            let current = (dictionary["command"] as? String).map { [$0] } ?? []
            return current + dictionary.values.flatMap { hookCommands(in: $0) }
        }

        if let array = value as? [Any] {
            return array.flatMap { hookCommands(in: $0) }
        }

        return []
    }

    private static func commandMatches(
        _ command: String,
        scriptURL: URL,
        compatibilityURLs: [URL] = []
    ) -> Bool {
        ([scriptURL] + compatibilityURLs).contains { candidateURL in
            command.contains(candidateURL.path)
                && scriptReferenceMatches(candidateURL, expectedURL: scriptURL)
        }
    }

    private static func scriptReferenceMatches(_ candidateURL: URL, expectedURL: URL) -> Bool {
        if candidateURL.path == expectedURL.path {
            return true
        }

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: candidateURL.path),
              fileManager.fileExists(atPath: expectedURL.path)
        else {
            return false
        }

        if candidateURL.resolvingSymlinksInPath().path == expectedURL.resolvingSymlinksInPath().path {
            return true
        }

        return fileManager.contentsEqual(
            atPath: candidateURL.path,
            andPath: expectedURL.path
        )
    }

    private static func readJSONObject(_ url: URL) -> Any? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONSerialization.jsonObject(with: data)
    }

    private static func homeURL(_ relativePath: String) -> URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(relativePath)
    }
}
