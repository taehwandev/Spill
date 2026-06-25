import SwiftUI

enum SpillPanelSurface {
    static let cardFill = Color(red: 0.12, green: 0.17, blue: 0.20).opacity(0.92)
    static let cardFillHovered = Color(red: 0.15, green: 0.21, blue: 0.24).opacity(0.96)
    static let insetFill = Color(red: 0.10, green: 0.15, blue: 0.18).opacity(0.88)

    static func cardFill(isHovered: Bool) -> Color {
        isHovered ? cardFillHovered : cardFill
    }
}
