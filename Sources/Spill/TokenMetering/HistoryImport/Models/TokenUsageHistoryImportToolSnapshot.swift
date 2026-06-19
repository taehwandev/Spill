import Foundation

struct TokenUsageHistoryImportToolSnapshot: Equatable, Identifiable, Sendable {
    let tool: TokenUsageHistoryImportTool
    var mode: TokenUsageHistoryImportMode
    var state: TokenUsageHistoryImportToolState
    var scannedSources: Int
    var importedEvents: Int
    var skippedDuplicates: Int
    var unsupportedRecords: Int
    var message: String?
    var lastSuccessfulImportAt: Date?
    var lastRun: TokenUsageHistoryImportLastRunSnapshot?

    var id: TokenUsageHistoryImportTool { tool }

    static func pending(
        tool: TokenUsageHistoryImportTool,
        mode: TokenUsageHistoryImportMode,
        lastSuccessfulImportAt: Date?
    ) -> Self {
        pending(tool: tool, mode: mode, lastSuccessfulImportAt: lastSuccessfulImportAt, lastRun: nil)
    }

    static func pending(
        tool: TokenUsageHistoryImportTool,
        mode: TokenUsageHistoryImportMode,
        lastSuccessfulImportAt: Date?,
        lastRun: TokenUsageHistoryImportLastRunSnapshot?
    ) -> Self {
        Self(
            tool: tool,
            mode: mode,
            state: lastRun?.state ?? .pending,
            scannedSources: lastRun?.scannedSources ?? 0,
            importedEvents: lastRun?.importedEvents ?? 0,
            skippedDuplicates: lastRun?.skippedDuplicates ?? 0,
            unsupportedRecords: lastRun?.unsupportedRecords ?? 0,
            message: lastRun?.message,
            lastSuccessfulImportAt: lastSuccessfulImportAt,
            lastRun: lastRun
        )
    }

    func preparedForRun(mode: TokenUsageHistoryImportMode) -> Self {
        Self(
            tool: tool,
            mode: mode,
            state: .pending,
            scannedSources: 0,
            importedEvents: 0,
            skippedDuplicates: 0,
            unsupportedRecords: 0,
            message: nil,
            lastSuccessfulImportAt: lastSuccessfulImportAt,
            lastRun: lastRun
        )
    }
}
