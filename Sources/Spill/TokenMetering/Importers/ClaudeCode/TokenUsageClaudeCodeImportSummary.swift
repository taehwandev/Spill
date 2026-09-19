import Foundation

struct TokenUsageClaudeCodeImportSummary {
    let scannedFiles: Int
    let parsedTurns: Int
    let importedEvents: Int
    let skippedDuplicateEvents: Int
    let cursorAdvancedFiles: Int
    let failedToWriteEvents: Bool
    // Turns whose event failed store validation. They are dropped one by one so
    // a single bad record cannot fail the whole batch and pin every cursor.
    var invalidEvents = 0
}
