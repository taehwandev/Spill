import Foundation

extension LocalAIProcessSnapshotReader {
    private static var sampleLock: NSLock {
        LocalAIProcessSampleStore.shared.lock
    }

    private nonisolated(unsafe) static var previousSamples: [Int: LocalAIProcessMetricSample] {
        get {
            LocalAIProcessSampleStore.shared.previousSamples
        }
        set {
            LocalAIProcessSampleStore.shared.previousSamples = newValue
        }
    }

    static func cpuPercent(
        previous: LocalAIProcessMetricSample?,
        current: LocalAIProcessMetricSample
    ) -> Double {
        guard let previous,
              previous.processID == current.processID,
              current.processStartTimeNanoseconds != nil,
              previous.processStartTimeNanoseconds == current.processStartTimeNanoseconds,
              current.timestamp > previous.timestamp,
              current.cpuTimeNanoseconds >= previous.cpuTimeNanoseconds
        else {
            return 0
        }

        let elapsedSeconds = current.timestamp.timeIntervalSince(previous.timestamp)
        guard elapsedSeconds > 0 else {
            return 0
        }

        let cpuDeltaSeconds = Double(current.cpuTimeNanoseconds - previous.cpuTimeNanoseconds) / 1_000_000_000
        return max(0, cpuDeltaSeconds / elapsedSeconds * 100)
    }

    static func currentMetrics(
        for processIDs: [Int],
        now: Date
    ) -> [Int: LocalAIProcessMetrics] {
        let currentProcessIDs = Set(processIDs)
        var rawMetricsByProcessID: [Int: LocalAIRawProcessMetrics] = [:]

        for processID in currentProcessIDs {
            if let taskInfo = taskInfo(for: processID) {
                let sample = LocalAIProcessMetricSample(
                    processID: processID,
                    timestamp: now,
                    cpuTimeNanoseconds: UInt64(taskInfo.pti_total_user) &+ UInt64(taskInfo.pti_total_system),
                    processStartTimeNanoseconds: processStartTimeNanoseconds(for: processID)
                )
                rawMetricsByProcessID[processID] = LocalAIRawProcessMetrics(
                    sample: sample,
                    memoryBytes: memoryFootprintBytes(for: processID) ?? UInt64(taskInfo.pti_resident_size)
                )
            }
        }

        sampleLock.lock()
        defer { sampleLock.unlock() }

        var metricsByProcessID: [Int: LocalAIProcessMetrics] = [:]
        for (processID, rawMetrics) in rawMetricsByProcessID {
            metricsByProcessID[processID] = LocalAIProcessMetrics(
                cpuPercent: cpuPercent(previous: previousSamples[processID], current: rawMetrics.sample),
                memoryBytes: rawMetrics.memoryBytes
            )
        }

        previousSamples = previousSamples.filter { currentProcessIDs.contains($0.key) }
        for (processID, rawMetrics) in rawMetricsByProcessID {
            previousSamples[processID] = rawMetrics.sample
        }

        return metricsByProcessID
    }
}

private final class LocalAIProcessSampleStore: @unchecked Sendable {
    static let shared = LocalAIProcessSampleStore()

    let lock = NSLock()
    nonisolated(unsafe) var previousSamples: [Int: LocalAIProcessMetricSample] = [:]
}
