import Foundation

enum TokenUsageDashboardToolVisibility {
    static func visibleTools(hiddenTools: Set<TokenUsageAITool>) -> Set<TokenUsageAITool> {
        TokenMeteringToolAvailability.visibleTools(hiddenTools: hiddenTools)
    }

    static func dashboardFilterTools(
        visibleTools: Set<TokenUsageAITool>?,
        showAdvancedTools: Bool
    ) -> Set<TokenUsageAITool>? {
        guard showAdvancedTools else {
            return visibleTools
        }

        let tokenDisplayTools = visibleTools ?? TokenMeteringToolAvailability.supportedTools
        return tokenDisplayTools.union([.openAI, .unknown])
    }
}
