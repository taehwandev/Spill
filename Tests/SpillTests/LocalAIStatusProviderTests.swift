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
        XCTAssertEqual(statuses.first { $0.kind == .codex }?.value, "Active")
        XCTAssertEqual(statuses.first { $0.kind == .codex }?.state, .active)
        XCTAssertEqual(statuses.first { $0.kind == .ollama }?.value, "Active")
        XCTAssertEqual(statuses.first { $0.kind == .ollama }?.state, .active)
        XCTAssertEqual(statuses.first { $0.kind == .openAI }?.value, "Set")
        XCTAssertEqual(statuses.first { $0.kind == .openAI }?.state, .normal)
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
                "/opt/homebrew/bin/antigravity -m ag-pro"
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
        XCTAssertEqual(statuses.first { $0.kind == .claude }?.value, "Active")
        XCTAssertEqual(statuses.first { $0.kind == .claude }?.subtitle, "claude-sonnet-4-5")
        XCTAssertEqual(statuses.first { $0.kind == .claude }?.metadata.version, "2.1.0")
        XCTAssertEqual(statuses.first { $0.kind == .antigravity }?.subtitle, "ag-pro")
        XCTAssertEqual(statuses.first { $0.kind == .ollama }?.subtitle, "llama3.2:latest")
        XCTAssertEqual(statuses.first { $0.kind == .ollama }?.metadata.version, "0.12.0")
        XCTAssertEqual(statuses.first { $0.kind == .openAI }?.title, "OpenAI API")
        XCTAssertEqual(statuses.first { $0.kind == .openAI }?.subtitle, "gpt-5.2")
    }

    func testInstalledToolsAreIdleWhenNoProcessIsRunning() {
        let statuses = LocalAIStatusProvider.statuses(
            environment: [:],
            processNames: [],
            installedExecutableNames: ["codex"]
        )

        XCTAssertEqual(statuses.map(\.kind), [.codex])
        XCTAssertEqual(statuses.first { $0.kind == .codex }?.value, "Idle")
        XCTAssertEqual(statuses.first { $0.kind == .codex }?.subtitle, "Installed")
        XCTAssertEqual(statuses.first { $0.kind == .codex }?.state, .normal)
    }

    func testCommandLineDetectionHandlesQuotedExecutablePaths() {
        let statuses = LocalAIStatusProvider.statuses(
            environment: [:],
            processNames: [],
            processCommands: ["\"/Applications/AI Tools/claude\" --model claude-opus-4-1"],
            installedExecutableNames: []
        )

        XCTAssertEqual(statuses.map(\.kind), [.claude])
        XCTAssertEqual(statuses.first?.value, "Active")
        XCTAssertEqual(statuses.first?.subtitle, "claude-opus-4-1")
    }

    func testCommandLineDetectionHandlesEnvWrapper() {
        let statuses = LocalAIStatusProvider.statuses(
            environment: [:],
            processNames: [],
            processCommands: ["/usr/bin/env ANTIGRAVITY_HOME=/tmp /opt/homebrew/bin/antigravity -m ag-pro"],
            installedExecutableNames: []
        )

        XCTAssertEqual(statuses.map(\.kind), [.antigravity])
        XCTAssertEqual(statuses.first?.value, "Active")
        XCTAssertEqual(statuses.first?.subtitle, "ag-pro")
    }

    func testAntigravityCliAliasIsDetected() {
        let statuses = LocalAIStatusProvider.statuses(
            environment: [:],
            processNames: [],
            processCommands: ["/opt/homebrew/bin/antigravity-cli --model ag-lite"],
            installedExecutableNames: []
        )

        XCTAssertEqual(statuses.map(\.kind), [.antigravity])
        XCTAssertEqual(statuses.first?.value, "Active")
        XCTAssertEqual(statuses.first?.subtitle, "ag-lite")
    }

    func testCommandLineDetectionDoesNotMatchExecutableOnlyFromArguments() {
        let statuses = LocalAIStatusProvider.statuses(
            environment: [:],
            processNames: [],
            processCommands: ["/usr/bin/python3 /tmp/codex --model fake-model"],
            installedExecutableNames: ["codex"]
        )

        XCTAssertEqual(statuses.map(\.kind), [.codex])
        XCTAssertEqual(statuses.first?.value, "Idle")
        XCTAssertEqual(statuses.first?.subtitle, "Installed")
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
        XCTAssertEqual(item.value, "Set")
        XCTAssertEqual(item.subtitle, "Configured")
        XCTAssertEqual(item.symbolName, "key.fill")
    }
}
