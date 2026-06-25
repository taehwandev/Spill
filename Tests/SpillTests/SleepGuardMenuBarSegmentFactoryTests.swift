import XCTest
@testable import Spill

final class SleepGuardMenuBarSegmentFactoryTests: XCTestCase {
    func testInactiveCaffeineUsesOutlineIconWithoutText() {
        let segment = SleepGuardMenuBarSegmentFactory.make(
            isEnabled: true,
            isActive: false,
            remainingLabel: "15m",
            showsRemainingInMenuBar: true
        )

        XCTAssertEqual(segment?.state, .unavailable)
        XCTAssertEqual(segment?.symbolName, "cup.and.saucer")
        XCTAssertEqual(segment?.value, "")
    }

    func testActiveCaffeineUsesFilledIconWithoutTextByDefault() {
        let segment = SleepGuardMenuBarSegmentFactory.make(
            isEnabled: true,
            isActive: true,
            remainingLabel: "15m",
            showsRemainingInMenuBar: false
        )

        XCTAssertEqual(segment?.state, .active)
        XCTAssertEqual(segment?.symbolName, "cup.and.saucer.fill")
        XCTAssertEqual(segment?.value, "")
    }

    func testActiveCaffeineCanShowRemainingTimeWhenEnabled() {
        let segment = SleepGuardMenuBarSegmentFactory.make(
            isEnabled: true,
            isActive: true,
            remainingLabel: "15m",
            showsRemainingInMenuBar: true
        )

        XCTAssertEqual(segment?.state, .active)
        XCTAssertEqual(segment?.symbolName, "cup.and.saucer.fill")
        XCTAssertEqual(segment?.value, "15m")
        XCTAssertEqual(segment?.displayText, "15m")
        XCTAssertEqual(segment?.visualStyle, .symbolBadge)
    }

    func testDisabledCaffeineDoesNotCreateSegment() {
        let segment = SleepGuardMenuBarSegmentFactory.make(
            isEnabled: false,
            isActive: true,
            remainingLabel: "15m",
            showsRemainingInMenuBar: true
        )

        XCTAssertNil(segment)
    }
}
