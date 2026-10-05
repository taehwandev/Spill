import SwiftUI

enum SpillPanelSurface {
    static var cardFill: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            if appearance.name.rawValue.lowercased().contains("dark") {
                return NSColor(white: 0.13, alpha: 0.55)
            } else {
                return NSColor(white: 1.0, alpha: 0.82)
            }
        })
    }

    static var cardFillHovered: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            if appearance.name.rawValue.lowercased().contains("dark") {
                return NSColor(white: 0.17, alpha: 0.70)
            } else {
                return NSColor(white: 1.0, alpha: 0.94)
            }
        })
    }

    static func cardFill(isHovered: Bool) -> Color {
        isHovered ? cardFillHovered : cardFill
    }
}
