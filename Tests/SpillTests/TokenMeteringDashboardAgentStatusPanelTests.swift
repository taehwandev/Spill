import XCTest
@testable import Spill

final class TokenMeteringDashboardAgentStatusPanelTests: XCTestCase {
    func testAgentStatusPanelKeepsSummaryAndGridWorkLocalToOneRenderPass() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let source = try String(
            contentsOf: root.appendingPathComponent("Sources/Spill/TokenMetering/TokenMeteringDashboardAgentStatusPanel.swift")
        )

        XCTAssertTrue(source.contains("private static let summaryColumns"))
        XCTAssertTrue(source.contains("let summary = TokenMeteringDashboardAgentStatusSummary.make(statuses: aiStatusStore.statuses)"))
        XCTAssertFalse(source.contains("private var summary: TokenMeteringDashboardAgentStatusSummary"))
        XCTAssertFalse(source.contains("private var summaryColumns: [GridItem]"))
    }

    func testAgentStatusSummaryCombinesMultipleAgentsWithProcessRows() throws {
        let statuses = [
            LocalAIToolStatus(
                kind: .codex,
                value: "Running",
                subtitle: "gpt-5.2",
                state: .normal,
                metadata: LocalAIToolMetadata(model: "gpt-5.2", version: "1.2.3", source: "Process Args"),
                processSummary: LocalAIProcessSummary(
                    processes: [
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
                    ]
                )
            ),
            LocalAIToolStatus(
                kind: .claude,
                value: "Ready",
                subtitle: "Ready locally",
                state: .normal,
                metadata: LocalAIToolMetadata(model: nil, version: "2.0.0", source: "Command")
            ),
            LocalAIToolStatus(
                kind: .antigravity,
                value: "Running",
                subtitle: "AGY IDE",
                state: .normal,
                processSummary: LocalAIProcessSummary(
                    processes: [
                        LocalAIProcessSnapshot(
                            processID: 200,
                            executableName: "antigravity",
                            cpuPercent: 3.0,
                            memoryBytes: 75 * 1024 * 1024,
                            commandLine: "/Applications/Antigravity.app/Contents/MacOS/antigravity"
                        )
                    ]
                )
            ),
            LocalAIToolStatus(
                kind: .ollama,
                value: "Running",
                subtitle: "llama3.2",
                state: .normal,
                processSummary: LocalAIProcessSummary(processes: [], fallbackProcessCount: 1)
            )
        ]
        let summary = TokenMeteringDashboardAgentStatusSummary.make(statuses: statuses)

        XCTAssertEqual(summary.detectedToolCount, 3)
        XCTAssertEqual(summary.runningToolCount, 2)
        XCTAssertEqual(summary.processCount, 3)
        XCTAssertEqual(summary.cpuText, "16%")
        XCTAssertEqual(summary.rows.map(\.kind), [.codex, .claude, .antigravity])

        let codex = try XCTUnwrap(summary.rows.first { $0.kind == .codex })
        XCTAssertEqual(codex.processRows.map(\.title), ["pid 100", "pid 101"])
        XCTAssertTrue(codex.processRows.allSatisfy { !$0.detail.contains("--model") })
        XCTAssertEqual(codex.metadataRows.map(\.value), ["gpt-5.2", "v1.2.3", "Process Args"])

        XCTAssertNil(summary.rows.first { $0.kind == .ollama })
    }

    func testAgentStatusRowsShowUnavailableMetricsAsUnavailable() throws {
        let statuses = [
            LocalAIToolStatus(
                kind: .codex,
                value: "Running",
                subtitle: "Local process",
                state: .normal,
                processSummary: LocalAIProcessSummary(
                    processes: [
                        LocalAIProcessSnapshot(
                            processID: 100,
                            executableName: "codex",
                            cpuPercent: 12.5,
                            memoryBytes: 150 * 1024 * 1024,
                            metricsAvailable: false,
                            commandLine: "/opt/homebrew/bin/codex"
                        )
                    ]
                )
            )
        ]

        let summary = TokenMeteringDashboardAgentStatusSummary.make(statuses: statuses)
        let codex = try XCTUnwrap(summary.rows.first { $0.kind == .codex })

        XCTAssertEqual(summary.cpuText, "N/A")
        XCTAssertEqual(summary.memoryText, "N/A")
        XCTAssertEqual(codex.cpuText, "N/A")
        XCTAssertEqual(codex.memoryText, "N/A")
        XCTAssertEqual(codex.processRows.first?.detail, "codex / CPU N/A / N/A")
    }
}
