import Foundation

struct TokenUsageDashboardToolShare: Identifiable, Equatable {
    let tool: TokenUsageAITool
    let tokens: Int
    /// Share of the owning row's tokens, 0...1.
    let ratio: Double

    var id: String { tool.rawValue }

    /// Builds shares from raw per-tool token counts, dropping empty tools and ordering by
    /// TokenUsageAITool.allCases so the SQL and events builds produce identical arrays.
    static func shares(from toolTokens: [TokenUsageAITool: Int], rowTokens: Int) -> [Self] {
        TokenUsageAITool.allCases.compactMap { tool in
            let tokens = toolTokens[tool, default: 0]
            guard tokens > 0 else {
                return nil
            }
            return Self(
                tool: tool,
                tokens: tokens,
                ratio: TokenUsageDashboardSnapshot.chartRatio(tokens: tokens, totalTokens: rowTokens)
            )
        }
    }
}
