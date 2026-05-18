import XCTest
@testable import Spill

final class SpillFooterContrastStyleTests: XCTestCase {
    func testFooterBadgeKeepsValuesPrimaryOnTransparentGlass() {
        let style = SpillFooterBadgeStyle.badge(symbolRole: .positive)

        XCTAssertEqual(style.symbolRole, .positive)
        XCTAssertEqual(style.titleRole, .secondary)
        XCTAssertEqual(style.valueRole, .primary)
    }

    func testAccessibilityStyleUsesStatusOnlyForSymbol() {
        let trusted = SpillFooterBadgeStyle.accessibility(isTrusted: true)
        let untrusted = SpillFooterBadgeStyle.accessibility(isTrusted: false)

        XCTAssertEqual(trusted.symbolRole, .positive)
        XCTAssertEqual(trusted.valueRole, .primary)
        XCTAssertEqual(untrusted.symbolRole, .warning)
        XCTAssertEqual(untrusted.valueRole, .primary)
    }

    func testSleepGuardStyleKeepsInactiveValueReadable() {
        let inactive = SpillFooterBadgeStyle.sleepGuard(isActive: false, hasError: false)
        let active = SpillFooterBadgeStyle.sleepGuard(isActive: true, hasError: false)
        let failed = SpillFooterBadgeStyle.sleepGuard(isActive: false, hasError: true)

        XCTAssertEqual(inactive.symbolRole, .secondary)
        XCTAssertEqual(inactive.valueRole, .primary)
        XCTAssertEqual(active.symbolRole, .active)
        XCTAssertEqual(active.valueRole, .primary)
        XCTAssertEqual(failed.symbolRole, .warning)
        XCTAssertEqual(failed.valueRole, .primary)
    }

    func testPowerStyleUsesReadablePositiveInsteadOfMintValue() {
        let normal = SpillFooterBadgeStyle.power(state: .normal)
        let warning = SpillFooterBadgeStyle.power(state: .warning)
        let unavailable = SpillFooterBadgeStyle.power(state: .unavailable)

        XCTAssertEqual(normal.symbolRole, .positive)
        XCTAssertEqual(normal.valueRole, .primary)
        XCTAssertEqual(warning.symbolRole, .warning)
        XCTAssertEqual(warning.valueRole, .primary)
        XCTAssertEqual(unavailable.symbolRole, .unavailable)
        XCTAssertEqual(unavailable.valueRole, .primary)
    }
}
