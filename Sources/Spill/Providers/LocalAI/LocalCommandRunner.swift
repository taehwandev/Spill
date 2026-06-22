import Foundation

enum LocalCommandRunner {
    private static let processLimit = DispatchSemaphore(value: 2)

    static func output(
        executablePath: String,
        arguments: [String],
        timeout: TimeInterval
    ) -> String? {
        guard FileManager.default.fileExists(atPath: executablePath) else {
            return nil
        }
        guard processLimit.wait(timeout: .now()) == .success else {
            return nil
        }
        defer {
            processLimit.signal()
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = nil
        let terminationSemaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            terminationSemaphore.signal()
        }

        do {
            try process.run()
        } catch {
            return nil
        }

        guard terminationSemaphore.wait(timeout: .now() + timeout) == .success else {
            process.terminate()
            _ = terminationSemaphore.wait(timeout: .now() + 0.2)
            return nil
        }

        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}
