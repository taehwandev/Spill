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

    static var insetFill: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            if appearance.name.rawValue.lowercased().contains("dark") {
                return NSColor(white: 0.08, alpha: 0.45)
            } else {
                return NSColor(red: 0.95, green: 0.96, blue: 0.97, alpha: 0.85)
            }
        })
    }

    static func cardFill(isHovered: Bool) -> Color {
        isHovered ? cardFillHovered : cardFill
    }
}
