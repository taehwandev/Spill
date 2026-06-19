import Combine
import Foundation

enum TokenUsageHistoryImportTool: String, CaseIterable, Hashable, Identifiable, Sendable {
    case codex
    case claude
    case antigravity

    var id: String { rawValue }

    var aiTool: TokenUsageAITool {
        switch self {
        case .codex:
            return .codex
        case .claude:
            return .claude
        case .antigravity:
            return .antigravity
        }
    }
}

enum TokenUsageHistoryImportMode: String, Equatable, Sendable {
    case firstImport
    case incremental
}

enum TokenUsageHistoryImportToolState: String, Codable, Equatable, Sendable {
    case pending
    case running
    case completed
    case unavailable
    case failed
    case cancelled

    var isFinished: Bool {
        switch self {
        case .completed, .unavailable, .failed, .cancelled:
            return true
        case .pending, .running:
            return false
        }
    }
}

struct TokenUsageHistoryImportLastRunSnapshot: Codable, Equatable, Sendable {
    let finishedAt: Date
    let state: TokenUsageHistoryImportToolState
    let scannedSources: Int
    let importedEvents: Int
    let skippedDuplicates: Int
    let unsupportedRecords: Int
    let message: String?
}

struct TokenUsageHistoryImportToolSnapshot: Equatable, Identifiable, Sendable {
    let tool: TokenUsageHistoryImportTool
    var mode: TokenUsageHistoryImportMode
    var state: TokenUsageHistoryImportToolState
    var scannedSources: Int
    var importedEvents: Int
    var skippedDuplicates: Int
    var unsupportedRecords: Int
    var message: String?
    var lastSuccessfulImportAt: Date?
    var lastRun: TokenUsageHistoryImportLastRunSnapshot?

    var id: TokenUsageHistoryImportTool { tool }

    static func pending(
        tool: TokenUsageHistoryImportTool,
        mode: TokenUsageHistoryImportMode,
        lastSuccessfulImportAt: Date?
    ) -> Self {
        pending(tool: tool, mode: mode, lastSuccessfulImportAt: lastSuccessfulImportAt, lastRun: nil)
    }

    static func pending(
        tool: TokenUsageHistoryImportTool,
        mode: TokenUsageHistoryImportMode,
        lastSuccessfulImportAt: Date?,
        lastRun: TokenUsageHistoryImportLastRunSnapshot?
    ) -> Self {
        Self(
            tool: tool,
            mode: mode,
            state: lastRun?.state ?? .pending,
            scannedSources: lastRun?.scannedSources ?? 0,
            importedEvents: lastRun?.importedEvents ?? 0,
            skippedDuplicates: lastRun?.skippedDuplicates ?? 0,
            unsupportedRecords: lastRun?.unsupportedRecords ?? 0,
            message: lastRun?.message,
            lastSuccessfulImportAt: lastSuccessfulImportAt,
            lastRun: lastRun
        )
    }

    func preparedForRun(mode: TokenUsageHistoryImportMode) -> Self {
        Self(
            tool: tool,
            mode: mode,
            state: .pending,
            scannedSources: 0,
            importedEvents: 0,
            skippedDuplicates: 0,
            unsupportedRecords: 0,
            message: nil,
            lastSuccessfulImportAt: lastSuccessfulImportAt,
            lastRun: lastRun
        )
    }
}

struct TokenUsageHistoryImportSnapshot: Equatable, Sendable {
    var isRunning: Bool
    var startedAt: Date?
    var finishedAt: Date?
    var tools: [TokenUsageHistoryImportToolSnapshot]

    static let idle = TokenUsageHistoryImportSnapshot(
        isRunning: false,
        startedAt: nil,
        finishedAt: nil,
        tools: TokenUsageHistoryImportTool.allCases.map {
            .pending(tool: $0, mode: .firstImport, lastSuccessfulImportAt: nil)
        }
    )
}

struct TokenUsageHistoryImportProcessContext {
    let executableURL: URL
    let arguments: [String]
    let environment: [String: String]
    let store: TokenUsageStore
    let maximumRuntime: TimeInterval
    let shouldCancel: () -> Bool
    let processDidStart: (Process) -> Void
    let processDidFinish: () -> Void
}

struct TokenUsageHistoryImportProcessResult: Equatable {
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let timedOut: Bool
}

final class TokenUsageHistoryImportCoordinator: ObservableObject, @unchecked Sendable {
    typealias ProcessRunner = (TokenUsageHistoryImportProcessContext) -> TokenUsageHistoryImportProcessResult
    typealias AntigravityImportRunner = (TokenUsageStore, Date, @escaping () -> Bool) -> TokenUsageAntigravityImportSummary

