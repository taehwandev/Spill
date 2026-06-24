import Foundation

extension TokenUsageStore {
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


    static func defaultDatabaseURL(for fileURL: URL) -> URL {
        let databaseExtensions: Set<String> = ["db", "sqlite", "sqlite3"]
        if databaseExtensions.contains(fileURL.pathExtension.lowercased()) {
            return fileURL
        }
        return fileURL
            .deletingPathExtension()
            .appendingPathExtension("sqlite3")
    }

}
