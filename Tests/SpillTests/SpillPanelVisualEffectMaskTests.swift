import AppKit
import XCTest
@testable import Spill

@MainActor
final class SpillPanelVisualEffectMaskTests: XCTestCase {
    func testVisualEffectMaterialUsesContinuousRoundedMask() throws {
        let size = NSSize(width: 420, height: 560)
        let view = SpillPanelVisualEffectView(
            frame: NSRect(origin: .zero, size: size)
        )
        view.layoutSubtreeIfNeeded()

        let mask = try XCTUnwrap(view.maskImage)
        XCTAssertEqual(mask.size, size)
        XCTAssertEqual(view.layer?.cornerRadius, 22)
        XCTAssertEqual(view.layer?.cornerCurve, .continuous)
        XCTAssertEqual(view.layer?.masksToBounds, true)

        let bitmap = try XCTUnwrap(
            mask.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:))
        )
        XCTAssertLessThan(try XCTUnwrap(bitmap.colorAt(x: 0, y: 0)).alphaComponent, 0.05)
        XCTAssertGreaterThan(
            try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2))
                .alphaComponent,
            0.95
        )
    }

    func testVisualEffectMaskFollowsResizedBounds() throws {
        let view = SpillPanelVisualEffectView(
            frame: NSRect(x: 0, y: 0, width: 320, height: 420)
        )
        view.layoutSubtreeIfNeeded()
        let initialMask = try XCTUnwrap(view.maskImage)

        let resized = NSSize(width: 480, height: 640)
        view.setFrameSize(resized)

        let resizedMask = try XCTUnwrap(view.maskImage)
        XCTAssertEqual(resizedMask.size, resized)
        XCTAssertFalse(initialMask === resizedMask)
    }

    func testControllerKeepsRoundedBorderConfiguration() throws {
        let source = try String(
            contentsOf: panelControllerURL,
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("visualEffectView.layer?.borderWidth = 0.8"))
        XCTAssertTrue(source.contains("applyPanelBorderColor()"))
    }

    private var panelControllerURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Spill/Panel/SpillPanelController.swift")
    }
}
