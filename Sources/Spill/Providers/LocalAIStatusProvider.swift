import Foundation

enum LocalAIToolKind: String, CaseIterable, Identifiable, Sendable {
    case codex
    case claude
    case antigravity
    case ollama
    case openAI

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .codex:
            return "Codex"
        case .claude:
            return "Claude"
        case .antigravity:
            return "Antigravity"
        case .ollama:
            return "Ollama"
        case .openAI:
            return "OpenAI API"
        }
    }

    var symbolName: String {
        switch self {
        case .codex:
            return "terminal.fill"
        case .claude:
            return "terminal.fill"
        case .antigravity:
            return "terminal.fill"
        case .ollama:
            return "cpu"
        case .openAI:
            return "key.fill"
        }
    }

    var executableNames: [String] {
        switch self {
        case .codex:
            return ["codex"]
        case .claude:
            return ["claude"]
        case .antigravity:
            return ["agy", "antigravity", "antigravity-cli"]
        case .ollama:
            return ["ollama"]
        case .openAI:
            return []
        }
    }

    var executableName: String? {
        executableNames.first
    }

    var applicationNames: [String] {
        switch self {
        case .antigravity:
            return ["Antigravity", "Antigravity IDE"]
        case .codex, .claude, .ollama, .openAI:
            return []
        }
    }
}

struct LocalAIToolMetadata: Hashable, Sendable {
    static let empty = LocalAIToolMetadata(model: nil, version: nil, source: nil)

    let model: String?
    let version: String?
    let source: String?

    init(
        model: String?,
        version: String?,
        source: String?
    ) {
        self.model = model
        self.version = version
        self.source = source
    }
}

struct LocalAIToolActionRecommendation: Hashable, Sendable {
    let title: String
    let detail: String

    static func recommendation(for status: LocalAIToolStatus) -> LocalAIToolActionRecommendation? {
        guard status.state != .unavailable else {
            return nil
        }

        switch status.kind {
        case .codex, .claude, .antigravity:
            guard status.kind.executableName != nil else {
                return nil
            }

            return commandLineRecommendation(
                status: status,
                readyTitle: "Start from terminal",
                activeTitle: "Continue in terminal"
            )
        case .ollama:
            if status.hasRunningProcesses {
                return LocalAIToolActionRecommendation(
                    title: "Inspect local models",
                    detail: "Ollama is running locally."
                )
            }

            return LocalAIToolActionRecommendation(
                title: "Start local server",
                detail: "Run the local model server when you need it."
            )
        case .openAI:
            return LocalAIToolActionRecommendation(
                title: "Use configured API",
                detail: "OpenAI configuration is available; secret values stay hidden."
            )
        }
    }

    private static func commandLineRecommendation(
        status: LocalAIToolStatus,
        readyTitle: String,
        activeTitle: String
    ) -> LocalAIToolActionRecommendation {
        LocalAIToolActionRecommendation(
            title: status.hasRunningProcesses ? activeTitle : readyTitle,
            detail: status.hasRunningProcesses
                ? "A local process is running. Open your terminal session to continue."
                : "Launch it from your terminal when you need a new session."
        )
    }
}

struct LocalAIToolStatus: Identifiable, Hashable, Sendable {
    let kind: LocalAIToolKind
    let value: String
    let subtitle: String?
    let state: SpillStatusState
    let metadata: LocalAIToolMetadata
    let processSummary: LocalAIProcessSummary

    init(
        kind: LocalAIToolKind,
        value: String,
        subtitle: String?,
        state: SpillStatusState,
        metadata: LocalAIToolMetadata = .empty,
        processSummary: LocalAIProcessSummary = .empty
    ) {
        self.kind = kind
        self.value = value
        self.subtitle = subtitle
        self.state = state
        self.metadata = metadata
        self.processSummary = processSummary
    }

    var id: String {
        kind.rawValue
    }

    var title: String {
        kind.title
    }

    var symbolName: String {
        kind.symbolName
    }

    var actionRecommendation: LocalAIToolActionRecommendation? {
        LocalAIToolActionRecommendation.recommendation(for: self)
    }

    var hasRunningProcesses: Bool {
        processSummary.isRunning || value == "Running"
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
        case .claude:
            return 20
        case .antigravity:
            return 30
        case .ollama:
            return 40
        case .openAI:
            return 50
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
        let environment = ProcessInfo.processInfo.environment
        let executablePaths = LocalExecutableDetector.installedExecutablePaths(
            for: [.codex, .claude, .antigravity, .ollama],
            environment: environment
        )
        let installedApplicationNames = LocalApplicationDetector.installedApplicationNames(
            for: [.antigravity]
        )
        let processSnapshots = LocalAIProcessSnapshotReader.currentSnapshots()
        let processCommands = processSnapshots.map(\.commandLine)
        let processNames = Set(processSnapshots.map(\.executableName))

        return statuses(
            environment: environment,
            processNames: processNames,
            processCommands: processCommands,
            processSnapshots: processSnapshots,
            installedExecutableNames: Set(executablePaths.keys),
            installedApplicationNames: installedApplicationNames,
            commandMetadata: LocalAICommandMetadataReader.metadata(for: executablePaths),
            ollamaRuntime: LocalOllamaRuntimeReader.runtimeSummary(
                executablePath: executablePaths[LocalAIToolKind.ollama.executableName ?? ""]
            )
        )
    }

