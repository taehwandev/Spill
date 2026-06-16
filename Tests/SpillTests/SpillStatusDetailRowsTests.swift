import XCTest
@testable import Spill

final class SpillStatusDetailRowsTests: XCTestCase {
    func testAIRowsDoNotExposeMenuBarSummary() {
        let rows = SpillStatusDetailRows.rows(
            for: LocalAIToolStatus(
                kind: .codex,
                value: "Live",
                subtitle: "Process Found",
                state: .normal
            )
        )

        XCTAssertEqual(rows.map(\.label), ["Status", "Detail", "Processes", "Next"])
        XCTAssertEqual(rows.map(\.value), ["Live", "Process Found", "0", "Start from terminal"])
    }

    func testAIRowsIncludeSafeModelAndVersionMetadata() {
        let rows = SpillStatusDetailRows.rows(
            for: LocalAIToolStatus(
                kind: .ollama,
                value: "Running",
                subtitle: "llama3.2:latest",
                state: .normal,
                metadata: LocalAIToolMetadata(
                    model: "llama3.2:latest",
                    version: "0.12.0",
                    source: "Ollama Runtime"
                ),
                processSummary: LocalAIProcessSummary(
                    processes: [
                        LocalAIProcessSnapshot(
                            processID: 42,
                            executableName: "ollama",
                            cpuPercent: 2.4,
                            memoryBytes: 64 * 1024 * 1024,
                            commandLine: "/usr/local/bin/ollama serve --private-path"
                        )
                    ]
                )
            )
        )

        XCTAssertEqual(rows.map(\.label), ["Status", "Detail", "Processes", "CPU", "Memory", "Process 42", "Next", "Model", "Version", "Source"])
        XCTAssertEqual(rows.map(\.value), [
            "Running",
            "llama3.2:latest",
            "1",
            "2.4%",
            "0.1 GB",
            "ollama / CPU 2.4% / 0.1 GB",
            "Inspect local models",
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

        XCTAssertEqual(rows.map(\.label), ["Status", "Detail", "Processes", "Next"])
        XCTAssertEqual(rows.map(\.value), ["Configured", "API key/base URL", "0", "Use configured API"])
    }
}
