import AppKit
import XCTest
@testable import Spill

@MainActor
final class MenuBarMetricSparklineViewTests: XCTestCase {
    func testRepeatedDrawsReuseRasterizedImageUntilSizeChanges() throws {
        let view = MenuBarMetricSparklineView(
            series: [.init(role: .status, values: [0.2, 0.95, 0.5, 0.75])],
            kind: .cpu,
            statusColor: .systemGreen
        )
        view.frame = NSRect(x: 0, y: 0, width: 40, height: 13)

        render(view)
        let firstKey = try XCTUnwrap(view.renderCacheKey)
        XCTAssertEqual(firstKey.size, NSSize(width: 40, height: 13))

        render(view)
        XCTAssertEqual(view.renderCacheKey, firstKey)

        view.frame = NSRect(x: 0, y: 0, width: 52, height: 13)
        render(view)
        XCTAssertEqual(view.renderCacheKey?.size, NSSize(width: 52, height: 13))
    }

    func testAlternatingAppearancesReuseOneImagePerAppearance() throws {
        let view = MenuBarMetricSparklineView(
            series: [.init(role: .status, values: [0.2, 0.95, 0.5, 0.75])],
            kind: .cpu,
            statusColor: .systemGreen
        )
        view.frame = NSRect(x: 0, y: 0, width: 40, height: 13)
        let light = try XCTUnwrap(NSAppearance(named: .aqua))
        let dark = try XCTUnwrap(NSAppearance(named: .darkAqua))

        for _ in 0..<3 {
            for appearance in [light, dark] {
                view.appearance = appearance
                view.viewDidChangeEffectiveAppearance()
                render(view)
                XCTAssertEqual(view.renderCacheKey?.appearanceName, appearance.name)
            }
        }

        XCTAssertEqual(view.renderedImages.count, 2)
    }

    func testRasterizedImageFillsWholeViewBounds() throws {
        let view = MenuBarMetricSparklineView(
            series: [.init(role: .status, values: [1, 1, 1, 1])],
            kind: .cpu,
            statusColor: .systemGreen
        )
        view.frame = NSRect(x: 0, y: 0, width: 40, height: 13)
        render(view)

        let key = try XCTUnwrap(view.renderCacheKey)
        let image = try XCTUnwrap(view.renderedImages[key])
        let bitmap = try XCTUnwrap(image.representations.first as? NSBitmapImageRep)
        // Full-height bars reach the top-right part of the bitmap only when drawing is scaled to points.
        let topRight = try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide * 3 / 4, y: bitmap.pixelsHigh / 4))
        XCTAssertGreaterThan(topRight.alphaComponent, 0.1)
    }

    private func render(_ view: NSView) {
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            return XCTFail("missing bitmap for \(view.bounds)")
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
    }
}
