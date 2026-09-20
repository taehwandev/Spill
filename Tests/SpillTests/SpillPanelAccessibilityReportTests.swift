import XCTest
@testable import Spill

final class SpillPanelAccessibilityReportTests: XCTestCase {
    func testDefaultReportRequiresVisibleAISection() {
        let report = SpillPanelAccessibilityReport(
            discoveredLabels: [
                "Spill",
                "WINDOWS",
                "AI",
                "Caffeine Off"
            ]
        )

        XCTAssertTrue(report.isValid)
        XCTAssertEqual(report.missingLabels, [])
    }

    func testDefaultReportRejectsMissingAISection() {
        let report = SpillPanelAccessibilityReport(
            discoveredLabels: ["Spill", "WINDOWS", "Caffeine Off"]
        )

        XCTAssertFalse(report.isValid)
        XCTAssertEqual(report.missingLabels, ["AI"])
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
            discoveredLabels: ["AI Codex Running Claude Running Antigravity Ready Ollama Running OpenAI API Configured"]
        )

        XCTAssertTrue(report.isValid)
    }
}
