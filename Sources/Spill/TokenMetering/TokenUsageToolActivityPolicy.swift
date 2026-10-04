import Foundation

/// A small app-owned snapshot for adapters invoked outside the Spill process.
/// The installed hooks remain registered, but return before reading transcripts
/// when their tool is disabled. Missing snapshots preserve the existing default.
enum TokenUsageToolActivityPolicy {
    private struct Snapshot: Codable {
        let schemaVersion: Int
        let enabledTools: [String]

        enum CodingKeys: String, CodingKey {
            case schemaVersion = "schema_version"
            case enabledTools = "enabled_tools"
        }
    }

    static func defaultURL() -> URL {
        AppDirectories.spillApplicationSupportDirectory()
            .appendingPathComponent("token-metering", isDirectory: true)
            .appendingPathComponent("enabled-tools.json")
    }

    static func write(
        enabledTools: Set<TokenUsageAITool>,
        to url: URL = defaultURL(),
        isSmokeTest: Bool = false,
        fileManager: FileManager = .default
    ) throws {
        // Smoke collection must never change the policy consumed by real hooks.
        guard !isSmokeTest else { return }
        let directory = url.deletingLastPathComponent()
        try TokenUsageStore.createPrivateDirectoryIfNeeded(at: directory)
        let snapshot = Snapshot(
            schemaVersion: 1,
            enabledTools: enabledTools.map(\.rawValue).sorted()
        )
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
