import XCTest
@testable import Spill

final class LocalAIStatusProviderTests: XCTestCase {
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

    func testRunningCommandIsHiddenWhenToolIsNotInstalled() {
        let statuses = LocalAIStatusProvider.statuses(
            environment: [:],
            processNames: [],
            processCommands: ["/opt/homebrew/bin/claude --model claude-opus-4-1"],
            installedExecutableNames: []
        )

        XCTAssertEqual(statuses, [])
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
