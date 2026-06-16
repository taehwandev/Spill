import Foundation

enum AppDirectories {
    static func applicationSupportDirectory(fileManager: FileManager = .default) -> URL {
        if let url = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) {
            return url
        }

        let fallbackURL = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
        try? fileManager.createDirectory(
            at: fallbackURL,
            withIntermediateDirectories: true
        )
        return fallbackURL
    }

    static func spillApplicationSupportDirectory(fileManager: FileManager = .default) -> URL {
        let url = applicationSupportDirectory(fileManager: fileManager)
            .appendingPathComponent("Spill", isDirectory: true)
        try? fileManager.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        return url
    }
}
