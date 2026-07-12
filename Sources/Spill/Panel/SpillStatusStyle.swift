import SwiftUI

extension SpillStatusState {
    var panelTint: Color {
        switch self {
        case .normal:
            return Color(nsColor: NSColor(name: nil) { appearance in
                if appearance.name.rawValue.lowercased().contains("dark") {
                    return NSColor(red: 0.38, green: 0.75, blue: 0.65, alpha: 1.0)
                } else {
                    return NSColor(red: 0.15, green: 0.58, blue: 0.48, alpha: 1.0)
                }
            })
        case .active:
            return Color(nsColor: NSColor(name: nil) { appearance in
                if appearance.name.rawValue.lowercased().contains("dark") {
                    return NSColor(red: 0.28, green: 0.68, blue: 0.72, alpha: 1.0)
                } else {
                    return NSColor(red: 0.12, green: 0.52, blue: 0.56, alpha: 1.0)
                }
            })
        case .warning:
            return Color(nsColor: NSColor(name: nil) { appearance in
                if appearance.name.rawValue.lowercased().contains("dark") {
                    return NSColor(red: 0.88, green: 0.52, blue: 0.35, alpha: 1.0)
                } else {
                    return NSColor(red: 0.78, green: 0.42, blue: 0.25, alpha: 1.0)
                }
            })
        case .unavailable:
            return .secondary
        case .refreshing:
            return Color(nsColor: NSColor(name: nil) { appearance in
                if appearance.name.rawValue.lowercased().contains("dark") {
                    return NSColor(red: 0.28, green: 0.68, blue: 0.72, alpha: 1.0)
                } else {
                    return NSColor(red: 0.12, green: 0.52, blue: 0.56, alpha: 1.0)
                }
            })
        }
    }
}
