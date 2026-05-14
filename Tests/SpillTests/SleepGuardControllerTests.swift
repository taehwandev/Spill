import XCTest
@testable import Spill

@MainActor
final class SleepGuardControllerTests: XCTestCase {
    func testStartsInactive() {
        let fakeManager = FakeSleepAssertionManager()
        let controller = SleepGuardController(assertionManager: fakeManager, automaticallySchedulesTimer: false)

        XCTAssertFalse(controller.isActive)
        XCTAssertEqual(controller.remainingSeconds, 0)
        XCTAssertEqual(fakeManager.createdSystemAssertions, [])
    }

    func testStartCreatesSystemAssertionOnlyByDefault() {
        var now = Date(timeIntervalSince1970: 100)
        let fakeManager = FakeSleepAssertionManager()
        let controller = SleepGuardController(
            assertionManager: fakeManager,
            now: { now },
            automaticallySchedulesTimer: false
        )

        XCTAssertTrue(controller.start(duration: .thirtyMinutes, keepDisplayAwake: false))

        XCTAssertTrue(controller.isActive)
        XCTAssertEqual(controller.activeDuration, .thirtyMinutes)
        XCTAssertEqual(controller.remainingSeconds, 1_800)
        XCTAssertEqual(controller.remainingLabel, "30m")
        XCTAssertEqual(fakeManager.createdSystemAssertions, [100])
        XCTAssertEqual(fakeManager.createdDisplayAssertions, [])
        XCTAssertEqual(fakeManager.releasedAssertions, [])

        now.addTimeInterval(60)
        controller.refreshRemaining()

        XCTAssertEqual(controller.remainingSeconds, 1_740)
        XCTAssertEqual(controller.remainingLabel, "29m")
    }

    func testStopReleasesAssertions() {
        let fakeManager = FakeSleepAssertionManager()
        let controller = SleepGuardController(assertionManager: fakeManager, automaticallySchedulesTimer: false)

        controller.start(duration: .fifteenMinutes, keepDisplayAwake: false)
        controller.stop()

        XCTAssertFalse(controller.isActive)
        XCTAssertEqual(controller.remainingSeconds, 0)
        XCTAssertEqual(fakeManager.releasedAssertions, [100])
    }

    func testExpiryReleasesAssertion() {
        var now = Date(timeIntervalSince1970: 100)
        let fakeManager = FakeSleepAssertionManager()
        let controller = SleepGuardController(
            assertionManager: fakeManager,
            now: { now },
            automaticallySchedulesTimer: false
        )

        controller.start(duration: .fifteenMinutes, keepDisplayAwake: false)
        now.addTimeInterval(901)
        controller.refreshRemaining()

        XCTAssertFalse(controller.isActive)
        XCTAssertEqual(controller.remainingSeconds, 0)
        XCTAssertEqual(fakeManager.releasedAssertions, [100])
    }

    func testDisplayAwakeCreatesAndReleasesDisplayAssertion() {
        let fakeManager = FakeSleepAssertionManager()
        let controller = SleepGuardController(assertionManager: fakeManager, automaticallySchedulesTimer: false)

        XCTAssertTrue(controller.start(duration: .oneHour, keepDisplayAwake: true))
        controller.stop()

        XCTAssertEqual(fakeManager.createdSystemAssertions, [100])
        XCTAssertEqual(fakeManager.createdDisplayAssertions, [101])
        XCTAssertEqual(fakeManager.releasedAssertions, [100, 101])
    }

    func testDisplayAssertionFailureRollsBackSystemAssertion() {
        let fakeManager = FakeSleepAssertionManager()
        fakeManager.shouldCreateDisplayAssertion = false
        let controller = SleepGuardController(assertionManager: fakeManager, automaticallySchedulesTimer: false)

        XCTAssertFalse(controller.start(duration: .oneHour, keepDisplayAwake: true))

        XCTAssertFalse(controller.isActive)
        XCTAssertEqual(fakeManager.createdSystemAssertions, [100])
        XCTAssertEqual(fakeManager.createdDisplayAssertions, [])
        XCTAssertEqual(fakeManager.releasedAssertions, [100])
        XCTAssertEqual(controller.errorMessage, "Could not keep the display awake.")
    }

    func testSystemAssertionFailureLeavesControllerOff() {
        let fakeManager = FakeSleepAssertionManager()
        fakeManager.shouldCreateSystemAssertion = false
        let controller = SleepGuardController(assertionManager: fakeManager, automaticallySchedulesTimer: false)

        XCTAssertFalse(controller.start(duration: .oneHour, keepDisplayAwake: false))

        XCTAssertFalse(controller.isActive)
        XCTAssertEqual(fakeManager.createdSystemAssertions, [])
        XCTAssertEqual(fakeManager.releasedAssertions, [])
        XCTAssertEqual(controller.errorMessage, "Could not start Sleep Guard.")
    }
}

private final class FakeSleepAssertionManager: SleepAssertionManaging {
    var shouldCreateSystemAssertion = true
    var shouldCreateDisplayAssertion = true
    var createdSystemAssertions: [SleepAssertionID] = []
    var createdDisplayAssertions: [SleepAssertionID] = []
    var releasedAssertions: [SleepAssertionID] = []
    private var nextID: SleepAssertionID = 100

    func createSystemAssertion(reason: String) -> SleepAssertionID? {
        guard shouldCreateSystemAssertion else {
            return nil
        }

        return createAssertion(recordingInto: &createdSystemAssertions)
    }

    func createDisplayAssertion(reason: String) -> SleepAssertionID? {
        guard shouldCreateDisplayAssertion else {
            return nil
        }

        return createAssertion(recordingInto: &createdDisplayAssertions)
    }

    func releaseAssertion(_ id: SleepAssertionID) {
        releasedAssertions.append(id)
    }

    private func createAssertion(recordingInto assertions: inout [SleepAssertionID]) -> SleepAssertionID {
        let id = nextID
        nextID += 1
        assertions.append(id)
        return id
    }
}
