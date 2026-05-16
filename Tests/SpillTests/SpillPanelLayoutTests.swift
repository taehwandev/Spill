import AppKit
import XCTest
@testable import Spill

@MainActor
final class SpillPanelLayoutTests: XCTestCase {
    func testDefaultFrameUsesAnchorXWhenAvailable() {
        let layout = SpillPanelLayout()
        let visibleFrame = NSRect(x: 0, y: 0, width: 1_440, height: 900)
        let anchorFrame = NSRect(x: 1_180, y: 875, width: 26, height: 22)

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
}
