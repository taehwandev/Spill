enum TokenMeteringToolAvailability {
    static let supportedTools = Set(TokenUsageAITool.dashboardTools)
    static let supportedLocalToolKinds = TokenUsageAITool.dashboardTools.compactMap(\.localAIToolKind)

    static func installedTools(from statuses: [LocalAIToolStatus]) -> Set<TokenUsageAITool> {
        Set(statuses.compactMap { status in
            guard status.kind.isTokenDashboardAgentTool else {
                return nil
            }
            return status.kind.tokenUsageDashboardTool
        })
    }

    static func visibleTools(hiddenTools: Set<TokenUsageAITool>) -> Set<TokenUsageAITool> {
        supportedTools.subtracting(hiddenTools)
    }

    static func installedHistoryImportTools(
        from statuses: [LocalAIToolStatus]
    ) -> [TokenUsageHistoryImportTool] {
        let installed = installedTools(from: statuses)
        return TokenUsageHistoryImportTool.allCases.filter { installed.contains($0.aiTool) }
    }
}
