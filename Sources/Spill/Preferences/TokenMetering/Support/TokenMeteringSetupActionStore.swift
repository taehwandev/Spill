import Combine
import Foundation

@MainActor
final class TokenMeteringSetupActionStore: ObservableObject {
    static let shared = TokenMeteringSetupActionStore()

    enum OperationState: Equatable, Sendable {
        case idle
        case running
        case succeeded
        case failed
    }

    enum RunResult: Equatable, Sendable {
        case succeeded
        case failed
    }

    typealias InstallationReader = @Sendable (Set<TokenUsageAITool>) -> Bool
    typealias SetupRunner = @Sendable (Set<TokenUsageAITool>) -> RunResult

    @Published private(set) var isInstalled = false
    @Published private(set) var operationState: OperationState = .idle

    private let installationReader: InstallationReader
    private let setupRunner: SetupRunner
    private var installedTools = Set<TokenUsageAITool>()
    private var refreshGeneration = 0

    init(
        installationReader: @escaping InstallationReader = {
            TokenMeteringSetupInstallationDiagnostics.isInstalled(for: $0)
        },
        setupRunner: @escaping SetupRunner = TokenMeteringSetupProcessRunner.run
    ) {
        self.installationReader = installationReader
        self.setupRunner = setupRunner
    }

    var isRunning: Bool {
        operationState == .running
    }

    /// Reads adapter config files off the main thread; the returned task lets callers await the result.
    @discardableResult
    func refresh(installedTools: Set<TokenUsageAITool>) -> Task<Void, Never>? {
        guard !isRunning else {
            return nil
        }
        self.installedTools = installedTools
        refreshGeneration += 1
        operationState = .idle
        if installedTools.isEmpty {
            isInstalled = false
            return nil
        }

        let generation = refreshGeneration
        let installationReader = installationReader
        return Task { [weak self] in
            let installed = await Task.detached(priority: .utility) {
                installationReader(installedTools)
            }.value
            guard let self, self.refreshGeneration == generation, !self.isRunning else {
                return
            }
            self.isInstalled = installed
        }
    }

    func installOrRepair(installedTools: Set<TokenUsageAITool>) {
        guard !installedTools.isEmpty, !isRunning else {
            return
        }

        self.installedTools = installedTools
        operationState = .running
        let setupRunner = setupRunner
        let installationReader = installationReader
        let targetTools = installedTools
        Task { [weak self] in
            let (result, installed) = await Task.detached(priority: .userInitiated) {
                (setupRunner(targetTools), installationReader(targetTools))
            }.value
            guard let self else {
                return
            }

            self.refreshGeneration += 1
            self.isInstalled = installed
            self.operationState = result == .succeeded && self.isInstalled
                ? .succeeded
                : .failed
        }
    }
}

private enum TokenMeteringSetupProcessRunner {
    static let maximumRuntime: TimeInterval = 120

    static func run(
        installedTools: Set<TokenUsageAITool>
    ) -> TokenMeteringSetupActionStore.RunResult {
        let includedTools = TokenUsageAITool.dashboardTools
            .filter(installedTools.contains)
            .map(\.rawValue)
        guard !includedTools.isEmpty else {
            return .failed
        }

        do {
            try TokenMeteringSetupInstaller.install(installsSharedRuntimeInstruction: false)
        } catch {
            return .failed
        }

        guard let nodeURL = TokenUsageCollectorCoordinator.nodeExecutableURL() else {
            return .failed
        }

        let process = Process()
        process.executableURL = nodeURL
        process.arguments = [
            TokenMeteringSetupInstaller.defaultInstallURL().path,
            "--apply",
            "--metering-only",
            "--json",
            "--include",
            includedTools.joined(separator: ",")
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        let terminationSemaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            terminationSemaphore.signal()
        }

        do {
            try process.run()
        } catch {
            return .failed
        }

        if terminationSemaphore.wait(timeout: .now() + maximumRuntime) == .timedOut {
            process.terminate()
            _ = terminationSemaphore.wait(timeout: .now() + 2)
            return .failed
        }

        return process.terminationStatus == 0 ? .succeeded : .failed
    }
}
