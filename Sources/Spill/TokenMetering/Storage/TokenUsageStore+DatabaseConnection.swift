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


    func removeLegacyEventsFileWithoutLock() throws {
        if FileManager.default.fileExists(atPath: fileURL.path),
           fileURL != databaseURL {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

}
