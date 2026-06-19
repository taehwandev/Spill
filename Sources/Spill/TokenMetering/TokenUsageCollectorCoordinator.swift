import Foundation

protocol TokenUsageExternalCollecting: AnyObject {
    func requestCollection(reason: String)
}

final class TokenUsageCollectorCoordinator: TokenUsageExternalCollecting, @unchecked Sendable {
    typealias AntigravityImportRunner = (TokenUsageStore, Date) -> TokenUsageAntigravityImportSummary

    static let collectionDidFinishNotification = Notification.Name("app.spill.token-usage-collector.collection-did-finish")

    private let store: TokenUsageStore
    private let antigravityImportRunner: AntigravityImportRunner
    private let antigravityLookbackInterval: TimeInterval
    private let queue = DispatchQueue(label: "app.spill.token-usage-collector")
    private let lock = NSLock()
    private var isCollecting = false
    private var hasPendingRequest = false

    init(
        store: TokenUsageStore,
        antigravityImportRunner: AntigravityImportRunner? = nil,
        antigravityLookbackInterval: TimeInterval = 24 * 60 * 60
    ) {
        self.store = store
        self.antigravityImportRunner = antigravityImportRunner ?? { store, startDate in
            TokenUsageAntigravityImporter().importRecentEvents(into: store, since: startDate)
        }
        self.antigravityLookbackInterval = antigravityLookbackInterval
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
            // The collector only drains app-owned queued events. Local runtime
            // history scans are user-initiated through TokenUsageHistoryImportCoordinator.
            // AGY is different: it has no runtime hook, so its active importer is
            // the real-time local collection path.
            store.drainQueuedEventsWithoutLoading()
            runAntigravityActiveImporter()

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

    private func runAntigravityActiveImporter() {
        let startDate = Date().addingTimeInterval(-antigravityLookbackInterval)
        _ = antigravityImportRunner(store, startDate)
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
