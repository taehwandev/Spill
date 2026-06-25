import Foundation

enum LocalAIProcessSnapshotReader {
    static func currentSnapshots(
        now: Date = Date(),
        shouldCancel: @escaping () -> Bool = { false }
    ) -> [LocalAIProcessSnapshot] {
        guard let output = LocalCommandRunner.output(
            executablePath: "/bin/ps",
            arguments: ["-axo", "pid=,command="],
            timeout: 1.0,
            maximumOutputBytes: 2_097_152,
            shouldCancel: shouldCancel
        ) else {
            return []
        }
        guard !shouldCancel() else {
            return []
        }

        let snapshots = output
            .split(whereSeparator: \.isNewline)
            .compactMap { parseLine(String($0)) }
        let candidateSnapshots = snapshots.filter(isKnownAIToolProcess)
        guard !shouldCancel() else {
            return []
        }

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
