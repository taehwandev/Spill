import XCTest
@testable import Spill

final class SpillStatusDetailRowsTests: XCTestCase {
    func testAIRowsDoNotExposeMenuBarSummary() {
        let rows = SpillStatusDetailRows.rows(
            for: LocalAIToolStatus(
                kind: .codex,
                value: "Live",
                subtitle: "Process Found",
                state: .active
            )
        )

        XCTAssertEqual(rows.map(\.label), ["Status", "Detail", "Next", "Command"])
        XCTAssertEqual(rows.map(\.value), ["Live", "Process Found", "Continue in terminal", "codex"])
    }

    func testAIRowsIncludeSafeModelAndVersionMetadata() {
        let rows = SpillStatusDetailRows.rows(
            for: LocalAIToolStatus(
                kind: .ollama,
                value: "Running",
                subtitle: "llama3.2:latest",
                state: .active,
                metadata: LocalAIToolMetadata(
                    model: "llama3.2:latest",
                    version: "0.12.0",
                    source: "Ollama Runtime"
                )
            )
        )

        XCTAssertEqual(rows.map(\.label), ["Status", "Detail", "Next", "Command", "Model", "Version", "Source"])
        XCTAssertEqual(rows.map(\.value), [
            "Running",
            "llama3.2:latest",
            "Inspect local models",
            "ollama list",
            "llama3.2:latest",
            "0.12.0",
            "Ollama Runtime"
        ])
    }

    func testOpenAIDetailRowsDoNotExposeSecretCommand() {
        let rows = SpillStatusDetailRows.rows(
            for: LocalAIToolStatus(
                kind: .openAI,
                value: "Configured",
                subtitle: "API key/base URL",
                state: .normal
            )
        )

        XCTAssertEqual(rows.map(\.label), ["Status", "Detail", "Next"])
        XCTAssertEqual(rows.map(\.value), ["Configured", "API key/base URL", "Use configured API"])
    }
}
