import Foundation

enum TokenUsageDashboardToolVisibility {
    static func visibleTools(hiddenTools: Set<TokenUsageAITool>) -> Set<TokenUsageAITool> {
        Set(TokenUsageAITool.dashboardTools).subtracting(hiddenTools)
    }
}
