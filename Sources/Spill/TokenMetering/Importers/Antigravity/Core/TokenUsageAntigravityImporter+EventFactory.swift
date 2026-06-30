import Foundation

extension TokenUsageAntigravityImporter {
    func event(
        from record: GenerationRecord,
        source: ConversationDatabase,
        labelTimeline: LabelTimeline
    ) -> TokenUsageEvent? {
        let inputTokens = record.usage.inputTokens
        let outputTokens = record.usage.outputTokens
        guard let totalTokens = Self.safeAdd(inputTokens, outputTokens) else {
            return nil
        }
        guard totalTokens > 0 else {
            return nil
        }

        let sourceID = source.url.deletingPathExtension().lastPathComponent
        let spanHash = Self.opaqueHash("\(sourceID):\(record.index)")
        let runHash = Self.opaqueHash(sourceID)
        let label = labelTimeline.label(for: record.createdAt)

        return TokenUsageEvent(
            schemaVersion: 1,
            deviceID: "device_local",
            projectID: label.projectID,
            artifactID: "artifact_global",
            runID: "run_\(runHash)",
            spanID: "span_\(spanHash)",
            aiTool: .antigravity,
            taskType: label.taskType,
            stage: label.stage,
            model: Self.safeModel(record.usage.model),
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            totalTokens: totalTokens,
            tokenBreakdown: TokenUsageBreakdown(
                system: 0,
                user: 0,
                history: 0,
                repoContext: 0,
                toolOutput: 0,
                generatedOutput: outputTokens,
                unknown: inputTokens
            ),
            tokenAccounting: TokenUsageAccounting(
                uncachedInputTokens: record.usage.uncachedInputTokens,
                cacheReadInputTokens: record.usage.cachedInputTokens
            ),
            latencyMS: 0,
            createdAt: ISO8601DateFormatter.tokenUsage.string(from: record.createdAt)
        )
    }

    private static func safeModel(_ value: String) -> String {
        let cleaned = String(value.map { character in
            character.isLetter || character.isNumber || character == "_" || character == "." || character == ":" || character == "-"
                ? character
                : "-"
        }.prefix(80))
        return cleaned.count >= 2 ? cleaned : "antigravity-unknown"
    }
}
