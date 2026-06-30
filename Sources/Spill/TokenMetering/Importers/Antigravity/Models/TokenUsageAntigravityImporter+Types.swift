import Foundation
import SQLite3

extension TokenUsageAntigravityImporter {
    struct ConversationDatabase {
        let url: URL
        let modifiedAt: Date
    }

    struct GenerationRecord {
        let index: Int
        let usage: UsageRecord
        let createdAt: Date
    }

    struct GenerationRecordReadResult {
        let scannedRowCount: Int
        let unsupportedRecordCount: Int
        let records: [GenerationRecord]
    }

    struct OpenedDatabase {
        let database: OpaquePointer
        let temporaryCopyURLs: [URL]
    }

    struct UsageRecord {
        let inputTokens: Int
        let uncachedInputTokens: Int
        let cachedInputTokens: Int
        let outputTokens: Int
        let model: String
        let usedSplitOutputFallback: Bool
    }

    struct ImportState {
        var maxGenerationIndexBySource: [String: Int]
    }

    struct RuntimeEventLabel {
        let taskType: TokenUsageTaskType
        let stage: TokenUsageStage
        let projectID: String
    }
}
