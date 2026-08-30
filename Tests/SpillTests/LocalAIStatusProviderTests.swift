import XCTest
@testable import Spill

final class LocalAIStatusProviderTests: XCTestCase {
    func testProcessSnapshotReaderParsesCommandOnlyRows() throws {
        let snapshot = try XCTUnwrap(LocalAIProcessSnapshotReader.parseLine("  123 /opt/homebrew/bin/codex --model gpt-5.2"))

        XCTAssertEqual(snapshot.processID, 123)
        XCTAssertEqual(snapshot.executableName, "codex")
        XCTAssertEqual(snapshot.cpuPercent, 0)
        XCTAssertEqual(snapshot.memoryBytes, 0)
        XCTAssertEqual(snapshot.commandLine, "/opt/homebrew/bin/codex --model gpt-5.2")
        XCTAssertEqual(snapshot.executableToken, "/opt/homebrew/bin/codex")
    }

    func testExecutableMatchingUsesPurePathComponents() {
        XCTAssertTrue("codex".matchesExecutable(named: "Codex"))
        XCTAssertTrue(" /opt/homebrew/bin/codex ".matchesExecutable(named: "codex"))
        XCTAssertTrue("/opt/homebrew/bin/codex/".matchesExecutable(named: "codex"))
        XCTAssertFalse("/opt/homebrew/bin/not-codex".matchesExecutable(named: "codex"))
        XCTAssertEqual(
            LocalAICommandLineParser.executableName(from: "/Applications/Antigravity IDE.app/Contents/MacOS/Antigravity IDE"),
            "Antigravity IDE"
        )
    }

    func testProcessMetricDeltaCalculatesRecentCPUPercent() {
        let previous = LocalAIProcessMetricSample(
            processID: 123,
            timestamp: Date(timeIntervalSince1970: 10),
            cpuTimeNanoseconds: 1_000_000_000,
            processStartTimeNanoseconds: 500_000
        )
        let current = LocalAIProcessMetricSample(
            processID: 123,
            timestamp: Date(timeIntervalSince1970: 12),
            cpuTimeNanoseconds: 1_500_000_000,
            processStartTimeNanoseconds: 500_000
        )

        XCTAssertEqual(
            LocalAIProcessSnapshotReader.cpuPercent(previous: previous, current: current),
            25,
            accuracy: 0.001
        )
    }

    func testProcessMetricDeltaIgnoresTooShortSampleIntervals() {
        let previous = LocalAIProcessMetricSample(
            processID: 123,
            timestamp: Date(timeIntervalSince1970: 10),
            cpuTimeNanoseconds: 1_000_000_000,
            processStartTimeNanoseconds: 500_000
        )
        let current = LocalAIProcessMetricSample(
            processID: 123,
            timestamp: Date(timeIntervalSince1970: 10.1),
            cpuTimeNanoseconds: 1_500_000_000,
            processStartTimeNanoseconds: 500_000
        )

        XCTAssertEqual(LocalAIProcessSnapshotReader.cpuPercent(previous: previous, current: current), 0)
    }

    func testProcessMetricDeltaIgnoresReusedPIDWithDifferentStartTime() {
        let previous = LocalAIProcessMetricSample(
            processID: 123,
            timestamp: Date(timeIntervalSince1970: 10),
            cpuTimeNanoseconds: 3_000_000_000,
            processStartTimeNanoseconds: 500_000
        )
        let current = LocalAIProcessMetricSample(
            processID: 123,
            timestamp: Date(timeIntervalSince1970: 12),
            cpuTimeNanoseconds: 5_000_000_000,
            processStartTimeNanoseconds: 900_000
        )

        XCTAssertEqual(LocalAIProcessSnapshotReader.cpuPercent(previous: previous, current: current), 0)
    }

    func testUnavailableProcessMetricsRenderAsUnavailableInsteadOfZero() {
        let summary = LocalAIProcessSummary(
            processes: [
                LocalAIProcessSnapshot(
                    processID: 123,
                    executableName: "codex",
                    cpuPercent: 42,
                    memoryBytes: 128 * 1024 * 1024,
                    metricsAvailable: false,
                    commandLine: "/opt/homebrew/bin/codex"
                )
            ]
        )

        XCTAssertEqual(summary.cpuPercent, 0)
        XCTAssertEqual(summary.memoryBytes, 0)
        XCTAssertEqual(summary.cpuPercentText, "N/A")
        XCTAssertEqual(summary.memoryText, "N/A")
    }