    fileprivate static let importerVersion = 1
    private static let incrementalLookbackHours = 48
    private static let maximumProcessRuntime: TimeInterval = 5 * 60
    private static let drainInterval: TimeInterval = 0.25

    @Published private(set) var snapshot: TokenUsageHistoryImportSnapshot

    private let store: TokenUsageStore
    private let stateStore: TokenUsageHistoryImportStateStore
    private let queue = DispatchQueue(label: "app.spill.token-usage-history-import")
    private let lock = NSLock()
    private let processLock = NSLock()
    private let codexImporterURLProvider: () -> URL?
    private let claudeHookURLProvider: () -> URL?
    private let nodeExecutableURLProvider: () -> URL?
    private let python3ExecutableURLProvider: () -> URL?
    private let antigravityImportRunner: AntigravityImportRunner
    private let processRunner: ProcessRunner
    private let historyStateDirectory: URL
    private var isImportRunning = false
    private var isCancellationRequested = false
    private var runningProcess: Process?

    init(
        store: TokenUsageStore,
        stateStore: TokenUsageHistoryImportStateStore = TokenUsageHistoryImportStateStore(),
        codexImporterURLProvider: @escaping () -> URL? = {
            TokenUsageHistoryImportCoordinator.preferredHistoryImportScriptURL(
                bundledURL: TokenMeteringAdapterKit.codex.scriptURL,
                installedURL: TokenMeteringAdapterKit.defaultInstallURL(for: TokenMeteringAdapterKit.codex)
            )
        },
        claudeHookURLProvider: @escaping () -> URL? = {
            TokenUsageHistoryImportCoordinator.preferredHistoryImportScriptURL(
                bundledURL: TokenMeteringAdapterKit.claudeCode.scriptURL,
                installedURL: TokenMeteringAdapterKit.defaultInstallURL(for: TokenMeteringAdapterKit.claudeCode)
            )
        },
        nodeExecutableURLProvider: @escaping () -> URL? = {
            TokenUsageCollectorCoordinator.nodeExecutableURL()
        },
        python3ExecutableURLProvider: @escaping () -> URL? = {
            TokenUsageCollectorCoordinator.python3ExecutableURL()
        },
        historyStateDirectory: URL = TokenUsageHistoryImportCoordinator.defaultHistoryStateDirectory(),
        antigravityImportRunner: AntigravityImportRunner? = nil,
        processRunner: @escaping ProcessRunner = TokenUsageHistoryImportCoordinator.runProcess(context:)
    ) {
        self.store = store
        self.stateStore = stateStore
        self.codexImporterURLProvider = codexImporterURLProvider
        self.claudeHookURLProvider = claudeHookURLProvider
        self.nodeExecutableURLProvider = nodeExecutableURLProvider
        self.python3ExecutableURLProvider = python3ExecutableURLProvider
        self.processRunner = processRunner
        self.historyStateDirectory = historyStateDirectory
        self.antigravityImportRunner = antigravityImportRunner ?? { store, startDate, shouldCancel in
            TokenUsageAntigravityImporter(
                stateURL: historyStateDirectory.appendingPathComponent("antigravity-active-importer-state.json")
            )
            .importRecentEvents(into: store, since: startDate, shouldCancel: shouldCancel)
        }
        snapshot = Self.makeIdleSnapshot(stateStore: stateStore)
    }

    func startImport() {
        startImport(for: TokenUsageHistoryImportTool.allCases)
    }

    func startImport(for tool: TokenUsageHistoryImportTool) {
        startImport(for: [tool])
    }

