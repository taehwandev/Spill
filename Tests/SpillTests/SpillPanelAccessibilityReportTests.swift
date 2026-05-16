import XCTest
@testable import Spill

final class SpillPanelAccessibilityReportTests: XCTestCase {
    func testValidReportAcceptsRequiredLabels() {
        let report = SpillPanelAccessibilityReport(
            requiredLabels: ["Spill Flow", "AI", "Sleep Guard Off"],
            discoveredLabels: [
                "Spill Flow",
                "AI",
                "Sleep Guard Off",
                "Codex Missing"
            ]
        )

        XCTAssertTrue(report.isValid)
        XCTAssertEqual(report.missingLabels, [])
        XCTAssertTrue(report.logLine.contains("valid=true"))
        XCTAssertTrue(report.logLine.contains("required=Spill_Flow,AI,Sleep_Guard_Off"))
    }

    func testReportFailsWhenRequiredLabelIsMissing() {
        let report = SpillPanelAccessibilityReport(
            requiredLabels: ["Spill Flow", "AI", "WINDOWS"],
            discoveredLabels: ["Spill Flow", "OpenAI Missing"]
        )

        XCTAssertFalse(report.isValid)
        XCTAssertEqual(report.missingLabels, ["AI", "WINDOWS"])
        XCTAssertTrue(report.logLine.contains("missing=AI,WINDOWS"))
    }

    func testRequiredLabelMatchesTokenBoundaryInsideCombinedLabel() {
        let report = SpillPanelAccessibilityReport(
            requiredLabels: ["AI"],
            discoveredLabels: ["AI Codex Missing Ollama Missing OpenAI Configured"]
        )

        XCTAssertTrue(report.isValid)
    }
}
