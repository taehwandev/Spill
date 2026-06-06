import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class TokenUsageStore: @unchecked Sendable {
    static let eventsDidChangeNotification = Notification.Name("app.spill.token-usage-store.events-did-change")

    private let fileURL: URL
    private let databaseURL: URL
    private let inboxURL: URL?
    private let lock = NSLock()

    init(
        fileURL: URL = TokenUsageStore.defaultEventsURL(),
        inboxURL: URL? = nil
    ) {
        self.fileURL = fileURL
        self.databaseURL = Self.defaultDatabaseURL(for: fileURL)
        self.inboxURL = inboxURL
    }

    var eventsFileURL: URL {
        fileURL
    }

    var eventsDatabaseURL: URL {
        databaseURL
    }

    var eventsInboxURL: URL? {
        inboxURL
    }

    func loadEvents() -> [TokenUsageEvent] {
        lock.withLock {
            readEventsWithoutLock()
        }
    }

    @discardableResult
    func importQueuedEvents() -> [TokenUsageEvent] {
        let result = lock.withLock {
            importQueuedEventsWithoutLock()
        }

        if result.didImportQueuedEvents {
            postEventsDidChange()
        }

        return result.events
    }

    @discardableResult
    func replaceEvents(_ events: [TokenUsageEvent]) throws -> [TokenUsageEvent] {
        let replacedEvents = try lock.withLock {
            for event in events {
                try event.validate()
            }

            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try replaceDatabaseEvents(events, database: database)
            try removeLegacyEventsFileWithoutLock()
            return loadDatabaseEvents(database: database)
        }

        postEventsDidChange()
        return replacedEvents
    }

    @discardableResult
    func appendEvent(_ event: TokenUsageEvent) throws -> [TokenUsageEvent] {
        let nextEvents = try lock.withLock {
            try event.validate()
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            _ = try migrateLegacyJSONEventsIfNeeded(database: database)
            try insertEvent(event, database: database)
            return loadDatabaseEvents(database: database)
        }

        postEventsDidChange()
        return nextEvents
    }

    func clearEvents() throws {
        try lock.withLock {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            try execute("DELETE FROM token_usage_events", database: database)
            try removeLegacyEventsFileWithoutLock()
            if let inboxURL, FileManager.default.fileExists(atPath: inboxURL.path) {
                try FileManager.default.removeItem(at: inboxURL)
            }
            if let legacyInboxURL = legacyJSONLInboxURL(),
               FileManager.default.fileExists(atPath: legacyInboxURL.path) {
                try FileManager.default.removeItem(at: legacyInboxURL)
            }
        }

        postEventsDidChange()
    }

    func enqueueInboxEvent(_ event: TokenUsageEvent) throws {
        let inboxURL = inboxURL ?? Self.defaultInboxURL()

        try lock.withLock {
            try event.validate()
            try FileManager.default.createDirectory(
                at: inboxURL,
                withIntermediateDirectories: true
            )

            let eventID = UUID().uuidString.lowercased()
            let temporaryURL = inboxURL.appendingPathComponent(".\(eventID).tmp")
            let finalURL = inboxURL.appendingPathComponent("\(eventID).json")
            let data = try TokenUsageSanitizer.eventData(event)

            try data.write(to: temporaryURL, options: [.withoutOverwriting])
            try FileManager.default.moveItem(at: temporaryURL, to: finalURL)
        }
    }

    func envelopeData() throws -> Data {
        try TokenUsageSanitizer.envelopeData(events: loadEvents())
    }

    static func defaultEventsURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return baseURL
            .appendingPathComponent("Spill", isDirectory: true)
            .appendingPathComponent("token-metering", isDirectory: true)
            .appendingPathComponent("events.json")
    }

    static func defaultDatabaseURL() -> URL {
        defaultDatabaseURL(for: defaultEventsURL())
    }

    static func defaultInboxURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return baseURL
            .appendingPathComponent("Spill", isDirectory: true)
            .appendingPathComponent("token-metering", isDirectory: true)
            .appendingPathComponent("events-inbox", isDirectory: true)
    }

    static func live() -> TokenUsageStore {
        TokenUsageStore(
            fileURL: defaultEventsURL(),
            inboxURL: defaultInboxURL()
        )
    }

    private func readEventsWithoutLock() -> [TokenUsageEvent] {
        let database: OpaquePointer
        do {
            database = try openDatabase()
        } catch {
            return []
        }
        defer { sqlite3_close(database) }

        return loadDatabaseEvents(database: database)
    }

    private func importQueuedEventsWithoutLock() -> StoreLoadResult {
        let database: OpaquePointer
        do {
            database = try openDatabase()
        } catch {
            return StoreLoadResult(events: [], didImportQueuedEvents: false)
        }
        defer { sqlite3_close(database) }

        let didMigrateLegacyEvents = (try? migrateLegacyJSONEventsIfNeeded(database: database)) ?? false
        let inboxResult = loadInboxEvents()
        var didImportQueuedEvents = didMigrateLegacyEvents

        if !inboxResult.consumedURLs.isEmpty {
            do {
                try insertEvents(inboxResult.events, database: database)
                removeConsumedInboxFiles(inboxResult.consumedURLs)
                didImportQueuedEvents = true
            } catch {
                didImportQueuedEvents = false
            }
        }

        return StoreLoadResult(
            events: loadDatabaseEvents(database: database),
            didImportQueuedEvents: didImportQueuedEvents
        )
    }

    private func loadJSONEvents(from url: URL) -> [TokenUsageEvent] {
        guard let data = try? Data(contentsOf: url),
              let events = try? JSONDecoder().decode(SafeDecodableArray<TokenUsageEvent>.self, from: data).elements
        else {
            return []
        }

        return events.filter { event in
            do {
                try event.validate()
                return true
            } catch {
                return false
            }
        }
    }

    private func loadInboxEvents() -> InboxReadResult {
        var events = [TokenUsageEvent]()
        var consumedURLs = [URL]()

        if let inboxURL,
           let urls = try? FileManager.default.contentsOfDirectory(
            at: inboxURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
           ) {
            for url in urls
                .filter({ $0.pathExtension == "json" })
                .sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                if let event = loadInboxEvent(from: url) {
                    events.append(event)
                }
                consumedURLs.append(url)
            }
        }

        if let legacyInboxURL = legacyJSONLInboxURL(),
           let legacyEvents = loadLegacyJSONLInboxEvents(from: legacyInboxURL) {
            events.append(contentsOf: legacyEvents)
            consumedURLs.append(legacyInboxURL)
        }

        return InboxReadResult(events: events, consumedURLs: consumedURLs)
    }

    private func loadInboxEvent(from url: URL) -> TokenUsageEvent? {
        guard let data = try? Data(contentsOf: url),
              let event = try? TokenUsageSanitizer.sanitizeEventJSONData(data)
        else {
            return nil
        }

        return event
    }

    private func loadLegacyJSONLInboxEvents(from url: URL) -> [TokenUsageEvent]? {
        guard let data = try? Data(contentsOf: url),
              let contents = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return contents
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> TokenUsageEvent? in
                guard let data = String(line).data(using: .utf8) else {
                    return nil
                }

                return try? TokenUsageSanitizer.sanitizeEventJSONData(data)
            }
    }

    private func removeConsumedInboxFiles(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func legacyJSONLInboxURL() -> URL? {
        guard let inboxURL else {
            return nil
        }

        return inboxURL
            .deletingLastPathComponent()
            .appendingPathComponent("events-inbox.jsonl")
    }

    private func openDatabase() throws -> OpaquePointer {
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var database: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(databaseURL.path, &database, flags, nil) == SQLITE_OK,
              let database
        else {
            defer { sqlite3_close(database) }
            throw TokenUsageStoreError.databaseOpenFailed
        }

        do {
            try execute("PRAGMA journal_mode = WAL", database: database)
            try execute("PRAGMA synchronous = NORMAL", database: database)
            try execute("PRAGMA busy_timeout = 5000", database: database)
            try execute(
                """
                CREATE TABLE IF NOT EXISTS token_usage_events (
                    span_id TEXT PRIMARY KEY NOT NULL,
                    run_id TEXT,
                    created_at TEXT NOT NULL,
                    ai_tool TEXT NOT NULL,
                    task_type TEXT,
                    stage TEXT,
                    model TEXT,
                    total_tokens INTEGER NOT NULL,
                    payload_json BLOB NOT NULL
                )
                """,
                database: database
            )
            try ensureDashboardColumns(database: database)
            try backfillDashboardColumns(database: database)
            try execute(
                """
                CREATE INDEX IF NOT EXISTS idx_token_usage_events_created_at
                ON token_usage_events(created_at)
                """,
                database: database
            )
            try execute(
                """
                CREATE INDEX IF NOT EXISTS idx_token_usage_events_tool_created_at
                ON token_usage_events(ai_tool, created_at)
                """,
                database: database
            )
            try execute(
                """
                CREATE INDEX IF NOT EXISTS idx_token_usage_events_task_type_created_at
                ON token_usage_events(task_type, created_at)
                """,
                database: database
            )
            try execute(
                """
                CREATE INDEX IF NOT EXISTS idx_token_usage_events_stage_created_at
                ON token_usage_events(stage, created_at)
                """,
                database: database
            )
            try execute(
                """
                CREATE INDEX IF NOT EXISTS idx_token_usage_events_model_created_at
                ON token_usage_events(model, created_at)
                """,
                database: database
            )
            try execute(
                """
                CREATE INDEX IF NOT EXISTS idx_token_usage_events_run_id
                ON token_usage_events(run_id)
                """,
                database: database
            )
            return database
        } catch {
            sqlite3_close(database)
            throw error
        }
    }

    private func execute(_ sql: String, database: OpaquePointer) throws {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw TokenUsageStoreError.databaseWriteFailed
        }
    }

    private func ensureDashboardColumns(database: OpaquePointer) throws {
        let existingColumns = databaseColumns(tableName: "token_usage_events", database: database)
        let requiredColumns: [(name: String, definition: String)] = [
            ("run_id", "TEXT"),
            ("task_type", "TEXT"),
            ("stage", "TEXT"),
            ("model", "TEXT")
        ]

        for column in requiredColumns where !existingColumns.contains(column.name) {
            try execute(
                "ALTER TABLE token_usage_events ADD COLUMN \(column.name) \(column.definition)",
                database: database
            )
        }
    }

    private func databaseColumns(tableName: String, database: OpaquePointer) -> Set<String> {
        let sql = "PRAGMA table_info(\(tableName))"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        var columns = Set<String>()
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let columnName = sqlite3_column_text(statement, 1) else {
                continue
            }
            columns.insert(String(cString: columnName))
        }
        return columns
    }

    private func backfillDashboardColumns(database: OpaquePointer) throws {
        let sql = """
        SELECT span_id, payload_json
        FROM token_usage_events
        WHERE run_id IS NULL OR task_type IS NULL OR stage IS NULL OR model IS NULL
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            throw TokenUsageStoreError.databaseWriteFailed
        }
        defer { sqlite3_finalize(statement) }

        var events = [TokenUsageEvent]()
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let blob = sqlite3_column_blob(statement, 1) else {
                continue
            }
            let byteCount = Int(sqlite3_column_bytes(statement, 1))
            let data = Data(bytes: blob, count: byteCount)
            if let event = try? JSONDecoder().decode(TokenUsageEvent.self, from: data),
               (try? event.validate()) != nil {
                events.append(event)
            }
        }

        guard !events.isEmpty else {
            return
        }

        try execute("BEGIN IMMEDIATE TRANSACTION", database: database)
        do {
            for event in events {
                try updateDashboardColumns(for: event, database: database)
            }
            try execute("COMMIT", database: database)
        } catch {
            try? execute("ROLLBACK", database: database)
            throw error
        }
    }

    private func updateDashboardColumns(for event: TokenUsageEvent, database: OpaquePointer) throws {
        let sql = """
        UPDATE token_usage_events
        SET run_id = ?, task_type = ?, stage = ?, model = ?
        WHERE span_id = ?
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            throw TokenUsageStoreError.databaseWriteFailed
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, event.runID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, event.taskType.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 3, event.stage.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 4, event.model, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 5, event.spanID, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw TokenUsageStoreError.databaseWriteFailed
        }
    }

    @discardableResult
    private func migrateLegacyJSONEventsIfNeeded(database: OpaquePointer) throws -> Bool {
        let legacyEvents = loadJSONEvents(from: fileURL)
        guard !legacyEvents.isEmpty else {
            return false
        }

        try insertEvents(legacyEvents, database: database)
        try removeLegacyEventsFileWithoutLock()
        return true
    }

    private func insertEvents(_ events: [TokenUsageEvent], database: OpaquePointer) throws {
        try execute("BEGIN IMMEDIATE TRANSACTION", database: database)
        do {
            for event in events {
                try insertEvent(event, database: database)
            }
            try execute("COMMIT", database: database)
        } catch {
            try? execute("ROLLBACK", database: database)
            throw error
        }
    }

    private func replaceDatabaseEvents(_ events: [TokenUsageEvent], database: OpaquePointer) throws {
        try execute("BEGIN IMMEDIATE TRANSACTION", database: database)
        do {
            try execute("DELETE FROM token_usage_events", database: database)
            for event in events {
                try insertEvent(event, database: database)
            }
            try execute("COMMIT", database: database)
        } catch {
            try? execute("ROLLBACK", database: database)
            throw error
        }
    }

    private func insertEvent(_ event: TokenUsageEvent, database: OpaquePointer) throws {
        try event.validate()

        let sql = """
        INSERT OR IGNORE INTO token_usage_events (
            span_id,
            run_id,
            created_at,
            ai_tool,
            task_type,
            stage,
            model,
            total_tokens,
            payload_json
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            throw TokenUsageStoreError.databaseWriteFailed
        }
        defer { sqlite3_finalize(statement) }

        let payload = try TokenUsageSanitizer.eventData(event)
        sqlite3_bind_text(statement, 1, event.spanID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, event.runID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 3, event.createdAt, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 4, event.aiTool.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 5, event.taskType.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 6, event.stage.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 7, event.model, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(statement, 8, sqlite3_int64(event.totalTokens))
        _ = payload.withUnsafeBytes { buffer in
            sqlite3_bind_blob(statement, 9, buffer.baseAddress, Int32(buffer.count), SQLITE_TRANSIENT)
        }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw TokenUsageStoreError.databaseWriteFailed
        }
    }

    private func loadDatabaseEvents(database: OpaquePointer) -> [TokenUsageEvent] {
        let sql = """
        SELECT payload_json
        FROM token_usage_events
        ORDER BY created_at ASC, rowid ASC
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        var events = [TokenUsageEvent]()
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let blob = sqlite3_column_blob(statement, 0) else {
                continue
            }
            let byteCount = Int(sqlite3_column_bytes(statement, 0))
            let data = Data(bytes: blob, count: byteCount)
            if let event = try? JSONDecoder().decode(TokenUsageEvent.self, from: data),
               (try? event.validate()) != nil {
                events.append(event)
            }
        }
        return events
    }

    private func removeLegacyEventsFileWithoutLock() throws {
        if FileManager.default.fileExists(atPath: fileURL.path),
           fileURL != databaseURL {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    private static func defaultDatabaseURL(for fileURL: URL) -> URL {
        let databaseExtensions: Set<String> = ["db", "sqlite", "sqlite3"]
        if databaseExtensions.contains(fileURL.pathExtension.lowercased()) {
            return fileURL
        }
        return fileURL
            .deletingPathExtension()
            .appendingPathExtension("sqlite3")
    }

    private func postEventsDidChange() {
        NotificationCenter.default.post(
            name: Self.eventsDidChangeNotification,
            object: self
        )
    }
}

private enum TokenUsageStoreError: Error {
    case databaseOpenFailed
    case databaseWriteFailed
}

private struct InboxReadResult {
    let events: [TokenUsageEvent]
    let consumedURLs: [URL]
}

private struct StoreLoadResult {
    let events: [TokenUsageEvent]
    let didImportQueuedEvents: Bool
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}

struct SafeDecodableArray<Element: Decodable>: Decodable {
    let elements: [Element]

    private struct DummyDecodable: Decodable {}

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var elements = [Element]()
        while !container.isAtEnd {
            do {
                let element = try container.decode(Element.self)
                elements.append(element)
            } catch {
                _ = try? container.decode(DummyDecodable.self)
            }
        }
        self.elements = elements
    }
}
