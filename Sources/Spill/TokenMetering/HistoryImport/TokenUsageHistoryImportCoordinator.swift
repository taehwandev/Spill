import Combine
import Foundation

final class TokenUsageHistoryImportCoordinator: ObservableObject, @unchecked Sendable {
    typealias ProcessRunner = (TokenUsageHistoryImportProcessContext) -> TokenUsageHistoryImportProcessResult
    typealias AntigravityImportRunner = (TokenUsageStore, Date, @escaping () -> Bool) -> TokenUsageAntigravityImportSummary

    static let importerVersion = 1
    static let incrementalLookbackHours = 48
    static let maximumProcessRuntime: TimeInterval = 5 * 60

    @Published var snapshot: TokenUsageHistoryImportSnapshot

    let store: TokenUsageStore
    let stateStore: TokenUsageHistoryImportStateStore
    let queue = DispatchQueue(label: "app.spill.token-usage-history-import")
    let lock = NSLock()
    let processLock = NSLock()
    let codexImporterURLProvider: () -> URL?
    let claudeHookURLProvider: () -> URL?
    let nodeExecutableURLProvider: () -> URL?
    let python3ExecutableURLProvider: () -> URL?
    let antigravityImportRunner: AntigravityImportRunner
    let processRunner: ProcessRunner
    let historyStateDirectory: URL
    var isImportRunning = false
    var isCancellationRequested = false
    var runningProcess: Process?

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
        processRunner: @escaping ProcessRunner = TokenUsageHistoryImportProcessRunner.run(context:)
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

}
