import Foundation

struct ProcessJSONSummary {
    let isValid: Bool
    let scannedSources: Int
    let importedEvents: Int
    let skippedDuplicates: Int
    let unsupportedRecords: Int

    init(_ stdout: String) {
        guard let line = stdout
            .split(whereSeparator: \.isNewline)
            .last,
            let data = line.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            isValid = false
            scannedSources = 0
            importedEvents = 0
            skippedDuplicates = 0
            unsupportedRecords = 0
            return
        }

        isValid = true
        scannedSources = Self.intValue(object["scanned_files"])
        importedEvents = Self.intValue(object["imported_events"])
        skippedDuplicates = Self.intValue(object["skipped_seen"])
        unsupportedRecords = Self.intValue(object["unsupported_records"])
    }

    private static func intValue(_ value: Any?) -> Int {
        if let value = value as? Int {
            return max(0, value)
        }
        if let value = value as? NSNumber {
            return max(0, value.intValue)
        }
        return 0
    }
}
