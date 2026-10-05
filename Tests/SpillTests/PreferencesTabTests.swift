import XCTest
@testable import Spill

final class PreferencesTabTests: XCTestCase {
    func testRawValuesAreTheIdentifiersOtherProcessesSend() {
        XCTAssertEqual(
            PreferencesTab.allCases.map(\.rawValue),
            ["general", "menubar", "tokens", "windows", "status_caffeine", "developer"]
        )
        XCTAssertEqual(PreferencesTab(rawValue: "tokens"), .tokenMetering)
        XCTAssertNil(PreferencesTab(rawValue: "missing"))
    }

    func testDeveloperTabFollowsTheBuildOption() {
        XCTAssertEqual(PreferencesTab.developer.isAvailable, SpillBuildOptions.developerOptionsEnabled)
        XCTAssertEqual(
            PreferencesTab.available.contains(.developer),
            SpillBuildOptions.developerOptionsEnabled
        )
        XCTAssertEqual(PreferencesTab.available.first, .general)
    }

    func testEveryTabHasASidebarTitleIconAndPageTitle() {
        for tab in PreferencesTab.allCases {
            XCTAssertFalse(tab.symbolName.isEmpty, "\(tab)")
            XCTAssertFalse(PreferencesL10n.text(tab.sidebarTitleKey, appLanguage: .english).isEmpty, "\(tab)")
            XCTAssertFalse(PreferencesL10n.text(tab.pageTitleKey, appLanguage: .english).isEmpty, "\(tab)")
        }
    }
}
