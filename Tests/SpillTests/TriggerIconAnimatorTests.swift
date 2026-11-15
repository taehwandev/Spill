import XCTest
@testable import Spill

// The animator's testing hooks are compiled only in DEBUG builds.
#if DEBUG
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

    func testContinuousLoopRunsWithoutIdleGapsAndWraps() {
        let animator = TriggerIconAnimator.makeForTesting()
        defer { animator.stop() }

        animator.start(loopsContinuously: true)

        XCTAssertTrue(animator.hasFrameTimerForTesting)
        XCTAssertFalse(animator.hasIdleTimerForTesting)

        for _ in 0..<200 {
            animator.advanceFrameForTesting()
        }

        XCTAssertTrue(animator.hasFrameTimerForTesting, "the loop never stops on its own")
        XCTAssertGreaterThanOrEqual(animator.phase, 0)
        XCTAssertLessThan(animator.phase, 1)
    }

    func testContinuousLoopEasesTowardFasterSpeedUnderLoad() {
        let animator = TriggerIconAnimator.makeForTesting()
        defer { animator.stop() }

        animator.start(loopsContinuously: true)
        animator.noteUsageRatio(0.95)
        animator.advanceFrameForTesting()

        let firstStep = animator.loopSpeedMultiplierForTesting
        XCTAssertGreaterThan(firstStep, 1)
        XCTAssertLessThan(firstStep, 3, "speed eases in instead of jumping")

        for _ in 0..<120 {
            animator.advanceFrameForTesting()
        }
        XCTAssertEqual(animator.loopSpeedMultiplierForTesting, 3, accuracy: 0.01)

        animator.noteUsageRatio(0.2)
        for _ in 0..<120 {
            animator.advanceFrameForTesting()
        }
        XCTAssertEqual(animator.loopSpeedMultiplierForTesting, 1, accuracy: 0.01)
    }

    func testLoopSpeedMapsLoadOntoRestToFullSpeed() {
        XCTAssertEqual(TriggerIconAnimator.loopSpeedMultiplier(forUsageRatio: 0), 1)
        XCTAssertEqual(TriggerIconAnimator.loopSpeedMultiplier(forUsageRatio: 0.45), 1)
        XCTAssertEqual(TriggerIconAnimator.loopSpeedMultiplier(forUsageRatio: 0.675), 2, accuracy: 1e-9)
        XCTAssertEqual(TriggerIconAnimator.loopSpeedMultiplier(forUsageRatio: 1), 3)
        XCTAssertEqual(TriggerIconAnimator.loopSpeedMultiplier(forUsageRatio: .nan), 1)
    }

    func testContinuousLoopPausesWhileScreensSleep() {
        let animator = TriggerIconAnimator.makeForTesting()
        defer { animator.stop() }

        animator.start(loopsContinuously: true)
        animator.setScreensAsleepForTesting(true)
        XCTAssertFalse(animator.hasFrameTimerForTesting)
        XCTAssertTrue(animator.isRunningForTesting)

        animator.setScreensAsleepForTesting(false)
        XCTAssertTrue(animator.hasFrameTimerForTesting)
    }

    func testSwitchingModeRestartsInTheNewMode() {
        let animator = TriggerIconAnimator.makeForTesting()
        defer { animator.stop() }

        animator.start(loopsContinuously: true)
        animator.advanceFrameForTesting()
        animator.start(loopsContinuously: false)

        XCTAssertEqual(animator.phase, 0)
        XCTAssertTrue(animator.hasIdleTimerForTesting)
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

    func testUsageRatioJumpRightAfterBurstWaitsForMinimumGap() {
        var currentTime = Date(timeIntervalSince1970: 1_000)
        let animator = TriggerIconAnimator.makeForTesting(now: { currentTime })
        defer { animator.stop() }

        animator.start()
        animator.startBurstForTesting()
        for _ in 0..<20 {
            animator.advanceFrameForTesting()
        }
        XCTAssertFalse(animator.isBurstingForTesting)

        animator.noteUsageRatio(0.10)
        currentTime.addTimeInterval(2)
        animator.noteUsageRatio(0.90)

        XCTAssertFalse(animator.isBurstingForTesting)
        XCTAssertFalse(animator.hasFrameTimerForTesting)

        currentTime.addTimeInterval(6)
        animator.noteUsageRatio(0.10)

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
#endif
