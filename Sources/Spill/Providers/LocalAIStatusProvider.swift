import Foundation

enum LocalAIToolKind: String, CaseIterable, Identifiable, Sendable {
    case codex
    case ollama
    case openAI

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .codex:
            return "Codex"
        case .ollama:
            return "Ollama"
        case .openAI:
            return "OpenAI"
        }
    }

    var symbolName: String {
        switch self {
        case .codex:
            return "terminal.fill"
        case .ollama:
            return "cpu"
        case .openAI:
            return "key.fill"
        }
    }
}

struct LocalAIToolStatus: Identifiable, Hashable, Sendable {
    let kind: LocalAIToolKind
    let value: String
    let subtitle: String?
    let state: SpillStatusState

    var id: String {
        kind.rawValue
    }

    var title: String {
        kind.title
    }

    var symbolName: String {
        kind.symbolName
    }

    var statusItem: SpillStatusItem {
        SpillStatusItem(
            id: id,
            providerID: LocalAIStatusProvider.providerID,
            title: title,
            value: value,
            subtitle: subtitle,
            symbolName: symbolName,
            state: state,
            sortPriority: sortPriority
        )
    }

    private var sortPriority: Int {
        switch kind {
        case .codex:
            return 10
        case .ollama:
            return 20
        case .openAI:
            return 30
        }
    }
}

struct LocalAIStatusProvider: SpillStatusProvider {
    static let providerID = SpillProviderID(rawValue: "ai")

    let id = "local.ai"
    let title = "AI"

    func snapshot() async -> [SpillStatusItem] {
        Self.statuses().map(\.statusItem)
    }

    static func statuses() -> [LocalAIToolStatus] {
        statuses(
            environment: ProcessInfo.processInfo.environment,
            processNames: LocalProcessNameReader.currentNames()
        )
    }

    static func statuses(
        environment: [String: String],
        processNames: Set<String>
    ) -> [LocalAIToolStatus] {
        let normalizedProcessNames = Set(processNames.map { $0.lowercased() })

        return [
            codexStatus(processNames: normalizedProcessNames),
            ollamaStatus(processNames: normalizedProcessNames),
            openAIStatus(environment: environment)
        ]
    }

    private static func codexStatus(processNames: Set<String>) -> LocalAIToolStatus {
        let isRunning = processNames.contains("codex")
            || processNames.contains { $0.hasSuffix("/codex") }

        return LocalAIToolStatus(
            kind: .codex,
            value: isRunning ? "Live" : "Idle",
            subtitle: isRunning ? "Process Found" : "No Process",
            state: isRunning ? .active : .unavailable
        )
    }

    private static func ollamaStatus(processNames: Set<String>) -> LocalAIToolStatus {
        let isRunning = processNames.contains("ollama")
            || processNames.contains { $0.hasSuffix("/ollama") }

        return LocalAIToolStatus(
            kind: .ollama,
            value: isRunning ? "On" : "Off",
            subtitle: isRunning ? "Process Found" : "No Process",
            state: isRunning ? .active : .unavailable
        )
    }

    private static func openAIStatus(environment: [String: String]) -> LocalAIToolStatus {
        let hasConfiguration = hasNonEmptyValue("OPENAI_API_KEY", in: environment)
            || hasNonEmptyValue("OPENAI_BASE_URL", in: environment)

        return LocalAIToolStatus(
            kind: .openAI,
            value: hasConfiguration ? "Set" : "Missing",
            subtitle: hasConfiguration ? "Configured" : "No Env",
            state: hasConfiguration ? .normal : .unavailable
        )
    }

    private static func hasNonEmptyValue(_ key: String, in environment: [String: String]) -> Bool {
        guard let value = environment[key] else {
            return false
        }

        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private enum LocalProcessNameReader {
    static func currentNames() -> Set<String> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "comm="]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = nil

        do {
            try process.run()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            return []
        }

        guard let output = String(data: data, encoding: .utf8) else {
            return []
        }

        return Set(
            output
                .split(whereSeparator: \.isNewline)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }
}
