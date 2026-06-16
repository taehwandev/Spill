import Foundation

enum TokenUsageStoreEnvironment {
    static func store(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> TokenUsageStore? {
        guard environment["SPILL_SMOKE_TEST"] == "1",
              let eventsFile = environment["SPILL_TOKEN_USAGE_EVENTS_FILE"],
              !eventsFile.isEmpty,
              let eventsURL = validatedURL(
                rawPath: eventsFile,
                allowedRoots: allowedRoots(environment: environment, fileManager: fileManager),
                fileManager: fileManager
              )
        else {
            return nil
        }

        let inboxURL = environment["SPILL_TOKEN_USAGE_INBOX_DIR"]
            .flatMap { $0.isEmpty ? nil : $0 }
            .flatMap {
                validatedURL(
                    rawPath: $0,
                    allowedRoots: allowedRoots(environment: environment, fileManager: fileManager),
                    fileManager: fileManager
                )
            }

        return TokenUsageStore(fileURL: eventsURL, inboxURL: inboxURL)
    }

    private static func allowedRoots(
        environment: [String: String],
        fileManager: FileManager
    ) -> [URL] {
        var roots = [
            AppDirectories.spillApplicationSupportDirectory(fileManager: fileManager)
        ]

        if environment["SPILL_SMOKE_TEST"] == "1" {
            roots.append(fileManager.temporaryDirectory)
            roots.append(URL(fileURLWithPath: "/tmp", isDirectory: true))
            roots.append(URL(fileURLWithPath: "/private/tmp", isDirectory: true))
        }

        return roots.map {
            resolvedURL($0, fileManager: fileManager)
        }
    }

    private static func validatedURL(
        rawPath: String,
        allowedRoots: [URL],
        fileManager: FileManager
    ) -> URL? {
        let url = URL(fileURLWithPath: rawPath)
        guard url.path == rawPath else {
            return nil
        }

        let resolved = resolvedURL(url, fileManager: fileManager)
        guard allowedRoots.contains(where: { contains(resolved, in: $0) }) else {
            return nil
        }
        return resolved
    }

    private static func resolvedURL(_ url: URL, fileManager: FileManager) -> URL {
        let standardized = url.standardizedFileURL
        if fileManager.fileExists(atPath: standardized.path) {
            return standardized.resolvingSymlinksInPath()
        }

        let parentURL = standardized.deletingLastPathComponent().resolvingSymlinksInPath()
        return parentURL.appendingPathComponent(
            standardized.lastPathComponent,
            isDirectory: standardized.hasDirectoryPath
        )
    }

    private static func contains(_ candidate: URL, in root: URL) -> Bool {
        let candidateComponents = candidate.standardizedFileURL.pathComponents
        let rootComponents = root.standardizedFileURL.pathComponents
        guard candidateComponents.count > rootComponents.count else {
            return false
        }

        return zip(rootComponents, candidateComponents).allSatisfy(==)
    }
}
