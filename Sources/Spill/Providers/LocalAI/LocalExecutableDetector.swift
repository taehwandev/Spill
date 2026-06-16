import Foundation

enum LocalExecutableDetector {
    static func installedExecutablePaths(
        for kinds: [LocalAIToolKind],
        environment: [String: String]
    ) -> [String: String] {
        let executableNames = kinds.flatMap(\.executableNames)
        let directories = searchDirectories(environment: environment)
        let fileManager = FileManager.default
        var installedPaths = [String: String]()

        for executableName in executableNames {
            guard let directory = directories.first(where: { directory in
                fileManager.isExecutableFile(atPath: "\(directory)/\(executableName)")
            }) else {
                continue
            }

            installedPaths[executableName] = "\(directory)/\(executableName)"
        }

        return installedPaths
    }

    static func installedExecutableNames(
        for kinds: [LocalAIToolKind],
        environment: [String: String]
    ) -> Set<String> {
        Set(installedExecutablePaths(for: kinds, environment: environment).keys)
    }

    private static func searchDirectories(environment: [String: String]) -> [String] {
        let pathDirectories = environment["PATH"]?
            .split(separator: ":")
            .map(String.init) ?? []
        let homeDirectory = NSHomeDirectory()
        let defaultDirectories = [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/local/sbin",
            "/usr/bin",
            "/bin",
            "\(homeDirectory)/.local/bin",
            "\(homeDirectory)/.npm-global/bin",
            "\(homeDirectory)/.bun/bin"
        ]

        return uniqueNonEmptyPaths(pathDirectories + defaultDirectories)
    }

    private static func uniqueNonEmptyPaths(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        var uniquePaths = [String]()

        for path in paths {
            let normalizedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedPath.isEmpty, seen.insert(normalizedPath).inserted else {
                continue
            }

            uniquePaths.append(normalizedPath)
        }

        return uniquePaths
    }
}
