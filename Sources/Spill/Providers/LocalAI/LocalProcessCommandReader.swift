import Foundation

enum LocalProcessCommandReader {
    static func currentCommands() -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "command="]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = nil

        do {
            try process.run()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            return []
        }

        guard let output = String(data: data, encoding: .utf8) else {
            return []
        }

        return output
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
