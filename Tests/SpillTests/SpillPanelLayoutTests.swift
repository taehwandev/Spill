import AppKit
import XCTest
@testable import Spill

@MainActor
final class SpillPanelLayoutTests: XCTestCase {
    func testDefaultFrameUsesAnchorXWhenAvailable() {
        let layout = SpillPanelLayout()
        let visibleFrame = NSRect(x: 0, y: 0, width: 1_440, height: 900)
        let anchorFrame = NSRect(x: 720, y: 875, width: 26, height: 22)

        let frame = layout.defaultFrame(in: visibleFrame, screen: nil, anchorFrame: anchorFrame)

        XCTAssertEqual(frame.midX, anchorFrame.midX, accuracy: 0.001)
        XCTAssertEqual(frame.maxY, anchorFrame.minY - 8, accuracy: 0.001)
    }

    func testDefaultFrameClampsAnchoredPanelToRightEdge() {
        let layout = SpillPanelLayout()
        let visibleFrame = NSRect(x: 0, y: 0, width: 1_440, height: 900)
        let anchorFrame = NSRect(x: 1_428, y: 875, width: 12, height: 22)

        let frame = layout.defaultFrame(in: visibleFrame, screen: nil, anchorFrame: anchorFrame)

        XCTAssertEqual(frame.maxX, visibleFrame.maxX - SpillPanelMetrics.edgeInset, accuracy: 0.001)
        XCTAssertEqual(frame.maxY, anchorFrame.minY - 8, accuracy: 0.001)
    }

    func testDefaultFrameIgnoresAnchorOutsideMenuBarArea() {
        let layout = SpillPanelLayout()
        let visibleFrame = NSRect(x: 0, y: 0, width: 1_440, height: 900)
        let anchorFrame = NSRect(x: 1_180, y: 180, width: 26, height: 22)

        let fallbackFrame = layout.defaultFrame(in: visibleFrame, screen: nil)
        let frame = layout.defaultFrame(in: visibleFrame, screen: nil, anchorFrame: anchorFrame)

        XCTAssertEqual(frame.minX, fallbackFrame.minX, accuracy: 0.001)
        XCTAssertEqual(frame.minY, fallbackFrame.minY, accuracy: 0.001)
        XCTAssertEqual(frame.width, fallbackFrame.width, accuracy: 0.001)
        XCTAssertEqual(frame.height, fallbackFrame.height, accuracy: 0.001)
    }

    func testDefaultFrameClampsHeightToVisibleFrame() {
        let layout = SpillPanelLayout()
        let visibleFrame = NSRect(x: 0, y: 0, width: 900, height: 560)

        let frame = layout.defaultFrame(in: visibleFrame, screen: nil)

        XCTAssertEqual(frame.height, visibleFrame.height - SpillPanelMetrics.edgeInset * 2, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(frame.minY, visibleFrame.minY + SpillPanelMetrics.edgeInset - 0.001)
        XCTAssertLessThanOrEqual(frame.maxY, visibleFrame.maxY - SpillPanelMetrics.edgeInset + 0.001)
    }

    func testDefaultFrameUsesPreferredContentSize() {
        let layout = SpillPanelLayout()
        let visibleFrame = NSRect(x: 0, y: 0, width: 1_440, height: 900)
        let preferredSize = NSSize(width: 560, height: 480)

        let frame = layout.defaultFrame(in: visibleFrame, screen: nil, preferredSize: preferredSize)

        XCTAssertEqual(frame.width, preferredSize.width, accuracy: 0.001)
        XCTAssertEqual(frame.height, preferredSize.height, accuracy: 0.001)
    }

    func testContentSizerExpandsForAdditionalRows() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 1_440, height: 900)
        let compactSize = SpillPanelContentSizer.preferredSize(
            statusModuleCount: 0,
            aiStatusCount: 0,
            windowActionCount: 6,
            menuBarActionCount: 0,
            iconSpacing: 8,
            visibleFrame: visibleFrame
        )
        let expandedSize = SpillPanelContentSizer.preferredSize(
            statusModuleCount: 3,
            aiStatusCount: 3,
            windowActionCount: 10,
            menuBarActionCount: 18,
            iconSpacing: 8,
            visibleFrame: visibleFrame
        )

