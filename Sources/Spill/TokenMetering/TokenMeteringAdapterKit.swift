import AppKit
import Foundation

struct TokenMeteringAdapter: Identifiable, Sendable {
    let aiTool: TokenUsageAITool
    let title: String
    let subtitle: String
    let scriptFileName: String
    /// nil means no hook config to copy (e.g. SDK wrappers).
    let hookConfigTemplate: String?
    /// Human-readable target file hint shown below the hook config copy button.
    let hookConfigTarget: String?

    var id: String { aiTool.rawValue }

    var directoryName: String {
        switch aiTool {
        case .claude:
            "claude-code"
        default:
            aiTool.rawValue
        }
    }

    var scriptURL: URL? {
        Bundle.main.url(
            forResource: scriptFileName.components(separatedBy: ".").first,
            withExtension: scriptFileName.components(separatedBy: ".").last,
            subdirectory: "adapters/\(directoryName)"
        )
    }

    var scriptContent: String? {
        guard let url = scriptURL else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Renders the hook config with the actual installed script path substituted in.
    func hookConfig(installedAt scriptPath: URL) -> String? {
        guard let template = hookConfigTemplate else { return nil }
        return template.replacingOccurrences(
            of: "<script_path>",
            with: ShellQuoting.singleQuoted(scriptPath.path)
        )
    }

    func install(to destination: URL, sourceURL: URL? = nil) throws {
        guard let url = sourceURL ?? scriptURL else {
            throw TokenMeteringAdapterInstallError.scriptNotFound(title)
        }
        try copyExecutableScript(from: url, to: destination)
    }

    func refreshInstallIfPresent(
        at destination: URL,
        sourceURL: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> Bool {
        guard fileManager.fileExists(atPath: destination.path) else {
            return false
        }

        try install(to: destination, sourceURL: sourceURL)
        return true
    }
}

enum TokenMeteringAdapterInstallError: LocalizedError {
    case scriptNotFound(String)

    var errorDescription: String? {
        switch self {
        case .scriptNotFound(let name):
            "\(name) script not found in app bundle."
        }
    }
}

enum TokenMeteringAdapterKit {
    static let hookAdapters: [TokenMeteringAdapter] = [
        claudeCode,
        codex,
    ]

    static let all: [TokenMeteringAdapter] = [
        claudeCode,
        codex,
        agy,
        openai,
    ]

    static let claudeCode = TokenMeteringAdapter(
        aiTool: .claude,
        title: "Claude Code",
        subtitle: "Local transcript reader",
        scriptFileName: "spill-hook.py",
        hookConfigTemplate: """
        Add one entry to the "Stop" array in ~/.claude/settings.json.
        ⚠️ "matcher" is required — omitting it prevents the hook from running.

        {
          "matcher": "",
          "hooks": [
            {
              "type": "command",
              "command": "python3 <script_path>",
              "timeout": 5
            }
          ]
        }
        """,
        hookConfigTarget: "~/.claude/settings.json → hooks.Stop"
    )

    static let codex = TokenMeteringAdapter(
        aiTool: .codex,
        title: "Codex",
        subtitle: "Local session usage reader",
        scriptFileName: "spill-importer.mjs",
        hookConfigTemplate: """
        Add to ~/.codex/hooks.json:
        The Stop group includes matcher so the setup shape stays consistent across hook runners.

        {
          "hooks": {
            "Stop": [
              {
                "matcher": "",
                "hooks": [
                  {
                    "type": "command",
                    "command": "node <script_path> --since-hours 6",
                    "timeout": 30
                  }
                ]
              }
            ]
          }
        }
        """,
        hookConfigTarget: "~/.codex/hooks.json"
    )

    static let agy = TokenMeteringAdapter(
        aiTool: .antigravity,
        title: "Antigravity",
        subtitle: "Active importer — no runtime hook",
        scriptFileName: "active-importer",
        hookConfigTemplate: nil,
        hookConfigTarget: nil
    )

    static let openai = TokenMeteringAdapter(
        aiTool: .openAI,
        title: "OpenAI",
        subtitle: "SDK wrapper — SpillOpenAIClient",
        scriptFileName: "spill-adapter.py",
        hookConfigTemplate: """
        Import SpillOpenAIClient and use it in place of openai.OpenAI:
          from spill_adapter import SpillOpenAIClient
          client = SpillOpenAIClient()          # reads OPENAI_API_KEY from env
          response = client.chat.completions.create(model="gpt-4o", messages=[...])
        Requires: pip install openai
        """,
        hookConfigTarget: nil
    )

    static func defaultInstallURL(for adapter: TokenMeteringAdapter) -> URL {
        AppDirectories.spillApplicationSupportDirectory()
            .appendingPathComponent("adapters", isDirectory: true)
            .appendingPathComponent(adapter.directoryName, isDirectory: true)
            .appendingPathComponent(adapter.scriptFileName)
    }

    static func refreshInstalledHookAdaptersIfPresent(
        installedURL: (TokenMeteringAdapter) -> URL = TokenMeteringAdapterKit.defaultInstallURL(for:)
    ) {
        for adapter in hookAdapters {
            _ = try? adapter.refreshInstallIfPresent(at: installedURL(adapter))
        }
    }
}

enum TokenMeteringSetupInstaller {
    static let scriptFileName = "spill-token-metering-setup.mjs"
    static let statsScriptFileName = "spill-token-metering-stats.mjs"
    static let runtimeInstructionFileName = "runtime-instruction.md"
    static let publicInstallScriptURL = "https://spill.thdev.app/token-metering/install.sh"
    static let publicSetupCommand = #"/bin/bash -c "$(curl -fsSL https://spill.thdev.app/token-metering/install.sh)""#

    static var scriptURL: URL? {
        Bundle.main.url(
            forResource: "spill-token-metering-setup",
            withExtension: "mjs",
            subdirectory: "adapters/setup"
        )
    }

    static var statsScriptURL: URL? {
        Bundle.main.url(
            forResource: "spill-token-metering-stats",
            withExtension: "mjs",
            subdirectory: "adapters/setup"
        )
    }

    static var runtimeInstructionURL: URL? {
        Bundle.main.url(
            forResource: "runtime-instruction",
            withExtension: "md",
            subdirectory: "adapters/setup"
        )
    }

    static func defaultInstallURL() -> URL {
        AppDirectories.spillApplicationSupportDirectory()
            .appendingPathComponent("adapters", isDirectory: true)
            .appendingPathComponent("setup", isDirectory: true)
            .appendingPathComponent(scriptFileName)
    }

    static func defaultStatsInstallURL() -> URL {
        defaultInstallURL()
            .deletingLastPathComponent()
            .appendingPathComponent(statsScriptFileName)
    }

    static func defaultRuntimeInstructionInstallURL() -> URL {
        defaultInstallURL()
            .deletingLastPathComponent()
            .appendingPathComponent(runtimeInstructionFileName)
    }

    static func defaultSharedRuntimeInstructionURL(fileManager: FileManager = .default) -> URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".spill", isDirectory: true)
            .appendingPathComponent(runtimeInstructionFileName)
    }

