import CryptoKit
import Foundation
import SQLite3

struct TokenUsageAntigravityImportSummary: Equatable {
    let scannedDatabases: Int
    let scannedGenerationRows: Int
    let parsedUsageEvents: Int
    let importedEvents: Int
    let skippedDuplicateEvents: Int
}

final class TokenUsageAntigravityImporter {
    private let conversationsDirectory: URL
    private let labelTimelineURL: URL
    private let diagnosticsURL: URL?
    private let fileManager: FileManager

    init(
        conversationsDirectory: URL = TokenUsageAntigravityImporter.defaultConversationsDirectory(),
        labelTimelineURL: URL = TokenUsageAntigravityImporter.defaultLabelTimelineURL(),
        diagnosticsURL: URL? = TokenUsageAntigravityImporter.defaultDiagnosticsURL(),
        fileManager: FileManager = .default
    ) {
        self.conversationsDirectory = conversationsDirectory
        self.labelTimelineURL = labelTimelineURL
        self.diagnosticsURL = diagnosticsURL
        self.fileManager = fileManager
    }

    @discardableResult
    func importRecentEvents(into store: TokenUsageStore, since startDate: Date) -> TokenUsageAntigravityImportSummary {
        let sources = discoverConversationDatabases(modifiedSince: startDate)
        let labelTimeline = readLabelTimeline()
        var knownSpanIDs = store.existingSpanIDs()
        var scannedRows = 0
        var parsedEvents = 0
        var candidateEvents = [TokenUsageEvent]()
        var skippedDuplicates = 0

        for source in sources {
            let records = readGenerationRecords(from: source)
            scannedRows += records.count

            for record in records {
                guard let event = event(from: record, source: source, labelTimeline: labelTimeline) else {
                    continue
                }
                parsedEvents += 1

                guard !knownSpanIDs.contains(event.spanID) else {
                    skippedDuplicates += 1
                    continue
                }

                knownSpanIDs.insert(event.spanID)
                candidateEvents.append(event)
            }
        }

        let importedEvents = (try? store.appendEventsWithoutLoading(candidateEvents)) ?? 0
        skippedDuplicates += candidateEvents.count - importedEvents

        let summary = TokenUsageAntigravityImportSummary(
            scannedDatabases: sources.count,
            scannedGenerationRows: scannedRows,
            parsedUsageEvents: parsedEvents,
            importedEvents: importedEvents,
            skippedDuplicateEvents: skippedDuplicates
        )
        writeDiagnostic(summary)
        return summary
    }

