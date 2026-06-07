import AppKit
import Foundation

struct TokenMeteringAdapter: Identifiable {
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
        return template.replacingOccurrences(of: "<script_path>", with: scriptPath.path)
    }

    func install(to destination: URL) throws {
        guard let url = scriptURL else {
            throw TokenMeteringAdapterInstallError.scriptNotFound(title)
        }
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: url, to: destination)

        var attrs = try FileManager.default.attributesOfItem(atPath: destination.path)
        let perms = (attrs[.posixPermissions] as? Int ?? 0o644) | 0o111
        attrs[.posixPermissions] = perms
        try FileManager.default.setAttributes(attrs, ofItemAtPath: destination.path)
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
        subtitle: "Stop hook — transcript reader",
        scriptFileName: "spill-hook.py",
        hookConfigTemplate: """
        Add one entry to the "Stop" array in ~/.claude/settings.json.
        ⚠️ "matcher" is required — omitting it prevents the hook from running.

        {
          "matcher": "",
          "hooks": [
            {
              "type": "command",
              "command": "python3 '<script_path>'",
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
        subtitle: "Stop hook — session token_count importer",
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
                    "command": "node '<script_path>' --since-hours 6",
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
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base
            .appendingPathComponent("Spill", isDirectory: true)
            .appendingPathComponent("adapters", isDirectory: true)
            .appendingPathComponent(adapter.directoryName, isDirectory: true)
            .appendingPathComponent(adapter.scriptFileName)
    }
}

enum TokenMeteringSetupInstaller {
    static let scriptFileName = "spill-token-metering-setup.mjs"
    static let statsScriptFileName = "spill-token-metering-stats.mjs"
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

    static func defaultInstallURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base
            .appendingPathComponent("Spill", isDirectory: true)
            .appendingPathComponent("adapters", isDirectory: true)
            .appendingPathComponent("setup", isDirectory: true)
            .appendingPathComponent(scriptFileName)
    }

    static func defaultStatsInstallURL() -> URL {
        defaultInstallURL()
            .deletingLastPathComponent()
            .appendingPathComponent(statsScriptFileName)
    }

    static func install(to destination: URL = defaultInstallURL()) throws {
        guard let url = scriptURL else {
            throw TokenMeteringAdapterInstallError.scriptNotFound("Setup helper")
        }
        guard let statsURL = statsScriptURL else {
            throw TokenMeteringAdapterInstallError.scriptNotFound("Stats helper")
        }

        for adapter in TokenMeteringAdapterKit.hookAdapters {
            try adapter.install(to: TokenMeteringAdapterKit.defaultInstallURL(for: adapter))
        }

        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: url, to: destination)

        var attrs = try FileManager.default.attributesOfItem(atPath: destination.path)
        let perms = (attrs[.posixPermissions] as? Int ?? 0o644) | 0o111
        attrs[.posixPermissions] = perms
        try FileManager.default.setAttributes(attrs, ofItemAtPath: destination.path)

        let statsDestination = destination
            .deletingLastPathComponent()
            .appendingPathComponent(statsScriptFileName)
        if FileManager.default.fileExists(atPath: statsDestination.path) {
            try FileManager.default.removeItem(at: statsDestination)
        }
        try FileManager.default.copyItem(at: statsURL, to: statsDestination)

        var statsAttrs = try FileManager.default.attributesOfItem(atPath: statsDestination.path)
        let statsPerms = (statsAttrs[.posixPermissions] as? Int ?? 0o644) | 0o111
        statsAttrs[.posixPermissions] = statsPerms
        try FileManager.default.setAttributes(statsAttrs, ofItemAtPath: statsDestination.path)
    }

    static func setupCommand(installedAt scriptURL: URL = defaultInstallURL()) -> String {
        publicSetupCommand
    }

    private static func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

extension TokenUsageAITool {
    var adapterTitle: String {
        TokenMeteringAdapterKit.all.first { $0.aiTool == self }?.title ?? rawValue
    }
}
