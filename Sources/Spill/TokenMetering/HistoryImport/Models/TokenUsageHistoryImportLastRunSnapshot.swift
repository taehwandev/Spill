import Foundation

struct TokenUsageHistoryImportLastRunSnapshot: Codable, Equatable, Sendable {
    let finishedAt: Date
    let state: TokenUsageHistoryImportToolState
    let scannedSources: Int
    let importedEvents: Int
    let skippedDuplicates: Int
    let unsupportedRecords: Int
    let message: String?
}
