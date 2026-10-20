import AppKit
import XCTest
@testable import Spill

@MainActor
final class MenuBarStatusTextViewTests: XCTestCase {
    func testTextAndFontChangesUpdateMetricsAndAccessibleValue() {
        let view = MenuBarStatusTextView(labelWithString: "5%")
        view.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        let initialSize = view.intrinsicContentSize
        view.stringValue = "1.44M"
        XCTAssertGreaterThan(view.intrinsicContentSize.width, initialSize.width)
        XCTAssertEqual(view.accessibilityValue() as? String, "1.44M")
        XCTAssertEqual(view.accessibilityRole(), .staticText)
        let initialHeight = view.intrinsicContentSize.height
        view.font = .monospacedDigitSystemFont(ofSize: 15, weight: .bold)
        XCTAssertGreaterThan(view.intrinsicContentSize.height, initialHeight)
    }

    func testRepeatedAppearanceRenderingKeepsMetricsAndDrawsAdaptiveText() throws {
        let view = MenuBarStatusTextView(labelWithString: "72.0%")
        view.font = .monospacedDigitSystemFont(ofSize: 13.5, weight: .semibold)
        view.frame = NSRect(x: 0, y: 0, width: 70, height: 22)
        let initialSize = view.intrinsicContentSize
        let light = try XCTUnwrap(NSAppearance(named: .aqua))
        let dark = try XCTUnwrap(NSAppearance(named: .darkAqua))
        let lightImage = try render(view, appearance: light)
        let darkImage = try render(view, appearance: dark)
        XCTAssertNotEqual(lightImage.representation(using: .png, properties: [:]),
                          darkImage.representation(using: .png, properties: [:]))
        for appearance in [light, dark, light, dark, light, dark] {
            _ = try render(view, appearance: appearance)
            XCTAssertEqual(view.intrinsicContentSize, initialSize)
            XCTAssertEqual(view.frame.size, NSSize(width: 70, height: 22))
            XCTAssertEqual(view.textColor, .labelColor)
        }
    }

    func testAlignmentAndClippingPreserveVisibleText() throws {
        let view = MenuBarStatusTextView(labelWithString: "72.0%")
        view.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        view.frame = NSRect(x: 0, y: 0, width: 100, height: 22)
        let appearance = try XCTUnwrap(NSAppearance(named: .darkAqua))
        view.alignment = .left
        let left = try firstVisibleColumn(try render(view, appearance: appearance))
        view.alignment = .center
        let center = try firstVisibleColumn(try render(view, appearance: appearance))
        view.alignment = .right
        let right = try firstVisibleColumn(try render(view, appearance: appearance))
        XCTAssertLessThan(left, center)
        XCTAssertLessThan(center, right)
        view.frame.size.width = 12
        XCTAssertNoThrow(try firstVisibleColumn(try render(view, appearance: appearance)))
    }

    private func render(_ view: NSView, appearance: NSAppearance) throws -> NSBitmapImageRep {
        view.appearance = appearance
        let image = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: image)
        return image
    }

    private func firstVisibleColumn(_ image: NSBitmapImageRep) throws -> Int {
        for x in 0..<image.pixelsWide {
            for y in 0..<image.pixelsHigh where (image.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.05 {
                return x
            }
        }
        XCTFail("Status text rendered no visible pixels")
        return image.pixelsWide
    }
}
