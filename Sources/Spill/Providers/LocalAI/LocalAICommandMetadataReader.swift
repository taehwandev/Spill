import Foundation

enum LocalAICommandMetadataReader {
    private static let cacheLock = NSLock()
    private nonisolated(unsafe) static var cachedVersionsByExecutablePath: [String: CachedVersion] = [:]
    private nonisolated(unsafe) static var inFlightExecutablePaths = Set<String>()
    private static let versionCacheTTL: TimeInterval = 300
    private static let failedVersionCacheTTL: TimeInterval = 15

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
           cached.isValid(at: now, successTTL: versionCacheTTL, failureTTL: failedVersionCacheTTL) {
            return cached.version
        }
        let shouldRunLookup = cacheLock.withLock { () -> Bool in
            guard !inFlightExecutablePaths.contains(executablePath) else {
                return false
            }
            inFlightExecutablePaths.insert(executablePath)
            return true
        }
        guard shouldRunLookup else {
            return cacheLock.withLock { cachedVersionsByExecutablePath[executablePath]?.version }
        }
        defer {
            cacheLock.withLock {
                _ = inFlightExecutablePaths.remove(executablePath)
            }
        }

        guard let output = LocalCommandRunner.output(
            executablePath: executablePath,
            arguments: ["--version"],
            timeout: 1.0
        ) else {
            cacheLock.withLock {
                cachedVersionsByExecutablePath[executablePath] = CachedVersion(version: nil, cachedAt: now)
            }
            return nil
        }

        guard let version = versionText(from: output) else {
            cacheLock.withLock {
                cachedVersionsByExecutablePath[executablePath] = CachedVersion(version: nil, cachedAt: now)
            }
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
        let version: String?
        let cachedAt: Date

        func isValid(at now: Date, successTTL: TimeInterval, failureTTL: TimeInterval) -> Bool {
            now.timeIntervalSince(cachedAt) < (version == nil ? failureTTL : successTTL)
        }
    }
}