        XCTAssertGreaterThan(expandedSize.height, compactSize.height)
        XCTAssertLessThanOrEqual(expandedSize.height, visibleFrame.height - SpillPanelMetrics.edgeInset * 2)
    }

    func testContentSizerDoesNotReserveHeightForEmptyAISection() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 1_440, height: 900)
        let sizeWithoutAI = SpillPanelContentSizer.preferredSize(
            statusModuleCount: 0,
            aiStatusCount: 0,
            windowActionCount: 6,
            menuBarActionCount: 0,
            iconSpacing: 8,
            visibleFrame: visibleFrame
        )
        let sizeWithAI = SpillPanelContentSizer.preferredSize(
            statusModuleCount: 0,
            aiStatusCount: 3,
            windowActionCount: 6,
            menuBarActionCount: 0,
            iconSpacing: 8,
            visibleFrame: visibleFrame
        )

        XCTAssertGreaterThan(sizeWithAI.height, sizeWithoutAI.height)
    }

    func testContentSizerWrapsAIStatusesIntoReadableRows() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 1_440, height: 900)
        let oneStatus = SpillPanelContentSizer.preferredSize(
            statusModuleCount: 0,
            aiStatusCount: 1,
            windowActionCount: 6,
            menuBarActionCount: 0,
            iconSpacing: 8,
            visibleFrame: visibleFrame
        )
        let twoStatuses = SpillPanelContentSizer.preferredSize(
            statusModuleCount: 0,
            aiStatusCount: 2,
            windowActionCount: 6,
            menuBarActionCount: 0,
            iconSpacing: 8,
            visibleFrame: visibleFrame
        )
        let threeStatuses = SpillPanelContentSizer.preferredSize(
            statusModuleCount: 0,
            aiStatusCount: 3,
            windowActionCount: 6,
            menuBarActionCount: 0,
            iconSpacing: 8,
            visibleFrame: visibleFrame
        )
        let fiveStatuses = SpillPanelContentSizer.preferredSize(
            statusModuleCount: 0,
            aiStatusCount: 5,
            windowActionCount: 6,
            menuBarActionCount: 0,
            iconSpacing: 8,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(oneStatus.height, twoStatuses.height)
        XCTAssertGreaterThan(threeStatuses.height, twoStatuses.height)
        XCTAssertGreaterThan(fiveStatuses.height, twoStatuses.height)
        XCTAssertLessThanOrEqual(fiveStatuses.height, visibleFrame.height - SpillPanelMetrics.edgeInset * 2)
    }

    func testContentSizerExpandsForUpdateBannerOnlyWhenVisible() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 1_440, height: 900)
        let sizeWithoutUpdate = SpillPanelContentSizer.preferredSize(
            statusModuleCount: 2,
            aiStatusCount: 0,
            windowActionCount: 6,
            menuBarActionCount: 4,
            iconSpacing: 8,
            visibleFrame: visibleFrame
        )
        let sizeWithUpdate = SpillPanelContentSizer.preferredSize(
            statusModuleCount: 2,
            aiStatusCount: 0,
            windowActionCount: 6,
            menuBarActionCount: 4,
            iconSpacing: 8,
            visibleFrame: visibleFrame,
            showsUpdateBanner: true
        )

        XCTAssertGreaterThan(sizeWithUpdate.height, sizeWithoutUpdate.height)
        XCTAssertLessThanOrEqual(sizeWithUpdate.height, visibleFrame.height - SpillPanelMetrics.edgeInset * 2)
    }
}
