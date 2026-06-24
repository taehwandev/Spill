import Darwin
import Foundation

enum LocalCommandRunner {
    private static let processLimit = DispatchSemaphore(value: 2)
    private static let defaultMaximumOutputBytes = 1_048_576

    static func output(
        executablePath: String,
        arguments: [String],
        timeout: TimeInterval,
        maximumOutputBytes: Int = defaultMaximumOutputBytes
    ) -> String? {
        guard FileManager.default.fileExists(atPath: executablePath),
              processLimit.wait(timeout: .now()) == .success
        else { return nil }
        defer { processLimit.signal() }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let pipe = Pipe()
        let errorPipe = Pipe()
        let outputBuffer = LockedOutputBuffer()
        process.standardOutput = pipe
        process.standardError = errorPipe
        let terminationSemaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in terminationSemaphore.signal() }
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            outputBuffer.append(data, maximumBytes: maximumOutputBytes)
        }
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            if handle.availableData.isEmpty {
                handle.readabilityHandler = nil
            }
        }
        defer {
            pipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            try? pipe.fileHandleForReading.close()
            try? errorPipe.fileHandleForReading.close()
        }

        do { try process.run() } catch { return nil }

        guard terminationSemaphore.wait(timeout: .now() + timeout) == .success else {
            terminateProcess(process, terminationSemaphore: terminationSemaphore)
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }

        outputBuffer.append(pipe.fileHandleForReading.availableData, maximumBytes: maximumOutputBytes)
        let data = outputBuffer.data()
        return String(data: data, encoding: .utf8)
    }

    private static func terminateProcess(
        _ process: Process,
        terminationSemaphore: DispatchSemaphore,
        graceInterval: TimeInterval = 0.5
    ) {
        guard process.isRunning else { return }

        process.terminate()
        if terminationSemaphore.wait(timeout: .now() + graceInterval) == .success { return }

        Darwin.kill(process.processIdentifier, SIGKILL)
        _ = terminationSemaphore.wait(timeout: .now() + graceInterval)
    }

    private final class LockedOutputBuffer: @unchecked Sendable {
        private let lock = NSLock()
        private var storage = Data()

        func append(_ data: Data, maximumBytes: Int) {
            guard !data.isEmpty, maximumBytes > 0 else { return }
            lock.withLock {
                let remainingByteCount = maximumBytes - storage.count
                guard remainingByteCount > 0 else { return }
                storage.append(data.prefix(remainingByteCount))
            }
        }

        func data() -> Data {
            lock.withLock { storage }
        }
    }
}
