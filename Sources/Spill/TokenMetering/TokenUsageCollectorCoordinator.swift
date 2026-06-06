import Foundation

protocol TokenUsageExternalCollecting: AnyObject {
    func requestCollection(reason: String)
}

final class TokenUsageCollectorCoordinator: TokenUsageExternalCollecting, @unchecked Sendable {
    private let store: TokenUsageStore
    private let queue = DispatchQueue(label: "app.spill.token-usage-collector")
    private let lock = NSLock()
    private let codexImporterURLProvider: () -> URL?
    private let nodeExecutableURLProvider: () -> URL?
    private let importerDrainInterval: TimeInterval
    private let importerMaximumRuntime: TimeInterval
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
        nodeExecutableURLProvider: @escaping () -> URL? = {
            TokenUsageCollectorCoordinator.nodeExecutableURL()
        },
        importerDrainInterval: TimeInterval = 0.25,
        importerMaximumRuntime: TimeInterval = 30
    ) {
        self.store = store
        self.codexImporterURLProvider = codexImporterURLProvider
        self.nodeExecutableURLProvider = nodeExecutableURLProvider
        self.importerDrainInterval = importerDrainInterval
        self.importerMaximumRuntime = importerMaximumRuntime
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
            // immediately, without waiting for the Codex importer to finish.
            store.importQueuedEvents()
            runCodexImporterIfAvailable()
            store.importQueuedEvents()

            let shouldRunAgain = lock.withLock {
                if hasPendingRequest {
                    hasPendingRequest = false
                    return true
                }

                isCollecting = false
                return false
            }

            if !shouldRunAgain {
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
        process.arguments = [
            importerURL.path,
            "--since-hours",
            "6",
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

    private func importQueuedEventsWhileProcessRuns(_ process: Process) {
        let startedAt = Date()

        while process.isRunning {
            store.importQueuedEvents()

            if Date().timeIntervalSince(startedAt) > importerMaximumRuntime {
                process.terminate()
                break
            }

            Thread.sleep(forTimeInterval: importerDrainInterval)
        }

        process.waitUntilExit()
        store.importQueuedEvents()
    }

    static func nodeExecutableURL(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isExecutableFile: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) -> URL? {
        let candidates = [
            environment["SPILL_TOKEN_USAGE_NODE"],
            environment["NODE_BINARY"],
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node",
            "/usr/bin/node",
        ].compactMap { $0 }

        for candidate in candidates where isExecutableFile(candidate) {
            return URL(fileURLWithPath: candidate)
        }

        return nil
    }
}