    func testCPUPercentTextIsBoundedForCompactDisplay() {
        XCTAssertEqual(LocalAIProcessSummary.formatCPUPercent(1600), "100%+")
    }

    func testProcessSnapshotReaderSamplesMetricsOnlyForKnownAIToolCandidates() {
        XCTAssertTrue(LocalAIProcessSnapshotReader.isKnownAIToolProcess(
            LocalAIProcessSnapshot(
                processID: 123,
                executableName: "env",
                cpuPercent: 0,
                memoryBytes: 0,
                commandLine: "/usr/bin/env PATH=/opt/homebrew/bin /opt/homebrew/bin/codex --model gpt-5.2"
            )
        ))
        XCTAssertTrue(LocalAIProcessSnapshotReader.isKnownAIToolProcess(
            LocalAIProcessSnapshot(
                processID: 124,
                executableName: "Antigravity IDE",
                cpuPercent: 0,
                memoryBytes: 0,
                commandLine: "/Applications/Antigravity IDE.app/Contents/MacOS/Antigravity IDE"
            )
        ))
        XCTAssertFalse(LocalAIProcessSnapshotReader.isKnownAIToolProcess(
            LocalAIProcessSnapshot(
                processID: 125,
                executableName: "Safari",
                cpuPercent: 0,
                memoryBytes: 0,
                commandLine: "/Applications/Safari.app/Contents/MacOS/Safari"
            )
        ))
    }

    func testProcessSnapshotReaderUsesMacOSProcessAPIsForMetrics() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let readerSource = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Providers/LocalAI/ProcessSnapshot/LocalAIProcessSnapshotReader.swift"))
        let darwinSource = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Providers/LocalAI/ProcessSnapshot/LocalAIProcessSnapshotReader+Darwin.swift"))
        let metricsSource = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Providers/LocalAI/ProcessSnapshot/LocalAIProcessSnapshotReader+Metrics.swift"))
        let combinedSource = [readerSource, darwinSource, metricsSource].joined(separator: "\n")

