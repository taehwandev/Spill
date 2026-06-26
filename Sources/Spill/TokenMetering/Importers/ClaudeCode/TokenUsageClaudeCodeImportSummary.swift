import Foundation

struct TokenUsageClaudeCodeImportSummary {
    let scannedFiles: Int
    let parsedTurns: Int
    let importedEvents: Int
    let skippedDuplicateEvents: Int
    let cursorAdvancedFiles: Int
    let failedToWriteEvents: Bool
}