    private func startImport(for requestedTools: [TokenUsageHistoryImportTool]) {
        let selectedTools = TokenUsageHistoryImportTool.allCases.filter { tool in
            requestedTools.contains(tool)
        }
        guard !selectedTools.isEmpty else {
            return
        }

        let shouldStart = lock.withLock {
            guard !isImportRunning else {
                return false
            }
            isImportRunning = true
            isCancellationRequested = false
            return true
        }

        guard shouldStart else {
            return
        }

        do {
            try prepareFullHistoryReconciliation(for: selectedTools)
        } catch {
            lock.withLock {
                isImportRunning = false
                isCancellationRequested = false
            }
            let finishedAt = Date()
            let selectedSet = Set(selectedTools)
            snapshot = snapshotWithUpdatedTools(
                startedAt: finishedAt,
                finishedAt: finishedAt,
                isRunning: false
            ) { current in
                guard selectedSet.contains(current.tool) else {
                    return current
                }
                return TokenUsageHistoryImportToolSnapshot(
                    tool: current.tool,
                    mode: .firstImport,
                    state: .failed,
                    scannedSources: 0,
                    importedEvents: 0,
                    skippedDuplicates: 0,
                    unsupportedRecords: 0,
                    message: "Failed to prepare local token history sync.",
                    lastSuccessfulImportAt: stateStore.lastSuccessfulImportAt(for: current.tool),
                    lastRun: stateStore.lastRun(for: current.tool)
                )
            }
            return
        }

        let toolPlans = Self.fullHistoryToolPlans(tools: selectedTools)
        let startedAt = Date()
        let selectedSet = Set(selectedTools)
        let initialSnapshot = TokenUsageHistoryImportSnapshot(
            isRunning: true,
            startedAt: startedAt,
            finishedAt: nil,
            tools: snapshot.tools.map { current in
                guard selectedSet.contains(current.tool) else {
                    return current
                }
                return current.preparedForRun(mode: toolPlans[current.tool] ?? .firstImport)
            }
        )

        snapshot = initialSnapshot

        queue.async { [weak self] in
            self?.runImport(tools: selectedTools, toolPlans: toolPlans)
        }
    }

    func cancelImport() {
        lock.withLock {
            isCancellationRequested = true
        }
        processLock.withLock {
            runningProcess?.terminate()
        }
    }

    private func runImport(
        tools selectedTools: [TokenUsageHistoryImportTool],
        toolPlans: [TokenUsageHistoryImportTool: TokenUsageHistoryImportMode]
    ) {
        for tool in selectedTools {
            guard !isCancelled else {
                let result = TokenUsageHistoryToolResult.cancelled("Cancelled before this importer started.")
                let finishedAt = Date()
                stateStore.recordLastRun(for: tool, result: result, at: finishedAt)
                publishToolSnapshot(tool, result: result, finishedAt: finishedAt, successfulAt: nil)
                continue
            }

            let mode = toolPlans[tool] ?? .firstImport
            publishToolState(tool, state: .running, message: nil)
            let result = runToolImport(tool, mode: mode)

            let finishedAt = Date()
            let successfulAt = result.state == .completed ? finishedAt : nil
            if let successfulAt {
                stateStore.markSuccessfulImport(for: tool, mode: mode, at: successfulAt)
            }
            stateStore.recordLastRun(for: tool, result: result, at: finishedAt)
            if result.state == .completed {
                store.drainQueuedEventsWithoutLoading(maximumInboxEventCount: nil)
            }
            publishToolSnapshot(tool, result: result, finishedAt: finishedAt, successfulAt: successfulAt)
        }

        store.drainQueuedEventsWithoutLoading(maximumInboxEventCount: nil)
        store.notifyEventsDidChange()
        let finishedAt = Date()
        lock.withLock {
            isImportRunning = false
            isCancellationRequested = false
        }
        processLock.withLock {
            runningProcess = nil
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            var nextSnapshot = self.snapshot
            nextSnapshot.isRunning = false
            nextSnapshot.finishedAt = finishedAt
            self.snapshot = nextSnapshot
        }
    }

    private func runToolImport(
        _ tool: TokenUsageHistoryImportTool,
        mode: TokenUsageHistoryImportMode
    ) -> TokenUsageHistoryToolResult {
        switch tool {
        case .codex:
            return runCodexImport(mode: mode)
        case .claude:
            return runClaudeImport(mode: mode)
        case .antigravity:
            return runAntigravityImport(mode: mode)
        }
    }

    private func runCodexImport(mode: TokenUsageHistoryImportMode) -> TokenUsageHistoryToolResult {
        guard let importerURL = codexImporterURLProvider(),
              FileManager.default.fileExists(atPath: importerURL.path)
        else {
            return .unavailable("Codex importer is not installed.")
        }
        guard let nodeURL = nodeExecutableURLProvider() else {
            return .failed("Node executable is unavailable.")
        }

        let arguments = [
            importerURL.path,
            "--state",
            historyStateDirectory.appendingPathComponent("codex-session-import-state.json").path,
            "--label-file",
            historyStateDirectory.appendingPathComponent("codex-label-context.json").path,
        ] + historyArguments(for: mode) + ["--json"]
        let processResult = runProcess(executableURL: nodeURL, arguments: arguments)
        if isCancelled {
            return .cancelled("Cancelled by user.")
        }
        guard processResult.exitCode == 0, !processResult.timedOut else {
            return .failed(processResult.timedOut ? "Codex import timed out." : "Codex import failed.")
        }

        let summary = ProcessJSONSummary(processResult.stdout)
        guard summary.isValid else {
            return .failed("Codex import did not return a valid summary.")
        }
        guard summary.scannedSources > 0 || summary.importedEvents > 0 || summary.skippedDuplicates > 0 else {
            return noHistoryResult(
                mode: mode,
                firstImportMessage: "No Codex local session history was found.",
                incrementalMessage: "No new Codex local history was found in the recent window."
            )
        }

        return .completed(
            scannedSources: summary.scannedSources,
            importedEvents: summary.importedEvents,
            skippedDuplicates: summary.skippedDuplicates,
            unsupportedRecords: summary.unsupportedRecords,
            message: nil
        )
    }

