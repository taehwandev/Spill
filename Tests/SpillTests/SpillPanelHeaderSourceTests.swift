import Foundation
import XCTest

final class SpillPanelHeaderSourceTests: XCTestCase {
    func testCompactPanelHeaderOmitsCloseWhilePreservingDismissAndQuitPaths() throws {
        let panelSource = try source(at: "Sources/Spill/Panel/SpillBarView.swift")
        let contextMenuSource = try source(at: "Sources/Spill/MenuBar/StatusItemController+ContextMenu.swift")
        let headerSource = try XCTUnwrap(headerSource(in: panelSource))

        XCTAssertTrue(headerSource.contains("action: settingsAction"))
        XCTAssertFalse(headerSource.contains("AppL10n.text(.close"))
        XCTAssertFalse(headerSource.contains("action: dismissAction"))
        XCTAssertTrue(panelSource.contains("dismissAction()"))
        XCTAssertTrue(contextMenuSource.contains("#selector(quitFromMenu)"))
        XCTAssertTrue(contextMenuSource.contains("AppL10n.text(.quitSpill"))
    }
}

private extension SpillPanelHeaderSourceTests {
    func source(at relativePath: String) throws -> String {
        try String(contentsOf: repositoryRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    func headerSource(in source: String) -> Substring? {
        guard let start = source.range(of: "private var header: some View"),
              let end = source.range(
                of: "private func headerCommand",
                range: start.upperBound..<source.endIndex
              )
        else {
            return nil
        }

        return source[start.lowerBound..<end.lowerBound]
    }

    var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
