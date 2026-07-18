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
        // Only the Spill-namespaced override is trusted. A generic name like NODE_BINARY
        // is set by many unrelated tools and shell profiles, so honoring it here would let
        // any local process or dotfile that happens to export NODE_BINARY redirect which
        // binary Spill executes.
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            environment["SPILL_TOKEN_USAGE_NODE"],
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node",
            "/usr/bin/node",
            // Fixed shim locations for version managers (unlike PATH, these can't be
            // redirected by an unrelated env var or dotfile).
            "\(homeDirectory)/.volta/bin/node",
            "\(homeDirectory)/.asdf/shims/node",
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
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            environment["SPILL_TOKEN_USAGE_PYTHON3"],
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3",
            // Fixed shim locations for version managers (unlike PATH, these can't be
            // redirected by an unrelated env var or dotfile).
            "\(homeDirectory)/.asdf/shims/python3",
            "\(homeDirectory)/.pyenv/shims/python3",
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
