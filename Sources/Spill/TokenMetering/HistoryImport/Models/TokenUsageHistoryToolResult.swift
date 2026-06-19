import Foundation

struct TokenUsageHistoryToolResult {
    let state: TokenUsageHistoryImportToolState
    let scannedSources: Int
    let importedEvents: Int
    let skippedDuplicates: Int
    let unsupportedRecords: Int
    let message: String?

    static func completed(
        scannedSources: Int,
        importedEvents: Int,
        skippedDuplicates: Int,
        unsupportedRecords: Int,
        message: String?
    ) -> Self {
        Self(
            state: .completed,
            scannedSources: scannedSources,
            importedEvents: importedEvents,
            skippedDuplicates: skippedDuplicates,
            unsupportedRecords: unsupportedRecords,
            message: message
        )
    }

    static func unavailable(_ message: String) -> Self {
        Self(
            state: .unavailable,
            scannedSources: 0,
            importedEvents: 0,
            skippedDuplicates: 0,
            unsupportedRecords: 0,
            message: message
        )
    }

    static func failed(_ message: String) -> Self {
        Self(
            state: .failed,
            scannedSources: 0,
            importedEvents: 0,
            skippedDuplicates: 0,
            unsupportedRecords: 0,
            message: message
        )
    }

    static func cancelled(_ message: String) -> Self {
        Self(
            state: .cancelled,
            scannedSources: 0,
            importedEvents: 0,
            skippedDuplicates: 0,
            unsupportedRecords: 0,
            message: message
        )
    }
}
