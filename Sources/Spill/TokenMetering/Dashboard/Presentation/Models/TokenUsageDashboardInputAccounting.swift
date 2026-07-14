import Foundation

struct TokenUsageDashboardInputAccounting: Equatable {
    let rows: [TokenUsageDashboardBarRow]
    let rawInputTokens: Int
    let exactFreshInputTokens: Int
}
