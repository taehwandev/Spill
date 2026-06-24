import Darwin
import Foundation

enum TokenUsageHistoryImportProcessRunner {
    private static let pollInterval: TimeInterval = 0.25

    static func run(
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
        let terminationSemaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            terminationSemaphore.signal()
        }
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
        var didRequestTermination = false

        while process.isRunning {
            if context.shouldCancel() {
                timedOut = false
                didRequestTermination = true
                terminateProcess(process, terminationSemaphore: terminationSemaphore)
                break
            }

            if Date().timeIntervalSince(startedAt) > context.maximumRuntime {
                timedOut = true
                didRequestTermination = true
                terminateProcess(process, terminationSemaphore: terminationSemaphore)
                break
            }

            Thread.sleep(forTimeInterval: Self.pollInterval)
        }

        if !didRequestTermination, process.isRunning {
            terminateProcess(process, terminationSemaphore: terminationSemaphore)
        }
        context.processDidFinish()
        context.store.drainQueuedEventsWithoutLoading(maximumInboxEventCount: nil)
        outputHandle.readabilityHandler = nil
        errorHandle.readabilityHandler = nil

        return TokenUsageHistoryImportProcessResult(
            exitCode: process.isRunning ? -1 : process.terminationStatus,
            stdout: outputBuffer.stringValue,
            stderr: errorBuffer.stringValue,
            timedOut: timedOut
        )
    }

    private static func terminateProcess(
        _ process: Process,
        terminationSemaphore: DispatchSemaphore,
        graceInterval: TimeInterval = 1.0
    ) {
        guard process.isRunning else {
            return
        }

        process.terminate()
        if terminationSemaphore.wait(timeout: .now() + graceInterval) == .success {
            return
        }

        Darwin.kill(process.processIdentifier, SIGKILL)
        _ = terminationSemaphore.wait(timeout: .now() + graceInterval)
    }
}

private final class ProcessPipeBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ newData: Data) {
        guard !newData.isEmpty else { return }
        lock.lock()
        data.append(newData)
        lock.unlock()
    }

    var stringValue: String {
        lock.lock()
        let snapshot = data
        lock.unlock()
        return String(data: snapshot, encoding: .utf8) ?? ""
    }
}
