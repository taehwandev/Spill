import Foundation

extension TokenUsageAntigravityImporter {
    func discoverConversationDatabases(modifiedSince startDate: Date) -> [ConversationDatabase] {
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

            for suffix in ["-wal", "-shm"] {
                let sidecarURL = url.deletingLastPathComponent()
                    .appendingPathComponent(url.lastPathComponent + suffix)
                if let values = try? sidecarURL.resourceValues(forKeys: [.contentModificationDateKey]),
                   let sidecarModifiedAt = values.contentModificationDate {
                    modifiedAt = max(modifiedAt, sidecarModifiedAt)
                }
            }

            guard modifiedAt >= startDate else {
                return nil
            }
            return ConversationDatabase(url: url, modifiedAt: modifiedAt)
        }
        .sorted { $0.url.lastPathComponent < $1.url.lastPathComponent }
    }
}
