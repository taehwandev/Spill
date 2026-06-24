import Foundation

extension TokenUsageCollectorCoordinator {
    static func nodeExecutableURL(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isExecutableFile: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) },
        isRegularFile: (String) -> Bool = { path in
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
                return false
            }
            return !isDirectory.boolValue
        }
    ) -> URL? {
        let candidates = [
            environment["SPILL_TOKEN_USAGE_NODE"],
            environment["NODE_BINARY"],
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node",
            "/usr/bin/node",
        ].compactMap { $0 }

        for candidate in candidates {
            let candidateURL = URL(fileURLWithPath: candidate)
            guard candidateURL.path == candidate else {
                continue
            }

            let standardizedPath = candidateURL.standardizedFileURL.path
            if isRegularFile(standardizedPath), isExecutableFile(standardizedPath) {
                return URL(fileURLWithPath: standardizedPath)
            }
        }

        return nil
    }

    static func python3ExecutableURL(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isExecutableFile: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) },
        isRegularFile: (String) -> Bool = { path in
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
                return false
            }
            return !isDirectory.boolValue
        }
    ) -> URL? {
        let candidates = [
            environment["SPILL_TOKEN_USAGE_PYTHON3"],
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3",
        ].compactMap { $0 }

        for candidate in candidates {
            let candidateURL = URL(fileURLWithPath: candidate)
            guard candidateURL.path == candidate else {
                continue
            }

            let standardizedPath = candidateURL.standardizedFileURL.path
            if isRegularFile(standardizedPath), isExecutableFile(standardizedPath) {
                return URL(fileURLWithPath: standardizedPath)
            }
        }

        return nil
    }
}
