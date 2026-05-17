import XCTest
@testable import Spill

final class SpillPanelAccessibilityReportTests: XCTestCase {
    func testValidReportAcceptsRequiredLabels() {
        let report = SpillPanelAccessibilityReport(
            requiredLabels: ["Spill", "AI", "Caffeine Off"],
            discoveredLabels: [
                "Spill",
                "AI",
                "Caffeine Off",
                "Codex Missing"
            ]
        )

        XCTAssertTrue(report.isValid)
        XCTAssertEqual(report.missingLabels, [])
        XCTAssertTrue(report.logLine.contains("valid=true"))
        XCTAssertTrue(report.logLine.contains("required=Spill,AI,Caffeine_Off"))
    }

    func testReportFailsWhenRequiredLabelIsMissing() {
        let report = SpillPanelAccessibilityReport(
            requiredLabels: ["Spill", "AI", "WINDOWS"],
            discoveredLabels: ["Spill", "OpenAI Missing"]
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
