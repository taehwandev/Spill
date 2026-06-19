import Foundation

enum TokenUsageHistoryImportToolState: String, Codable, Equatable, Sendable {
    case pending
    case running
    case completed
    case unavailable
    case failed
    case cancelled

    var isFinished: Bool {
        switch self {
        case .completed, .unavailable, .failed, .cancelled:
            return true
        case .pending, .running:
            return false
        }
    }
}
