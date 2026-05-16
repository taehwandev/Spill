import XCTest
@testable import Spill

final class SpillPanelContentReportTests: XCTestCase {
    func testValidContentReportAcceptsPanelWithInlineActionState() {
        let report = SpillPanelContentReport(
            isVisible: true,
            panelState: .permissionRequired,
            statusModuleIDs: ["cpu", "memory"],
            statusDetailRowCount: 10,
            aiStatusCount: LocalAIToolKind.allCases.count,
            aiDetailRowCount: 6,
            windowActionCount: 0,
            menuBarActionCount: 0,
            footerItemCount: 5,
            showsPowerFooter: true,
            showsCountBadge: true
        )

        XCTAssertTrue(report.isValid)
        XCTAssertTrue(report.logLine.contains("state=permissionRequired"))
        XCTAssertTrue(report.logLine.contains("statusModules=cpu,memory"))
    }

    func testReadyPanelRequiresAnActionSurface() {
        let report = SpillPanelContentReport(
            isVisible: true,
            panelState: .ready,
            statusModuleIDs: [],
            statusDetailRowCount: 0,
            aiStatusCount: LocalAIToolKind.allCases.count,
            aiDetailRowCount: 6,
            windowActionCount: 0,
            menuBarActionCount: 0,
            footerItemCount: 5,
            showsPowerFooter: true,
            showsCountBadge: true
        )

        XCTAssertFalse(report.isValid)
        XCTAssertTrue(report.logLine.contains("actionSurface=false"))
    }

    func testContentReportRequiresAllAIStatuses() {
        let report = SpillPanelContentReport(
            isVisible: true,
            panelState: .empty,
            statusModuleIDs: ["cpu"],
            statusDetailRowCount: 8,
            aiStatusCount: LocalAIToolKind.allCases.count - 1,
            aiDetailRowCount: 4,
            windowActionCount: 0,
            menuBarActionCount: 0,
            footerItemCount: 5,
            showsPowerFooter: true,
            showsCountBadge: true
        )

        XCTAssertFalse(report.isValid)
        XCTAssertTrue(report.logLine.contains("aiContent=false"))
    }
}
