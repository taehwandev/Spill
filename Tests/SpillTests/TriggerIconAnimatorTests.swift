import XCTest
@testable import Spill

@MainActor
final class TriggerIconAnimatorTests: XCTestCase {
    func testStartStopAreIdempotent() {
        let animator = TriggerIconAnimator.makeForTesting()
        defer { animator.stop() }

        animator.start()
        animator.start()

        XCTAssertTrue(animator.isRunningForTesting)
        XCTAssertTrue(animator.hasIdleTimerForTesting)
        XCTAssertFalse(animator.hasFrameTimerForTesting)

        animator.stop()
        animator.stop()

        XCTAssertFalse(animator.isRunningForTesting)
        XCTAssertFalse(animator.isBurstingForTesting)
        XCTAssertFalse(animator.hasIdleTimerForTesting)
        XCTAssertFalse(animator.hasFrameTimerForTesting)
        XCTAssertEqual(animator.phase, 0)
    }

    func testStopRedrawsAtRestWhenBurstIsMidFrame() {
        let animator = TriggerIconAnimator.makeForTesting()
        var frameCount = 0
        animator.onFrame = {
            frameCount += 1
        }
        defer { animator.stop() }

        animator.start()
        animator.startBurstForTesting()
        animator.advanceFrameForTesting()

        XCTAssertGreaterThan(animator.phase, 0)
        XCTAssertEqual(frameCount, 1)

        animator.stop()

        XCTAssertEqual(animator.phase, 0)
        XCTAssertEqual(frameCount, 2)
        XCTAssertFalse(animator.hasFrameTimerForTesting)
    }

    func testFirstUsageRatioAfterStartOnlySetsBaseline() {
        let animator = TriggerIconAnimator.makeForTesting()
        defer { animator.stop() }

        animator.start()
        animator.noteUsageRatio(0.95)

        XCTAssertFalse(animator.isBurstingForTesting)
        XCTAssertFalse(animator.hasFrameTimerForTesting)
    }

    func testUsageRatioJumpThresholdStartsBurst() {
        let animator = TriggerIconAnimator.makeForTesting()
        defer { animator.stop() }

        animator.start()
        animator.noteUsageRatio(0.40)
        animator.noteUsageRatio(0.55)

        XCTAssertFalse(animator.isBurstingForTesting)
        XCTAssertFalse(animator.hasFrameTimerForTesting)

        animator.noteUsageRatio(0.76)

        XCTAssertTrue(animator.isBurstingForTesting)
        XCTAssertTrue(animator.hasFrameTimerForTesting)
    }

    func testFrameAdvanceCompletesBurstAndReturnsToRest() {
        let animator = TriggerIconAnimator.makeForTesting()
        var frameCount = 0
        animator.onFrame = {
            frameCount += 1
        }
        defer { animator.stop() }

        animator.start()
        animator.startBurstForTesting()

        for _ in 0..<19 {
            animator.advanceFrameForTesting()
            XCTAssertTrue(animator.isBurstingForTesting)
            XCTAssertGreaterThan(animator.phase, 0)
        }

        animator.advanceFrameForTesting()

        XCTAssertFalse(animator.isBurstingForTesting)
        XCTAssertFalse(animator.hasFrameTimerForTesting)
        XCTAssertEqual(animator.phase, 0, accuracy: 0.0001)
        XCTAssertEqual(frameCount, 20)
    }
}
