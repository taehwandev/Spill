import Foundation
import XCTest
@testable import Spill

final class SparkleVersionComparatorTests: XCTestCase {
    // MARK: - Legacy build-number migration

    func testOldBuildNumberOneDetectsNewerFullVersionInAppcast() {
        // Old install: CFBundleVersion="1", ShortVersionString="2026.24.1"
        // New appcast: sparkle:version="2026.25.1"
        let comparator = makeComparator(bundleVersion: "1", shortVersion: "2026.24.1")

        XCTAssertEqual(comparator.compareVersion("1", toVersion: "2026.25.1"), .orderedAscending)
    }

    func testOldBuildNumberOneTreatsLegacyAppcastBuildNumberAsOlderRawVersion() {
        // Only the installed side can be normalized from CFBundleVersion to
        // CFBundleShortVersionString. A legacy appcast "1" has no embedded
        // short version, so treating it as raw 1 avoids false equality.
        let comparator = makeComparator(bundleVersion: "1", shortVersion: "2026.24.1")

        XCTAssertEqual(comparator.compareVersion("1", toVersion: "1"), .orderedDescending)
    }

    func testOldBuildNumberOneIsNewerThanSmallerFullVersionInAppcast() {
        // Hypothetical downgrade entry in appcast should be rejected.
        let comparator = makeComparator(bundleVersion: "1", shortVersion: "2026.25.1")

        XCTAssertEqual(comparator.compareVersion("1", toVersion: "2026.24.1"), .orderedDescending)
    }

    // MARK: - New full-version build numbers

    func testNewBuildVersionDetectsNewerVersion() {
        let comparator = makeComparator(bundleVersion: "2026.24.1", shortVersion: "2026.24.1")

        XCTAssertEqual(comparator.compareVersion("2026.24.1", toVersion: "2026.25.1"), .orderedAscending)
    }

    func testNewBuildVersionIsEqualWhenVersionsMatch() {
        let comparator = makeComparator(bundleVersion: "2026.25.1", shortVersion: "2026.25.1")

        XCTAssertEqual(comparator.compareVersion("2026.25.1", toVersion: "2026.25.1"), .orderedSame)
    }

    func testNewBuildVersionIsNewerThanOlderAppcastEntry() {
        let comparator = makeComparator(bundleVersion: "2026.25.1", shortVersion: "2026.25.1")

        XCTAssertEqual(comparator.compareVersion("2026.25.1", toVersion: "2026.24.1"), .orderedDescending)
    }

    func testPatchVersionIncrementIsDetected() {
        let comparator = makeComparator(bundleVersion: "2026.25.1", shortVersion: "2026.25.1")

        XCTAssertEqual(comparator.compareVersion("2026.25.1", toVersion: "2026.25.2"), .orderedAscending)
    }

    // MARK: - DottedVersion normalizing initializer

    func testNormalizingInitSubstitutesShortVersionWhenBundleVersionMatches() {
        let result = DottedVersion(normalizing: "1", bundleVersion: "1", shortVersion: "2026.24.1")
        XCTAssertEqual(result, DottedVersion("2026.24.1"))
    }

    func testNormalizingInitDoesNotSubstituteWhenVersionDiffersFromBundleVersion() {
        let result = DottedVersion(normalizing: "2026.25.1", bundleVersion: "1", shortVersion: "2026.24.1")
        XCTAssertEqual(result, DottedVersion("2026.25.1"))
    }

    func testNormalizingInitUsesVersionDirectlyWhenBundleVersionIsEmpty() {
        let result = DottedVersion(normalizing: "2026.25.1", bundleVersion: "", shortVersion: "")
        XCTAssertEqual(result, DottedVersion("2026.25.1"))
    }

    func testNormalizingInitReturnsNilForInvalidVersion() {
        let result = DottedVersion(normalizing: "invalid", bundleVersion: "1", shortVersion: "2026.24.1")
        XCTAssertNil(result)
    }

    // MARK: - Helpers

    private func makeComparator(bundleVersion: String, shortVersion: String) -> SparkleVersionComparator {
        let bundle = MockInfoBundle(bundleVersion: bundleVersion, shortVersion: shortVersion)
        return SparkleVersionComparator(bundle: bundle)
    }
}

private final class MockInfoBundle: Bundle, @unchecked Sendable {
    private let _bundleVersion: String
    private let _shortVersion: String

    init(bundleVersion: String, shortVersion: String) {
        self._bundleVersion = bundleVersion
        self._shortVersion = shortVersion
        super.init()
    }

    override func object(forInfoDictionaryKey key: String) -> Any? {
        switch key {
        case "CFBundleVersion": return _bundleVersion
        case "CFBundleShortVersionString": return _shortVersion
        default: return super.object(forInfoDictionaryKey: key)
        }
    }
}
