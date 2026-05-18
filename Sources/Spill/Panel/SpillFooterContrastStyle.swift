import SwiftUI

enum SpillFooterForegroundRole: Equatable {
    case primary
    case secondary
    case positive
    case active
    case warning
    case unavailable

    var color: Color {
        switch self {
        case .primary:
            return .primary
        case .secondary:
            return .primary.opacity(0.66)
        case .positive:
            return .green
        case .active:
            return .teal
        case .warning:
            return .orange
        case .unavailable:
            return .primary.opacity(0.52)
        }
    }
}

struct SpillFooterBadgeStyle: Equatable {
    let symbolRole: SpillFooterForegroundRole
    let titleRole: SpillFooterForegroundRole
    let valueRole: SpillFooterForegroundRole

    static func badge(symbolRole: SpillFooterForegroundRole) -> SpillFooterBadgeStyle {
        SpillFooterBadgeStyle(
            symbolRole: symbolRole,
            titleRole: .secondary,
            valueRole: .primary
        )
    }

    static func accessibility(isTrusted: Bool) -> SpillFooterBadgeStyle {
        badge(symbolRole: isTrusted ? .positive : .warning)
    }

    static func scan(isScanning: Bool) -> SpillFooterBadgeStyle {
        badge(symbolRole: isScanning ? .active : .secondary)
    }

    static func sleepGuard(isActive: Bool, hasError: Bool) -> SpillFooterBadgeStyle {
        if isActive {
            return badge(symbolRole: .active)
        }

        if hasError {
            return badge(symbolRole: .warning)
        }

        return badge(symbolRole: .secondary)
    }

    static func power(state: SpillStatusState) -> SpillFooterBadgeStyle {
        switch state {
        case .normal:
            return badge(symbolRole: .positive)
        case .active, .refreshing:
            return badge(symbolRole: .active)
        case .warning:
            return badge(symbolRole: .warning)
        case .unavailable:
            return badge(symbolRole: .unavailable)
        }
    }

    static let count = badge(symbolRole: .secondary)
    static let time = badge(symbolRole: .secondary)
}

private struct SpillFooterForegroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let role: SpillFooterForegroundRole

    func body(content: Content) -> some View {
        content
            .foregroundStyle(role.color)
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowYOffset)
    }

    private var shadowColor: Color {
        .black.opacity(shadowOpacity)
    }

    private var shadowOpacity: Double {
        let base: Double
        switch role {
        case .primary:
            base = 0.22
        case .secondary, .unavailable:
            base = 0.16
        case .positive, .active, .warning:
            base = 0.18
        }

        return colorSchemeContrast == .increased ? min(base + 0.12, 0.38) : base
    }

    private var shadowRadius: CGFloat {
        colorSchemeContrast == .increased ? 0.75 : 0.55
    }

    private var shadowYOffset: CGFloat {
        colorScheme == .dark ? 0.45 : 0.25
    }
}

extension View {
    func spillFooterForeground(_ role: SpillFooterForegroundRole) -> some View {
        modifier(SpillFooterForegroundModifier(role: role))
    }
}