    static func refreshInstalledFilesIfPresent() {
        TokenMeteringAdapterKit.refreshInstalledHookAdaptersIfPresent()
        _ = try? refreshInstalledHelperIfPresent(
            sourceURL: scriptURL,
            destination: defaultInstallURL()
        )
        _ = try? refreshInstalledHelperIfPresent(
            sourceURL: statsScriptURL,
            destination: defaultStatsInstallURL()
        )
        _ = try? refreshInstalledRuntimeInstructionIfPresent(
            sourceURL: runtimeInstructionURL,
            destination: defaultRuntimeInstructionInstallURL()
        )
        _ = try? refreshInstalledRuntimeInstructionIfPresent(
            sourceURL: runtimeInstructionURL,
            destination: defaultSharedRuntimeInstructionURL()
        )
    }

    @discardableResult
    static func refreshInstalledHelperIfPresent(
        sourceURL: URL?,
        destination: URL,
        fileManager: FileManager = .default
    ) throws -> Bool {
        guard let sourceURL,
              fileManager.fileExists(atPath: destination.path)
        else {
            return false
        }

        try copyExecutableScript(from: sourceURL, to: destination, fileManager: fileManager)
        return true
    }
}

extension TokenMeteringSetupInstaller {
    @discardableResult
    static func refreshInstalledRuntimeInstructionIfPresent(
        sourceURL: URL?,
        destination: URL,
        fileManager: FileManager = .default
    ) throws -> Bool {
        guard let sourceURL,
              fileManager.fileExists(atPath: destination.path)
        else {
            return false
        }

        try copyPrivateResource(
            from: sourceURL,
            to: destination,
            permissions: 0o600,
            fileManager: fileManager
        )
        return true
    }

