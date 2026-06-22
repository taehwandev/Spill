import Foundation
import SQLite3

extension TokenUsageAntigravityImporter {
    func readGenerationRecords(
        from source: ConversationDatabase,
        after previousMaxIndex: Int?
    ) -> GenerationRecordReadResult {
        guard let openedDatabase = openReadableDatabase(for: source.url) else {
            return GenerationRecordReadResult(scannedRowCount: 0, unsupportedRecordCount: 0, records: [])
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
            return GenerationRecordReadResult(scannedRowCount: 0, unsupportedRecordCount: 0, records: [])
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
}
