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

        let runID = turn.sessionID
        // When requestId is present, omit turnIndex and timestamp from the span_id hash.
        // Bug #2: Claude Code writes the same requestId 2-3x per turn with slightly different
        // timestamps. Including timestamp or turnIndex would make each occurrence hash to a
        // different span_id, defeating the DB PRIMARY KEY dedup. The requestId alone is a
        // stable unique key for the turn; spanInputTokens and outputTokens guard against
        // accidental collisions across turns that share a requestId format.
        let spanSource: String
        if !turn.requestId.isEmpty {
            spanSource = [runID, model, turn.requestId,
                          String(turn.spanInputTokens), String(outputTokens)].joined(separator: ":")
        } else {
            spanSource = [runID, model, "", String(turn.turnIndex), turn.timestamp,
                          String(turn.spanInputTokens), String(outputTokens)].joined(separator: ":")
        }
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
            tokenAccounting: turn.tokenAccounting,
            latencyMS: 0,
            createdAt: ISO8601DateFormatter.tokenUsage.string(from: createdAt)
        )
    }
}
