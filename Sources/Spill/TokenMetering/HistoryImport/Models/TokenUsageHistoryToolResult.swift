import Foundation

struct TokenUsageHistoryToolResult: Equatable {
    let state: TokenUsageHistoryImportToolState
    let scannedSources: Int
    let importedEvents: Int
    let skippedDuplicates: Int
    let unsupportedRecords: Int
    let message: String?
    let failureStage: TokenUsageHistoryImportFailureStage?
    let failureReason: TokenUsageHistoryImportFailureReason?
    let exitCode: Int32?
    let timedOut: Bool
    let durationSeconds: TimeInterval?

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
            message: message,
            failureStage: nil,
            failureReason: nil,
            exitCode: nil,
            timedOut: false,
            durationSeconds: nil
        )
    }

    static func unavailable(_ message: String) -> Self {
        Self(
            state: .unavailable,
            scannedSources: 0,
            importedEvents: 0,
            skippedDuplicates: 0,
            unsupportedRecords: 0,
            message: message,
            failureStage: nil,
            failureReason: nil,
            exitCode: nil,
            timedOut: false,
            durationSeconds: nil
        )
    }

    static func failed(
        _ message: String,
        failureStage: TokenUsageHistoryImportFailureStage = .unknown,
        failureReason: TokenUsageHistoryImportFailureReason = .unknownFailed,
        exitCode: Int32? = nil,
        timedOut: Bool = false,
        durationSeconds: TimeInterval? = nil,
        scannedSources: Int = 0,
        importedEvents: Int = 0,
        skippedDuplicates: Int = 0,
        unsupportedRecords: Int = 0
    ) -> Self {
        Self(
            state: .failed,
            scannedSources: scannedSources,
            importedEvents: importedEvents,
            skippedDuplicates: skippedDuplicates,
            unsupportedRecords: unsupportedRecords,
            message: message,
            failureStage: failureStage,
            failureReason: failureReason,
            exitCode: exitCode,
            timedOut: timedOut,
            durationSeconds: durationSeconds
        )
    }

    static func cancelled(_ message: String) -> Self {
        Self(
            state: .cancelled,
            scannedSources: 0,
            importedEvents: 0,
            skippedDuplicates: 0,
            unsupportedRecords: 0,
            message: message,
            failureStage: nil,
            failureReason: nil,
            exitCode: nil,
            timedOut: false,
            durationSeconds: nil
        )
    }
}
