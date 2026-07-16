import Foundation
import SQLite3

extension TokenUsageStore {
    func readEventsWithoutLock() -> [TokenUsageEvent] {
        let database: OpaquePointer
        do {
            database = try openDatabase()
        } catch {
            return []
        }
        defer { sqlite3_close(database) }

        return loadDatabaseEvents(database: database)
    }


    func loadJSONEvents(from url: URL) -> [TokenUsageEvent] {
        guard let data = try? Data(contentsOf: url),
              let events = try? JSONDecoder().decode(SafeDecodableArray<TokenUsageEvent>.self, from: data).elements
        else {
            return []
        }

        return events
    }

    func openDatabase() throws -> OpaquePointer {
        try Self.createPrivateDirectoryIfNeeded(at: databaseURL.deletingLastPathComponent())

        var lastError: Error = TokenUsageStoreError.databaseOpenFailed
        for attempt in 0..<3 {
            do {
                return try openDatabaseOnce()
            } catch {
                lastError = error
                if attempt < 2 {
                    Thread.sleep(forTimeInterval: 0.05 * Double(attempt + 1))
                }
            }
        }
        throw lastError
    }

    private func openDatabaseOnce() throws -> OpaquePointer {

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

    /// Creates `url` if needed and enforces `0700` permissions (owner read/write/execute
    /// only). The `token-metering` tree holds the events database, the events inbox, and
    /// session-state files that other local processes (the Stop hook, history import) write
    /// unauthenticated event data into — restricting it to the owning user blocks other
    /// local accounts from reading usage history or planting forged inbox events.
    /// Applied on every open, not just first creation, so upgrades from an earlier version
    /// that created these directories with default (looser) permissions get hardened too.
    @discardableResult
    static func createPrivateDirectoryIfNeeded(at url: URL) throws -> URL {
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        return url
    }

    func databaseSchemaCheckpoint(database: OpaquePointer) -> DatabaseSchemaCheckpoint {
        DatabaseSchemaCheckpoint(
            fileIdentity: databaseFileIdentity(),
            schemaVersion: databaseSchemaVersion(database: database)
        )
    }

    func databaseFileIdentity() -> String? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: databaseURL.path),
              let systemNumber = attributes[.systemNumber],
              let systemFileNumber = attributes[.systemFileNumber]
        else {
            return nil
        }

        return "\(String(describing: systemNumber)):\(String(describing: systemFileNumber))"
    }

    func databaseSchemaVersion(database: OpaquePointer) -> Int {
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

    func databaseUserVersion(database: OpaquePointer) -> Int {
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

    func execute(_ sql: String, database: OpaquePointer) throws {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw TokenUsageStoreError.databaseWriteFailed
        }
    }

    /// Runs `body` against `database` if the caller already has one open (e.g. a dashboard
    /// snapshot build batching many reads onto a single shared connection instead of one
    /// open/close per query), otherwise opens+closes a private connection exactly like every
    /// existing single-query wrapper. Centralizes that fallback so per-query wrapper functions
    /// can accept an optional pre-opened connection without duplicating the lock/open/close
    /// boilerplate at each call site.
    ///
    /// When it owns the connection, it also wraps `body` in an explicit read transaction.
    /// Without one, each statement `body` runs is its own implicit transaction and can observe
    /// a different commit point if a writer (the importer process) commits in between --
    /// sharing one connection alone only shrinks that window, it doesn't close it. BEGIN
    /// DEFERRED's first read acquires a WAL snapshot that every later read in the same
    /// transaction keeps seeing, even if other connections commit afterward. If BEGIN itself
    /// fails, `body` still runs without one rather than discarding the whole batch, matching
    /// this function's existing best-effort/fall-back-to-defaults behavior.
    func withDatabaseConnection<T>(
        _ database: OpaquePointer?,
        default defaultValue: T,
        _ body: (OpaquePointer) -> T
    ) -> T {
        if let database {
            return body(database)
        }
        return lock.withLock {
            let ownedDatabase: OpaquePointer
            do {
                ownedDatabase = try openDatabase()
            } catch {
                return defaultValue
            }
            defer { sqlite3_close(ownedDatabase) }

            var transactionStarted = false
            do {
                try execute("BEGIN DEFERRED", database: ownedDatabase)
                transactionStarted = true
            } catch {
                // Fall through and read without an explicit transaction.
            }
            defer {
                if transactionStarted {
                    try? execute("COMMIT", database: ownedDatabase)
                }
            }

            return body(ownedDatabase)
        }
    }


    func removeLegacyEventsFileWithoutLock() throws {
        if FileManager.default.fileExists(atPath: fileURL.path),
           fileURL != databaseURL {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

}
