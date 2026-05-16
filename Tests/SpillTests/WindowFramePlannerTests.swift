import CoreGraphics
import XCTest
@testable import Spill

final class WindowFramePlannerTests: XCTestCase {
    func testLeftAndRightHalfFramesUseActiveVisibleFrame() {
        let snapshot = WindowFrameSnapshot(
            windowFrame: CGRect(x: 100, y: 100, width: 400, height: 300),
            visibleFrames: [CGRect(x: 0, y: 0, width: 1440, height: 900)]
        )

        XCTAssertEqual(
            WindowFramePlanner.targetFrame(for: .leftHalf, snapshot: snapshot, restoreFrame: nil),
            CGRect(x: 0, y: 0, width: 720, height: 900)
        )
        XCTAssertEqual(
            WindowFramePlanner.targetFrame(for: .rightHalf, snapshot: snapshot, restoreFrame: nil),
            CGRect(x: 720, y: 0, width: 720, height: 900)
        )
    }

    func testCenterPreservesCurrentSizeAndClampsToVisibleFrame() {
        let snapshot = WindowFrameSnapshot(
            windowFrame: CGRect(x: 50, y: 80, width: 1_600, height: 700),
            visibleFrames: [CGRect(x: 0, y: 0, width: 1_440, height: 900)]
        )

        XCTAssertEqual(
            WindowFramePlanner.targetFrame(for: .center, snapshot: snapshot, restoreFrame: nil),
            CGRect(x: 0, y: 100, width: 1_440, height: 700)
        )
    }

    func testMaximizeUsesVisibleFrame() {
        let visibleFrame = CGRect(x: 0, y: 24, width: 1440, height: 876)
        let snapshot = WindowFrameSnapshot(
            windowFrame: CGRect(x: 200, y: 300, width: 500, height: 400),
            visibleFrames: [visibleFrame]
        )

        XCTAssertEqual(
            WindowFramePlanner.targetFrame(for: .maximize, snapshot: snapshot, restoreFrame: nil),
            visibleFrame
        )
    }

    func testNextDisplayMovesWindowToNextVisibleFrame() {
        let snapshot = WindowFrameSnapshot(
            windowFrame: CGRect(x: 100, y: 100, width: 400, height: 300),
            visibleFrames: [
                CGRect(x: 0, y: 0, width: 1440, height: 900),
                CGRect(x: 1440, y: 0, width: 1280, height: 800)
            ]
        )

        XCTAssertEqual(
            WindowFramePlanner.targetFrame(for: .nextDisplay, snapshot: snapshot, restoreFrame: nil),
            CGRect(x: 1880, y: 250, width: 400, height: 300)
        )
    }

    func testRestoreUsesSavedFrame() {
        let restoreFrame = CGRect(x: 120, y: 160, width: 640, height: 480)
        let snapshot = WindowFrameSnapshot(
            windowFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrames: [CGRect(x: 0, y: 0, width: 1440, height: 900)]
        )

        XCTAssertEqual(
            WindowFramePlanner.targetFrame(for: .restore, snapshot: snapshot, restoreFrame: restoreFrame),
            restoreFrame
        )
    }
}
