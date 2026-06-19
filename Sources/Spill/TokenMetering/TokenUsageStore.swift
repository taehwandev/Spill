import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class TokenUsageStore: @unchecked Sendable {
    static let eventsDidChangeNotification = Notification.Name("app.spill.token-usage-store.events-did-change")
    static let distributedEventsDidChangeNotification = Notification.Name("app.spill.token-usage-store.events-did-change.distributed")
    static let defaultInboxImportBatchLimit = 500
    private static let eventSelectColumns = """
    span_id,
    device_id,
    project_id,
    artifact_id,
    run_id,
    created_at,
    ai_tool,
    task_type,
    stage,
    model,
    input_tokens,
    output_tokens,
    total_tokens,
    latency_ms,
    source_system,
    source_user,
    source_history,
    source_repo_context,
    source_tool_output,
    source_generated_output,
    source_unknown
    """

    private let fileURL: URL
    private let databaseURL: URL
    private let inboxURL: URL?
    private let lock = NSLock()
    private var preparedDatabaseSchemaCheckpoint: DatabaseSchemaCheckpoint?

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

    private var tokenMeteringDirectory: URL {
        fileURL.deletingLastPathComponent()
    }

    func loadEvents() -> [TokenUsageEvent] {
        lock.withLock {
            readEventsWithoutLock()
        }
    }

    func loadEvents(
        startingAt startDate: Date?,
        endingBefore endDate: Date?
    ) -> [TokenUsageEvent] {
        lock.withLock {
            let database: OpaquePointer
            do {
                database = try openDatabase()
            } catch {
                return []
            }
            defer { sqlite3_close(database) }

            return loadDatabaseEvents(
                startingAt: startDate,
                endingBefore: endDate,
                database: database
            )
        }
    }

    @discardableResult
    func importQueuedEvents() -> [TokenUsageEvent] {
        let inboxResult = loadInboxEvents(maximumEventCount: nil)
        let result = lock.withLock {
            importQueuedEventsWithoutLock(loadEvents: true, inboxResult: inboxResult)
        }

        if result.didImportQueuedEvents {
            postEventsDidChange()
        }

        return result.events
    }

    @discardableResult
    func importQueuedEventsWithoutLoading(
        maximumInboxEventCount: Int? = 500
    ) -> Bool {
        let inboxResult = loadInboxEvents(maximumEventCount: maximumInboxEventCount)
        let didImportQueuedEvents = lock.withLock {
            importQueuedEventsWithoutLock(loadEvents: false, inboxResult: inboxResult).didImportQueuedEvents
        }

        if didImportQueuedEvents {
            postEventsDidChange()
        }

        return didImportQueuedEvents
    }

    @discardableResult
    func drainQueuedEventsWithoutLoading(
        maximumInboxEventCount: Int? = TokenUsageStore.defaultInboxImportBatchLimit
    ) -> Bool {
        var didImportQueuedEvents = false

        while true {
            let inboxResult = loadInboxEvents(maximumEventCount: maximumInboxEventCount)
            guard !inboxResult.consumedURLs.isEmpty else {
                break
            }

            let didImportBatch = lock.withLock {
                importQueuedEventsWithoutLock(loadEvents: false, inboxResult: inboxResult).didImportQueuedEvents
            }
            didImportQueuedEvents = didImportQueuedEvents || didImportBatch

            if maximumInboxEventCount == nil {
                break
            }
        }

        if didImportQueuedEvents {
            postEventsDidChange()
        }
        return didImportQueuedEvents
    }

    func totalTokens(
        startingAt startDate: Date,
        endingBefore endDate: Date,
        dashboardToolsOnly: Bool = true
    ) -> Int {
        lock.withLock {
            let database: OpaquePointer
            do {
                database = try openDatabase()
            } catch {
                return 0
            }
            defer { sqlite3_close(database) }

            return loadTotalTokens(
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                database: database
            )
        }
    }

    func allTimeTotalTokens(dashboardToolsOnly: Bool = true) -> Int {
        lock.withLock {
            let database: OpaquePointer
            do {
                database = try openDatabase()
            } catch {
                return 0
            }
            defer { sqlite3_close(database) }

            return loadDashboardCountAndTotal(
                dashboardToolsOnly: dashboardToolsOnly,
                database: database
            ).totalTokens
        }
    }

    func dashboardSummary(dashboardToolsOnly: Bool = true) -> TokenUsageDashboardSummary {
        lock.withLock {
            let database: OpaquePointer
            do {
                database = try openDatabase()
            } catch {
                return .empty
            }
            defer { sqlite3_close(database) }

            return loadDashboardSummary(
                dashboardToolsOnly: dashboardToolsOnly,
                database: database
            )
        }
    }

    func dashboardSummary(
        startingAt startDate: Date,
        endingBefore endDate: Date,
        dashboardToolsOnly: Bool = true
    ) -> TokenUsageDashboardSummary {
        lock.withLock {
            let database: OpaquePointer
            do {
                database = try openDatabase()
            } catch {
                return .empty
            }
            defer { sqlite3_close(database) }

            return loadDashboardSummary(
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                database: database
            )
        }
    }

    func dashboardDateBounds(
        selectedTool: TokenUsageAITool? = nil,
        dashboardToolsOnly: Bool = true
    ) -> TokenUsageDashboardDateBounds {
        lock.withLock {
            let database: OpaquePointer
            do {
                database = try openDatabase()
            } catch {
                return .empty
            }
            defer { sqlite3_close(database) }

            return loadDashboardDateBounds(
                selectedTool: selectedTool,
                dashboardToolsOnly: dashboardToolsOnly,
                database: database
            )
        }
    }

    func dashboardDayTokenTotals(
        startingAt startDate: Date,
        endingBefore endDate: Date,
        calendar: Calendar,
        dashboardToolsOnly: Bool = true
    ) -> [String: Int] {
        lock.withLock {
            let database: OpaquePointer
            do {
                database = try openDatabase()
            } catch {
                return [:]
            }
            defer { sqlite3_close(database) }

            return loadDashboardDayTokenTotals(
                startingAt: startDate,
                endingBefore: endDate,
                calendar: calendar,
                dashboardToolsOnly: dashboardToolsOnly,
                database: database
            )
        }
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
            _ = try insertEvent(event, database: database)
            return loadDatabaseEvents(database: database)
        }

        postEventsDidChange()
        return nextEvents
    }

    @discardableResult
    func appendEventsWithoutLoading(_ events: [TokenUsageEvent]) throws -> Int {
        guard !events.isEmpty else {
            return 0
        }

        let insertedCount = try lock.withLock {
            for event in events {
                try event.validate()
            }

            let database = try openDatabase()
            defer { sqlite3_close(database) }
            _ = try migrateLegacyJSONEventsIfNeeded(database: database)
            return try insertEvents(events, database: database)
        }

        if insertedCount > 0 {
            postEventsDidChange()
        }
        return insertedCount
    }

    func loadEvents(afterRowID rowID: Int64) -> (events: [TokenUsageEvent], maxRowID: Int64) {
        lock.withLock {
            let database: OpaquePointer
            do {
                database = try openDatabase()
            } catch {
                return ([], rowID)
            }
            defer { sqlite3_close(database) }

            return loadDatabaseEventsAfterRowID(rowID, database: database)
        }
    }

    func currentEventCount() -> Int {
        lock.withLock {
            let database: OpaquePointer
            do {
                database = try openDatabase()
            } catch {
                return 0
            }
            defer { sqlite3_close(database) }

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, "SELECT COUNT(*) FROM token_usage_events", -1, &statement, nil) == SQLITE_OK,
                  let statement
            else {
                return 0
            }
            defer { sqlite3_finalize(statement) }
            guard sqlite3_step(statement) == SQLITE_ROW else {
                return 0
            }
            return Int(sqlite3_column_int64(statement, 0))
        }
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
        resetImporterState(for: TokenUsageAITool.allCases)
        postEventsDidChange()
    }

    func clearEvents(forAITool aiTool: String) throws {
        try lock.withLock {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, "DELETE FROM token_usage_events WHERE ai_tool = ?", -1, &statement, nil) == SQLITE_OK,
                  let statement
            else {
                throw TokenUsageStoreError.databaseWriteFailed
            }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_text(statement, 1, aiTool, -1, SQLITE_TRANSIENT)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw TokenUsageStoreError.databaseWriteFailed
            }
        }
        if let tool = TokenUsageAITool(rawValue: aiTool) {
            resetImporterState(for: [tool])
        }
        postEventsDidChange()
    }

    func clearEvents(for aiTools: [TokenUsageAITool]) throws {
        let toolValues = aiTools.map(\.rawValue)
        guard !toolValues.isEmpty else {
            return
        }

        try lock.withLock {
            let database = try openDatabase()
            defer { sqlite3_close(database) }
            _ = try migrateLegacyJSONEventsIfNeeded(database: database)

            let placeholders = Array(repeating: "?", count: toolValues.count).joined(separator: ", ")
            let sql = "DELETE FROM token_usage_events WHERE ai_tool IN (\(placeholders))"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
                  let statement
            else {
                throw TokenUsageStoreError.databaseWriteFailed
            }
            defer { sqlite3_finalize(statement) }

            for (index, toolValue) in toolValues.enumerated() {
                sqlite3_bind_text(statement, Int32(index + 1), toolValue, -1, SQLITE_TRANSIENT)
            }

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw TokenUsageStoreError.databaseWriteFailed
            }
            try removeLegacyEventsFileWithoutLock()
        }
        resetImporterState(for: aiTools)
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
        AppDirectories.spillApplicationSupportDirectory()
            .appendingPathComponent("token-metering", isDirectory: true)
            .appendingPathComponent("events.json")
    }

    static func defaultDatabaseURL() -> URL {
        defaultDatabaseURL(for: defaultEventsURL())
    }

    static func defaultInboxURL() -> URL {
        AppDirectories.spillApplicationSupportDirectory()
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

    private func importQueuedEventsWithoutLock(
        loadEvents: Bool,
        inboxResult: InboxReadResult
    ) -> StoreLoadResult {
        let database: OpaquePointer
        do {
            database = try openDatabase()
        } catch {
            return StoreLoadResult(events: [], didImportQueuedEvents: false)
        }
        defer { sqlite3_close(database) }

        let didMigrateLegacyEvents = (try? migrateLegacyJSONEventsIfNeeded(database: database)) ?? false
        var didImportQueuedEvents = didMigrateLegacyEvents

        if !inboxResult.consumedURLs.isEmpty {
            do {
                _ = try insertEvents(inboxResult.events, database: database)
                removeConsumedInboxFiles(inboxResult.consumedURLs)
                didImportQueuedEvents = true
            } catch {
                didImportQueuedEvents = false
            }
        }

        return StoreLoadResult(
            events: loadEvents ? loadDatabaseEvents(database: database) : [],
            didImportQueuedEvents: didImportQueuedEvents
        )
    }

    private func loadJSONEvents(from url: URL) -> [TokenUsageEvent] {
        guard let data = try? Data(contentsOf: url),
              let events = try? JSONDecoder().decode(SafeDecodableArray<TokenUsageEvent>.self, from: data).elements
        else {
            return []
        }

        return events
    }

    private func loadInboxEvents(maximumEventCount: Int?) -> InboxReadResult {
        var events = [TokenUsageEvent]()
        var consumedURLs = [URL]()
        let maximumEventCount = maximumEventCount.map { max(0, $0) }

        if let inboxURL,
           let urls = try? FileManager.default.contentsOfDirectory(
            at: inboxURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
           ) {
            let inboxEventURLs = urls
                .filter({ $0.pathExtension == "json" || $0.pathExtension == "jsonl" })
                .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
            let limitedURLs = maximumEventCount.map { Array(inboxEventURLs.prefix($0)) } ?? inboxEventURLs

            for url in limitedURLs {
                if url.pathExtension == "jsonl" {
                    if let jsonlEvents = loadJSONLInboxEvents(from: url) {
                        events.append(contentsOf: jsonlEvents)
                    }
                } else if let event = loadInboxEvent(from: url) {
                    events.append(event)
                }
                consumedURLs.append(url)
            }
        }

        if let maximumEventCount, events.count >= maximumEventCount {
            return InboxReadResult(events: events, consumedURLs: consumedURLs)
        }

        if let legacyInboxURL = legacyJSONLInboxURL(),
           let legacyEvents = loadJSONLInboxEvents(from: legacyInboxURL) {
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

    private func loadJSONLInboxEvents(from url: URL) -> [TokenUsageEvent]? {
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
            let schemaCheckpoint = databaseSchemaCheckpoint(database: database)
            if schemaCheckpoint.fileIdentity == nil
                || preparedDatabaseSchemaCheckpoint != schemaCheckpoint {
                try prepareDatabaseSchema(database: database)
                preparedDatabaseSchemaCheckpoint = databaseSchemaCheckpoint(database: database)
            }
            return database
        } catch {
            sqlite3_close(database)
            throw error
        }
    }

    private func databaseSchemaCheckpoint(database: OpaquePointer) -> DatabaseSchemaCheckpoint {
        DatabaseSchemaCheckpoint(
            fileIdentity: databaseFileIdentity(),
            schemaVersion: databaseSchemaVersion(database: database)
        )
    }

    private func databaseFileIdentity() -> String? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: databaseURL.path),
              let systemNumber = attributes[.systemNumber],
              let systemFileNumber = attributes[.systemFileNumber]
        else {
            return nil
        }

        return "\(String(describing: systemNumber)):\(String(describing: systemFileNumber))"
    }

    private func databaseSchemaVersion(database: OpaquePointer) -> Int {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "PRAGMA schema_version", -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return -1
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return -1
        }

        return Int(sqlite3_column_int(statement, 0))
    }

    private func databaseUserVersion(database: OpaquePointer) -> Int {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "PRAGMA user_version", -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return -1
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return -1
        }

        return Int(sqlite3_column_int(statement, 0))
    }

    private func execute(_ sql: String, database: OpaquePointer) throws {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw TokenUsageStoreError.databaseWriteFailed
        }
    }

    private func prepareDatabaseSchema(database: OpaquePointer) throws {
        try execute(
            """
            CREATE TABLE IF NOT EXISTS token_usage_events (
                span_id TEXT PRIMARY KEY NOT NULL,
                device_id TEXT,
                project_id TEXT,
                artifact_id TEXT,
                run_id TEXT,
                created_at TEXT NOT NULL,
                ai_tool TEXT NOT NULL,
                task_type TEXT,
                stage TEXT,
                model TEXT,
                input_tokens INTEGER,
                output_tokens INTEGER,
                latency_ms INTEGER,
                total_tokens INTEGER NOT NULL,
                payload_json BLOB NOT NULL
            )
            """,
            database: database
        )
        try ensureDashboardColumns(database: database)
        try backfillDashboardColumns(database: database)
        try normalizeStoredCreatedAtValues(database: database)
        try execute(
            """
            CREATE INDEX IF NOT EXISTS idx_token_usage_events_created_at
            ON token_usage_events(created_at)
            """,
            database: database
        )

        let userVersion = databaseUserVersion(database: database)
        if userVersion < 2 {
            try execute("DROP INDEX IF EXISTS idx_token_usage_events_tool_created_at", database: database)
            try execute("DROP INDEX IF EXISTS idx_token_usage_events_task_type_created_at", database: database)
            try execute("DROP INDEX IF EXISTS idx_token_usage_events_stage_created_at", database: database)
            try execute("DROP INDEX IF EXISTS idx_token_usage_events_model_created_at", database: database)
            try execute("DROP INDEX IF EXISTS idx_token_usage_events_project_created_at", database: database)
            try execute("PRAGMA user_version = 2", database: database)
        }

        try execute(
            """
            CREATE INDEX IF NOT EXISTS idx_token_usage_events_tool_created_at
            ON token_usage_events(ai_tool, created_at, total_tokens, input_tokens, output_tokens)
            """,
            database: database
        )
        try execute(
            """
            CREATE INDEX IF NOT EXISTS idx_token_usage_events_task_type_created_at
            ON token_usage_events(task_type, created_at, total_tokens)
            """,
            database: database
        )
        try execute(
            """
            CREATE INDEX IF NOT EXISTS idx_token_usage_events_stage_created_at
            ON token_usage_events(stage, created_at, total_tokens)
            """,
            database: database
        )
        try execute(
            """
            CREATE INDEX IF NOT EXISTS idx_token_usage_events_model_created_at
            ON token_usage_events(model, created_at, total_tokens)
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
        try execute(
            """
            CREATE INDEX IF NOT EXISTS idx_token_usage_events_project_created_at
            ON token_usage_events(project_id, created_at, total_tokens)
            """,
            database: database
        )
    }

    private func ensureDashboardColumns(database: OpaquePointer) throws {
        let existingColumns = databaseColumns(tableName: "token_usage_events", database: database)
        let requiredColumns: [(name: String, definition: String)] = [
            ("device_id", "TEXT"),
            ("project_id", "TEXT"),
            ("artifact_id", "TEXT"),
            ("run_id", "TEXT"),
            ("task_type", "TEXT"),
            ("stage", "TEXT"),
            ("model", "TEXT"),
            ("input_tokens", "INTEGER"),
            ("output_tokens", "INTEGER"),
            ("latency_ms", "INTEGER"),
            ("source_system", "INTEGER"),
            ("source_user", "INTEGER"),
            ("source_history", "INTEGER"),
            ("source_repo_context", "INTEGER"),
            ("source_tool_output", "INTEGER"),
            ("source_generated_output", "INTEGER"),
            ("source_unknown", "INTEGER")
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
        WHERE run_id IS NULL
            OR device_id IS NULL
            OR project_id IS NULL
            OR artifact_id IS NULL
            OR task_type IS NULL
            OR stage IS NULL
            OR model IS NULL
            OR input_tokens IS NULL
            OR output_tokens IS NULL
            OR latency_ms IS NULL
            OR source_system IS NULL
            OR source_user IS NULL
            OR source_history IS NULL
            OR source_repo_context IS NULL
            OR source_tool_output IS NULL
            OR source_generated_output IS NULL
            OR source_unknown IS NULL
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
            if let event = try? JSONDecoder().decode(TokenUsageEvent.self, from: data) {
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

    private func normalizeStoredCreatedAtValues(database: OpaquePointer) throws {
        var updates = [(spanID: String, createdAt: String)]()
        do {
            let sql = """
            SELECT span_id, created_at
            FROM token_usage_events
            WHERE created_at NOT GLOB '????-??-??T??:??:??.???Z'
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
                  let statement
            else {
                throw TokenUsageStoreError.databaseWriteFailed
            }
            defer { sqlite3_finalize(statement) }

            while sqlite3_step(statement) == SQLITE_ROW {
                guard let spanIDText = sqlite3_column_text(statement, 0),
                      let createdAtText = sqlite3_column_text(statement, 1)
                else {
                    continue
                }

                let spanID = String(cString: spanIDText)
                let createdAt = String(cString: createdAtText)
                guard let normalizedCreatedAt = Self.normalizedCreatedAt(createdAt),
                      normalizedCreatedAt != createdAt
                else {
                    continue
                }

                updates.append((spanID: spanID, createdAt: normalizedCreatedAt))
            }
        }

        guard !updates.isEmpty else {
            return
        }

        try execute("BEGIN IMMEDIATE TRANSACTION", database: database)
        do {
            for update in updates {
                try updateCreatedAt(
                    spanID: update.spanID,
                    createdAt: update.createdAt,
                    database: database
                )
            }
            try execute("COMMIT", database: database)
        } catch {
            try? execute("ROLLBACK", database: database)
            throw error
        }
    }

    private func updateCreatedAt(
        spanID: String,
        createdAt: String,
        database: OpaquePointer
    ) throws {
        let sql = """
        UPDATE token_usage_events
        SET created_at = ?
        WHERE span_id = ?
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            throw TokenUsageStoreError.databaseWriteFailed
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, createdAt, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, spanID, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw TokenUsageStoreError.databaseWriteFailed
        }
    }

    private func updateDashboardColumns(for event: TokenUsageEvent, database: OpaquePointer) throws {
        let sql = """
        UPDATE token_usage_events
        SET device_id = ?,
            project_id = ?,
            artifact_id = ?,
            run_id = ?,
            task_type = ?,
            stage = ?,
            model = ?,
            input_tokens = ?,
            output_tokens = ?,
            latency_ms = ?,
            source_system = ?,
            source_user = ?,
            source_history = ?,
            source_repo_context = ?,
            source_tool_output = ?,
            source_generated_output = ?,
            source_unknown = ?
        WHERE span_id = ?
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            throw TokenUsageStoreError.databaseWriteFailed
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, event.deviceID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, event.projectID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 3, event.artifactID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 4, event.runID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 5, event.taskType.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 6, event.stage.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 7, event.model, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(statement, 8, sqlite3_int64(event.inputTokens))
        sqlite3_bind_int64(statement, 9, sqlite3_int64(event.outputTokens))
        sqlite3_bind_int64(statement, 10, sqlite3_int64(event.latencyMS))
        sqlite3_bind_int64(statement, 11, sqlite3_int64(event.tokenBreakdown.system))
        sqlite3_bind_int64(statement, 12, sqlite3_int64(event.tokenBreakdown.user))
        sqlite3_bind_int64(statement, 13, sqlite3_int64(event.tokenBreakdown.history))
        sqlite3_bind_int64(statement, 14, sqlite3_int64(event.tokenBreakdown.repoContext))
        sqlite3_bind_int64(statement, 15, sqlite3_int64(event.tokenBreakdown.toolOutput))
        sqlite3_bind_int64(statement, 16, sqlite3_int64(event.tokenBreakdown.generatedOutput))
        sqlite3_bind_int64(statement, 17, sqlite3_int64(event.tokenBreakdown.unknown))
        sqlite3_bind_text(statement, 18, event.spanID, -1, SQLITE_TRANSIENT)

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

        _ = try insertEvents(legacyEvents, database: database)
        try removeLegacyEventsFileWithoutLock()
        return true
    }

    private func insertEvents(_ events: [TokenUsageEvent], database: OpaquePointer) throws -> Int {
        try execute("BEGIN IMMEDIATE TRANSACTION", database: database)
        var insertedCount = 0
        do {
            for event in events {
                insertedCount += try insertEvent(event, database: database)
            }
            try execute("COMMIT", database: database)
            return insertedCount
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
                _ = try insertEvent(event, database: database)
            }
            try execute("COMMIT", database: database)
        } catch {
            try? execute("ROLLBACK", database: database)
            throw error
        }
    }

    private func insertEvent(_ event: TokenUsageEvent, database: OpaquePointer) throws -> Int {
        try event.validate()

        let sql = """
        INSERT OR IGNORE INTO token_usage_events (
            span_id,
            device_id,
            project_id,
            artifact_id,
            run_id,
            created_at,
            ai_tool,
            task_type,
            stage,
            model,
            input_tokens,
            output_tokens,
            latency_ms,
            source_system,
            source_user,
            source_history,
            source_repo_context,
            source_tool_output,
            source_generated_output,
            source_unknown,
            total_tokens,
            payload_json
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
        sqlite3_bind_text(statement, 2, event.deviceID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 3, event.projectID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 4, event.artifactID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 5, event.runID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(
            statement,
            6,
            Self.normalizedCreatedAt(event.createdAt) ?? event.createdAt,
            -1,
            SQLITE_TRANSIENT
        )
        sqlite3_bind_text(statement, 7, event.aiTool.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 8, event.taskType.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 9, event.stage.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 10, event.model, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(statement, 11, sqlite3_int64(event.inputTokens))
        sqlite3_bind_int64(statement, 12, sqlite3_int64(event.outputTokens))
        sqlite3_bind_int64(statement, 13, sqlite3_int64(event.latencyMS))
        sqlite3_bind_int64(statement, 14, sqlite3_int64(event.tokenBreakdown.system))
        sqlite3_bind_int64(statement, 15, sqlite3_int64(event.tokenBreakdown.user))
        sqlite3_bind_int64(statement, 16, sqlite3_int64(event.tokenBreakdown.history))
        sqlite3_bind_int64(statement, 17, sqlite3_int64(event.tokenBreakdown.repoContext))
        sqlite3_bind_int64(statement, 18, sqlite3_int64(event.tokenBreakdown.toolOutput))
        sqlite3_bind_int64(statement, 19, sqlite3_int64(event.tokenBreakdown.generatedOutput))
        sqlite3_bind_int64(statement, 20, sqlite3_int64(event.tokenBreakdown.unknown))
        sqlite3_bind_int64(statement, 21, sqlite3_int64(event.totalTokens))
        _ = payload.withUnsafeBytes { buffer in
            sqlite3_bind_blob(statement, 22, buffer.baseAddress, Int32(buffer.count), SQLITE_TRANSIENT)
        }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw TokenUsageStoreError.databaseWriteFailed
        }
        return Int(sqlite3_changes(database))
    }

    private func loadDatabaseEvents(database: OpaquePointer) -> [TokenUsageEvent] {
        loadDatabaseEvents(startingAt: nil, endingBefore: nil, database: database)
    }

    private func loadDatabaseEvents(
        startingAt startDate: Date?,
        endingBefore endDate: Date?,
        database: OpaquePointer
    ) -> [TokenUsageEvent] {
        var conditions = [String]()
        if startDate != nil {
            conditions.append("created_at >= ?")
        }
        if endDate != nil {
            conditions.append("created_at < ?")
        }

        var sql = """
        SELECT \(Self.eventSelectColumns)
        FROM token_usage_events
        """
        if !conditions.isEmpty {
            sql += "\nWHERE \(conditions.joined(separator: " AND "))"
        }
        sql += "\nORDER BY created_at ASC, rowid ASC"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        var bindIndex: Int32 = 1
        if let startDate {
            let startValue = ISO8601DateFormatter.tokenUsage.string(from: startDate)
            sqlite3_bind_text(statement, bindIndex, startValue, -1, SQLITE_TRANSIENT)
            bindIndex += 1
        }
        if let endDate {
            let endValue = ISO8601DateFormatter.tokenUsage.string(from: endDate)
            sqlite3_bind_text(statement, bindIndex, endValue, -1, SQLITE_TRANSIENT)
        }

        var events = [TokenUsageEvent]()
        while sqlite3_step(statement) == SQLITE_ROW {
            if let event = Self.event(from: statement, startingAt: 0) {
                events.append(event)
            }
        }
        return events
    }

    private func loadDatabaseEventsAfterRowID(
        _ rowID: Int64,
        database: OpaquePointer
    ) -> (events: [TokenUsageEvent], maxRowID: Int64) {
        let sql = """
        SELECT rowid, \(Self.eventSelectColumns)
        FROM token_usage_events
        WHERE rowid > ?
        ORDER BY created_at ASC, rowid ASC
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return ([], rowID)
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 1, rowID)

        var events = [TokenUsageEvent]()
        var maxRowID = rowID
        while sqlite3_step(statement) == SQLITE_ROW {
            let currentRowID = sqlite3_column_int64(statement, 0)
            if currentRowID > maxRowID {
                maxRowID = currentRowID
            }
            if let event = Self.event(from: statement, startingAt: 1) {
                events.append(event)
            }
        }
        return (events, maxRowID)
    }

    private static func event(from statement: OpaquePointer, startingAt offset: Int32) -> TokenUsageEvent? {
        guard let spanID = columnString(statement, offset + 0),
              let deviceID = columnString(statement, offset + 1),
              let projectID = columnString(statement, offset + 2),
              let artifactID = columnString(statement, offset + 3),
              let runID = columnString(statement, offset + 4),
              let createdAt = columnString(statement, offset + 5),
              let aiToolRaw = columnString(statement, offset + 6),
              let taskTypeRaw = columnString(statement, offset + 7),
              let stageRaw = columnString(statement, offset + 8),
              let model = columnString(statement, offset + 9),
              let taskType = TokenUsageTaskType(rawValue: taskTypeRaw),
              let stage = TokenUsageStage(rawValue: stageRaw)
        else {
            return nil
        }

        let aiTool: TokenUsageAITool
        switch aiToolRaw {
        case "agy":
            aiTool = .antigravity
        case "ollama":
            aiTool = .unknown
        default:
            aiTool = TokenUsageAITool(rawValue: aiToolRaw) ?? .unknown
        }

        let inputTokens = Int(sqlite3_column_int64(statement, offset + 10))
        let outputTokens = Int(sqlite3_column_int64(statement, offset + 11))
        let totalTokens = Int(sqlite3_column_int64(statement, offset + 12))
        let latencyMS = Int(sqlite3_column_int64(statement, offset + 13))
        let tokenBreakdown = TokenUsageBreakdown(
            system: Int(sqlite3_column_int64(statement, offset + 14)),
            user: Int(sqlite3_column_int64(statement, offset + 15)),
            history: Int(sqlite3_column_int64(statement, offset + 16)),
            repoContext: Int(sqlite3_column_int64(statement, offset + 17)),
            toolOutput: Int(sqlite3_column_int64(statement, offset + 18)),
            generatedOutput: Int(sqlite3_column_int64(statement, offset + 19)),
            unknown: Int(sqlite3_column_int64(statement, offset + 20))
        )
        let event = TokenUsageEvent(
            schemaVersion: 1,
            deviceID: deviceID,
            projectID: projectID,
            artifactID: artifactID,
            runID: runID,
            spanID: spanID,
            aiTool: aiTool,
            taskType: taskType,
            stage: stage,
            model: model,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            totalTokens: totalTokens,
            tokenBreakdown: tokenBreakdown,
            latencyMS: latencyMS,
            createdAt: createdAt
        )
        guard (try? event.validate()) != nil else {
            return nil
        }
        return event
    }

    private static func columnString(_ statement: OpaquePointer, _ index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let text = sqlite3_column_text(statement, index)
        else {
            return nil
        }
        return String(cString: text)
    }

    private func loadDashboardSummary(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool,
        database: OpaquePointer
    ) -> TokenUsageDashboardSummary {
        let totals = loadDashboardCountAndTotal(
            startingAt: startDate,
            endingBefore: endDate,
            dashboardToolsOnly: dashboardToolsOnly,
            database: database
        )
        return TokenUsageDashboardSummary(
            eventCount: totals.eventCount,
            totalTokens: totals.totalTokens,
            toolTotals: loadGroupedTokenTotals(
                column: "ai_tool",
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                database: database
            ),
            taskTotals: loadGroupedTokenTotals(
                column: "task_type",
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                database: database
            ),
            sourceTotals: loadSourceTokenTotals(
                startingAt: startDate,
                endingBefore: endDate,
                dashboardToolsOnly: dashboardToolsOnly,
                database: database
            )
        )
    }

    private func loadDashboardDateBounds(
        selectedTool: TokenUsageAITool?,
        dashboardToolsOnly: Bool,
        database: OpaquePointer
    ) -> TokenUsageDashboardDateBounds {
        var conditions = [String]()
        if selectedTool != nil {
            conditions.append("ai_tool = ?")
        } else if dashboardToolsOnly {
            conditions.append("ai_tool IN ('codex', 'claude', 'antigravity')")
        }

        var sql = """
        SELECT MIN(created_at), MAX(created_at)
        FROM token_usage_events
        """
        if !conditions.isEmpty {
            sql += "\nWHERE \(conditions.joined(separator: " AND "))"
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return .empty
        }
        defer { sqlite3_finalize(statement) }

        if let selectedTool {
            sqlite3_bind_text(statement, 1, selectedTool.rawValue, -1, SQLITE_TRANSIENT)
        }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return .empty
        }

        let earliest = Self.columnString(statement, 0)
            .flatMap(ISO8601DateFormatter.parseTokenUsageDate(from:))
        let latest = Self.columnString(statement, 1)
            .flatMap(ISO8601DateFormatter.parseTokenUsageDate(from:))
        return TokenUsageDashboardDateBounds(earliest: earliest, latest: latest)
    }

    private func loadDashboardCountAndTotal(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool,
        database: OpaquePointer
    ) -> (eventCount: Int, totalTokens: Int) {
        let sql = """
        SELECT COUNT(*), COALESCE(SUM(total_tokens), 0)
        FROM token_usage_events
        \(Self.dashboardWhereClause(startingAt: startDate, endingBefore: endDate, dashboardToolsOnly: dashboardToolsOnly))
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return (0, 0)
        }
        defer { sqlite3_finalize(statement) }
        Self.bindDashboardDateRange(startingAt: startDate, endingBefore: endDate, statement: statement)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return (0, 0)
        }

        return (
            eventCount: Int(sqlite3_column_int64(statement, 0)),
            totalTokens: Int(sqlite3_column_int64(statement, 1))
        )
    }

    private func loadGroupedTokenTotals(
        column: String,
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool,
        database: OpaquePointer
    ) -> [String: Int] {
        let sql = """
        SELECT \(column), COALESCE(SUM(total_tokens), 0)
        FROM token_usage_events
        \(Self.dashboardWhereClause(startingAt: startDate, endingBefore: endDate, dashboardToolsOnly: dashboardToolsOnly))
        GROUP BY \(column)
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return [:]
        }
        defer { sqlite3_finalize(statement) }
        Self.bindDashboardDateRange(startingAt: startDate, endingBefore: endDate, statement: statement)

        var totals = [String: Int]()
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let keyText = sqlite3_column_text(statement, 0) else {
                continue
            }
            let key = String(cString: keyText)
            guard !key.isEmpty else {
                continue
            }
            totals[key] = Int(sqlite3_column_int64(statement, 1))
        }
        return totals
    }

    private func loadSourceTokenTotals(
        startingAt startDate: Date? = nil,
        endingBefore endDate: Date? = nil,
        dashboardToolsOnly: Bool,
        database: OpaquePointer
    ) -> [String: Int] {
        let sql = """
        SELECT
            COALESCE(SUM(source_system), 0),
            COALESCE(SUM(source_user), 0),
            COALESCE(SUM(source_history), 0),
            COALESCE(SUM(source_repo_context), 0),
            COALESCE(SUM(source_tool_output), 0),
            COALESCE(SUM(source_generated_output), 0),
            COALESCE(SUM(source_unknown), 0)
        FROM token_usage_events
        \(Self.dashboardWhereClause(startingAt: startDate, endingBefore: endDate, dashboardToolsOnly: dashboardToolsOnly))
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return [:]
        }
        defer { sqlite3_finalize(statement) }
        Self.bindDashboardDateRange(startingAt: startDate, endingBefore: endDate, statement: statement)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return [:]
        }

        return [
            "system": Int(sqlite3_column_int64(statement, 0)),
            "user": Int(sqlite3_column_int64(statement, 1)),
            "history": Int(sqlite3_column_int64(statement, 2)),
            "repo_context": Int(sqlite3_column_int64(statement, 3)),
            "tool_output": Int(sqlite3_column_int64(statement, 4)),
            "generated_output": Int(sqlite3_column_int64(statement, 5)),
            "unknown": Int(sqlite3_column_int64(statement, 6))
        ]
    }

    private func loadTotalTokens(
        startingAt startDate: Date,
        endingBefore endDate: Date,
        dashboardToolsOnly: Bool,
        database: OpaquePointer
    ) -> Int {
        var sql = """
        SELECT COALESCE(SUM(total_tokens), 0)
        FROM token_usage_events
        WHERE created_at >= ? AND created_at < ?
        """
        if dashboardToolsOnly {
            sql += " AND ai_tool IN ('codex', 'claude', 'antigravity')"
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return 0
        }
        defer { sqlite3_finalize(statement) }

        let startValue = ISO8601DateFormatter.tokenUsage.string(from: startDate)
        let endValue = ISO8601DateFormatter.tokenUsage.string(from: endDate)
        sqlite3_bind_text(statement, 1, startValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, endValue, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return 0
        }

        return Int(sqlite3_column_int64(statement, 0))
    }

    private func loadDashboardDayTokenTotals(
        startingAt startDate: Date,
        endingBefore endDate: Date,
        calendar: Calendar,
        dashboardToolsOnly: Bool,
        database: OpaquePointer
    ) -> [String: Int] {
        var sql = """
        SELECT created_at, total_tokens
        FROM token_usage_events
        WHERE created_at >= ? AND created_at < ?
        """
        if dashboardToolsOnly {
            sql += " AND ai_tool IN ('codex', 'claude', 'antigravity')"
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            return [:]
        }
        defer { sqlite3_finalize(statement) }

        let startValue = ISO8601DateFormatter.tokenUsage.string(from: startDate)
        let endValue = ISO8601DateFormatter.tokenUsage.string(from: endDate)
        sqlite3_bind_text(statement, 1, startValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, endValue, -1, SQLITE_TRANSIENT)

        var totals = [String: Int]()
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let createdAt = Self.columnString(statement, 0),
                  let date = ISO8601DateFormatter.parseTokenUsageDate(from: createdAt)
            else {
                continue
            }
            let dayID = TokenUsageDashboardSnapshot.dayID(for: date, calendar: calendar)
            totals[dayID, default: 0] += Int(sqlite3_column_int64(statement, 1))
        }
        return totals
    }

    private static func dashboardToolWhereClause(dashboardToolsOnly: Bool) -> String {
        dashboardToolsOnly
            ? "WHERE ai_tool IN ('codex', 'claude', 'antigravity')"
            : ""
    }

    private static func dashboardWhereClause(
        startingAt startDate: Date?,
        endingBefore endDate: Date?,
        dashboardToolsOnly: Bool
    ) -> String {
        var conditions = [String]()
        if startDate != nil, endDate != nil {
            conditions.append("created_at >= ? AND created_at < ?")
        }
        if dashboardToolsOnly {
            conditions.append("ai_tool IN ('codex', 'claude', 'antigravity')")
        }
        guard !conditions.isEmpty else {
            return ""
        }
        return "WHERE \(conditions.joined(separator: " AND "))"
    }

    private static func bindDashboardDateRange(
        startingAt startDate: Date?,
        endingBefore endDate: Date?,
        statement: OpaquePointer
    ) {
        guard let startDate, let endDate else {
            return
        }

        let startValue = ISO8601DateFormatter.tokenUsage.string(from: startDate)
        let endValue = ISO8601DateFormatter.tokenUsage.string(from: endDate)
        sqlite3_bind_text(statement, 1, startValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, endValue, -1, SQLITE_TRANSIENT)
    }

    private static func normalizedCreatedAt(_ createdAt: String) -> String? {
        guard let date = ISO8601DateFormatter.parseTokenUsageDate(from: createdAt) else {
            return nil
        }

        return ISO8601DateFormatter.tokenUsage.string(from: date)
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

    func notifyEventsDidChange() {
        postEventsDidChange()
    }

    private func postEventsDidChange() {
        NotificationCenter.default.post(
            name: Self.eventsDidChangeNotification,
            object: self
        )
        DistributedNotificationCenter.default().postNotificationName(
            Self.distributedEventsDidChangeNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    private func resetImporterState(for aiTools: [TokenUsageAITool]) {
        let fileManager = FileManager.default
        let tokenMeteringDir = tokenMeteringDirectory
        let sessionStateDir = tokenMeteringDir.appendingPathComponent("session-state", isDirectory: true)
        let historyImportDir = tokenMeteringDir.appendingPathComponent("history-import", isDirectory: true)

        for tool in aiTools {
            switch tool {
            case .antigravity:
                let activeState = sessionStateDir.appendingPathComponent("antigravity-active-importer-state.json")
                let historyState = historyImportDir.appendingPathComponent("antigravity-active-importer-state.json")
                try? fileManager.removeItem(at: activeState)
                try? fileManager.removeItem(at: historyState)
            case .codex:
                // History import state
                let codexHistoryState = historyImportDir.appendingPathComponent("codex-session-import-state.json")
                try? fileManager.removeItem(at: codexHistoryState)
                // Live Stop-hook state (default path used by the live importer)
                let codexLiveState = tokenMeteringDir.appendingPathComponent("codex-session-import-state.json")
                try? fileManager.removeItem(at: codexLiveState)
            case .claude:
                let claudeDir = historyImportDir.appendingPathComponent("claude-session-state", isDirectory: true)
                if let files = try? fileManager.contentsOfDirectory(at: claudeDir, includingPropertiesForKeys: nil) {
                    for file in files where file.pathExtension == "json" {
                        try? fileManager.removeItem(at: file)
                    }
                }
            default:
                break
            }
        }
    }
}

struct TokenUsageDashboardSummary: Equatable {
    let eventCount: Int
    let totalTokens: Int
    let toolTotals: [String: Int]
    let taskTotals: [String: Int]
    let sourceTotals: [String: Int]

    static let empty = TokenUsageDashboardSummary(
        eventCount: 0,
        totalTokens: 0,
        toolTotals: [:],
        taskTotals: [:],
        sourceTotals: [:]
    )
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

private struct DatabaseSchemaCheckpoint: Equatable {
    let fileIdentity: String?
    let schemaVersion: Int
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
