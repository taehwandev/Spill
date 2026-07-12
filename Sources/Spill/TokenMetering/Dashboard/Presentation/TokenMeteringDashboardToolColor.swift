import SwiftUI

enum TokenMeteringDashboardToolPalette {
    static let codex = Color(red: 0.04, green: 0.76, blue: 0.79)
    static let claude = Color(red: 0.86, green: 0.45, blue: 0.28)
    static let antigravity = Color(red: 0.12, green: 0.55, blue: 0.96)
    static let openAI = Color(red: 0.09, green: 0.62, blue: 0.45)
}

extension TokenUsageAITool {
    var dashboardTint: Color {
        switch self {
        case .codex:
            return Color(nsColor: NSColor(name: nil) { appearance in
                if appearance.name.rawValue.lowercased().contains("dark") {
                    return NSColor(red: 0.18, green: 0.67, blue: 0.69, alpha: 1.0)
                } else {
                    return NSColor(red: 0.08, green: 0.55, blue: 0.57, alpha: 1.0)
                }
            })
        case .claude:
            return Color(nsColor: NSColor(name: nil) { appearance in
                if appearance.name.rawValue.lowercased().contains("dark") {
                    return NSColor(red: 0.80, green: 0.48, blue: 0.36, alpha: 1.0)
                } else {
                    return NSColor(red: 0.72, green: 0.38, blue: 0.26, alpha: 1.0)
                }
            })
        case .antigravity:
            return Color(nsColor: NSColor(name: nil) { appearance in
                if appearance.name.rawValue.lowercased().contains("dark") {
                    return NSColor(red: 0.25, green: 0.52, blue: 0.88, alpha: 1.0)
                } else {
                    return NSColor(red: 0.18, green: 0.42, blue: 0.76, alpha: 1.0)
                }
            })
        case .openAI:
            return Color(nsColor: NSColor(name: nil) { appearance in
                if appearance.name.rawValue.lowercased().contains("dark") {
                    return NSColor(red: 0.20, green: 0.58, blue: 0.45, alpha: 1.0)
                } else {
                    return NSColor(red: 0.12, green: 0.48, blue: 0.35, alpha: 1.0)
                }
            })
        case .unknown:
            return .secondary
        }
    }
}

extension LocalAIToolKind {
    var dashboardTint: Color {
        switch self {
        case .codex:
            return TokenUsageAITool.codex.dashboardTint
        case .claude:
            return TokenUsageAITool.claude.dashboardTint
        case .antigravity:
            return TokenUsageAITool.antigravity.dashboardTint
        case .ollama:
            return .green
        case .openAI:
            return TokenUsageAITool.openAI.dashboardTint
        }
    }
}
