import Foundation

extension TokenUsageClaudeCodeImporter {
    struct LabelTimeline {
        struct Entry {
            let taskType: TokenUsageTaskType?
            let stage: TokenUsageStage?
            let projectID: String
            let updatedAt: Date
            let expiresAt: Date
        }

        let entries: [Entry]

        init(entries: [Entry]) {
            self.entries = entries.sorted { lhs, rhs in
                lhs.updatedAt < rhs.updatedAt
            }
        }

        func label(for timestamp: Date) -> EventLabel {
            let match = entries.last {
                $0.updatedAt <= timestamp && timestamp <= $0.expiresAt
            }
            return EventLabel(
                taskType: match?.taskType ?? .uncategorized,
                stage: match?.stage ?? .summarize,
                projectID: match?.projectID ?? "project_global"
            )
        }
    }

    struct LabelTimelineCache {
        var fileID: UInt64?
        var byteOffset: UInt64 = 0
        var completedEntries: [LabelTimeline.Entry] = []
        var pendingLineData = Data()
    }

    struct EventLabel {
        let taskType: TokenUsageTaskType
        let stage: TokenUsageStage
        let projectID: String
    }

    func readLabelTimeline() -> LabelTimeline {
        guard let attributes = try? fileManager.attributesOfItem(atPath: labelTimelineURL.path),
              let fileSize = (attributes[.size] as? NSNumber)?.uint64Value
        else {
            labelTimelineCache = LabelTimelineCache()
            return LabelTimeline(entries: [])
        }

        let fileID = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value
        if labelTimelineCache.fileID != fileID || labelTimelineCache.byteOffset > fileSize {
            labelTimelineCache = LabelTimelineCache(fileID: fileID)
        } else if labelTimelineCache.fileID == nil {
            labelTimelineCache.fileID = fileID
        }

        guard labelTimelineCache.byteOffset < fileSize,
              let handle = try? FileHandle(forReadingFrom: labelTimelineURL)
        else {
            return cachedLabelTimeline()
        }
        defer { try? handle.close() }

        guard (try? handle.seek(toOffset: labelTimelineCache.byteOffset)) != nil,
              let appendedData = try? handle.readToEnd(),
              !appendedData.isEmpty
        else {
            return cachedLabelTimeline()
        }

        labelTimelineCache.byteOffset += UInt64(appendedData.count)
        labelTimelineBytesRead += appendedData.count

        var combinedData = labelTimelineCache.pendingLineData
        combinedData.append(appendedData)
        var lineSegments = combinedData.split(
            separator: UInt8(ascii: "\n"),
            omittingEmptySubsequences: false
        )

        if combinedData.last == UInt8(ascii: "\n") {
            _ = lineSegments.popLast()
            labelTimelineCache.pendingLineData = Data()
        } else {
            labelTimelineCache.pendingLineData = Data(lineSegments.popLast() ?? Data.SubSequence())
        }

        labelTimelineCache.completedEntries.append(contentsOf: lineSegments.compactMap {
            parseLabelTimelineEntry(from: Data($0))
        })
        return cachedLabelTimeline()
    }

    private func cachedLabelTimeline() -> LabelTimeline {
        var entries = labelTimelineCache.completedEntries
        if let pendingEntry = parseLabelTimelineEntry(from: labelTimelineCache.pendingLineData) {
            entries.append(pendingEntry)
        }
        return LabelTimeline(entries: entries)
    }

    private func parseLabelTimelineEntry(from lineData: Data) -> LabelTimeline.Entry? {
        guard let line = String(data: lineData, encoding: .utf8) else {
            return nil
        }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        let tool = object["ai_tool"] as? String
        if let tool, !tool.isEmpty, tool != "unknown", tool != "claude" {
            return nil
        }

        let taskType = (object["task_type"] as? String).flatMap(TokenUsageTaskType.init(rawValue:))
        let stage = (object["stage"] as? String).flatMap(TokenUsageStage.init(rawValue:))
        guard taskType != nil || stage != nil else { return nil }

        let projectID = safeOpaqueID(object["project_id"] as? String) ?? "project_global"
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

    private func safeOpaqueID(_ value: String?) -> String? {
        guard let value,
              value.range(of: #"^[A-Za-z0-9_-]{6,64}$"#, options: .regularExpression) != nil
        else { return nil }
        return value
    }
}
