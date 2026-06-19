import Foundation

struct TokenUsageAntigravityImportSummary: Equatable {
    let scannedDatabases: Int
    let scannedGenerationRows: Int
    let parsedUsageEvents: Int
    let importedEvents: Int
    let skippedDuplicateEvents: Int
    let unsupportedRecords: Int
    let splitOutputFallbackEvents: Int
    let cursorAdvancedDatabases: Int
    let failedToWriteEvents: Bool
}
