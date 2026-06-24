import Foundation

enum LocalAIProcessSnapshotReader {
    static func currentSnapshots(now: Date = Date()) -> [LocalAIProcessSnapshot] {
        guard let output = LocalCommandRunner.output(
            executablePath: "/bin/ps",
            arguments: ["-axo", "pid=,command="],
            timeout: 1.0,
            maximumOutputBytes: 2_097_152
        ) else {
            return []
        }

        let snapshots = output
            .split(whereSeparator: \.isNewline)
            .compactMap { parseLine(String($0)) }
        let candidateSnapshots = snapshots.filter(isKnownAIToolProcess)

        let metricsByProcessID = currentMetrics(
            for: candidateSnapshots.map(\.processID),
            now: now
        )

        return candidateSnapshots.map { snapshot in
            let metrics = metricsByProcessID[snapshot.processID]
            return LocalAIProcessSnapshot(
                processID: snapshot.processID,
                executableName: snapshot.executableName,
                cpuPercent: metrics?.cpuPercent ?? 0,
                memoryBytes: metrics?.memoryBytes ?? 0,
                metricsAvailable: metrics != nil,
                commandLine: snapshot.commandLine,
                executableToken: snapshot.executableToken
            )
        }
    }
}
