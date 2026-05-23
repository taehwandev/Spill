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
            discoveredLabels: ["Spill", "OpenAI API Set"]
        )

        XCTAssertFalse(report.isValid)
        XCTAssertEqual(report.missingLabels, ["AI", "WINDOWS"])
        XCTAssertTrue(report.logLine.contains("missing=AI,WINDOWS"))
    }

    func testRequiredLabelMatchesTokenBoundaryInsideCombinedLabel() {
        let report = SpillPanelAccessibilityReport(
            requiredLabels: ["AI"],
            discoveredLabels: ["AI Codex Active Claude Active Antigravity Idle Ollama Active OpenAI API Set"]
        )

        XCTAssertTrue(report.isValid)
    }
}
