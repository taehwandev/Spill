import Foundation

extension LocalAIProcessSnapshotReader {
    static func parseLine(_ line: String) -> LocalAIProcessSnapshot? {
        let parts = line.split(
            separator: " ",
            maxSplits: 1,
            omittingEmptySubsequences: true
        )

        guard parts.count == 2,
              let processID = Int(parts[0])
        else {
            return nil
        }

        let commandLine = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !commandLine.isEmpty else {
            return nil
        }

        let tokens = LocalAICommandLineParser.tokens(from: commandLine)
        let executableToken = LocalAICommandLineParser.executableToken(from: tokens)

        return LocalAIProcessSnapshot(
            processID: processID,
            executableName: safeExecutableName(from: executableToken),
            cpuPercent: 0,
            memoryBytes: 0,
            metricsAvailable: false,
            commandLine: commandLine,
            executableToken: executableToken
        )
    }

    static func isKnownAIToolProcess(
        _ snapshot: LocalAIProcessSnapshot,
        enabledKinds: Set<LocalAIToolKind> = Set(LocalAIToolKind.allCases)
    ) -> Bool {
        let processKinds = enabledKinds.filter { !$0.executableNames.isEmpty }
        let candidateExecutableNames = processKinds.flatMap(\.executableNames)
        let matchesExecutable = candidateExecutableNames.contains { executableName in
            snapshot.executableName.matchesExecutable(named: executableName)
                || snapshot.executableToken?.matchesExecutable(named: executableName) == true
        }
        guard !matchesExecutable else {
            return true
        }

        let lowercasedCommandLine = snapshot.commandLine.lowercased()
        let lowercasedExecutableName = snapshot.executableName.lowercased()
        let candidateApplicationNamesLowercased = processKinds.flatMap(\.applicationNames).map { $0.lowercased() }
        return candidateApplicationNamesLowercased.contains { lowercased in
            lowercasedCommandLine.contains("/\(lowercased).app/")
                || lowercasedCommandLine.hasSuffix("/\(lowercased).app")
                || lowercasedExecutableName == lowercased
        }
    }

    private static func safeExecutableName(from executableToken: String?) -> String {
        guard let executableToken else {
            return "Process"
        }

        let lastPathComponent = LocalAICommandLineParser.executableName(from: executableToken)
        return lastPathComponent.isEmpty ? executableToken : lastPathComponent
    }
}
