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
        /// Longest `expiresAt - updatedAt` span; bounds how far back a lookup must look.
        private let maximumSpan: TimeInterval

        init(entries: [Entry], isSorted: Bool = false) {
            self.entries = isSorted ? entries : Self.sorted(entries)
            maximumSpan = entries.reduce(0) { max($0, $1.expiresAt.timeIntervalSince($1.updatedAt)) }
        }

        static func sorted(_ entries: [Entry]) -> [Entry] {
            entries.sorted { lhs, rhs in
                lhs.updatedAt < rhs.updatedAt
            }
        }

        /// The latest-updated entry whose window covers `timestamp`. A history can hold
        /// hundreds of thousands of entries, so this binary-searches the last entry updated at
        /// or before `timestamp` and walks back only while an earlier window could still cover it.
        func label(for timestamp: Date) -> EventLabel {
            var low = 0
            var high = entries.count
            while low < high {
                let middle = (low + high) / 2
                if entries[middle].updatedAt <= timestamp {
                    low = middle + 1
                } else {
                    high = middle
                }
            }
            let earliestCoveringUpdate = timestamp.addingTimeInterval(-maximumSpan)
            var match: Entry?
            var index = low - 1
            while index >= 0, entries[index].updatedAt >= earliestCoveringUpdate {
                if timestamp <= entries[index].expiresAt {
                    match = entries[index]
                    break
                }
                index -= 1
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
        /// Kept sorted by `updatedAt` so each import does not re-sort the whole history.
        var completedEntries: [LabelTimeline.Entry] = []
        var pendingLineData = Data()

        mutating func appendEntries(_ newEntries: [LabelTimeline.Entry]) {
            guard !newEntries.isEmpty else {
                return
            }
            let sortedNewEntries = LabelTimeline.sorted(newEntries)
            if let last = completedEntries.last, let first = sortedNewEntries.first, first.updatedAt < last.updatedAt {
                completedEntries = LabelTimeline.sorted(completedEntries + sortedNewEntries)
            } else {
                completedEntries.append(contentsOf: sortedNewEntries)
            }
        }
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

        // Prepend a carried partial line only when there is one; otherwise this would copy the
        // whole appended read (tens of MB on a first launch) just to concatenate nothing.
        let combinedData: Data
        if labelTimelineCache.pendingLineData.isEmpty {
            combinedData = appendedData
        } else {
            var joined = labelTimelineCache.pendingLineData
            joined.append(appendedData)
            combinedData = joined
        }
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

        // Parse in bounded batches so the Foundation objects JSONSerialization autoreleases
        // for a large first read are freed as we go instead of piling up until the task ends.
        var parsedEntries = [LabelTimeline.Entry]()
        var batchStart = lineSegments.startIndex
        while batchStart < lineSegments.endIndex {
            let batchEnd = lineSegments.index(batchStart, offsetBy: 1_000, limitedBy: lineSegments.endIndex)
                ?? lineSegments.endIndex
            autoreleasepool {
                for segment in lineSegments[batchStart..<batchEnd] {
                    if let entry = parseLabelTimelineEntry(from: Data(segment)) {
                        parsedEntries.append(entry)
                    }
                }
            }
            batchStart = batchEnd
        }
        labelTimelineCache.appendEntries(parsedEntries)
        return cachedLabelTimeline()
    }

    private func cachedLabelTimeline() -> LabelTimeline {
        guard let pendingEntry = parseLabelTimelineEntry(from: labelTimelineCache.pendingLineData) else {
            return LabelTimeline(entries: labelTimelineCache.completedEntries, isSorted: true)
        }
        var entries = labelTimelineCache.completedEntries
        entries.append(pendingEntry)
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
