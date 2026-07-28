import SwiftUI

enum SpillGlanceTint: Equatable {
    case normal
    case active
    case warning
    case muted
    case codex
    case claude
    case antigravity

    var color: Color {
        switch self {
        case .normal:
            return SpillStatusState.normal.panelTint
        case .active:
            return SpillStatusState.active.panelTint
        case .warning:
            return SpillStatusState.warning.panelTint
        case .muted:
            return .secondary
        case .codex:
            return TokenUsageAITool.codex.dashboardTint
        case .claude:
            return TokenUsageAITool.claude.dashboardTint
        case .antigravity:
            return TokenUsageAITool.antigravity.dashboardTint
        }
    }
}
