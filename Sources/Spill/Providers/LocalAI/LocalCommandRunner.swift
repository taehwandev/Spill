import Foundation

enum LocalCommandRunner {
    static func output(
        executablePath: String,
        arguments: [String],
        timeout: TimeInterval
    ) -> String? {
        guard FileManager.default.fileExists(atPath: executablePath) else {
            return nil
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = nil

        do {
            try process.run()
        } catch {
            return nil
        }

        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            process.waitUntilExit()
            group.leave()
        }

        guard group.wait(timeout: .now() + timeout) == .success else {
            process.terminate()
            _ = group.wait(timeout: .now() + 0.2)
            return nil
        }

        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}