    private func runClaudeImport(mode: TokenUsageHistoryImportMode) -> TokenUsageHistoryToolResult {
        guard let hookURL = claudeHookURLProvider(),
              FileManager.default.fileExists(atPath: hookURL.path)
        else {
            return .unavailable("Claude Code importer is not installed.")
        }
        guard let python3URL = python3ExecutableURLProvider() else {
            return .failed("Python 3 executable is unavailable.")
        }

        let claudeProjectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects", isDirectory: true)
        guard FileManager.default.fileExists(atPath: claudeProjectsDir.path) else {
            return .unavailable("No Claude Code local transcript history was found.")
        }

        let arguments = [
            hookURL.path,
            "--scan-dir",
            claudeProjectsDir.path
        ] + historyArguments(for: mode) + ["--json"]
        let processResult = runProcess(
            executableURL: python3URL,
            arguments: arguments,
            environment: [
                "SPILL_TOKEN_USAGE_LABEL_FILE": historyStateDirectory
                    .appendingPathComponent("claude-label-context.json")
                    .path,
                "SPILL_TOKEN_USAGE_SESSION_STATE_DIR": claudeHistorySessionStateDirectory()
                    .path
            ]
        )
        if isCancelled {
            return .cancelled("Cancelled by user.")
        }
        guard processResult.exitCode == 0, !processResult.timedOut else {
            return .failed(processResult.timedOut ? "Claude import timed out." : "Claude import failed.")
        }

        let summary = ProcessJSONSummary(processResult.stdout)
        guard summary.isValid else {
            return .failed("Claude import did not return a valid summary.")
        }
        guard summary.scannedSources > 0 || summary.importedEvents > 0 || summary.skippedDuplicates > 0 else {
            return noHistoryResult(
                mode: mode,
                firstImportMessage: "No Claude Code local transcript history was found.",
                incrementalMessage: "No new Claude Code local transcript history was found in the recent window."
            )
        }

        let result = TokenUsageHistoryToolResult.completed(
            scannedSources: summary.scannedSources,
            importedEvents: summary.importedEvents,
            skippedDuplicates: summary.skippedDuplicates,
            unsupportedRecords: summary.unsupportedRecords,
            message: nil
        )
        syncClaudeHistoryStateToLiveState()
        return result
    }

    // After a Claude history scan the history session-state dir holds the
    // per-transcript (fresh, output, byte_offset) the scan wrote.  The live
    // Stop hook uses a separate session-state dir and may still be behind that
    // position, which would cause the next hook invocation to re-read already-
    // counted turns and produce double-counted events.  Advance any live state
    // file that is behind the matching history state file so the hook resumes
    // exactly where the history scan left off.
    private func syncClaudeHistoryStateToLiveState() {
        let fileManager = FileManager.default
        let historyStateDir = claudeHistorySessionStateDirectory()
        let liveStateDir = historyStateDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("session-state", isDirectory: true)

        guard let files = try? fileManager.contentsOfDirectory(
            at: historyStateDir,
            includingPropertiesForKeys: nil
        ) else { return }

        for historyFile in files where historyFile.pathExtension == "json" {
            guard let historyData = try? Data(contentsOf: historyFile),
                  let historyState = try? JSONSerialization.jsonObject(with: historyData) as? [String: Any],
                  let historyFresh = historyState["fresh"] as? Int,
                  historyFresh > 0
            else { continue }

            let liveFile = liveStateDir.appendingPathComponent(historyFile.lastPathComponent)
            var liveFresh = 0
            if let liveData = try? Data(contentsOf: liveFile),
               let liveState = try? JSONSerialization.jsonObject(with: liveData) as? [String: Any],
               let currentFresh = liveState["fresh"] as? Int {
                liveFresh = currentFresh
            }

            guard historyFresh > liveFresh else { continue }

            let tmpFile = liveStateDir.appendingPathComponent(".\(historyFile.lastPathComponent).sync.tmp")
            try? fileManager.createDirectory(at: liveStateDir, withIntermediateDirectories: true)
            guard (try? historyData.write(to: tmpFile)) != nil else { continue }
            try? fileManager.moveItem(at: tmpFile, to: liveFile)
        }
    }

