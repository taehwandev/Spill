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
            return ["Antigravity"]
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

struct LocalAIToolStatus: Identifiable, Hashable, Sendable {
    let kind: LocalAIToolKind
    let value: String
    let subtitle: String?
    let state: SpillStatusState
    let metadata: LocalAIToolMetadata

    init(
        kind: LocalAIToolKind,
        value: String,
        subtitle: String?,
        state: SpillStatusState,
        metadata: LocalAIToolMetadata = .empty
    ) {
        self.kind = kind
        self.value = value
        self.subtitle = subtitle
        self.state = state
        self.metadata = metadata
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

        return statuses(
            environment: environment,
            processNames: LocalProcessNameReader.currentNames(),
            processCommands: LocalProcessCommandReader.currentCommands(),
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
            installedExecutableNames: installedExecutableNames,
            installedApplicationNames: []
        )
    }

    static func statuses(
        environment: [String: String],
        processNames: Set<String>,
        processCommands: [String],
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
                installedExecutableNames: normalizedInstalledExecutableNames,
                installedApplicationNames: normalizedInstalledApplicationNames,
                metadata: commandMetadata[.codex]
            ),
            commandStatus(
                kind: .claude,
                processNames: normalizedProcessNames,
                processCommands: processCommands,
                installedExecutableNames: normalizedInstalledExecutableNames,
                installedApplicationNames: normalizedInstalledApplicationNames,
                metadata: commandMetadata[.claude]
            ),
            commandStatus(
                kind: .antigravity,
                processNames: normalizedProcessNames,
                processCommands: processCommands,
                installedExecutableNames: normalizedInstalledExecutableNames,
                installedApplicationNames: normalizedInstalledApplicationNames,
                metadata: commandMetadata[.antigravity]
            ),
            commandStatus(
                kind: .ollama,
                processNames: normalizedProcessNames,
                processCommands: processCommands,
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
        let isRunning = hasRunningProcess(
            namedAnyOf: executableNames,
            processNames: processNames,
            processCommands: processCommands
        )
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
            metadata: enrichedMetadata
        )
    }

    private static func commandValue(isRunning: Bool) -> String {
        return isRunning ? "Active" : "Idle"
    }

    private static func commandSubtitle(
        metadata: LocalAIToolMetadata,
        isRunning: Bool
    ) -> String {
        return compactSubtitle(
            metadata: metadata,
            fallback: isRunning ? "Process Running" : "Installed"
        )
    }

    private static func commandState(isRunning: Bool) -> SpillStatusState {
        return isRunning ? .active : .normal
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
            value: "Set",
            subtitle: compactSubtitle(metadata: metadata, fallback: "Configured"),
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
        names.contains { name in
            processNames.contains(name)
                || processNames.contains { processName in
                    processName.hasSuffix("/\(name)")
                        || URL(fileURLWithPath: processName).lastPathComponent == name
                }
                || processCommands.contains { command in
                    commandLine(command, matchesExecutableNamed: name)
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

    fileprivate static func commandLine(_ commandLine: String, matchesExecutableNamed name: String) -> Bool {
        let tokens = LocalAICommandLineParser.tokens(from: commandLine)
        guard let executableToken = LocalAICommandLineParser.executableToken(from: tokens) else {
            return false
        }

        return executableToken.matchesExecutable(named: name)
    }
}

private enum LocalExecutableDetector {
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

private enum LocalApplicationDetector {
    static func installedApplicationNames(for kinds: [LocalAIToolKind]) -> Set<String> {
        let applicationNames = kinds.flatMap(\.applicationNames)
        guard !applicationNames.isEmpty else {
            return []
        }

        let fileManager = FileManager.default
        let directories = [
            "/Applications",
            "\(NSHomeDirectory())/Applications"
        ]
        var installedNames = Set<String>()

        for applicationName in applicationNames {
            let appBundleName = "\(applicationName).app"
            let isInstalled = directories.contains { directory in
                fileManager.fileExists(atPath: "\(directory)/\(appBundleName)")
            }

            if isInstalled {
                installedNames.insert(applicationName)
            }
        }

        return installedNames
    }
}

private enum LocalAIProcessMetadataReader {
    static func metadata(
        for kind: LocalAIToolKind,
        processCommands: [String]
    ) -> LocalAIToolMetadata? {
        guard !kind.executableNames.isEmpty else {
            return nil
        }

        for command in processCommands where kind.executableNames.contains(where: { executableName in
            LocalAIStatusProvider.commandLine(command, matchesExecutableNamed: executableName)
        }) {
            guard let model = LocalAICommandLineParser.modelArgument(in: command) else {
                continue
            }

            return LocalAIToolMetadata(model: model, version: nil, source: "Process Args")
        }

        return nil
    }
}

struct LocalOllamaRuntimeSummary: Equatable, Sendable {
    let activeModel: String?
}

private enum LocalOllamaRuntimeReader {
    static func runtimeSummary(executablePath: String?) -> LocalOllamaRuntimeSummary? {
        guard let executablePath,
              let output = LocalCommandRunner.output(
                executablePath: executablePath,
                arguments: ["ps"],
                timeout: 1.0
              )
        else {
            return nil
        }

        return LocalOllamaRuntimeSummary(activeModel: activeModel(from: output))
    }

    private static func activeModel(from output: String) -> String? {
        for line in output.split(whereSeparator: \.isNewline).map(String.init) {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty,
                  !trimmedLine.hasPrefix("NAME")
            else {
                continue
            }

            return trimmedLine
                .split(whereSeparator: \.isWhitespace)
                .first
                .map(String.init)
        }

        return nil
    }
}

private enum LocalAICommandMetadataReader {
    static func metadata(for executablePaths: [String: String]) -> [LocalAIToolKind: LocalAIToolMetadata] {
        var metadata = [LocalAIToolKind: LocalAIToolMetadata]()

        for kind in LocalAIToolKind.allCases {
            guard let executablePath = kind.executableNames.compactMap({ executablePaths[$0] }).first,
                  let version = version(executablePath: executablePath)
            else {
                continue
            }

            metadata[kind] = LocalAIToolMetadata(model: nil, version: version, source: "Command")
        }

        return metadata
    }

    private static func version(executablePath: String) -> String? {
        guard let output = LocalCommandRunner.output(
            executablePath: executablePath,
            arguments: ["--version"],
            timeout: 1.0
        ) else {
            return nil
        }

        return versionText(from: output)
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
}

private enum LocalAICommandLineParser {
    static func tokens(from commandLine: String) -> [String] {
        var tokens: [String] = []
        var currentToken = ""
        var quote: Character?
        var isEscaped = false

        for character in commandLine {
            if isEscaped {
                currentToken.append(character)
                isEscaped = false
                continue
            }

            if character == "\\" {
                isEscaped = true
                continue
            }

            if let currentQuote = quote {
                if character == currentQuote {
                    quote = nil
                } else {
                    currentToken.append(character)
                }
                continue
            }

            if character == "\"" || character == "'" {
                quote = character
                continue
            }

            if character.isWhitespace {
                if !currentToken.isEmpty {
                    tokens.append(currentToken)
                    currentToken = ""
                }
                continue
            }

            currentToken.append(character)
        }

        if isEscaped {
            currentToken.append("\\")
        }

        if !currentToken.isEmpty {
            tokens.append(currentToken)
        }

        return tokens
    }

    static func executableToken(from tokens: [String]) -> String? {
        guard let firstToken = tokens.first else {
            return nil
        }

        guard firstToken.matchesExecutable(named: "env") else {
            return firstToken
        }

        return tokens.dropFirst().first { token in
            !token.hasPrefix("-") && !token.contains("=")
        }
    }

    static func modelArgument(in commandLine: String) -> String? {
        let tokens = tokens(from: commandLine)

        for index in tokens.indices {
            let token = tokens[index]

            if token == "--model" || token == "-m" {
                let nextIndex = tokens.index(after: index)
                guard nextIndex < tokens.endIndex else {
                    continue
                }

                let value = sanitizedModelValue(tokens[nextIndex])
                if value != nil {
                    return value
                }
            }

            if token.hasPrefix("--model=") {
                let value = String(token.dropFirst("--model=".count))
                if let value = sanitizedModelValue(value) {
                    return value
                }
            }
        }

        return nil
    }

    private static func sanitizedModelValue(_ value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'"))
        )

        guard !trimmedValue.isEmpty, !trimmedValue.hasPrefix("-") else {
            return nil
        }

        return trimmedValue
    }
}

private enum LocalCommandRunner {
    static func output(
        executablePath: String,
        arguments: [String],
        timeout: TimeInterval
    ) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = nil

        do {
            try process.run()
        } catch {
            return nil
        }

        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            process.waitUntilExit()
            group.leave()
        }

        guard group.wait(timeout: .now() + timeout) == .success else {
            process.terminate()
            _ = group.wait(timeout: .now() + 0.2)
            return nil
        }

        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
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

private enum LocalProcessCommandReader {
    static func currentCommands() -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "command="]

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

        return output
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

private extension String {
    func matchesExecutable(named name: String) -> Bool {
        let token = trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercasedToken = token.lowercased()
        let lowercasedName = name.lowercased()

        return lowercasedToken == lowercasedName
            || lowercasedToken.hasSuffix("/\(lowercasedName)")
            || URL(fileURLWithPath: lowercasedToken).lastPathComponent == lowercasedName
    }
}
