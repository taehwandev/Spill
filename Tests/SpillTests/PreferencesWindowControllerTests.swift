import XCTest

final class PreferencesWindowControllerTests: XCTestCase {
    func testStandaloneSpillGlanceSurfaceIsRemoved() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let preferencesView = try source(
            at: "Sources/Spill/Preferences/PreferencesView.swift",
            root: root
        )
        let sidebarView = try source(
            at: "Sources/Spill/Preferences/Components/PreferencesSidebarView.swift",
            root: root
        )
        let appDelegate = try source(at: "Sources/Spill/App/AppDelegate.swift", root: root)
        let settings = try source(at: "Sources/Spill/Settings/SpillSettings.swift", root: root)
        let dashboardView = try source(
            at: "Sources/Spill/TokenMetering/Dashboard/Screen/TokenMeteringDashboardView.swift",
            root: root
        )
        let dashboardProcess = try source(
            at: "Sources/Spill/TokenMetering/Dashboard/App/TokenMeteringDashboardProcess.swift",
            root: root
        )
        let dashboardStore = try source(
            at: "Sources/Spill/TokenMetering/Dashboard/State/TokenUsageDashboardStore.swift",
            root: root
        )

        XCTAssertFalse(sidebarView.contains(#"tag: "glance""#))
        XCTAssertFalse(preferencesView.contains("SpillGlancePreferencesSection"))
        XCTAssertFalse(appDelegate.contains("SpillGlancePanelController"))
        XCTAssertFalse(settings.contains("glanceEnabled"))
        XCTAssertFalse(dashboardView.contains("toggleSpillGlance"))
        XCTAssertFalse(dashboardProcess.contains("glanceEnabledSettingsKey"))
        XCTAssertFalse(dashboardStore.contains("glanceSummary"))
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: root.appendingPathComponent("Sources/Spill/Glance").path
            )
        )
    }

    func testWindowReleasesHostedContentWhenClosed() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let windowController = try source(
            at: "Sources/Spill/Preferences/PreferencesWindowController.swift",
            root: root
        )

        XCTAssertTrue(windowController.contains("PreferencesWindowController: NSObject, NSWindowDelegate"))
        XCTAssertTrue(windowController.contains("window.delegate = self"))
        XCTAssertTrue(windowController.contains("func windowWillClose"))
        XCTAssertTrue(windowController.contains("releaseWindowContent()"))
        XCTAssertTrue(windowController.contains("self.window = nil"))
        XCTAssertTrue(windowController.contains("window?.contentView = nil"))
        XCTAssertTrue(windowController.contains("languageObservation?.cancel()"))
        XCTAssertTrue(windowController.contains("appearanceObservation?.cancel()"))
    }

    private func source(at relativePath: String, root: URL) throws -> String {
        try String(
            contentsOf: root.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
