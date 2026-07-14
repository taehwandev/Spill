import Foundation

enum TokenMeteringSetupInstallationDiagnostics {
    static func isInstalled(for installedTools: Set<TokenUsageAITool>) -> Bool {
        guard !installedTools.isEmpty else {
            return false
        }

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: TokenMeteringSetupInstaller.defaultInstallURL().path) else {
            return false
        }

        return installedTools.allSatisfy { tool in
            adapterConfigured(for: tool)
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
}
