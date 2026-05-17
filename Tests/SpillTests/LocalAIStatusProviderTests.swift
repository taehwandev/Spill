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

    func testClaudeGeminiOllamaAndOpenAIModelMetadataMapping() {
        let statuses = LocalAIStatusProvider.statuses(
            environment: [
                "OPENAI_API_KEY": "secret",
                "OPENAI_MODEL": "gpt-5.2"
            ],
            processNames: [],
            processCommands: [
                "/opt/homebrew/bin/claude --model claude-sonnet-4-5",
                "/opt/homebrew/bin/gemini -m gemini-2.5-pro"
            ],
            installedExecutableNames: ["claude", "gemini", "ollama"],
            commandMetadata: [
                .claude: LocalAIToolMetadata(model: nil, version: "2.1.0", source: "Command"),
                .gemini: LocalAIToolMetadata(model: nil, version: "0.6.1", source: "Command"),
                .ollama: LocalAIToolMetadata(model: nil, version: "0.12.0", source: "Command")
            ],
            ollamaRuntime: LocalOllamaRuntimeSummary(activeModel: "llama3.2:latest")
        )

        XCTAssertEqual(statuses.map(\.kind), [.claude, .gemini, .ollama, .openAI])
        XCTAssertEqual(statuses.first { $0.kind == .claude }?.value, "Active")
        XCTAssertEqual(statuses.first { $0.kind == .claude }?.subtitle, "claude-sonnet-4-5")
        XCTAssertEqual(statuses.first { $0.kind == .claude }?.metadata.version, "2.1.0")
        XCTAssertEqual(statuses.first { $0.kind == .gemini }?.subtitle, "gemini-2.5-pro")
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
