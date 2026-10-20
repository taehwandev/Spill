import AppKit
import XCTest
@testable import Spill

@MainActor
final class MenuBarMultiDisplayRenderingTests: XCTestCase {
    func testStatusTextDoesNotEnterTextFieldLayoutAcrossDisplayAppearances() throws {
        let segments = [
            segment(.cpu, value: "72.0%"),
            segment(.memory, value: "60.0%"),
            segment(.ai, value: "1.44M"),
            segment(.caffeine, value: "1:59")
        ]
        let appearances = try [NSAppearance.Name.aqua, .darkAqua, .aqua].map {
            try XCTUnwrap(NSAppearance(named: $0))
        }

        for layout: MenuBarStatusLayoutStyle in [.inline, .stacked] {
            let view = MenuBarStatusContentView(segments: segments, layoutStyle: layout)
            view.frame = NSRect(origin: .zero, size: view.intrinsicContentSize)
            view.layoutSubtreeIfNeeded()
            let descendants = descendants(of: view)
            XCTAssertFalse(descendants.contains { $0 is NSTextField },
                "Status replicants must not enter NSTextField appearance-driven layout")
            let originalFrames = descendants.map(\.frame)
            let originalWidth = view.intrinsicContentSize.width

            for _ in 0..<3 {
                for appearance in appearances {
                    view.appearance = appearance
                    view.layoutSubtreeIfNeeded()
                    let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    try savePreviewIfRequested(bitmap, layout: layout, appearance: appearance)
                    XCTAssertEqual(view.intrinsicContentSize.width, originalWidth)
                    XCTAssertEqual(descendants.map(\.frame), originalFrames)
                }
            }
        }
    }

    private func descendants(of view: NSView) -> [NSView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }

    private func savePreviewIfRequested(
        _ bitmap: NSBitmapImageRep, layout: MenuBarStatusLayoutStyle, appearance: NSAppearance
    ) throws {
        guard let directory = ProcessInfo.processInfo.environment["SPILL_MENU_BAR_DISPLAY_PREVIEW_DIRECTORY"] else { return }
        let content = NSImage(cgImage: try XCTUnwrap(bitmap.cgImage), size: bitmap.size)
        let image = NSImage(size: bitmap.size)
        image.lockFocus()
        appearance.performAsCurrentDrawingAppearance {
            NSColor.windowBackgroundColor.setFill()
            NSBezierPath(rect: NSRect(origin: .zero, size: bitmap.size)).fill()
            content.draw(in: NSRect(origin: .zero, size: bitmap.size),
                         from: .zero, operation: .sourceOver, fraction: 1)
        }
        image.unlockFocus()
        let tiff = try XCTUnwrap(image.tiffRepresentation)
        let result = try XCTUnwrap(NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]))
        let url = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try result.write(to: url.appendingPathComponent("\(layout)-\(appearance.name.rawValue).png"))
    }

    private func segment(_ kind: MenuBarStatusSegment.Kind, value: String) -> MenuBarStatusSegment {
        MenuBarStatusSegment(
            kind: kind, title: "Status", shortTitle: "Status", value: value,
            displayText: value, usageRatio: 0.5, state: .normal, symbolName: "circle.fill"
        )
    }
}