    // Keep the live AGY active importer aligned with explicit history sync.
    // Otherwise the next AGY turn can re-trigger a large catch-up import.
    private func syncAntigravityHistoryStateToLiveState() {
        let historyStateFile = historyStateDirectory
            .appendingPathComponent("antigravity-active-importer-state.json")
        let liveStateFile = historyStateDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("session-state", isDirectory: true)
            .appendingPathComponent("antigravity-active-importer-state.json")

        guard let historyData = try? Data(contentsOf: historyStateFile),
              let mergedData = Self.mergedAntigravityStateData(
                historyData: historyData,
                liveData: try? Data(contentsOf: liveStateFile)
              )
        else { return }

        let fileManager = FileManager.default
        let liveStateDir = liveStateFile.deletingLastPathComponent()
        let tmpFile = liveStateDir.appendingPathComponent(".antigravity-active-importer-state.sync.tmp")
        try? fileManager.createDirectory(at: liveStateDir, withIntermediateDirectories: true)
        try? fileManager.removeItem(at: tmpFile)
        guard (try? mergedData.write(to: tmpFile)) != nil else { return }
        try? fileManager.removeItem(at: liveStateFile)
        try? fileManager.moveItem(at: tmpFile, to: liveStateFile)
    }

    private static func mergedAntigravityStateData(historyData: Data, liveData: Data?) -> Data? {
        let historyCursors = antigravityCursorMap(from: historyData)
        guard !historyCursors.isEmpty else {
            return nil
        }

        var mergedCursors = antigravityCursorMap(from: liveData)
        for (source, index) in historyCursors {
            mergedCursors[source] = max(mergedCursors[source] ?? -1, index)
        }

        let object: [String: Any] = [
            "schema_version": 1,
            "ai_tool": "antigravity",
            "privacy": "Contains only opaque conversation hashes and numeric generation cursors; no paths, prompts, responses, commands, logs, diffs, source, environment values, or secrets.",
            "max_generation_index_by_source": mergedCursors,
        ]
        return try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private static func antigravityCursorMap(from data: Data?) -> [String: Int] {
        guard let data,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cursors = object["max_generation_index_by_source"] as? [String: Any]
        else {
            return [:]
        }

        var result = [String: Int]()
        for (source, value) in cursors {
            if let index = value as? Int {
                result[source] = index
            } else if let number = value as? NSNumber {
                result[source] = number.intValue
            }
        }
        return result
    }

    private func runAntigravityImport(mode: TokenUsageHistoryImportMode) -> TokenUsageHistoryToolResult {
        let startDate: Date
        switch mode {
        case .firstImport:
            startDate = .distantPast
        case .incremental:
            startDate = Date().addingTimeInterval(-TimeInterval(Self.incrementalLookbackHours) * 3600)
        }

        let summary = antigravityImportRunner(store, startDate) { [weak self] in
            self?.isCancelled ?? true
        }
        if isCancelled {
            return .cancelled("Cancelled by user.")
        }
        if summary.failedToWriteEvents {
            return .failed("Antigravity/AGY import failed while writing usage events.")
        }
        guard summary.scannedDatabases > 0 || summary.importedEvents > 0 || summary.skippedDuplicateEvents > 0 else {
            return noHistoryResult(
                mode: mode,
                firstImportMessage: "No Antigravity/AGY exact usage history was found.",
                incrementalMessage: "No new Antigravity/AGY exact usage history was found in the recent window."
            )
        }

        syncAntigravityHistoryStateToLiveState()
        return .completed(
            scannedSources: summary.scannedDatabases,
            importedEvents: summary.importedEvents,
            skippedDuplicates: summary.skippedDuplicateEvents,
            unsupportedRecords: summary.unsupportedRecords,
            message: nil
        )
    }

    private func noHistoryResult(
        mode: TokenUsageHistoryImportMode,
        firstImportMessage: String,
        incrementalMessage: String
    ) -> TokenUsageHistoryToolResult {
        switch mode {
        case .firstImport:
            return .unavailable(firstImportMessage)
        case .incremental:
            return .completed(
                scannedSources: 0,
                importedEvents: 0,
                skippedDuplicates: 0,
                unsupportedRecords: 0,
                message: incrementalMessage
            )
        }
    }

    private func historyArguments(for mode: TokenUsageHistoryImportMode) -> [String] {
        switch mode {
        case .firstImport:
            return ["--all"]
        case .incremental:
            return ["--since-hours", "\(Self.incrementalLookbackHours)"]
        }
    }

    private func runProcess(
        executableURL: URL,
        arguments: [String],
        environment: [String: String] = [:]
    ) -> TokenUsageHistoryImportProcessResult {
        let context = TokenUsageHistoryImportProcessContext(
            executableURL: executableURL,
            arguments: arguments,
            environment: environment,
            store: store,
            maximumRuntime: Self.maximumProcessRuntime,
            shouldCancel: { [weak self] in
                self?.isCancelled ?? true
            },
            processDidStart: { [weak self] process in
                self?.processLock.withLock {
                    self?.runningProcess = process
                }
            },
            processDidFinish: { [weak self] in
                self?.processLock.withLock {
                    self?.runningProcess = nil
                }
            }
        )
        return processRunner(context)
    }

    static func defaultHistoryStateDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Spill/token-metering/history-import", isDirectory: true)
    }

