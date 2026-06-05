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

    var scriptURL: URL? {
        Bundle.main.url(
            forResource: scriptFileName.components(separatedBy: ".").first,
            withExtension: scriptFileName.components(separatedBy: ".").last,
            subdirectory: "adapters/\(aiTool.rawValue)"
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
            throw TokenMeteringAdapterInstallError.scriptNotFound
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
    case scriptNotFound

    var errorDescription: String? {
        "Adapter script not found in app bundle."
    }
}

enum TokenMeteringAdapterKit {
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
        Add to ~/.claude/settings.json under "hooks" → "Stop" → hooks array:
        {
          "type": "command",
          "command": "python3 <script_path>",
          "timeout": 5
        }
        """,
        hookConfigTarget: "~/.claude/settings.json"
    )

    static let codex = TokenMeteringAdapter(
        aiTool: .codex,
        title: "Codex",
        subtitle: "Notification command — completion event",
        scriptFileName: "spill-notify.py",
        hookConfigTemplate: """
        Pass as the Codex notification command flag:
          codex --notification-command "python3 <script_path>"
        Or set in ~/.codex/config.toml:
          notification_command = "python3 <script_path>"
        """,
        hookConfigTarget: "~/.codex/config.toml"
    )

    static let agy = TokenMeteringAdapter(
        aiTool: .antigravity,
        title: "Antigravity",
        subtitle: "PostInvocation hook — token usage reporter",
        scriptFileName: "spill-hook.py",
        hookConfigTemplate: """
        Add to your AGY hooks config under PostInvocation:
        {
          "spill-metering": {
            "PostInvocation": [
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
            ]
          }
        }
        """,
        hookConfigTarget: ".agents/hooks.json"
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
            .appendingPathComponent(adapter.aiTool.rawValue, isDirectory: true)
            .appendingPathComponent(adapter.scriptFileName)
    }
}

extension TokenUsageAITool {
    var adapterTitle: String {
        TokenMeteringAdapterKit.all.first { $0.aiTool == self }?.title ?? rawValue
    }
}
