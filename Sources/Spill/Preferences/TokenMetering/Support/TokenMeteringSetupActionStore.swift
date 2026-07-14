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

    func refresh(installedTools: Set<TokenUsageAITool>) {
        guard !isRunning else {
            return
        }
        self.installedTools = installedTools
        if installedTools.isEmpty {
            isInstalled = false
            operationState = .idle
            return
        }
        isInstalled = installationReader(installedTools)
        operationState = .idle
    }

    func installOrRepair(installedTools: Set<TokenUsageAITool>) {
        guard !installedTools.isEmpty, !isRunning else {
            return
        }

        self.installedTools = installedTools
        operationState = .running
        let setupRunner = setupRunner
        let targetTools = installedTools
        Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                setupRunner(targetTools)
            }.value
            guard let self else {
                return
            }

            self.isInstalled = self.installationReader(self.installedTools)
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