    static func preferredHistoryImportScriptURL(
        bundledURL: URL?,
        installedURL: URL,
        fileManager: FileManager = .default
    ) -> URL? {
        if let bundledURL, fileManager.fileExists(atPath: bundledURL.path) {
            return bundledURL
        }
        if fileManager.fileExists(atPath: installedURL.path) {
            return installedURL
        }
        return bundledURL
    }

    private var isCancelled: Bool {
        lock.withLock {
            isCancellationRequested
        }
    }

    private func publishToolState(
        _ tool: TokenUsageHistoryImportTool,
        state: TokenUsageHistoryImportToolState,
        message: String?
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            var nextSnapshot = self.snapshot
            guard let index = nextSnapshot.tools.firstIndex(where: { $0.tool == tool }) else {
                return
            }
            nextSnapshot.tools[index].state = state
            nextSnapshot.tools[index].message = message
            self.snapshot = nextSnapshot
        }
    }

    private func publishToolSnapshot(
        _ tool: TokenUsageHistoryImportTool,
        result: TokenUsageHistoryToolResult,
        finishedAt: Date,
        successfulAt: Date?
    ) {
        let lastRun = TokenUsageHistoryImportLastRunSnapshot(
            finishedAt: finishedAt,
            state: result.state,
            scannedSources: result.scannedSources,
            importedEvents: result.importedEvents,
            skippedDuplicates: result.skippedDuplicates,
            unsupportedRecords: result.unsupportedRecords,
            message: result.message
        )
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            var nextSnapshot = self.snapshot
            guard let index = nextSnapshot.tools.firstIndex(where: { $0.tool == tool }) else {
                return
            }
            nextSnapshot.tools[index].state = result.state
            nextSnapshot.tools[index].scannedSources = result.scannedSources
            nextSnapshot.tools[index].importedEvents = result.importedEvents
            nextSnapshot.tools[index].skippedDuplicates = result.skippedDuplicates
            nextSnapshot.tools[index].unsupportedRecords = result.unsupportedRecords
            nextSnapshot.tools[index].message = result.message
            nextSnapshot.tools[index].lastSuccessfulImportAt = successfulAt
                ?? self.stateStore.lastSuccessfulImportAt(for: tool)
            nextSnapshot.tools[index].lastRun = lastRun
            self.snapshot = nextSnapshot
        }
    }

    private static func fullHistoryToolPlans(
        tools: [TokenUsageHistoryImportTool]
    ) -> [TokenUsageHistoryImportTool: TokenUsageHistoryImportMode] {
        Dictionary(
            uniqueKeysWithValues: tools.map { tool in
                (tool, .firstImport)
            }
        )
    }

    private func prepareFullHistoryReconciliation(for tools: [TokenUsageHistoryImportTool]) throws {
        store.drainQueuedEventsWithoutLoading(maximumInboxEventCount: nil)
        resetToolScanState(for: tools)
        try FileManager.default.createDirectory(
            at: historyStateDirectory,
            withIntermediateDirectories: true
        )
    }

    private func claudeHistorySessionStateDirectory() -> URL {
        historyStateDirectory.appendingPathComponent("claude-session-state", isDirectory: true)
    }

    private func resetToolScanState(for tools: [TokenUsageHistoryImportTool]) {
        // Claude history scan state tracks per-transcript token totals. Without
        // clearing it, scan_main treats transcripts as already processed even
        // when --all is passed.
        if tools.contains(.claude) {
            let sessionStateDir = claudeHistorySessionStateDirectory()
            if let files = try? FileManager.default.contentsOfDirectory(
                at: sessionStateDir,
                includingPropertiesForKeys: nil
            ) {
                for file in files where file.pathExtension == "json" {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }

        // Codex and AGY each have a single state file in historyStateDirectory.
        if tools.contains(.codex) {
            let codexState = historyStateDirectory.appendingPathComponent("codex-session-import-state.json")
            try? FileManager.default.removeItem(at: codexState)
        }
        if tools.contains(.antigravity) {
            let antigravityState = historyStateDirectory.appendingPathComponent("antigravity-active-importer-state.json")
            try? FileManager.default.removeItem(at: antigravityState)
        }
    }

    private static func makeIdleSnapshot(
        stateStore: TokenUsageHistoryImportStateStore
    ) -> TokenUsageHistoryImportSnapshot {
        TokenUsageHistoryImportSnapshot(
            isRunning: false,
            startedAt: nil,
            finishedAt: nil,
            tools: TokenUsageHistoryImportTool.allCases.map { tool in
                .pending(
                    tool: tool,
                    mode: .firstImport,
                    lastSuccessfulImportAt: stateStore.lastSuccessfulImportAt(for: tool),
                    lastRun: stateStore.lastRun(for: tool)
                )
            }
        )
    }

    private func snapshotWithUpdatedTools(
        startedAt: Date?,
        finishedAt: Date?,
        isRunning: Bool,
        update: (TokenUsageHistoryImportToolSnapshot) -> TokenUsageHistoryImportToolSnapshot
    ) -> TokenUsageHistoryImportSnapshot {
        TokenUsageHistoryImportSnapshot(
            isRunning: isRunning,
            startedAt: startedAt,
            finishedAt: finishedAt,
            tools: snapshot.tools.map(update)
        )
    }

    private static func runProcess(
        context: TokenUsageHistoryImportProcessContext
    ) -> TokenUsageHistoryImportProcessResult {
        let process = Process()
        process.executableURL = context.executableURL
        process.arguments = context.arguments
        if !context.environment.isEmpty {
            var environment = ProcessInfo.processInfo.environment
            for (key, value) in context.environment {
                environment[key] = value
            }
            process.environment = environment
        }

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        let outputBuffer = ProcessPipeBuffer()
        let errorBuffer = ProcessPipeBuffer()
        let outputHandle = outputPipe.fileHandleForReading
        let errorHandle = errorPipe.fileHandleForReading
        outputHandle.readabilityHandler = { handle in
            outputBuffer.append(handle.availableData)
        }
        errorHandle.readabilityHandler = { handle in
            errorBuffer.append(handle.availableData)
        }

        do {
            try process.run()
        } catch {
            outputHandle.readabilityHandler = nil
            errorHandle.readabilityHandler = nil
            return TokenUsageHistoryImportProcessResult(
                exitCode: -1,
                stdout: "",
                stderr: "",
                timedOut: false
            )
        }

        context.processDidStart(process)
        let startedAt = Date()
        var timedOut = false

        while process.isRunning {
            if context.shouldCancel() {
                process.terminate()
                timedOut = false
                break
            }

            if Date().timeIntervalSince(startedAt) > context.maximumRuntime {
                process.terminate()
                timedOut = true
                break
            }

            Thread.sleep(forTimeInterval: Self.drainInterval)
        }

        process.waitUntilExit()
        context.processDidFinish()
        context.store.drainQueuedEventsWithoutLoading(maximumInboxEventCount: nil)
        outputHandle.readabilityHandler = nil
        errorHandle.readabilityHandler = nil
        outputBuffer.append(outputHandle.readDataToEndOfFile())
        errorBuffer.append(errorHandle.readDataToEndOfFile())

        return TokenUsageHistoryImportProcessResult(
            exitCode: process.terminationStatus,
            stdout: outputBuffer.stringValue,
            stderr: errorBuffer.stringValue,
            timedOut: timedOut
        )
    }
}

final class TokenUsageHistoryImportStateStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let keyPrefix: String

    init(
        defaults: UserDefaults = .standard,
        keyPrefix: String = "app.spill.token-history-import"
    ) {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
    }

    func hasCompletedFirstImport(for tool: TokenUsageHistoryImportTool) -> Bool {
        defaults.object(forKey: firstCompletedKey(for: tool)) != nil
    }

    func lastSuccessfulImportAt(for tool: TokenUsageHistoryImportTool) -> Date? {
        defaults.object(forKey: lastSuccessKey(for: tool)) as? Date
    }

    func lastRun(for tool: TokenUsageHistoryImportTool) -> TokenUsageHistoryImportLastRunSnapshot? {
        guard let data = defaults.data(forKey: lastRunKey(for: tool)) else {
            return nil
        }
        return try? JSONDecoder().decode(TokenUsageHistoryImportLastRunSnapshot.self, from: data)
    }

    func markSuccessfulImport(
        for tool: TokenUsageHistoryImportTool,
        mode: TokenUsageHistoryImportMode,
        at date: Date
    ) {
        defaults.set(date, forKey: lastSuccessKey(for: tool))
        if mode == .firstImport {
            defaults.set(date, forKey: firstCompletedKey(for: tool))
        }
    }

    fileprivate func recordLastRun(
        for tool: TokenUsageHistoryImportTool,
        result: TokenUsageHistoryToolResult,
        at date: Date
    ) {
        let snapshot = TokenUsageHistoryImportLastRunSnapshot(
            finishedAt: date,
            state: result.state,
            scannedSources: result.scannedSources,
            importedEvents: result.importedEvents,
            skippedDuplicates: result.skippedDuplicates,
            unsupportedRecords: result.unsupportedRecords,
            message: result.message
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: lastRunKey(for: tool))
        }
    }

    func resetAllImportState() {
        resetImportState(for: TokenUsageHistoryImportTool.allCases)
    }

    func resetImportState(for tools: [TokenUsageHistoryImportTool]) {
        for tool in tools {
            defaults.removeObject(forKey: firstCompletedKey(for: tool))
            defaults.removeObject(forKey: lastSuccessKey(for: tool))
        }
    }

    private func firstCompletedKey(for tool: TokenUsageHistoryImportTool) -> String {
        "\(keyPrefix).v\(TokenUsageHistoryImportCoordinator.importerVersion).\(tool.rawValue).first_import_completed_at"
    }

    private func lastSuccessKey(for tool: TokenUsageHistoryImportTool) -> String {
        "\(keyPrefix).v\(TokenUsageHistoryImportCoordinator.importerVersion).\(tool.rawValue).last_successful_import_at"
    }

    private func lastRunKey(for tool: TokenUsageHistoryImportTool) -> String {
        "\(keyPrefix).v\(TokenUsageHistoryImportCoordinator.importerVersion).\(tool.rawValue).last_run"
    }
}

