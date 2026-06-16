import Foundation

enum LocalProcessNameReader {
    static func currentNames() -> Set<String> {
        let executablePath = "/bin/ps"
        guard FileManager.default.fileExists(atPath: executablePath) else {
            return []
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["-axo", "comm="]

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

        return Set(
            output
                .split(whereSeparator: \.isNewline)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }
}
