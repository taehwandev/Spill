import CryptoKit
import Foundation
import SQLite3

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

final class TokenUsageAntigravityImporter {
    private let conversationsDirectory: URL
    private let labelTimelineURL: URL
    private let diagnosticsURL: URL?
    private let stateURL: URL?
    private let fileManager: FileManager
    private let forceTemporaryCopyFallback: Bool

    init(
        conversationsDirectory: URL = TokenUsageAntigravityImporter.defaultConversationsDirectory(),
        labelTimelineURL: URL = TokenUsageAntigravityImporter.defaultLabelTimelineURL(),
        diagnosticsURL: URL? = TokenUsageAntigravityImporter.defaultDiagnosticsURL(),
        stateURL: URL? = TokenUsageAntigravityImporter.defaultStateURL(),
        fileManager: FileManager = .default,
        forceTemporaryCopyFallback: Bool = false
    ) {
        self.conversationsDirectory = conversationsDirectory
        self.labelTimelineURL = labelTimelineURL
        self.diagnosticsURL = diagnosticsURL
        self.stateURL = stateURL
        self.fileManager = fileManager
        self.forceTemporaryCopyFallback = forceTemporaryCopyFallback
    }

    @discardableResult
    func importRecentEvents(
        into store: TokenUsageStore,
        since startDate: Date,
        shouldCancel: () -> Bool = { false }
    ) -> TokenUsageAntigravityImportSummary {
        let sources = discoverConversationDatabases(modifiedSince: startDate)
        let labelTimeline = readLabelTimeline()
        var importState = readImportState()
        var scannedRows = 0
        var parsedEvents = 0
        var unsupportedRecords = 0
        var candidateEvents = [TokenUsageEvent]()
        var skippedDuplicates = 0
        var splitOutputFallbackEvents = 0
        var cursorAdvancedDatabases = Set<String>()
        var scannedDatabases = 0

        for source in sources {
            guard !shouldCancel() else {
                break
            }

            let sourceKey = Self.sourceStateKey(for: source)
            let previousMaxIndex = importState.maxGenerationIndexBySource[sourceKey]
            let readResult = readGenerationRecords(from: source, after: previousMaxIndex)
            scannedDatabases += 1
            scannedRows += readResult.scannedRowCount
            unsupportedRecords += readResult.unsupportedRecordCount
            var cancelledDuringSource = false
            var maxEventIndex: Int?

            for record in readResult.records {
                guard !shouldCancel() else {
                    cancelledDuringSource = true
                    break
                }

                if record.usage.usedSplitOutputFallback {
                    splitOutputFallbackEvents += 1
                }
                guard let event = event(from: record, source: source, labelTimeline: labelTimeline) else {
                    unsupportedRecords += 1
                    continue
                }
                parsedEvents += 1
                candidateEvents.append(event)
                maxEventIndex = max(maxEventIndex ?? record.index, record.index)
            }

            if cancelledDuringSource {
                break
            }

            if let maxEventIndex,
               maxEventIndex != previousMaxIndex,
               maxEventIndex >= 0 {
                importState.maxGenerationIndexBySource[sourceKey] = maxEventIndex
                cursorAdvancedDatabases.insert(sourceKey)
            }
        }

        guard !shouldCancel() else {
            let summary = TokenUsageAntigravityImportSummary(
                scannedDatabases: scannedDatabases,
                scannedGenerationRows: scannedRows,
                parsedUsageEvents: parsedEvents,
                importedEvents: 0,
                skippedDuplicateEvents: skippedDuplicates,
                unsupportedRecords: unsupportedRecords,
                splitOutputFallbackEvents: splitOutputFallbackEvents,
                cursorAdvancedDatabases: 0,
                failedToWriteEvents: false
            )
            writeDiagnostic(summary)
            return summary
        }

        let importedEvents: Int
        var persistedCursorAdvancedDatabases = 0
        var failedToWriteEvents = false
        do {
            importedEvents = try store.appendEventsWithoutLoading(candidateEvents)
            skippedDuplicates += candidateEvents.count - importedEvents
            writeImportState(importState)
            persistedCursorAdvancedDatabases = cursorAdvancedDatabases.count
        } catch {
            importedEvents = 0
            failedToWriteEvents = true
        }

        let summary = TokenUsageAntigravityImportSummary(
            scannedDatabases: scannedDatabases,
            scannedGenerationRows: scannedRows,
            parsedUsageEvents: parsedEvents,
            importedEvents: importedEvents,
            skippedDuplicateEvents: skippedDuplicates,
            unsupportedRecords: unsupportedRecords,
            splitOutputFallbackEvents: splitOutputFallbackEvents,
            cursorAdvancedDatabases: persistedCursorAdvancedDatabases,
            failedToWriteEvents: failedToWriteEvents
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
                  var modifiedAt = values?.contentModificationDate
            else {
                return nil
            }

            // In SQLite WAL mode, transactions update the -wal file, leaving the main .db file's modification time stale.
            // We check the corresponding -wal file if it exists, taking the maximum of the two dates to determine the true last write time.
            let walURL = url.deletingLastPathComponent().appendingPathComponent(url.lastPathComponent + "-wal")
            if let walValues = try? walURL.resourceValues(forKeys: [.contentModificationDateKey]),
               let walModifiedAt = walValues.contentModificationDate {
                modifiedAt = max(modifiedAt, walModifiedAt)
            }

            guard modifiedAt >= startDate else {
                return nil
            }
            return ConversationDatabase(url: url, modifiedAt: modifiedAt)
        }
        .sorted { $0.url.lastPathComponent < $1.url.lastPathComponent }
    }