    private func discoverConversationDatabases(modifiedSince startDate: Date) -> [ConversationDatabase] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: conversationsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls.compactMap { url -> ConversationDatabase? in
            guard url.pathExtension == "db" else {
                return nil
            }
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            guard values?.isRegularFile == true,
                  let modifiedAt = values?.contentModificationDate,
                  modifiedAt >= startDate
            else {
                return nil
            }
            return ConversationDatabase(url: url, modifiedAt: modifiedAt)
        }
        .sorted { $0.url.lastPathComponent < $1.url.lastPathComponent }
    }

    private func readGenerationRecords(from source: ConversationDatabase) -> [GenerationRecord] {
        var database: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(source.url.path, &database, flags, nil) == SQLITE_OK,
              let database
        else {
            sqlite3_close(database)
            return []
        }
        defer { sqlite3_close(database) }

        let sql = "SELECT idx, data FROM gen_metadata ORDER BY idx"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        var records = [GenerationRecord]()
        while sqlite3_step(statement) == SQLITE_ROW {
            let index = Int(sqlite3_column_int64(statement, 0))
            guard let blob = sqlite3_column_blob(statement, 1) else {
                continue
            }
            let byteCount = Int(sqlite3_column_bytes(statement, 1))
            let data = Data(bytes: blob, count: byteCount)
            if let usage = Self.usageRecord(from: data) {
                records.append(GenerationRecord(index: index, usage: usage))
            }
        }
        return records
    }

    private func event(
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
        // AGY gen_metadata rows observed so far expose idx/data/size but no
        // trusted per-row timestamp. Use the database mtime as a coarse
        // createdAt and label lookup timestamp until AGY exposes a row-level
        // timestamp in the same token-only metadata source.
        let label = labelTimeline.label(for: source.modifiedAt)

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
            latencyMS: 0,
            createdAt: ISO8601DateFormatter.tokenUsage.string(from: source.modifiedAt)
        )
    }

    private static func usageRecord(from data: Data) -> UsageRecord? {
        let envelope = [UInt8](data)
        guard let generation = firstLengthDelimitedField(1, in: envelope),
              let usage = firstLengthDelimitedField(4, in: generation)
        else {
            return nil
        }

        let usageFields = varintFieldTotals(in: usage)
        // Observed AGY gen_metadata usage fields: 2 = uncached input,
        // 5 = cached input, 3 = aggregate output.
        let uncachedInput = safeToken(usageFields[2])
        let cachedInput = safeToken(usageFields[5])
        let output = safeToken(usageFields[3])
        guard let input = safeAdd(uncachedInput, cachedInput) else {
            return nil
        }
        guard input > 0 || output > 0 else {
            return nil
        }

        let request = firstLengthDelimitedField(3, in: envelope)
        // Observed AGY model fields: generation.19 is preferred, request.28 is
        // a fallback when the generation envelope omits the model string.
        let model = firstUTF8Field(19, in: generation)
            ?? request.flatMap { firstUTF8Field(28, in: $0) }
            ?? "antigravity-unknown"
        return UsageRecord(inputTokens: input, outputTokens: output, model: model)
    }

    private func readLabelTimeline() -> LabelTimeline {
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

    private func writeDiagnostic(_ summary: TokenUsageAntigravityImportSummary) {
        guard let diagnosticsURL else {
            return
        }

        let object: [String: Any] = [
            "schema_version": 1,
            "ai_tool": "antigravity",
            "kind": "active_importer_scan",
            "created_at": ISO8601DateFormatter.tokenUsage.string(from: Date()),
            "scanned_databases": summary.scannedDatabases,
            "scanned_generation_rows": summary.scannedGenerationRows,
            "parsed_usage_events": summary.parsedUsageEvents,
            "imported_events": summary.importedEvents,
            "skipped_duplicate_events": summary.skippedDuplicateEvents,
            "timestamp_source": "conversation_database_mtime",
            "timestamp_limitation": "AGY gen_metadata rows observed by this importer expose no trusted per-row timestamp.",
            "privacy": "No payload values, prompts, responses, commands, file paths, logs, diffs, source, environment values, or secrets are stored."
        ]

        do {
            try fileManager.createDirectory(
                at: diagnosticsURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            try data.write(to: diagnosticsURL, options: [.atomic])
        } catch {
            return
        }
    }

    private static func firstLengthDelimitedField(_ number: Int, in bytes: [UInt8]) -> [UInt8]? {
        var reader = ProtoReader(bytes)
        while let field = reader.nextField() {
            if field.number == number, case .bytes(let value) = field.value {
                return value
            }
        }
        return nil
    }

    private static func firstUTF8Field(_ number: Int, in bytes: [UInt8]) -> String? {
        guard let value = firstLengthDelimitedField(number, in: bytes),
              let string = String(bytes: value, encoding: .utf8)
        else {
            return nil
        }
        return string.range(of: #"^[A-Za-z0-9_.:-]{2,80}$"#, options: .regularExpression) != nil ? string : nil
    }

    private static func varintFieldTotals(in bytes: [UInt8]) -> [Int: UInt64] {
        var reader = ProtoReader(bytes)
        var fields = [Int: UInt64]()
        while let field = reader.nextField() {
            if case .varint(let value) = field.value {
                let current = fields[field.number] ?? 0
                let sum = current.addingReportingOverflow(value)
                fields[field.number] = sum.overflow ? UInt64.max : sum.partialValue
            }
        }
        return fields
    }

    private static func safeToken(_ value: UInt64?) -> Int {
        guard let value else {
            return 0
        }
        return value > UInt64(Int.max) ? Int.max : Int(value)
    }

    private static func safeAdd(_ lhs: Int, _ rhs: Int) -> Int? {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? nil : result.partialValue
    }

    private static func safeModel(_ value: String) -> String {
        let cleaned = String(value.map { character in
            character.isLetter || character.isNumber || character == "_" || character == "." || character == ":" || character == "-"
                ? character
                : "-"
        }.prefix(80))
        return cleaned.count >= 2 ? cleaned : "antigravity-unknown"
    }

    private static func safeOpaqueID(_ value: String?) -> String? {
        guard let value,
              value.range(of: #"^[A-Za-z0-9_-]{6,64}$"#, options: .regularExpression) != nil
        else {
            return nil
        }
        return value
    }

    private static func opaqueHash(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined().prefix(24).description
    }

    private static func defaultConversationsDirectory() -> URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".gemini", isDirectory: true)
            .appendingPathComponent("antigravity-cli", isDirectory: true)
            .appendingPathComponent("conversations", isDirectory: true)
    }

    private static func defaultLabelTimelineURL() -> URL {
        AppDirectories.spillApplicationSupportDirectory()
            .appendingPathComponent("token-metering", isDirectory: true)
            .appendingPathComponent("label-context", isDirectory: true)
            .appendingPathComponent("antigravity-timeline.jsonl")
    }

    private static func defaultDiagnosticsURL() -> URL {
        AppDirectories.spillApplicationSupportDirectory()
            .appendingPathComponent("token-metering", isDirectory: true)
            .appendingPathComponent("diagnostics", isDirectory: true)
            .appendingPathComponent("antigravity-active-importer-last.json")
    }
}

private struct ConversationDatabase {
    let url: URL
    let modifiedAt: Date
}

private struct GenerationRecord {
    let index: Int
    let usage: UsageRecord
}

private struct UsageRecord {
    let inputTokens: Int
    let outputTokens: Int
    let model: String
}

private struct LabelTimeline {
    struct Entry {
        let taskType: TokenUsageTaskType?
        let stage: TokenUsageStage?
        let projectID: String
        let updatedAt: Date
        let expiresAt: Date
    }

    let entries: [Entry]

    /// Returns the label whose [updatedAt, expiresAt] window contains `timestamp`.
    /// When multiple entries overlap, the one with the latest updatedAt wins.
    /// Falls back to uncategorized/summarize when no entry matches.
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

private struct RuntimeEventLabel {
    let taskType: TokenUsageTaskType
    let stage: TokenUsageStage
    let projectID: String
}

private struct ProtoReader {
    private let bytes: [UInt8]
    private var index = 0

    init(_ bytes: [UInt8]) {
        self.bytes = bytes
    }

    mutating func nextField() -> ProtoField? {
        guard let key = readVarint(), key > 0 else {
            return nil
        }
        let number = Int(key >> 3)
        let wireType = Int(key & 0x7)

        switch wireType {
        case 0:
            guard let value = readVarint() else {
                return nil
            }
            return ProtoField(number: number, value: .varint(value))
        case 1:
            guard skip(byteCount: 8) else {
                return nil
            }
            return ProtoField(number: number, value: .fixed)
        case 2:
            guard let length = readVarint(),
                  length <= UInt64(Int.max),
                  index + Int(length) <= bytes.count
            else {
                return nil
            }
            let start = index
            index += Int(length)
            return ProtoField(number: number, value: .bytes(Array(bytes[start..<index])))
        case 5:
            guard skip(byteCount: 4) else {
                return nil
            }
            return ProtoField(number: number, value: .fixed)
        default:
            return nil
        }
    }

    private mutating func readVarint() -> UInt64? {
        var shift: UInt64 = 0
        var value: UInt64 = 0
        var count = 0

        while index < bytes.count, count < 10 {
            let byte = bytes[index]
            index += 1
            value |= UInt64(byte & 0x7f) << shift
            if byte & 0x80 == 0 {
                return value
            }
            shift += 7
            count += 1
        }

        return nil
    }

    private mutating func skip(byteCount: Int) -> Bool {
        guard index + byteCount <= bytes.count else {
            return false
        }
        index += byteCount
        return true
    }
}

private struct ProtoField {
    let number: Int
    let value: ProtoValue
}

private enum ProtoValue {
    case varint(UInt64)
    case bytes([UInt8])
    case fixed
}
