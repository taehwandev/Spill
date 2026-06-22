import Foundation

extension TokenUsageAntigravityImporter {
    func readLabelTimeline() -> LabelTimeline {
        guard let raw = try? String(contentsOf: labelTimelineURL, encoding: .utf8) else {
            return LabelTimeline(entries: [])
        }
        let entries: [LabelTimeline.Entry] = raw
            .components(separatedBy: "\n")
            .compactMap { line -> LabelTimeline.Entry? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty,
                      let data = trimmed.data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { return nil }

                let tool = object["ai_tool"] as? String
                if let tool, !tool.isEmpty, tool != "unknown", tool != "antigravity", tool != "agy" {
                    return nil
                }

                let taskType = (object["task_type"] as? String).flatMap(TokenUsageTaskType.init(rawValue:))
                let stage = (object["stage"] as? String).flatMap(TokenUsageStage.init(rawValue:))
                let projectID = Self.safeOpaqueID(object["project_id"] as? String) ?? "project_global"
                guard taskType != nil || stage != nil else { return nil }

                let updatedAt = (object["updated_at"] as? String).flatMap(ISO8601DateFormatter.parseTokenUsageDate(from:))
                let expiresAt = (object["expires_at"] as? String).flatMap(ISO8601DateFormatter.parseTokenUsageDate(from:))
                guard let updatedAt, let expiresAt else { return nil }

                return LabelTimeline.Entry(
                    taskType: taskType,
                    stage: stage,
                    projectID: projectID,
                    updatedAt: updatedAt,
                    expiresAt: expiresAt
                )
            }
        return LabelTimeline(entries: entries)
    }

    private static func safeOpaqueID(_ value: String?) -> String? {
        guard let value,
              value.range(of: #"^[A-Za-z0-9_-]{6,64}$"#, options: .regularExpression) != nil
        else {
            return nil
        }
        return value
    }
    struct LabelTimeline {
        struct Entry {
            let taskType: TokenUsageTaskType?
            let stage: TokenUsageStage?
            let projectID: String
            let updatedAt: Date
            let expiresAt: Date
        }

        let entries: [Entry]

        func label(for timestamp: Date) -> RuntimeEventLabel {
            let match = entries
                .filter { $0.updatedAt <= timestamp && timestamp <= $0.expiresAt }
                .max(by: { $0.updatedAt < $1.updatedAt })
            return RuntimeEventLabel(
                taskType: match?.taskType ?? .uncategorized,
                stage: match?.stage ?? .summarize,
                projectID: match?.projectID ?? "project_global"
            )
        }
    }
}
