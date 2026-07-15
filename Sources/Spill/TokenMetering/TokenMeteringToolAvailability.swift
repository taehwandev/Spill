import Foundation

enum TokenMeteringToolAvailability {
    static func installedTools(from statuses: [LocalAIToolStatus]) -> Set<TokenUsageAITool> {
        Set(statuses.compactMap { status in
            guard status.kind.isTokenDashboardAgentTool else {
                return nil
            }
            return status.kind.tokenUsageDashboardTool
        })
    }

    static func visibleTools(
        from statuses: [LocalAIToolStatus],
        hiddenTools: Set<TokenUsageAITool>
    ) -> Set<TokenUsageAITool> {
        installedTools(from: statuses).subtracting(hiddenTools)
    }

    static func installedLocalToolKinds(from statuses: [LocalAIToolStatus]) -> [LocalAIToolKind] {
        let installed = installedTools(from: statuses)
        return LocalAIToolKind.allCases.filter { kind in
            kind.tokenUsageDashboardTool.map(installed.contains) ?? false
        }
    }

    /// Tools that are both present on this machine (CLI found via PATH scan) and
    /// have Spill's own metering adapter actually wired up. This is the correct
    /// signal for surfaces that ask "should this tool be offered as a visible,
    /// actively-tracked tool", such as the AI tool visibility toggle. A tool
    /// whose adapter files linger after the CLI itself was uninstalled must not
    /// pass this check; a tool whose CLI is present but never had Spill's
    /// adapter installed must not pass it either.
    ///
    /// `adapterStatuses` (keyed by `TokenMeteringAdapter.id`, i.e. the tool's
    /// raw value) must come from `TokenMeteringSetupInstallationDiagnostics
    /// .connectionStatus`, the same per-tool check the Setup card itself uses
    /// (`TokenMeteringPreferencesSection.refreshAdapterStatuses`) — this keeps
    /// one definition of "connected" instead of a second one computed here.
    /// For Antigravity there is no separate hook/script install step (Spill's
    /// active importer collects for it as soon as it's installed), so its
    /// connection status is already just "is it installed" by design; that
    /// matches how the rest of the app treats Antigravity everywhere else.
    static func installedAndAdapterConnectedLocalToolKinds(
        from statuses: [LocalAIToolStatus],
        adapterStatuses: [String: TokenMeteringAdapterConnectionStatus],
        setupScriptInstalled: Bool = FileManager.default.fileExists(
            atPath: TokenMeteringSetupInstaller.defaultInstallURL().path
        )
    ) -> [LocalAIToolKind] {
        guard setupScriptInstalled else {
            return []
        }

        let presentOnMachine = Set(installedLocalToolKinds(from: statuses))
        return LocalAIToolKind.allCases.filter { kind in
            guard presentOnMachine.contains(kind),
                  let tool = kind.tokenUsageDashboardTool,
                  let adapter = TokenMeteringAdapterKit.localRuntimeAdapters.first(where: { $0.aiTool == tool })
            else {
                return false
            }

            return adapterStatuses[adapter.id]?.isActive ?? false
        }
    }

    static func installedHistoryImportTools(
        from statuses: [LocalAIToolStatus]
    ) -> [TokenUsageHistoryImportTool] {
        let installed = installedTools(from: statuses)
        return TokenUsageHistoryImportTool.allCases.filter { installed.contains($0.aiTool) }
    }
}