    private func readGenerationRecords(
        from source: ConversationDatabase,
        after previousMaxIndex: Int?
    ) -> GenerationRecordReadResult {
        guard let openedDatabase = openReadableDatabase(for: source.url) else {
            return GenerationRecordReadResult(
                scannedRowCount: 0,
                unsupportedRecordCount: 0,
                records: []
            )
        }
        let database = openedDatabase.database
        defer { sqlite3_close(database) }
        defer {
            if let temporaryCopyURL = openedDatabase.temporaryCopyURL {
                try? fileManager.removeItem(at: temporaryCopyURL)
            }
        }

        let sql: String
        if previousMaxIndex != nil {
            sql = "SELECT idx, data FROM gen_metadata WHERE idx > ? ORDER BY idx"
        } else {
            sql = "SELECT idx, data FROM gen_metadata ORDER BY idx"
        }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return GenerationRecordReadResult(
                scannedRowCount: 0,
                unsupportedRecordCount: 0,
                records: []
            )
        }
        defer { sqlite3_finalize(statement) }
        if let previousMaxIndex {
            sqlite3_bind_int64(statement, 1, sqlite3_int64(previousMaxIndex))
        }

        var records = [GenerationRecord]()
        var scannedRows = 0
        var unsupportedRecords = 0
        while sqlite3_step(statement) == SQLITE_ROW {
            scannedRows += 1
            let index = Int(sqlite3_column_int64(statement, 0))
            guard let blob = sqlite3_column_blob(statement, 1) else {
                unsupportedRecords += 1
                continue
            }
            let byteCount = Int(sqlite3_column_bytes(statement, 1))
            let data = Data(bytes: blob, count: byteCount)
            if let usage = Self.usageRecord(from: data),
               let createdAt = Self.generationCreatedAt(from: data) {
                records.append(GenerationRecord(index: index, usage: usage, createdAt: createdAt))
            } else {
                unsupportedRecords += 1
            }
        }
        return GenerationRecordReadResult(
            scannedRowCount: scannedRows,
            unsupportedRecordCount: unsupportedRecords,
            records: records
        )
    }

    private func openReadableDatabase(for sourceURL: URL) -> OpenedDatabase? {
        if !forceTemporaryCopyFallback,
           let database = openSQLiteDatabase(at: sourceURL) {
            return OpenedDatabase(database: database, temporaryCopyURL: nil)
        }

        guard let temporaryCopyURL = copyDatabaseToTemporaryFile(sourceURL) else {
            return nil
        }
        guard let database = openSQLiteDatabase(at: temporaryCopyURL) else {
            try? fileManager.removeItem(at: temporaryCopyURL)
            return nil
        }
        return OpenedDatabase(database: database, temporaryCopyURL: temporaryCopyURL)
    }

    private func openSQLiteDatabase(at url: URL) -> OpaquePointer? {
        var database: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &database, flags, nil) == SQLITE_OK,
              let database
        else {
            sqlite3_close(database)
            return nil
        }
        return database
    }

    private func copyDatabaseToTemporaryFile(_ sourceURL: URL) -> URL? {
        let directoryURL = fileManager.temporaryDirectory
            .appendingPathComponent("spill-agy-import", isDirectory: true)
        let temporaryURL = directoryURL
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("db")

        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let data = try Data(contentsOf: sourceURL)
            try data.write(to: temporaryURL, options: [.atomic])
            return temporaryURL
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            return nil
        }
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
            latencyMS: 0,
            createdAt: ISO8601DateFormatter.tokenUsage.string(from: record.createdAt)
        )
    }

    private static func generationCreatedAt(from data: Data) -> Date? {
        let envelope = [UInt8](data)
        guard let generation = firstLengthDelimitedField(1, in: envelope),
              let timestampContainer = firstLengthDelimitedField(9, in: generation),
              let timestampMessage = firstLengthDelimitedField(4, in: timestampContainer),
              let seconds = firstVarintField(1, in: timestampMessage)
        else {
            return nil
        }

        let minimumSeconds: UInt64 = 946_684_800
        let maximumSeconds: UInt64 = 4_102_444_800
        guard seconds >= minimumSeconds, seconds < maximumSeconds else {
            return nil
        }
        return Date(timeIntervalSince1970: TimeInterval(seconds))
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
        // 5 = cached input, 3 = aggregate output. Some records also expose
        // split output components in 9/10; use those only when aggregate
        // output is absent so known aggregate totals remain the source of truth.
        let uncachedInput = safeToken(usageFields[2])
        let cachedInput = safeToken(usageFields[5])
        let aggregateOutput = safeToken(usageFields[3])
        guard let splitOutput = safeAdd(safeToken(usageFields[9]), safeToken(usageFields[10])) else {
            return nil
        }
        let output = aggregateOutput > 0 ? aggregateOutput : splitOutput
        let usedSplitOutputFallback = aggregateOutput == 0 && splitOutput > 0
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
        return UsageRecord(
            inputTokens: input,
            outputTokens: output,
            model: model,
            usedSplitOutputFallback: usedSplitOutputFallback
        )
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
            "unsupported_records": summary.unsupportedRecords,
            "split_output_fallback_events": summary.splitOutputFallbackEvents,
            "cursor_advanced_databases": summary.cursorAdvancedDatabases,
            "failed_to_write_events": summary.failedToWriteEvents,
            "timestamp_source": "generation_metadata_timestamp",
            "timestamp_limitation": "AGY gen_metadata rows without trusted numeric timestamps are counted as unsupported.",
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

    private static func firstVarintField(_ number: Int, in bytes: [UInt8]) -> UInt64? {
        var reader = ProtoReader(bytes)
        while let field = reader.nextField() {
            if field.number == number, case .varint(let value) = field.value {
                return value
            }
        }
        return nil
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

    private static func sourceStateKey(for source: ConversationDatabase) -> String {
        opaqueHash(source.url.deletingPathExtension().lastPathComponent)
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

    private static func defaultStateURL() -> URL {
        AppDirectories.spillApplicationSupportDirectory()
            .appendingPathComponent("token-metering", isDirectory: true)
            .appendingPathComponent("session-state", isDirectory: true)
            .appendingPathComponent("antigravity-active-importer-state.json")
    }

    private func readImportState() -> ImportState {
        guard let stateURL,
              let data = try? Data(contentsOf: stateURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawCursors = object["max_generation_index_by_source"] as? [String: Any]
        else {
            return ImportState(maxGenerationIndexBySource: [:])
        }

        var cursors = [String: Int]()
        for (key, value) in rawCursors {
            guard key.range(of: #"^[a-f0-9]{24}$"#, options: .regularExpression) != nil else {
                continue
            }
            if let intValue = value as? Int, intValue >= 0 {
                cursors[key] = intValue
            } else if let number = value as? NSNumber, number.intValue >= 0 {
                cursors[key] = number.intValue
            }
        }
        return ImportState(maxGenerationIndexBySource: cursors)
    }

    private func writeImportState(_ state: ImportState) {
        guard let stateURL else {
            return
        }

        let object: [String: Any] = [
            "schema_version": 1,
            "ai_tool": "antigravity",
            "max_generation_index_by_source": state.maxGenerationIndexBySource,
            "privacy": "Contains only opaque conversation hashes and numeric generation cursors; no paths, prompts, responses, commands, logs, diffs, source, environment values, or secrets."
        ]

        do {
            try fileManager.createDirectory(
                at: stateURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            try data.write(to: stateURL, options: [.atomic])
        } catch {
            return
        }
    }
}

private struct ConversationDatabase {
    let url: URL
    let modifiedAt: Date
}

private struct GenerationRecord {
    let index: Int
    let usage: UsageRecord
    let createdAt: Date
}

private struct GenerationRecordReadResult {
    let scannedRowCount: Int
    let unsupportedRecordCount: Int
    let records: [GenerationRecord]
}

private struct OpenedDatabase {
    let database: OpaquePointer
    let temporaryCopyURL: URL?
}

private struct UsageRecord {
    let inputTokens: Int
    let outputTokens: Int
    let model: String
    let usedSplitOutputFallback: Bool
}

private struct ImportState {
    var maxGenerationIndexBySource: [String: Int]
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
