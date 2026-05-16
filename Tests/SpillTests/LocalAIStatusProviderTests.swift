import XCTest
@testable import Spill

final class LocalAIStatusProviderTests: XCTestCase {
    func testDetectedProcessAndOpenAIConfigMapping() {
        let statuses = LocalAIStatusProvider.statuses(
            environment: ["OPENAI_API_KEY": "set"],
            processNames: ["codex", "/opt/homebrew/bin/ollama"]
        )

        XCTAssertEqual(statuses.first { $0.kind == .codex }?.value, "Live")
        XCTAssertEqual(statuses.first { $0.kind == .codex }?.state, .active)
        XCTAssertEqual(statuses.first { $0.kind == .ollama }?.value, "On")
        XCTAssertEqual(statuses.first { $0.kind == .ollama }?.state, .active)
        XCTAssertEqual(statuses.first { $0.kind == .openAI }?.value, "Set")
        XCTAssertEqual(statuses.first { $0.kind == .openAI }?.state, .normal)
    }

    func testMissingToolsAreQuietUnavailableStates() {
        let statuses = LocalAIStatusProvider.statuses(environment: [:], processNames: [])

        XCTAssertEqual(statuses.first { $0.kind == .codex }?.value, "Idle")
        XCTAssertEqual(statuses.first { $0.kind == .codex }?.state, .unavailable)
        XCTAssertEqual(statuses.first { $0.kind == .ollama }?.value, "Off")
        XCTAssertEqual(statuses.first { $0.kind == .ollama }?.state, .unavailable)
        XCTAssertEqual(statuses.first { $0.kind == .openAI }?.value, "Missing")
        XCTAssertEqual(statuses.first { $0.kind == .openAI }?.state, .unavailable)
    }

    func testStatusItemMappingDoesNotExposeSecretValue() {
        let item = LocalAIStatusProvider.statuses(
            environment: ["OPENAI_API_KEY": "secret"],
            processNames: []
        )
        .first { $0.kind == .openAI }!
        .statusItem

        XCTAssertEqual(item.id, "openAI")
        XCTAssertEqual(item.providerID.rawValue, "ai")
        XCTAssertEqual(item.title, "OpenAI")
        XCTAssertEqual(item.value, "Set")
        XCTAssertEqual(item.subtitle, "Configured")
        XCTAssertEqual(item.symbolName, "key.fill")
    }
}