        XCTAssertTrue(darwinSource.contains("proc_pidinfo"))
        XCTAssertTrue(darwinSource.contains("PROC_PIDTASKINFO"))
        XCTAssertTrue(darwinSource.contains("proc_pid_rusage"))
        XCTAssertTrue(darwinSource.contains("ri_phys_footprint"))
        XCTAssertTrue(readerSource.contains("candidateSnapshots.map(\\.processID)"))
        XCTAssertTrue(readerSource.contains("snapshots.filter(isKnownAIToolProcess)"))
        XCTAssertTrue(readerSource.contains("executableToken: snapshot.executableToken"))
        XCTAssertTrue(metricsSource.contains("LocalAIRawProcessMetrics"))
        XCTAssertTrue(metricsSource.contains("UInt64(taskInfo.pti_total_user) &+ UInt64(taskInfo.pti_total_system)"))
        XCTAssertFalse(combinedSource.contains("pcpu=,rss="))
        XCTAssertFalse(combinedSource.contains("LocalAICommandLineParser.tokens(from: snapshot.commandLine)"))
    }

    func testCommandMetadataCachesVersionLookups() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let counterURL = directory.appendingPathComponent("count.txt")
        let executableURL = directory.appendingPathComponent("codex")
        let script = """
        #!/bin/sh
        count=0
        if [ -f "\(counterURL.path)" ]; then
          count=$(cat "\(counterURL.path)")
        fi
        count=$((count + 1))
        echo "$count" > "\(counterURL.path)"
        echo "codex 9.8.7"
        """
        try script.write(to: executableURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)

        let first = LocalAICommandMetadataReader.metadata(
            for: ["codex": executableURL.path],
            now: Date(timeIntervalSince1970: 100)
        )
        let second = LocalAICommandMetadataReader.metadata(
            for: ["codex": executableURL.path],
            now: Date(timeIntervalSince1970: 160)
        )

        XCTAssertEqual(first[.codex]?.version, "9.8.7")
        XCTAssertEqual(second[.codex]?.version, "9.8.7")
        XCTAssertEqual(try String(contentsOf: counterURL).trimmingCharacters(in: .whitespacesAndNewlines), "1")

        let expired = LocalAICommandMetadataReader.metadata(
            for: ["codex": executableURL.path],
            now: Date(timeIntervalSince1970: 401)
        )

        XCTAssertEqual(expired[.codex]?.version, "9.8.7")
        XCTAssertEqual(try String(contentsOf: counterURL).trimmingCharacters(in: .whitespacesAndNewlines), "2")
    }

    func testCommandMetadataCachesFailedVersionLookupsBriefly() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let executableURL = directory.appendingPathComponent("codex")
        try """
        #!/bin/sh
        exit 1
        """.write(to: executableURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)

        let failed = LocalAICommandMetadataReader.metadata(
            for: ["codex": executableURL.path],
            now: Date(timeIntervalSince1970: 100)
        )
        XCTAssertNil(failed[.codex])

        try """
        #!/bin/sh
        echo "codex 9.8.8"
        """.write(to: executableURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)

        let cachedFailure = LocalAICommandMetadataReader.metadata(
            for: ["codex": executableURL.path],
            now: Date(timeIntervalSince1970: 110)
        )
        XCTAssertNil(cachedFailure[.codex])

        let recovered = LocalAICommandMetadataReader.metadata(
            for: ["codex": executableURL.path],
            now: Date(timeIntervalSince1970: 116)
        )
        XCTAssertEqual(recovered[.codex]?.version, "9.8.8")
    }

    func testLocalCommandRunnerAvoidsDispatchWorkerWaitStorm() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let source = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Providers/LocalAI/Command/LocalCommandRunner.swift"))
        let snapshotSource = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Providers/LocalAI/ProcessSnapshot/LocalAIProcessSnapshotReader.swift"))

        XCTAssertTrue(source.contains("processLimit"))
        XCTAssertTrue(source.contains("process.terminationHandler"))
        XCTAssertTrue(source.contains("terminationSemaphore.wait"))
        XCTAssertTrue(source.contains("SIGKILL"))
        XCTAssertTrue(source.contains("readabilityHandler"))
        XCTAssertFalse(source.contains("DispatchQueue.global"))
        XCTAssertFalse(source.contains("waitUntilExit"))
        XCTAssertFalse(source.contains("readDataToEndOfFile"))
        XCTAssertTrue(snapshotSource.contains("LocalCommandRunner.output"))
        XCTAssertFalse(snapshotSource.contains("waitUntilExit"))
        XCTAssertFalse(snapshotSource.contains("readDataToEndOfFile"))
    }

    func testLocalCommandRunnerDrainsLargeOutputWhileProcessRuns() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let executableURL = directory.appendingPathComponent("large-output")
        let line = String(repeating: "x", count: 128)
        try """
        #!/bin/sh
        i=0
        while [ "$i" -lt 1200 ]; do
          printf '\(line)\\n'
          i=$((i + 1))
        done
        """.write(to: executableURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)

        let output = try XCTUnwrap(LocalCommandRunner.output(
            executablePath: executableURL.path,
            arguments: [],
            timeout: 2.0,
            maximumOutputBytes: 256 * 1024
        ))
        XCTAssertGreaterThan(output.utf8.count, 64 * 1024)
    }

    func testLocalCommandRunnerStopsProcessWhenCancelled() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let executableURL = directory.appendingPathComponent("slow-output")
        try """
        #!/bin/sh
        sleep 5
        echo done
        """.write(to: executableURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)

        let startedAt = Date()
        let output = LocalCommandRunner.output(
            executablePath: executableURL.path,
            arguments: [],
            timeout: 5.0,
            shouldCancel: {
                Date().timeIntervalSince(startedAt) > 0.1
            }
        )

        XCTAssertNil(output)
        XCTAssertLessThan(Date().timeIntervalSince(startedAt), 1.5)
    }

    func testDetectedProcessAndOpenAIConfigMapping() {
        let statuses = LocalAIStatusProvider.statuses(
            environment: ["OPENAI_API_KEY": "set"],
            processNames: ["codex", "/opt/homebrew/bin/ollama"],
            installedExecutableNames: ["codex", "ollama"]
        )

        XCTAssertEqual(statuses.map(\.kind), [.codex, .ollama, .openAI])
        XCTAssertEqual(statuses.first { $0.kind == .codex }?.value, "Running")
        XCTAssertEqual(statuses.first { $0.kind == .codex }?.state, .normal)
        XCTAssertEqual(statuses.first { $0.kind == .codex }?.processSummary.processCount, 1)
        XCTAssertEqual(statuses.first { $0.kind == .ollama }?.value, "Running")
        XCTAssertEqual(statuses.first { $0.kind == .ollama }?.state, .normal)
        XCTAssertEqual(statuses.first { $0.kind == .ollama }?.processSummary.processCount, 1)
        XCTAssertEqual(statuses.first { $0.kind == .openAI }?.value, "Configured")
        XCTAssertEqual(statuses.first { $0.kind == .openAI }?.state, .normal)
    }

    func testRunningProcessesAggregateMetricsWithoutActiveState() throws {
        let statuses = LocalAIStatusProvider.statuses(
            environment: [:],
            processNames: [],
            processCommands: [
                "/opt/homebrew/bin/codex --model gpt-5.2",
                "/opt/homebrew/bin/codex"
            ],
            processSnapshots: [
                LocalAIProcessSnapshot(
                    processID: 100,
                    executableName: "codex",
                    cpuPercent: 12.5,
                    memoryBytes: 150 * 1024 * 1024,
                    commandLine: "/opt/homebrew/bin/codex --model gpt-5.2"
                ),
                LocalAIProcessSnapshot(
                    processID: 101,
                    executableName: "codex",
                    cpuPercent: 0.4,
                    memoryBytes: 50 * 1024 * 1024,
                    commandLine: "/opt/homebrew/bin/codex"
                )
            ],
            installedExecutableNames: ["codex"]
        )

        let codex = try XCTUnwrap(statuses.first { $0.kind == .codex })
        XCTAssertEqual(codex.value, "Running")
        XCTAssertEqual(codex.state, .normal)
        XCTAssertEqual(codex.processSummary.processCount, 2)
        XCTAssertEqual(codex.processSummary.cpuPercent, 12.9, accuracy: 0.001)
        XCTAssertEqual(codex.processSummary.memoryBytes, 200 * 1024 * 1024)
        XCTAssertEqual(codex.processSummary.processes.map(\.processID), [100, 101])
    }

    func testClaudeAntigravityOllamaAndOpenAIModelMetadataMapping() {
        let statuses = LocalAIStatusProvider.statuses(
            environment: [
                "OPENAI_API_KEY": "secret",
                "OPENAI_MODEL": "gpt-5.2"
            ],
            processNames: [],
            processCommands: [
                "/opt/homebrew/bin/claude --model claude-sonnet-4-5",
                "/opt/homebrew/bin/antigravity -m ag-pro",
                "/Users/me/.pencil/mcp/antigravity/out/mcp-server-darwin-arm64 --app antigravity"
            ],
            installedExecutableNames: ["claude", "antigravity", "ollama"],
            commandMetadata: [
                .claude: LocalAIToolMetadata(model: nil, version: "2.1.0", source: "Command"),
                .antigravity: LocalAIToolMetadata(model: nil, version: "0.6.1", source: "Command"),
                .ollama: LocalAIToolMetadata(model: nil, version: "0.12.0", source: "Command")
            ],
            ollamaRuntime: LocalOllamaRuntimeSummary(activeModel: "llama3.2:latest")
        )

        XCTAssertEqual(statuses.map(\.kind), [.claude, .antigravity, .ollama, .openAI])
        XCTAssertEqual(statuses.first { $0.kind == .claude }?.value, "Running")
        XCTAssertEqual(statuses.first { $0.kind == .claude }?.subtitle, "claude-sonnet-4-5")
        XCTAssertEqual(statuses.first { $0.kind == .claude }?.metadata.version, "2.1.0")
        XCTAssertEqual(statuses.first { $0.kind == .antigravity }?.subtitle, "ag-pro")
        XCTAssertEqual(statuses.first { $0.kind == .antigravity }?.metadata.model, "ag-pro")
        XCTAssertEqual(statuses.first { $0.kind == .ollama }?.subtitle, "llama3.2:latest")
        XCTAssertEqual(statuses.first { $0.kind == .ollama }?.metadata.version, "0.12.0")
        XCTAssertEqual(statuses.first { $0.kind == .openAI }?.title, "OpenAI API")
        XCTAssertEqual(statuses.first { $0.kind == .openAI }?.subtitle, "gpt-5.2")
    }

    func testInstalledToolsShowReadyWhenNoProcessIsRunning() {
        let statuses = LocalAIStatusProvider.statuses(
            environment: [:],
            processNames: [],
            installedExecutableNames: ["codex"]
        )

        XCTAssertEqual(statuses.map(\.kind), [.codex])
        XCTAssertEqual(statuses.first { $0.kind == .codex }?.value, "Ready")
        XCTAssertEqual(statuses.first { $0.kind == .codex }?.subtitle, "Ready locally")
        XCTAssertEqual(statuses.first { $0.kind == .codex }?.state, .normal)
    }

    func testCommandLineDetectionHandlesQuotedExecutablePaths() {
        let statuses = LocalAIStatusProvider.statuses(
            environment: [:],
            processNames: [],
            processCommands: ["\"/Applications/AI Tools/claude\" --model claude-opus-4-1"],
            installedExecutableNames: ["claude"]
        )

        XCTAssertEqual(statuses.map(\.kind), [.claude])
        XCTAssertEqual(statuses.first?.value, "Running")
        XCTAssertEqual(statuses.first?.subtitle, "claude-opus-4-1")
    }

    func testCommandLineDetectionHandlesEnvWrapper() {
        let statuses = LocalAIStatusProvider.statuses(
            environment: [:],
            processNames: [],
            processCommands: [
                "/usr/bin/env ANTIGRAVITY_HOME=/tmp /opt/homebrew/bin/antigravity -m ag-pro",
                "/Users/me/.pencil/mcp/antigravity/out/mcp-server-darwin-arm64 --app antigravity"
            ],
            installedExecutableNames: ["antigravity"]
        )

        XCTAssertEqual(statuses.map(\.kind), [.antigravity])
        XCTAssertEqual(statuses.first?.value, "Running")
        XCTAssertEqual(statuses.first?.subtitle, "ag-pro")
        XCTAssertEqual(statuses.first?.metadata.model, "ag-pro")
    }

    func testAntigravityCliAliasUsesProcessMetadataOnly() {
        let statuses = LocalAIStatusProvider.statuses(
            environment: [:],
            processNames: [],
            processCommands: ["/opt/homebrew/bin/antigravity-cli --model ag-lite"],
            installedExecutableNames: ["antigravity-cli"]
        )

        XCTAssertEqual(statuses.map(\.kind), [.antigravity])
        XCTAssertEqual(statuses.first?.value, "Running")
        XCTAssertEqual(statuses.first?.state, .normal)
        XCTAssertEqual(statuses.first?.subtitle, "ag-lite")
        XCTAssertEqual(statuses.first?.metadata.model, "ag-lite")
    }

    func testAgyExecutableAliasIsDetected() {
        let statuses = LocalAIStatusProvider.statuses(
            environment: [:],
            processNames: ["agy"],
            processCommands: [],
            installedExecutableNames: ["agy"]
        )

        XCTAssertEqual(statuses.map(\.kind), [.antigravity])
        XCTAssertEqual(statuses.first?.title, "Antigravity")
        XCTAssertEqual(statuses.first?.value, "Running")
        XCTAssertEqual(statuses.first?.subtitle, "Local process")
    }

    func testAntigravityInstalledAppUsesLocalProcessStateOnly() {
        let statuses = LocalAIStatusProvider.statuses(
            environment: [:],
            processNames: ["Antigravity"],
            processCommands: [
                "/Applications/Antigravity.app/Contents/MacOS/Antigravity",
                "/Users/me/.pencil/mcp/antigravity/out/mcp-server-darwin-arm64 --app antigravity"
            ],
            installedExecutableNames: [],
            installedApplicationNames: ["Antigravity"]
        )

        XCTAssertEqual(statuses.map(\.kind), [.antigravity])
        XCTAssertEqual(statuses.first?.value, "Running")
        XCTAssertEqual(statuses.first?.subtitle, "Local process")
    }

    func testAntigravityIDEInstalledAppUsesLocalProcessStateOnly() {
        let statuses = LocalAIStatusProvider.statuses(
            environment: [:],
            processNames: ["Antigravity IDE"],
            processCommands: [
                "/Applications/Antigravity IDE.app/Contents/MacOS/Antigravity IDE"
            ],
            installedExecutableNames: [],
            installedApplicationNames: ["Antigravity IDE"]
        )

        XCTAssertEqual(statuses.map(\.kind), [.antigravity])
        XCTAssertEqual(statuses.first?.value, "Running")
        XCTAssertEqual(statuses.first?.subtitle, "Local process")
    }

    func testAntigravityMCPServerOnlyDoesNotMarkAppActive() {
        let statuses = LocalAIStatusProvider.statuses(
            environment: [:],
            processNames: [],
            processCommands: [
                "/Users/me/.pencil/mcp/antigravity/out/mcp-server-darwin-arm64 --app antigravity"
            ],
            installedExecutableNames: [],
            installedApplicationNames: ["Antigravity"]
        )

        XCTAssertEqual(statuses.map(\.kind), [.antigravity])
        XCTAssertEqual(statuses.first?.value, "Ready")
        XCTAssertEqual(statuses.first?.subtitle, "Ready locally")
    }

    func testRunningCommandIsShownWhenToolIsNotInSpillPath() {
        let statuses = LocalAIStatusProvider.statuses(
            environment: [:],
            processNames: [],
            processCommands: ["/opt/homebrew/bin/claude --model claude-opus-4-1"],
            installedExecutableNames: []
        )

        XCTAssertEqual(statuses.map(\.kind), [.claude])
        XCTAssertEqual(statuses.first?.value, "Running")
    }

    func testCommandLineDetectionDoesNotMatchExecutableOnlyFromArguments() {
        let statuses = LocalAIStatusProvider.statuses(
            environment: [:],
            processNames: [],
            processCommands: ["/usr/bin/python3 /tmp/codex --model fake-model"],
            installedExecutableNames: ["codex"]
        )

        XCTAssertEqual(statuses.map(\.kind), [.codex])
        XCTAssertEqual(statuses.first?.value, "Ready")
        XCTAssertEqual(statuses.first?.subtitle, "Ready locally")
    }

    func testMissingToolsAreHidden() {
        let statuses = LocalAIStatusProvider.statuses(
            environment: [:],
            processNames: [],
            installedExecutableNames: []
        )

        XCTAssertEqual(statuses, [])
    }

    func testStatusItemMappingDoesNotExposeSecretValue() {
        let item = LocalAIStatusProvider.statuses(
            environment: ["OPENAI_API_KEY": "secret"],
            processNames: [],
            installedExecutableNames: []
        )
        .first { $0.kind == .openAI }!
        .statusItem

        XCTAssertEqual(item.id, "openAI")
        XCTAssertEqual(item.providerID.rawValue, "ai")
        XCTAssertEqual(item.title, "OpenAI API")
        XCTAssertEqual(item.value, "Configured")
        XCTAssertEqual(item.subtitle, "API key/base URL")
        XCTAssertEqual(item.symbolName, "key.fill")
    }

    func testActionRecommendationsDescribeNextStepWithoutCopyCommands() {
        let codex = LocalAIToolStatus(
            kind: .codex,
            value: "Ready",
            subtitle: "Ready locally",
            state: .normal
        )
        let ollama = LocalAIToolStatus(
            kind: .ollama,
            value: "Running",
            subtitle: "Local process",
            state: .normal,
            processSummary: LocalAIProcessSummary(
                processes: [
                    LocalAIProcessSnapshot(
                        processID: 123,
                        executableName: "ollama",
                        cpuPercent: 0.2,
                        memoryBytes: 10 * 1024 * 1024
                    )
                ]
            )
        )

        XCTAssertEqual(codex.actionRecommendation?.title, "Start from terminal")
        XCTAssertEqual(codex.actionRecommendation?.detail, "Launch it from your terminal when you need a new session.")
        XCTAssertEqual(ollama.actionRecommendation?.title, "Inspect local models")
        XCTAssertEqual(ollama.actionRecommendation?.detail, "Ollama is running locally.")
    }

    func testOpenAIActionRecommendationDoesNotExposeSecretValues() {
        let openAI = LocalAIStatusProvider.statuses(
            environment: ["OPENAI_API_KEY": "secret"],
            processNames: [],
            installedExecutableNames: []
        )
        .first { $0.kind == .openAI }

        XCTAssertEqual(openAI?.actionRecommendation?.title, "Use configured API")
        XCTAssertEqual(openAI?.actionRecommendation?.detail, "OpenAI configuration is available; secret values stay hidden.")
    }

    func testUnavailableAIStatusDoesNotExposeActionRecommendation() {
        let unavailable = LocalAIToolStatus(
            kind: .codex,
            value: "N/A",
            subtitle: nil,
            state: .unavailable
        )

        XCTAssertNil(unavailable.actionRecommendation)
    }
}
