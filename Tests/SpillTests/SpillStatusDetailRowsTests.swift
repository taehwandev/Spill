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

        XCTAssertEqual(rows.map(\.label), ["Status", "Detail"])
        XCTAssertEqual(rows.map(\.value), ["Live", "Process Found"])
    }

    func testAIRowsIncludeSafeModelAndVersionMetadata() {
        let rows = SpillStatusDetailRows.rows(
            for: LocalAIToolStatus(
                kind: .ollama,
                value: "Active",
                subtitle: "llama3.2:latest",
                state: .active,
                metadata: LocalAIToolMetadata(
                    model: "llama3.2:latest",
                    version: "0.12.0",
                    source: "Ollama Runtime"
                )
            )
        )

        XCTAssertEqual(rows.map(\.label), ["Status", "Detail", "Model", "Version", "Source"])
        XCTAssertEqual(rows.map(\.value), ["Active", "llama3.2:latest", "llama3.2:latest", "0.12.0", "Ollama Runtime"])
    }
}
