import Foundation
import SQLite3

/// Which explicit SQLite transaction a `withTransaction` call opens. Centralizes the
/// BEGIN/COMMIT/ROLLBACK statement spellings so every transaction site shares one set of
/// control strings instead of hand-writing them (the store previously used two divergent
/// idioms, including inconsistent `BEGIN IMMEDIATE` vs `BEGIN IMMEDIATE TRANSACTION`).
enum TokenUsageTransactionMode {
    /// Read transactions: the first read acquires a stable WAL snapshot without taking a
    /// write lock, so later reads in the same transaction keep seeing that snapshot even if
    /// another connection commits meanwhile.
    case deferred
    /// Write transactions: take the reserved write lock up front so a concurrent writer
    /// cannot invalidate work performed mid-transaction.
    case immediate

    var beginStatement: String {
        switch self {
        case .deferred: return "BEGIN DEFERRED"
        case .immediate: return "BEGIN IMMEDIATE TRANSACTION"
        }
    }

    /// Shared across every transaction site (write helper and the read path below) so the
    /// COMMIT/ROLLBACK spellings live in exactly one place.
    static let commitStatement = "COMMIT"
    static let rollbackStatement = "ROLLBACK"
}

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

    /// Runs `body` inside an explicit `mode` transaction on `database`, committing on a
    /// normal return and rolling back on failure. This is the single owner of the
    /// BEGIN/COMMIT/ROLLBACK ordering for every write path in the store.
    ///
    /// BEGIN runs before the do/catch: if it fails no transaction was opened, so the error
    /// propagates directly without a (meaningless) ROLLBACK, and the caller decides whether
    /// to fail closed or degrade. If `body` (or COMMIT) throws, the transaction is rolled
    /// back best-effort — matching every original site, ROLLBACK errors are swallowed with
    /// `try?` because the original error is the one worth surfacing — and then rethrown.
    func withTransaction<T>(
        _ mode: TokenUsageTransactionMode,
        database: OpaquePointer,
        _ body: () throws -> T
    ) throws -> T {
        try execute(mode.beginStatement, database: database)
        do {
            let result = try body()
            try execute(TokenUsageTransactionMode.commitStatement, database: database)
            return result
        } catch {
            try? execute(TokenUsageTransactionMode.rollbackStatement, database: database)
            throw error
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
    /// fails the connection is already broken (every query in `body` would fail too), so this
    /// fails closed and returns `defaultValue` rather than running `body` without the consistency
    /// guarantee its callers depend on.
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

            // `body` here is non-throwing, so this read path is not expressed through
            // `withTransaction`: it needs a best-effort COMMIT rather than the write helper's
            // throwing one. A read that already produced its result has nothing to lose if
            // releasing the WAL snapshot fails, so COMMIT stays `try?` and the body result is
            // returned regardless. BEGIN still fails closed (see the method doc above).
            do {
                try execute(TokenUsageTransactionMode.deferred.beginStatement, database: ownedDatabase)
            } catch {
                return defaultValue
            }
            defer { try? execute(TokenUsageTransactionMode.commitStatement, database: ownedDatabase) }

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
