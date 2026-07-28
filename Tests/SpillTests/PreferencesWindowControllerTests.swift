import XCTest

final class PreferencesWindowControllerTests: XCTestCase {
    func testSpillGlanceHasDedicatedPreferencesSidebarRoute() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let preferencesView = try source(
            at: "Sources/Spill/Preferences/PreferencesView.swift",
            root: root
        )
        let sidebarView = try source(
            at: "Sources/Spill/Preferences/Components/PreferencesSidebarView.swift",
            root: root
        )
        let menuBarSection = try source(
            at: "Sources/Spill/Preferences/Sections/MenuBarPreferencesSection.swift",
            root: root
        )

        XCTAssertTrue(sidebarView.contains(#"tag: "glance""#))
        XCTAssertTrue(sidebarView.contains("title: t(.spillGlance)"))
        XCTAssertTrue(preferencesView.contains(#"case "glance": return t(.spillGlance)"#))
        XCTAssertTrue(preferencesView.contains("SpillGlancePreferencesSection("))
        XCTAssertFalse(
            menuBarSection.contains("SpillGlancePreferencesSection"),
            "Glance should have one discoverable Settings owner instead of a buried duplicate."
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
