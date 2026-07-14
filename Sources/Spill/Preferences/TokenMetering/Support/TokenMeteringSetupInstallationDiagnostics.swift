import Foundation

enum TokenMeteringSetupInstallationDiagnostics {
    static func isInstalled(for installedTools: Set<TokenUsageAITool>) -> Bool {
        guard !installedTools.isEmpty else {
            return false
        }

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: TokenMeteringSetupInstaller.defaultInstallURL().path),
              fileManager.fileExists(
                atPath: TokenMeteringSetupInstaller.defaultSharedRuntimeInstructionURL().path
              )
        else {
            return false
        }

        return installedTools.allSatisfy { tool in
            runtimeInstructionBridgeConfigured(for: tool, fileManager: fileManager)
                && adapterConfigured(for: tool)
        }
    }

    private static func adapterConfigured(for tool: TokenUsageAITool) -> Bool {
        switch tool {
        case .codex:
            return TokenMeteringAdapterConnectionDiagnostics.status(
                for: TokenMeteringAdapterKit.codex
            ).isActive
        case .claude:
            return TokenMeteringAdapterConnectionDiagnostics.status(
                for: TokenMeteringAdapterKit.claudeCode
            ).isActive
        case .antigravity:
            return true
        case .openAI, .unknown:
            return false
        }
    }

    static func connectionStatus(
        for tool: TokenUsageAITool,
        runtimeInstalled: Bool
    ) -> TokenMeteringAdapterConnectionStatus {
        guard tool == .antigravity else {
            guard let adapter = TokenMeteringAdapterKit.localRuntimeAdapters.first(where: {
                $0.aiTool == tool
            }) else {
                return .missing
            }
            return TokenMeteringAdapterConnectionDiagnostics.status(for: adapter)
        }

        return runtimeInstalled
            ? TokenMeteringAdapterConnectionStatus(scriptInstalled: true, hookConfigured: true)
            : .missing
    }

    private static func runtimeInstructionBridgeConfigured(
        for tool: TokenUsageAITool,
        fileManager: FileManager
    ) -> Bool {
        guard let bridgeURL = runtimeInstructionBridgeURL(for: tool, fileManager: fileManager),
              let contents = try? String(contentsOf: bridgeURL, encoding: .utf8)
        else {
            return false
        }

        return contents.contains("<!-- spill-token-metering-instruction:begin -->")
            && contents.contains("<!-- spill-token-metering-instruction:end -->")
            && contents.contains(
                TokenMeteringSetupInstaller.defaultSharedRuntimeInstructionURL(
                    fileManager: fileManager
                ).path
            )
    }

    private static func runtimeInstructionBridgeURL(
        for tool: TokenUsageAITool,
        fileManager: FileManager
    ) -> URL? {
        let home = fileManager.homeDirectoryForCurrentUser
        switch tool {
        case .codex:
            let override = home.appendingPathComponent(".codex/AGENTS.override.md")
            if fileManager.fileExists(atPath: override.path) {
                return override
            }
            return home.appendingPathComponent(".codex/AGENTS.md")
        case .claude:
            return home.appendingPathComponent(".claude/CLAUDE.md")
        case .antigravity:
            return home.appendingPathComponent(".antigravity/AGENTS.md")
        case .openAI, .unknown:
            return nil
        }
    }
}
