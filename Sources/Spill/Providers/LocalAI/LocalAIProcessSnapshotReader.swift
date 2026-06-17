import Darwin
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

struct LocalAIProcessSummary: Hashable, Sendable {
    static let empty = LocalAIProcessSummary(processes: [], fallbackProcessCount: 0)

    let processes: [LocalAIProcessSnapshot]
    let processCount: Int
    let cpuPercent: Double
    let memoryBytes: UInt64
    let hasAvailableMetrics: Bool

    init(processes: [LocalAIProcessSnapshot], fallbackProcessCount: Int = 0) {
        self.processes = processes.sorted { lhs, rhs in
            if lhs.cpuPercent == rhs.cpuPercent {
                return lhs.processID < rhs.processID
            }
            return lhs.cpuPercent > rhs.cpuPercent
        }
        self.processCount = max(processes.count, fallbackProcessCount)
        self.hasAvailableMetrics = processes.contains { $0.metricsAvailable }
        self.cpuPercent = processes.reduce(0) { $0 + ($1.metricsAvailable ? $1.cpuPercent : 0) }
        self.memoryBytes = processes.reduce(0) { $0 + ($1.metricsAvailable ? $1.memoryBytes : 0) }
    }

    var isRunning: Bool {
        processCount > 0
    }

    var cpuPercentText: String {
        Self.formatCPUPercent(cpuPercent, isAvailable: hasAvailableMetrics)
    }

    var memoryText: String {
        hasAvailableMetrics ? SystemMemoryProvider.formatBytes(memoryBytes) : Self.unavailableMetricText
    }

    static let unavailableMetricText = "N/A"

    static func formatCPUPercent(_ value: Double, isAvailable: Bool = true) -> String {
        guard isAvailable else {
            return unavailableMetricText
        }
        if value > 100 {
            return "100%+"
        }
        if value >= 10 {
            return String(format: "%.0f%%", value)
        }
        return String(format: "%.1f%%", value)
    }
}

struct LocalAIProcessMetricSample: Hashable, Sendable {
    let processID: Int
    let timestamp: Date
    let cpuTimeNanoseconds: UInt64
    let processStartTimeNanoseconds: UInt64?
}

enum LocalAIProcessSnapshotReader {
    private static let sampleLock = NSLock()
    private nonisolated(unsafe) static var previousSamples: [Int: LocalAIProcessMetricSample] = [:]

    static func currentSnapshots(now: Date = Date()) -> [LocalAIProcessSnapshot] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,command="]

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

    static func isKnownAIToolProcess(_ snapshot: LocalAIProcessSnapshot) -> Bool {
        let matchesExecutable = candidateExecutableNames.contains { executableName in
            snapshot.executableName.matchesExecutable(named: executableName)
                || snapshot.executableToken?.matchesExecutable(named: executableName) == true
        }
        guard !matchesExecutable else {
            return true
        }

        let lowercasedCommandLine = snapshot.commandLine.lowercased()
        let lowercasedExecutableName = snapshot.executableName.lowercased()
        return candidateApplicationNamesLowercased.contains { lowercased in
            lowercasedCommandLine.contains("/\(lowercased).app/")
                || lowercasedCommandLine.hasSuffix("/\(lowercased).app")
                || lowercasedExecutableName == lowercased
        }
    }

    private static let candidateToolKinds: [LocalAIToolKind] = [.codex, .claude, .antigravity, .ollama]
    private static let candidateExecutableNames = candidateToolKinds.flatMap(\.executableNames)
    private static let candidateApplicationNames = candidateToolKinds.flatMap(\.applicationNames)
    private static let candidateApplicationNamesLowercased = candidateApplicationNames.map { $0.lowercased() }

    private static func safeExecutableName(from executableToken: String?) -> String {
        guard let executableToken else {
            return "Process"
        }

        let lastPathComponent = URL(fileURLWithPath: executableToken).lastPathComponent
        return lastPathComponent.isEmpty ? executableToken : lastPathComponent
    }

    private static func currentMetrics(
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

    private static func taskInfo(for processID: Int) -> proc_taskinfo? {
        var taskInfo = proc_taskinfo()
        let expectedSize = MemoryLayout<proc_taskinfo>.stride
        let result = withUnsafeMutablePointer(to: &taskInfo) { pointer in
            proc_pidinfo(
                Int32(processID),
                PROC_PIDTASKINFO,
                0,
                pointer,
                Int32(expectedSize)
            )
        }

        guard result == Int32(expectedSize) else {
            return nil
        }

        return taskInfo
    }

    private static func processStartTimeNanoseconds(for processID: Int) -> UInt64? {
        var bsdInfo = proc_bsdinfo()
        let expectedSize = MemoryLayout<proc_bsdinfo>.stride
        let result = withUnsafeMutablePointer(to: &bsdInfo) { pointer in
            proc_pidinfo(
                Int32(processID),
                PROC_PIDTBSDINFO,
                0,
                pointer,
                Int32(expectedSize)
            )
        }

        guard result == Int32(expectedSize) else {
            return nil
        }

        return bsdInfo.pbi_start_tvsec * 1_000_000_000 + bsdInfo.pbi_start_tvusec * 1_000
    }

    private static func memoryFootprintBytes(for processID: Int) -> UInt64? {
        var rusage = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &rusage) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { reboundPointer in
                proc_pid_rusage(
                    Int32(processID),
                    RUSAGE_INFO_V4,
                    reboundPointer
                )
            }
        }

        guard result == 0,
              rusage.ri_phys_footprint > 0
        else {
            return nil
        }

        return UInt64(rusage.ri_phys_footprint)
    }
}

private struct LocalAIProcessMetrics: Hashable, Sendable {
    let cpuPercent: Double
    let memoryBytes: UInt64
}

private struct LocalAIRawProcessMetrics: Hashable, Sendable {
    let sample: LocalAIProcessMetricSample
    let memoryBytes: UInt64
}
