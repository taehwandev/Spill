import XCTest
@testable import Spill

final class MenuBarScanRefreshPolicyTests: XCTestCase {
    func testRefreshIsDueWhenNoPreviousScanExists() {
        let policy = MenuBarScanRefreshPolicy(minimumRefreshInterval: 5)

        XCTAssertTrue(policy.shouldRefresh(lastScannedAt: nil, now: Date(timeIntervalSince1970: 10), force: false))
    }

    func testRefreshIsSkippedInsideMinimumInterval() {
        let policy = MenuBarScanRefreshPolicy(minimumRefreshInterval: 5)
        let lastScan = Date(timeIntervalSince1970: 10)
        let now = Date(timeIntervalSince1970: 14)

        XCTAssertFalse(policy.shouldRefresh(lastScannedAt: lastScan, now: now, force: false))
    }

    func testRefreshIsDueAfterMinimumInterval() {
        let policy = MenuBarScanRefreshPolicy(minimumRefreshInterval: 5)
        let lastScan = Date(timeIntervalSince1970: 10)
        let now = Date(timeIntervalSince1970: 15)

        XCTAssertTrue(policy.shouldRefresh(lastScannedAt: lastScan, now: now, force: false))
    }

    func testForcedRefreshIgnoresMinimumInterval() {
        let policy = MenuBarScanRefreshPolicy(minimumRefreshInterval: 60)
        let lastScan = Date(timeIntervalSince1970: 10)
        let now = Date(timeIntervalSince1970: 11)

        XCTAssertTrue(policy.shouldRefresh(lastScannedAt: lastScan, now: now, force: true))
    }

    func testRefreshUsesMinimumIntervalOverrideWhenProvided() {
        let policy = MenuBarScanRefreshPolicy(minimumRefreshInterval: 60)
        let lastScan = Date(timeIntervalSince1970: 10)
        let now = Date(timeIntervalSince1970: 20)

        XCTAssertTrue(
            policy.shouldRefresh(
                lastScannedAt: lastScan,
                now: now,
                force: false,
                minimumRefreshInterval: 10
            )
        )
    }
}