    static func install(to destination: URL = defaultInstallURL()) throws {
        guard let url = scriptURL else {
            throw TokenMeteringAdapterInstallError.scriptNotFound("Setup helper")
        }
        guard let statsURL = statsScriptURL else {
            throw TokenMeteringAdapterInstallError.scriptNotFound("Stats helper")
        }
        guard let runtimeInstructionURL else {
            throw TokenMeteringAdapterInstallError.scriptNotFound("Runtime instruction")
        }

        for adapter in TokenMeteringAdapterKit.hookAdapters {
            try adapter.install(to: TokenMeteringAdapterKit.defaultInstallURL(for: adapter))
        }

        try copyExecutableScript(from: url, to: destination)

        let statsDestination = destination
            .deletingLastPathComponent()
            .appendingPathComponent(statsScriptFileName)
        try copyExecutableScript(from: statsURL, to: statsDestination)
        try copyPrivateResource(
            from: runtimeInstructionURL,
            to: destination.deletingLastPathComponent().appendingPathComponent(runtimeInstructionFileName),
            permissions: 0o600
        )
        try copyPrivateResource(
            from: runtimeInstructionURL,
            to: defaultSharedRuntimeInstructionURL(),
            permissions: 0o600
        )
    }

    static func setupCommand(installedAt scriptURL: URL = defaultInstallURL()) -> String {
        publicSetupCommand
    }
}

private enum ShellQuoting {
    static func singleQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

private func copyExecutableScript(
    from sourceURL: URL,
    to destination: URL,
    fileManager: FileManager = .default
) throws {
    try copyPrivateResource(
        from: sourceURL,
        to: destination,
        permissions: 0o700,
        fileManager: fileManager
    )
}

private func copyPrivateResource(
    from sourceURL: URL,
    to destination: URL,
    permissions: Int,
    fileManager: FileManager = .default
) throws {
    let resourceDirectory = destination.deletingLastPathComponent()
    if resourceDirectory.lastPathComponent != ".spill" {
        try TokenUsageStore.createPrivateDirectoryIfNeeded(at: resourceDirectory.deletingLastPathComponent())
    }
    try TokenUsageStore.createPrivateDirectoryIfNeeded(at: resourceDirectory)

    let temporaryURL = destination
        .deletingLastPathComponent()
        .appendingPathComponent(".\(destination.lastPathComponent).tmp-\(UUID().uuidString)")
    try fileManager.copyItem(at: sourceURL, to: temporaryURL)
    do {
        var attrs = try fileManager.attributesOfItem(atPath: temporaryURL.path)
        attrs[.posixPermissions] = permissions
        try fileManager.setAttributes(attrs, ofItemAtPath: temporaryURL.path)

        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(
                destination,
                withItemAt: temporaryURL,
                options: .usingNewMetadataOnly
            )
        } else {
            try fileManager.moveItem(at: temporaryURL, to: destination)
        }
    } catch {
        try? fileManager.removeItem(at: temporaryURL)
        throw error
    }
}

extension TokenUsageAITool {
    var adapterTitle: String {
        TokenMeteringAdapterKit.all.first { $0.aiTool == self }?.title ?? rawValue
    }
}
