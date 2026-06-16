import Foundation

struct LocalAIProcessSnapshot: Hashable, Sendable {
    let processID: Int
    let executableName: String
    let cpuPercent: Double
    let memoryBytes: UInt64
    let commandLine: String

    init(
        processID: Int,
        executableName: String,
        cpuPercent: Double,
        memoryBytes: UInt64,
        commandLine: String = ""
    ) {
        self.processID = processID
        self.executableName = executableName
        self.cpuPercent = max(0, cpuPercent)
        self.memoryBytes = memoryBytes
        self.commandLine = commandLine
    }
}

struct LocalAIProcessSummary: Hashable, Sendable {
    static let empty = LocalAIProcessSummary(processes: [], fallbackProcessCount: 0)

    let processes: [LocalAIProcessSnapshot]
    let processCount: Int
    let cpuPercent: Double
    let memoryBytes: UInt64

    init(processes: [LocalAIProcessSnapshot], fallbackProcessCount: Int = 0) {
        self.processes = processes.sorted { lhs, rhs in
            if lhs.cpuPercent == rhs.cpuPercent {
                return lhs.processID < rhs.processID
            }
            return lhs.cpuPercent > rhs.cpuPercent
        }
        self.processCount = max(processes.count, fallbackProcessCount)
        self.cpuPercent = processes.reduce(0) { $0 + $1.cpuPercent }
        self.memoryBytes = processes.reduce(0) { $0 + $1.memoryBytes }
    }

    var isRunning: Bool {
        processCount > 0
    }

    var cpuPercentText: String {
        Self.formatCPUPercent(cpuPercent)
    }

    static func formatCPUPercent(_ value: Double) -> String {
        if value >= 10 {
            return String(format: "%.0f%%", value)
        }
        return String(format: "%.1f%%", value)
    }
}

enum LocalAIProcessSnapshotReader {
    static func currentSnapshots() -> [LocalAIProcessSnapshot] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,pcpu=,rss=,command="]

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

        guard process.terminationStatus == 0,
              let output = String(data: data, encoding: .utf8)
        else {
            return []
        }

        return output
            .split(whereSeparator: \.isNewline)
            .compactMap { parseLine(String($0)) }
    }

    static func parseLine(_ line: String) -> LocalAIProcessSnapshot? {
        let parts = line.split(
            separator: " ",
            maxSplits: 3,
            omittingEmptySubsequences: true
        )

        guard parts.count == 4,
              let processID = Int(parts[0]),
              let cpuPercent = Double(parts[1]),
              let rssKilobytes = UInt64(parts[2])
        else {
            return nil
        }

        let commandLine = String(parts[3]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !commandLine.isEmpty else {
            return nil
        }

        return LocalAIProcessSnapshot(
            processID: processID,
            executableName: safeExecutableName(from: commandLine),
            cpuPercent: cpuPercent,
            memoryBytes: rssKilobytes * 1024,
            commandLine: commandLine
        )
    }

    private static func safeExecutableName(from commandLine: String) -> String {
        let tokens = LocalAICommandLineParser.tokens(from: commandLine)
        guard let executableToken = LocalAICommandLineParser.executableToken(from: tokens) else {
            return "Process"
        }

        let lastPathComponent = URL(fileURLWithPath: executableToken).lastPathComponent
        return lastPathComponent.isEmpty ? executableToken : lastPathComponent
    }
}
