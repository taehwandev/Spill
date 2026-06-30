import CryptoKit
import Foundation

extension TokenUsageClaudeCodeImporter {
    func event(from turn: AssistantTurn, labelTimeline: LabelTimeline) -> TokenUsageEvent? {
        let inputTokens = turn.inputTokens
        let outputTokens = turn.outputTokens
        guard let totalTokens = Self.safeAdd(inputTokens, outputTokens),
              totalTokens > 0
        else { return nil }

        guard let createdAt = ISO8601DateFormatter.parseTokenUsageDate(from: turn.timestamp) else {
            return nil
        }

        let model = Self.safeModel(turn.model)

        // Match Python Stop hook formula exactly:
        // "span-" + sha256(":".join([run_id, model, request_id, str(turn_index), timestamp, str(span_input), str(output)]))[:12]
        let runID = turn.sessionID
        let spanSource = [
            runID,
            model,
            turn.requestId,
            String(turn.turnIndex),
            turn.timestamp,
            String(turn.spanInputTokens),
            String(outputTokens),
        ].joined(separator: ":")
        let spanID = "span-" + SHA256.hash(data: Data(spanSource.utf8))
            .map { String(format: "%02x", $0) }.joined().prefix(12)

        let label = labelTimeline.label(for: createdAt)

        return TokenUsageEvent(
            schemaVersion: 1,
            deviceID: "device_local",
            projectID: label.projectID,
            artifactID: "artifact_global",
            runID: runID,
            spanID: spanID,
            aiTool: .claude,
            taskType: label.taskType,
            stage: label.stage,
            model: model,
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
            latencyMS: 0,
            createdAt: ISO8601DateFormatter.tokenUsage.string(from: createdAt)
        )
    }
}
