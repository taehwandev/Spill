import Foundation

struct TokenUsageHistoryImportSnapshot: Equatable, Sendable {
    var isRunning: Bool
    var startedAt: Date?
    var finishedAt: Date?
    var tools: [TokenUsageHistoryImportToolSnapshot]

    static let idle = TokenUsageHistoryImportSnapshot(
        isRunning: false,
        startedAt: nil,
        finishedAt: nil,
        tools: TokenUsageHistoryImportTool.allCases.map {
            .pending(tool: $0, mode: .firstImport, lastSuccessfulImportAt: nil)
        }
    )
}
