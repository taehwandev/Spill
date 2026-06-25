import Foundation

enum TokenUsageHistoryImportFailureReason: String, Equatable, Sendable {
    case invalidSummary = "invalid_summary"
    case nodeUnavailable = "node_unavailable"
    case prepareFailed = "prepare_failed"
    case processFailed = "process_failed"
    case pythonUnavailable = "python_unavailable"
    case timeout
    case unknownFailed = "unknown_failed"
    case writeFailed = "write_failed"
}
