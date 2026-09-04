import Foundation
import SQLite3

extension TokenUsageAntigravityImporter {
    private static let maximumTemporaryDatabaseCopyByteCount: Int64 = 200 * 1024 * 1024
    private static let temporaryDatabaseCopyMaximumAge: TimeInterval = 24 * 60 * 60

    func readGenerationRecords(
        from source: ConversationDatabase,
        after previousMaxIndex: Int?
    ) -> GenerationRecordReadResult {
        guard let openedDatabase = openReadableDatabase(for: source.url) else {
            return GenerationRecordReadResult(
                didReadDatabase: false,
                scannedRowCount: 0,
                unsupportedRecordCount: 0,
                records: []
            )
        }
        let database = openedDatabase.database
        defer { sqlite3_close(database) }
        defer {
            for temporaryCopyURL in openedDatabase.temporaryCopyURLs {
                try? fileManager.removeItem(at: temporaryCopyURL)
            }
        }

        var stepTimestamps = [Date]()
        let stepSql = "SELECT metadata FROM steps WHERE metadata IS NOT NULL ORDER BY idx"
        var stepStatement: OpaquePointer?
        if sqlite3_prepare_v2(database, stepSql, -1, &stepStatement, nil) == SQLITE_OK,
           let stepStatement {
            defer { sqlite3_finalize(stepStatement) }
            while sqlite3_step(stepStatement) == SQLITE_ROW {
                guard let blob = sqlite3_column_blob(stepStatement, 0) else { continue }
                let byteCount = Int(sqlite3_column_bytes(stepStatement, 0))
                let data = Data(bytes: blob, count: byteCount)
                let envelope = [UInt8](data)
                // Only step rows with usage field 9 correspond to generation records
                guard Self.firstLengthDelimitedField(9, in: envelope) != nil,
                      let stepDate = Self.stepCreatedAt(from: data)
                else {
                    continue
                }
                stepTimestamps.append(stepDate)
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
                didReadDatabase: false,
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
            let embeddedDate = Self.generationCreatedAt(from: data)
            let fallbackDate = index >= 0 && index < stepTimestamps.count ? stepTimestamps[index] : nil
            let createdAt = embeddedDate ?? fallbackDate

            if let usage = Self.usageRecord(from: data),
               let createdAt {
                records.append(GenerationRecord(index: index, usage: usage, createdAt: createdAt))
            } else {
                unsupportedRecords += 1
            }
        }
        return GenerationRecordReadResult(
            didReadDatabase: true,
            scannedRowCount: scannedRows,
            unsupportedRecordCount: unsupportedRecords,
            records: records
        )
    }

    private func openReadableDatabase(for sourceURL: URL) -> OpenedDatabase? {
        if !forceTemporaryCopyFallback,
           let database = openSQLiteDatabase(at: sourceURL) {
            return OpenedDatabase(database: database, temporaryCopyURLs: [])
        }

        guard let temporaryCopy = copyDatabaseToTemporaryFile(sourceURL) else {
            return nil
        }
        guard let database = openSQLiteDatabase(at: temporaryCopy.databaseURL) else {
            for temporaryCopyURL in temporaryCopy.copiedURLs {
                try? fileManager.removeItem(at: temporaryCopyURL)
            }
            return nil
        }
        return OpenedDatabase(database: database, temporaryCopyURLs: temporaryCopy.copiedURLs)
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

    private func copyDatabaseToTemporaryFile(_ sourceURL: URL) -> TemporaryDatabaseCopy? {
        let directoryURL = fileManager.temporaryDirectory
            .appendingPathComponent("spill-agy-import", isDirectory: true)
        let temporaryURL = directoryURL
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("db")

        do {
            pruneStaleTemporaryDatabaseCopies(in: directoryURL)
            let sidecarURLs = [
                URL(fileURLWithPath: sourceURL.path + "-wal"),
                URL(fileURLWithPath: sourceURL.path + "-shm")
            ]
                .filter { fileManager.fileExists(atPath: $0.path) }
            let totalSize = try ([sourceURL] + sidecarURLs).reduce(Int64(0)) { total, url in
                let attributes = try fileManager.attributesOfItem(atPath: url.path)
                return total + ((attributes[.size] as? NSNumber)?.int64Value ?? 0)
            }
            if totalSize > Self.maximumTemporaryDatabaseCopyByteCount {
                return nil
            }

            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            try fileManager.copyItem(at: sourceURL, to: temporaryURL)
            var copiedURLs = [temporaryURL]
            for sidecarURL in sidecarURLs {
                let suffix = sidecarURL.path.hasSuffix("-wal") ? "-wal" : "-shm"
                let temporarySidecarURL = URL(fileURLWithPath: temporaryURL.path + suffix)
                try fileManager.copyItem(at: sidecarURL, to: temporarySidecarURL)
                copiedURLs.append(temporarySidecarURL)
            }
            return TemporaryDatabaseCopy(databaseURL: temporaryURL, copiedURLs: copiedURLs)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            try? fileManager.removeItem(at: URL(fileURLWithPath: temporaryURL.path + "-wal"))
            try? fileManager.removeItem(at: URL(fileURLWithPath: temporaryURL.path + "-shm"))
            return nil
        }
    }

    private func pruneStaleTemporaryDatabaseCopies(in directoryURL: URL) {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let cutoff = Date().addingTimeInterval(-Self.temporaryDatabaseCopyMaximumAge)
        for url in urls {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            guard values?.isRegularFile == true,
                  (values?.contentModificationDate ?? .distantPast) < cutoff
            else {
                continue
            }
            try? fileManager.removeItem(at: url)
        }
    }
}

private struct TemporaryDatabaseCopy {
    let databaseURL: URL
    let copiedURLs: [URL]
}
