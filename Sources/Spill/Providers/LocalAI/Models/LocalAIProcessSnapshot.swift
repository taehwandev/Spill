import Foundation

struct LocalAIProcessSnapshot: Hashable, Sendable {
    let processID: Int
    let executableName: String
    let cpuPercent: Double
    let memoryBytes: UInt64
    let metricsAvailable: Bool
    let commandLine: String
    let executableToken: String?

    init(
        processID: Int,
        executableName: String,
        cpuPercent: Double,
        memoryBytes: UInt64,
        metricsAvailable: Bool = true,
        commandLine: String = "",
        executableToken: String? = nil
    ) {
        self.processID = processID
        self.executableName = executableName
        self.cpuPercent = metricsAvailable ? max(0, cpuPercent) : 0
        self.memoryBytes = metricsAvailable ? memoryBytes : 0
        self.metricsAvailable = metricsAvailable
        self.commandLine = commandLine
        self.executableToken = executableToken ?? Self.executableToken(from: commandLine)
    }

    private static func executableToken(from commandLine: String) -> String? {
        guard !commandLine.isEmpty else {
            return nil
        }

        return LocalAICommandLineParser.executableToken(
            from: LocalAICommandLineParser.tokens(from: commandLine)
        )
    }
}
