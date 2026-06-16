import Foundation

protocol TokenUsageExternalCollecting: AnyObject {
    func requestCollection(reason: String)
}

final class TokenUsageCollectorCoordinator: TokenUsageExternalCollecting, @unchecked Sendable {
    static let collectionDidFinishNotification = Notification.Name("app.spill.token-usage-collector.collection-did-finish")

    private let store: TokenUsageStore
    private let queue = DispatchQueue(label: "app.spill.token-usage-collector")
    private let lock = NSLock()
    private let codexImporterURLProvider: () -> URL?
    private let claudeHookURLProvider: () -> URL?
    private let nodeExecutableURLProvider: () -> URL?
    private let python3ExecutableURLProvider: () -> URL?
    private let antigravityImporterProvider: () -> TokenUsageAntigravityImporter?
    private let importerDrainInterval: TimeInterval
    private let importerMaximumRuntime: TimeInterval
    private let importerLookbackInterval: TimeInterval
    private var isCollecting = false
    private var hasPendingRequest = false

    init(
        store: TokenUsageStore,
        codexImporterURLProvider: @escaping () -> URL? = {
            let installedURL = TokenMeteringAdapterKit.defaultInstallURL(for: TokenMeteringAdapterKit.codex)
            if FileManager.default.fileExists(atPath: installedURL.path) {
                return installedURL
            }
            return TokenMeteringAdapterKit.codex.scriptURL
        },
        claudeHookURLProvider: @escaping () -> URL? = {
            let installedURL = TokenMeteringAdapterKit.defaultInstallURL(for: TokenMeteringAdapterKit.claudeCode)
            if FileManager.default.fileExists(atPath: installedURL.path) {
                return installedURL
            }
            return TokenMeteringAdapterKit.claudeCode.scriptURL
        },
        nodeExecutableURLProvider: @escaping () -> URL? = {
            TokenUsageCollectorCoordinator.nodeExecutableURL()
        },
        python3ExecutableURLProvider: @escaping () -> URL? = {
            TokenUsageCollectorCoordinator.python3ExecutableURL()
        },
        antigravityImporterProvider: @escaping () -> TokenUsageAntigravityImporter? = {
            TokenUsageAntigravityImporter()
        },
        importerDrainInterval: TimeInterval = 0.25,
        importerMaximumRuntime: TimeInterval = 30,
        importerLookbackInterval: TimeInterval = 24 * 60 * 60
    ) {
        self.store = store
        self.codexImporterURLProvider = codexImporterURLProvider
        self.claudeHookURLProvider = claudeHookURLProvider
        self.nodeExecutableURLProvider = nodeExecutableURLProvider
        self.python3ExecutableURLProvider = python3ExecutableURLProvider
        self.antigravityImporterProvider = antigravityImporterProvider
        self.importerDrainInterval = importerDrainInterval
        self.importerMaximumRuntime = importerMaximumRuntime
        self.importerLookbackInterval = importerLookbackInterval
    }

    func requestCollection(reason: String) {
        let shouldStart = lock.withLock {
            if isCollecting {
                hasPendingRequest = true
                return false
            }

            isCollecting = true
            return true
        }

        guard shouldStart else {
            return
        }

        queue.async { [weak self] in
            self?.runCollectionLoop()
        }
    }

    private func runCollectionLoop() {
        while true {
            // Import inbox events first so the dashboard shows existing data
            // immediately, without waiting for local importers to finish.
            store.importQueuedEventsWithoutLoading()
            runLocalImportersIfAvailable()
            store.importQueuedEventsWithoutLoading()

            let shouldRunAgain = lock.withLock {
                if hasPendingRequest {
                    hasPendingRequest = false
                    return true
                }

                isCollecting = false
                return false
            }

            if !shouldRunAgain {
                NotificationCenter.default.post(name: Self.collectionDidFinishNotification, object: self)
                return
            }
        }
    }

    private func runCodexImporterIfAvailable() {
        guard let importerURL = codexImporterURLProvider(),
              FileManager.default.fileExists(atPath: importerURL.path),
              let nodeURL = nodeExecutableURLProvider()
        else {
            return
        }

        let process = Process()
        process.executableURL = nodeURL
        let sinceHours = max(1, Int(importerLookbackInterval / 3600))
        process.arguments = [
            importerURL.path,
            "--since-hours",
            "\(sinceHours)",
            "--json"
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            importQueuedEventsWhileProcessRuns(process)
        } catch {
            return
        }
    }

    private func runLocalImportersIfAvailable() {
        runClaudeTranscriptScanIfAvailable()
        runCodexImporterIfAvailable()
        runAntigravityImporterIfAvailable()
    }

    private func runClaudeTranscriptScanIfAvailable() {
        guard let hookURL = claudeHookURLProvider(),
              FileManager.default.fileExists(atPath: hookURL.path),
              let python3URL = python3ExecutableURLProvider()
        else {
            return
        }

        let claudeProjectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects", isDirectory: true)
        guard FileManager.default.fileExists(atPath: claudeProjectsDir.path) else {
            return
        }

        let sinceHours = max(1, Int(importerLookbackInterval / 3600))
        let process = Process()
        process.executableURL = python3URL
        process.arguments = [
            hookURL.path,
            "--scan-dir",
            claudeProjectsDir.path,
            "--since-hours",
            "\(sinceHours)",
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            importQueuedEventsWhileProcessRuns(process)
        } catch {
            return
        }
    }

    private func runAntigravityImporterIfAvailable() {
        guard let importer = antigravityImporterProvider() else {
            return
        }

        let startDate = Date().addingTimeInterval(-importerLookbackInterval)
        _ = importer.importRecentEvents(into: store, since: startDate)
    }

    private func importQueuedEventsWhileProcessRuns(_ process: Process) {
        let startedAt = Date()

        while process.isRunning {
            store.importQueuedEventsWithoutLoading()

            if Date().timeIntervalSince(startedAt) > importerMaximumRuntime {
                process.terminate()
                break
            }

            Thread.sleep(forTimeInterval: importerDrainInterval)
        }

        process.waitUntilExit()
        store.importQueuedEventsWithoutLoading()
    }

    static func nodeExecutableURL(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isExecutableFile: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) },
        isRegularFile: (String) -> Bool = { path in
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
                return false
            }
            return !isDirectory.boolValue
        }
    ) -> URL? {
        let candidates = [
            environment["SPILL_TOKEN_USAGE_NODE"],
            environment["NODE_BINARY"],
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node",
            "/usr/bin/node",
        ].compactMap { $0 }

        for candidate in candidates {
            let candidateURL = URL(fileURLWithPath: candidate)
            guard candidateURL.path == candidate else {
                continue
            }

            let standardizedPath = candidateURL.standardizedFileURL.path
            if isRegularFile(standardizedPath), isExecutableFile(standardizedPath) {
                return URL(fileURLWithPath: standardizedPath)
            }
        }

        return nil
    }

    static func python3ExecutableURL(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isExecutableFile: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) },
        isRegularFile: (String) -> Bool = { path in
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
                return false
            }
            return !isDirectory.boolValue
        }
    ) -> URL? {
        let candidates = [
            environment["SPILL_TOKEN_USAGE_PYTHON3"],
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3",
        ].compactMap { $0 }

        for candidate in candidates {
            let candidateURL = URL(fileURLWithPath: candidate)
            guard candidateURL.path == candidate else {
                continue
            }

            let standardizedPath = candidateURL.standardizedFileURL.path
            if isRegularFile(standardizedPath), isExecutableFile(standardizedPath) {
                return URL(fileURLWithPath: standardizedPath)
            }
        }

        return nil
    }
}
