import XCTest
@testable import Spill

final class SpillPanelAccessibilityReportTests: XCTestCase {
    func testDefaultReportDoesNotRequireHiddenAISection() {
        let report = SpillPanelAccessibilityReport(
            discoveredLabels: [
                "Spill",
                "WINDOWS",
                "MENU BAR",
                "Caffeine Off"
            ]
        )

        XCTAssertTrue(report.isValid)
        XCTAssertEqual(report.missingLabels, [])
    }

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
            discoveredLabels: ["Spill", "OpenAI API Configured"]
        )

        XCTAssertFalse(report.isValid)
        XCTAssertEqual(report.missingLabels, ["AI", "WINDOWS"])
        XCTAssertTrue(report.logLine.contains("missing=AI,WINDOWS"))
    }

    func testRequiredLabelMatchesTokenBoundaryInsideCombinedLabel() {
        let report = SpillPanelAccessibilityReport(
            requiredLabels: ["AI"],
            discoveredLabels: ["AI Codex Running Claude Running Antigravity Installed Ollama Running OpenAI API Configured"]
        )

        XCTAssertTrue(report.isValid)
    }
}
