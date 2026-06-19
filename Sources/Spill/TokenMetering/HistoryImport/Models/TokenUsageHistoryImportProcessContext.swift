import Foundation

struct TokenUsageHistoryImportProcessContext {
    let executableURL: URL
    let arguments: [String]
    let environment: [String: String]
    let store: TokenUsageStore
    let maximumRuntime: TimeInterval
    let shouldCancel: () -> Bool
    let processDidStart: (Process) -> Void
    let processDidFinish: () -> Void
}
