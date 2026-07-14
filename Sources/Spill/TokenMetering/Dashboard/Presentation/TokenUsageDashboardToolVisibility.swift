import Foundation

enum TokenUsageDashboardToolVisibility {
    static func visibleTools(
        statuses: [LocalAIToolStatus],
        hiddenTools: Set<TokenUsageAITool>
    ) -> Set<TokenUsageAITool> {
        TokenMeteringToolAvailability.visibleTools(
            from: statuses,
            hiddenTools: hiddenTools
        )
    }

    static func dashboardFilterTools(
        visibleInstalledTools: Set<TokenUsageAITool>?,
        showAdvancedTools: Bool
    ) -> Set<TokenUsageAITool>? {
        showAdvancedTools ? nil : visibleInstalledTools
    }
}
