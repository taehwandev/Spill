import XCTest

final class PreferencesWindowControllerTests: XCTestCase {
    func testWindowReleasesHostedContentWhenClosed() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let windowController = try String(
            contentsOf: root.appendingPathComponent(
                "Sources/Spill/Preferences/PreferencesWindowController.swift"
            ),
            encoding: .utf8
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
}