    static func statuses(
        environment: [String: String],
        processNames: Set<String>
    ) -> [LocalAIToolStatus] {
        statuses(
            environment: environment,
            processNames: processNames,
            processCommands: [],
            processSnapshots: [],
            installedExecutableNames: [],
            installedApplicationNames: []
        )
    }

    static func statuses(
        environment: [String: String],
        processNames: Set<String>,
        installedExecutableNames: Set<String>
    ) -> [LocalAIToolStatus] {
        statuses(
            environment: environment,
            processNames: processNames,
            processCommands: [],
            processSnapshots: [],
            installedExecutableNames: installedExecutableNames,
            installedApplicationNames: []
        )
    }

    static func statuses(
        environment: [String: String],
        processNames: Set<String>,
        processCommands: [String],
        processSnapshots: [LocalAIProcessSnapshot] = [],
        installedExecutableNames: Set<String>,
        installedApplicationNames: Set<String> = [],
        commandMetadata: [LocalAIToolKind: LocalAIToolMetadata] = [:],
        ollamaRuntime: LocalOllamaRuntimeSummary? = nil
    ) -> [LocalAIToolStatus] {
        let normalizedProcessNames = Set(processNames.map { $0.lowercased() })
        let normalizedInstalledExecutableNames = Set(installedExecutableNames.map { $0.lowercased() })
        let normalizedInstalledApplicationNames = Set(installedApplicationNames.map { $0.lowercased() })

        return [
            commandStatus(
                kind: .codex,
                processNames: normalizedProcessNames,
                processCommands: processCommands,
                processSnapshots: processSnapshots,
                installedExecutableNames: normalizedInstalledExecutableNames,
                installedApplicationNames: normalizedInstalledApplicationNames,
                metadata: commandMetadata[.codex]
            ),
            commandStatus(
                kind: .claude,
                processNames: normalizedProcessNames,
                processCommands: processCommands,
                processSnapshots: processSnapshots,
                installedExecutableNames: normalizedInstalledExecutableNames,
                installedApplicationNames: normalizedInstalledApplicationNames,
                metadata: commandMetadata[.claude]
            ),
            commandStatus(
                kind: .antigravity,
                processNames: normalizedProcessNames,
                processCommands: processCommands,
                processSnapshots: processSnapshots,
                installedExecutableNames: normalizedInstalledExecutableNames,
                installedApplicationNames: normalizedInstalledApplicationNames,
                metadata: commandMetadata[.antigravity]
            ),
            commandStatus(
                kind: .ollama,
                processNames: normalizedProcessNames,
                processCommands: processCommands,
                processSnapshots: processSnapshots,
                installedExecutableNames: normalizedInstalledExecutableNames,
                installedApplicationNames: normalizedInstalledApplicationNames,
                metadata: commandMetadata[.ollama],
                runtimeModel: ollamaRuntime?.activeModel
            ),
            openAIStatus(environment: environment)
        ].compactMap { $0 }
    }

    private static func commandStatus(
        kind: LocalAIToolKind,
        processNames: Set<String>,
        processCommands: [String],
        processSnapshots: [LocalAIProcessSnapshot],
        installedExecutableNames: Set<String>,
        installedApplicationNames: Set<String>,
        metadata commandMetadata: LocalAIToolMetadata?,
        runtimeModel: String? = nil
    ) -> LocalAIToolStatus? {
        let executableNames = kind.executableNames
        let applicationNames = kind.applicationNames
        guard !executableNames.isEmpty || !applicationNames.isEmpty else {
            return nil
        }

        let processMetadata = LocalAIProcessMetadataReader.metadata(
            for: kind,
            processCommands: processCommands
        )
        let metadata = combinedMetadata(
            commandMetadata: commandMetadata,
            processMetadata: processMetadata,
            runtimeModel: runtimeModel
        )
        let matchingProcesses = matchingProcessSnapshots(
            executableNames: executableNames,
            applicationNames: applicationNames,
            processSnapshots: processSnapshots
        )
        let fallbackRunning = hasRunningProcess(
            namedAnyOf: executableNames + applicationNames,
            processNames: processNames,
            processCommands: processCommands
        )
        let processSummary = LocalAIProcessSummary(
            processes: matchingProcesses,
            fallbackProcessCount: matchingProcesses.isEmpty && fallbackRunning ? 1 : 0
        )
        let isRunning = processSummary.isRunning
        let isInstalled = executableNames.contains { installedExecutableNames.contains($0) }
            || applicationNames.contains { installedApplicationNames.contains($0.lowercased()) }

        guard isInstalled else {
            return nil
        }

        let enrichedMetadata = LocalAIToolMetadata(
            model: metadata.model,
            version: metadata.version,
            source: metadata.source
        )

        let value = commandValue(isRunning: isRunning)
        let subtitle = commandSubtitle(
            metadata: enrichedMetadata,
            isRunning: isRunning
        )
        let state = commandState(isRunning: isRunning)

        return LocalAIToolStatus(
            kind: kind,
            value: value,
            subtitle: subtitle,
            state: state,
            metadata: enrichedMetadata,
            processSummary: processSummary
        )
    }

