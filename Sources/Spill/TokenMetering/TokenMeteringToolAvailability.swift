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

    static func installedHistoryImportTools(
        from statuses: [LocalAIToolStatus]
    ) -> [TokenUsageHistoryImportTool] {
        let installed = installedTools(from: statuses)
        return TokenUsageHistoryImportTool.allCases.filter { installed.contains($0.aiTool) }
    }
}
