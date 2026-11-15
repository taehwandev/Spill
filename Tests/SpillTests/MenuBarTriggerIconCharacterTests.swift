import AppKit
import XCTest
@testable import Spill

@MainActor
final class MenuBarTriggerIconCharacterTests: XCTestCase {
    private let characterStyles: [MenuBarTriggerIconStyle] = [.dropCat, .dropBunny, .dropFish]

    func testEveryCharacterRendersAtMenuBarSize() throws {
        for style in characterStyles {
            for phase: CGFloat in [0, 0.25, 0.5, 0.75, 0.99] {
                let image = try XCTUnwrap(MenuBarTriggerIconRenderer.image(style: style, phase: phase, size: 13))
                XCTAssertEqual(image.size, NSSize(width: 13, height: 13))
                XCTAssertTrue(image.isTemplate, "\(style) is tinted to the menu bar like an SF Symbol")
            }
        }
    }

    /// The burst ends at phase 1 and the animator parks at phase 0, so both
    /// must be the same still pose or the icon would jump when a burst ends.
    func testMotionReturnsToRestAtBothEndsOfABurst() {
        XCTAssertEqual(MenuBarTriggerIconCharacterRenderer.envelope(0), 0, accuracy: 1e-9)
        XCTAssertEqual(MenuBarTriggerIconCharacterRenderer.envelope(1), 0, accuracy: 1e-9)
        XCTAssertEqual(MenuBarTriggerIconCharacterRenderer.swing(0), 0, accuracy: 1e-9)
        XCTAssertEqual(MenuBarTriggerIconCharacterRenderer.swing(1), 0, accuracy: 1e-9)
        XCTAssertFalse(MenuBarTriggerIconCharacterRenderer.isBlinking(0))
        XCTAssertGreaterThan(abs(MenuBarTriggerIconCharacterRenderer.swing(0.125)), 0.3)
    }

    /// The cat loops without pausing, so the last frame of a loop must flow
    /// into the first: the tail is at the same angle at phase 0 and 1, and
    /// it sways well away from rest in between.
    func testCatTailLoopsSeamlessly() {
        XCTAssertEqual(MenuBarTriggerIconCharacterRenderer.tailSway(0), 0, accuracy: 1e-9)
        XCTAssertEqual(MenuBarTriggerIconCharacterRenderer.tailSway(1), 0, accuracy: 1e-9)
        XCTAssertEqual(MenuBarTriggerIconCharacterRenderer.tailSway(1.0 / 16), 1, accuracy: 1e-9)
        XCTAssertFalse(MenuBarTriggerIconCharacterRenderer.isCatBlinking(0))
        XCTAssertTrue(MenuBarTriggerIconCharacterRenderer.isCatBlinking(0.61))
    }

    /// Set SPILL_TRIGGER_CHARACTER_DIR to write a frame strip per character
    /// (large and menu bar size) for visual review.
    func testWritesFrameStripsWhenRequested() throws {
        guard let output = ProcessInfo.processInfo.environment["SPILL_TRIGGER_CHARACTER_DIR"] else {
            throw XCTSkip("Set SPILL_TRIGGER_CHARACTER_DIR to write character frame strips")
        }
        let directory = URL(fileURLWithPath: output)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let phases: [CGFloat] = [0, 0.08, 0.16, 0.25, 0.4, 0.56, 0.7, 0.85]

        for style in characterStyles {
            for size: CGFloat in [96, 26] {
                let strip = NSImage(size: NSSize(width: size * CGFloat(phases.count), height: size))
                strip.lockFocus()
                NSColor(calibratedWhite: 0.90, alpha: 1).setFill()
                NSRect(origin: .zero, size: strip.size).fill()
                for (index, phase) in phases.enumerated() {
                    let frame = try XCTUnwrap(MenuBarTriggerIconRenderer.image(style: style, phase: phase, size: size))
                    frame.draw(in: NSRect(x: size * CGFloat(index), y: 0, width: size, height: size))
                }
                strip.unlockFocus()
                let data = try XCTUnwrap(strip.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:))?
                    .representation(using: .png, properties: [:]))
                try data.write(to: directory.appendingPathComponent("\(style.rawValue)-\(Int(size)).png"))
            }
        }
    }
}
