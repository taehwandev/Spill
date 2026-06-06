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
        }
    ) {
        self.store = store
        self.codexImporterURLProvider = codexImporterURLProvider
        self.nodeExecutableURLProvider = nodeExecutableURLProvider
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
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return
        }
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
