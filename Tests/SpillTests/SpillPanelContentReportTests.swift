import XCTest
@testable import Spill

final class SpillPanelContentReportTests: XCTestCase {
    func testValidContentReportAcceptsPanelWithoutFocusedWindow() {
        let report = SpillPanelContentReport(
            isVisible: true,
            statusModuleIDs: ["cpu", "memory"],
            statusDetailRowCount: 10,
            aiStatusCount: 0,
            aiDetailRowCount: 0,
            windowActionCount: 0,
            footerItemCount: 5,
            showsPowerFooter: true
        )

        XCTAssertTrue(report.isValid)
        XCTAssertTrue(report.logLine.contains("statusModules=cpu,memory"))
    }

    func testPanelDoesNotRequireWindowActionsOrAccessibility() {
        let report = SpillPanelContentReport(
            isVisible: true,
            statusModuleIDs: [],
            statusDetailRowCount: 0,
            aiStatusCount: 0,
            aiDetailRowCount: 0,
            windowActionCount: 0,
            footerItemCount: 5,
            showsPowerFooter: true
        )

        XCTAssertTrue(report.isValid)
    }

    func testContentReportAllowsSubsetAIStatuses() {
        let report = SpillPanelContentReport(
            isVisible: true,
            statusModuleIDs: ["cpu"],
            statusDetailRowCount: 8,
            aiStatusCount: 1,
            aiDetailRowCount: 2,
            windowActionCount: 0,
            footerItemCount: 5,
            showsPowerFooter: true
        )

        XCTAssertTrue(report.isValid)
        XCTAssertTrue(report.logLine.contains("aiContent=true"))
    }

    func testContentReportRejectsImpossibleAIStatusCount() {
        let report = SpillPanelContentReport(
            isVisible: true,
            statusModuleIDs: ["cpu"],
            statusDetailRowCount: 8,
            aiStatusCount: LocalAIToolKind.allCases.count + 1,
            aiDetailRowCount: 4,
            windowActionCount: 0,
            footerItemCount: 5,
            showsPowerFooter: true
        )

        XCTAssertFalse(report.isValid)
        XCTAssertTrue(report.logLine.contains("aiContent=false"))
    }
}
