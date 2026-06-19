import Foundation

enum LocalAICommandMetadataReader {
    private static let cacheLock = NSLock()
    private nonisolated(unsafe) static var cachedVersionsByExecutablePath: [String: CachedVersion] = [:]
    private static let versionCacheTTL: TimeInterval = 300

    static func metadata(for executablePaths: [String: String], now: Date = Date()) -> [LocalAIToolKind: LocalAIToolMetadata] {
        var metadata = [LocalAIToolKind: LocalAIToolMetadata]()

        for kind in LocalAIToolKind.allCases {
            guard let executablePath = kind.executableNames.compactMap({ executablePaths[$0] }).first,
                  let version = version(executablePath: executablePath, now: now)
            else {
                continue
            }

            metadata[kind] = LocalAIToolMetadata(model: nil, version: version, source: "Command")
        }

        return metadata
    }

    private static func version(executablePath: String, now: Date) -> String? {
        if let cached = cacheLock.withLock({ cachedVersionsByExecutablePath[executablePath] }),
           now.timeIntervalSince(cached.cachedAt) < versionCacheTTL {
            return cached.version
        }

        guard let output = LocalCommandRunner.output(
            executablePath: executablePath,
            arguments: ["--version"],
            timeout: 1.0
        ) else {
            return nil
        }

        guard let version = versionText(from: output) else {
            return nil
        }
        cacheLock.withLock {
            cachedVersionsByExecutablePath[executablePath] = CachedVersion(version: version, cachedAt: now)
        }
        return version
    }

    private static func versionText(from output: String) -> String? {
        guard let firstLine = output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !firstLine.isEmpty
        else {
            return nil
        }

        let separators = CharacterSet.whitespacesAndNewlines
            .union(CharacterSet(charactersIn: ",:;()"))
        let tokens = firstLine
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }

        return tokens.first { token in
            token.contains { character in
                character.isNumber
            }
        }?.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }

    private struct CachedVersion {
        let version: String
        let cachedAt: Date
    }
}