    private static func commandValue(isRunning: Bool) -> String {
        return isRunning ? "Running" : "Ready"
    }

    private static func commandSubtitle(
        metadata: LocalAIToolMetadata,
        isRunning: Bool
    ) -> String {
        return compactSubtitle(
            metadata: metadata,
            fallback: isRunning ? "Local process" : "Ready locally"
        )
    }

    private static func commandState(isRunning: Bool) -> SpillStatusState {
        return .normal
    }

    private static func openAIStatus(environment: [String: String]) -> LocalAIToolStatus? {
        let hasConfiguration = hasNonEmptyValue("OPENAI_API_KEY", in: environment)
            || hasNonEmptyValue("OPENAI_BASE_URL", in: environment)

        guard hasConfiguration else {
            return nil
        }

        let model = firstNonEmptyValue(
            in: environment,
            keys: ["OPENAI_MODEL", "OPENAI_DEFAULT_MODEL", "OPENAI_API_MODEL"]
        )
        let metadata = LocalAIToolMetadata(
            model: model,
            version: nil,
            source: model == nil ? nil : "Environment"
        )

        return LocalAIToolStatus(
            kind: .openAI,
            value: "Configured",
            subtitle: compactSubtitle(metadata: metadata, fallback: "API key/base URL"),
            state: .normal,
            metadata: metadata
        )
    }

    private static func combinedMetadata(
        commandMetadata: LocalAIToolMetadata?,
        processMetadata: LocalAIToolMetadata?,
        runtimeModel: String?
    ) -> LocalAIToolMetadata {
        let model = processMetadata?.model ?? runtimeModel ?? commandMetadata?.model
        let source: String?
        if processMetadata?.model != nil {
            source = processMetadata?.source
        } else if runtimeModel != nil {
            source = "Ollama Runtime"
        } else {
            source = commandMetadata?.source
        }

        return LocalAIToolMetadata(
            model: model,
            version: commandMetadata?.version,
            source: source
        )
    }

    private static func compactSubtitle(metadata: LocalAIToolMetadata, fallback: String) -> String {
        if let model = metadata.model, !model.isEmpty {
            return model
        }

        if let version = metadata.version, !version.isEmpty {
            return "v\(version)"
        }

        return fallback
    }

    private static func hasRunningProcess(
        namedAnyOf names: [String],
        processNames: Set<String>,
        processCommands: [String]
    ) -> Bool {
        names.contains { rawName in
            let name = rawName.lowercased()
            return processNames.contains(name)
                || processNames.contains { processName in
                    processName.hasSuffix("/\(name)")
                        || URL(fileURLWithPath: processName).lastPathComponent == name
                }
                || processCommands.contains { command in
                    commandLine(command, matchesExecutableNamed: rawName)
                }
            }
    }

    private static func matchingProcessSnapshots(
        executableNames: [String],
        applicationNames: [String],
        processSnapshots: [LocalAIProcessSnapshot]
    ) -> [LocalAIProcessSnapshot] {
        processSnapshots.filter { snapshot in
            executableNames.contains { executableName in
                commandLine(snapshot.commandLine, matchesExecutableNamed: executableName)
                    || snapshot.executableName.matchesExecutable(named: executableName)
            }
            || applicationNames.contains { applicationName in
                commandLine(snapshot.commandLine, matchesApplicationNamed: applicationName)
                    || snapshot.executableName.caseInsensitiveCompare(applicationName) == .orderedSame
            }
        }
    }

    private static func hasNonEmptyValue(_ key: String, in environment: [String: String]) -> Bool {
        guard let value = environment[key] else {
            return false
        }

        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func firstNonEmptyValue(in environment: [String: String], keys: [String]) -> String? {
        for key in keys {
            guard let value = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty
            else {
                continue
            }

            return value
        }

        return nil
    }

    static func commandLine(_ commandLine: String, matchesExecutableNamed name: String) -> Bool {
        let tokens = LocalAICommandLineParser.tokens(from: commandLine)
        guard let executableToken = LocalAICommandLineParser.executableToken(from: tokens) else {
            return false
        }

        return executableToken.matchesExecutable(named: name)
    }

    static func commandLine(_ commandLine: String, matchesApplicationNamed name: String) -> Bool {
        let lowercasedCommandLine = commandLine.lowercased()
        let lowercasedName = name.lowercased()

        return lowercasedCommandLine.contains("/\(lowercasedName).app/")
            || lowercasedCommandLine.hasSuffix("/\(lowercasedName).app")
    }
}
