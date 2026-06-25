import Foundation

struct TokenUsageHistoryImportProcessResult: Equatable {
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let timedOut: Bool
    let durationSeconds: TimeInterval
}
