import AppKit
import SwiftUI
import XCTest
@testable import Spill

final class TokenUsageLimitCardVisualTests: XCTestCase {
    @MainActor
    func testCardsRenderAtCompactAndRegularWidthsInBothAppearances() throws {
        let output = ProcessInfo.processInfo.environment["SPILL_LIMIT_CARD_VISUAL_DIR"]
        for width in [700, 1000] {
            for scheme in [ColorScheme.light, .dark] {
                let content = LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 8, alignment: .top), count: 3), spacing: 8) {
                    card(title: "AGY · Gemini", items: [item("5h", value: "85%"), item("Wk", value: "67%")])
                    card(title: "Codex", items: [item("GPT-5.3-Codex-Spark Wk", value: "4.9%")])
                    card(title: "Claude", items: [])
                }
                .padding(16)
                .frame(width: CGFloat(width))
                .background(scheme == .dark ? Color(white: 0.12) : Color.white)
                .environment(\.colorScheme, scheme)
                let renderer = ImageRenderer(content: content)
                renderer.scale = 2
                let image = try XCTUnwrap(renderer.cgImage)
                XCTAssertEqual(image.width, width * 2)
                XCTAssertGreaterThan(image.height, 120)
                XCTAssertLessThan(image.height, 400)
                if let output {
                    let directory = URL(fileURLWithPath: output)
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    let name = "limits-\(width)-\(scheme == .dark ? "dark" : "light").png"
                    let png = try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
                    try png.write(to: directory.appendingPathComponent(name))
                }
            }
        }
    }

    @MainActor
    private func card(title: String, items: [TokenMeteringDashboardLimitCard.Item]) -> some View {
        TokenMeteringDashboardLimitCard(title: title, tint: .teal, remainingCaption: "남은 사용량",
            items: items, emptyText: "새 사용량 정보가 없습니다. 새로고침 후 다시 확인하세요.",
            extraText: nil, accessibilityText: title, onOpen: {})
    }

    private func item(_ title: String, value: String) -> TokenMeteringDashboardLimitCard.Item {
        let snapshot = TokenUsageLimitSnapshot(aiTool: .antigravity, limitKey: title, label: title,
            usedPercent: 100 - (Double(value.dropLast()) ?? 0), remainingCredits: nil, windowMinutes: 300, resetsAt: nil,
            capturedAt: Date(timeIntervalSince1970: 1_000_000), source: .clientCache)
        return .init(snapshot: snapshot, title: title, value: value,
                     reset: "10/17 오후 10:44 리셋", age: nil, tooltip: "", dimmed: false)
    }
}