private struct TokenUsageHistoryToolResult {
    let state: TokenUsageHistoryImportToolState
    let scannedSources: Int
    let importedEvents: Int
    let skippedDuplicates: Int
    let unsupportedRecords: Int
    let message: String?

    static func completed(
        scannedSources: Int,
        importedEvents: Int,
        skippedDuplicates: Int,
        unsupportedRecords: Int,
        message: String?
    ) -> Self {
        Self(
            state: .completed,
            scannedSources: scannedSources,
            importedEvents: importedEvents,
            skippedDuplicates: skippedDuplicates,
            unsupportedRecords: unsupportedRecords,
            message: message
        )
    }

    static func unavailable(_ message: String) -> Self {
        Self(
            state: .unavailable,
            scannedSources: 0,
            importedEvents: 0,
            skippedDuplicates: 0,
            unsupportedRecords: 0,
            message: message
        )
    }

    static func failed(_ message: String) -> Self {
        Self(
            state: .failed,
            scannedSources: 0,
            importedEvents: 0,
            skippedDuplicates: 0,
            unsupportedRecords: 0,
            message: message
        )
    }

    static func cancelled(_ message: String) -> Self {
        Self(
            state: .cancelled,
            scannedSources: 0,
            importedEvents: 0,
            skippedDuplicates: 0,
            unsupportedRecords: 0,
            message: message
        )
    }
}

private struct ProcessJSONSummary {
    let isValid: Bool
    let scannedSources: Int
    let importedEvents: Int
    let skippedDuplicates: Int
    let unsupportedRecords: Int

    init(_ stdout: String) {
        guard let line = stdout
            .split(whereSeparator: \.isNewline)
            .last,
            let data = line.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            isValid = false
            scannedSources = 0
            importedEvents = 0
            skippedDuplicates = 0
            unsupportedRecords = 0
            return
        }

        isValid = true
        scannedSources = Self.intValue(object["scanned_files"])
        importedEvents = Self.intValue(object["imported_events"])
        skippedDuplicates = Self.intValue(object["skipped_seen"])
        unsupportedRecords = Self.intValue(object["unsupported_records"])
    }

    private static func intValue(_ value: Any?) -> Int {
        if let value = value as? Int {
            return max(0, value)
        }
        if let value = value as? NSNumber {
            return max(0, value.intValue)
        }
        return 0
    }
}

private final class ProcessPipeBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ chunk: Data) {
        guard !chunk.isEmpty else {
            return
        }

        lock.withLock {
            data.append(chunk)
        }
    }

    var stringValue: String {
        lock.withLock {
            String(data: data, encoding: .utf8) ?? ""
        }
    }
}
