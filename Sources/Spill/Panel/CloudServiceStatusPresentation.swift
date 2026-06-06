import SwiftUI

enum CloudServiceStatusPresentation {
    static func aggregateHealth(for items: [CloudServiceStatusItem]) -> CloudServiceHealth {
        let rankedItems = items.filter { item in
            item.kind != .antigravity || item.health != .unknown
        }
        let scopedItems = rankedItems.isEmpty ? items : rankedItems
        return scopedItems.max { lhs, rhs in
            lhs.health.serverStatusRank < rhs.health.serverStatusRank
        }?.health ?? .unknown
    }

    static func serviceStatus(
        for kind: LocalAIToolKind,
        in snapshot: CloudServiceStatusSnapshot?
    ) -> CloudServiceStatusItem? {
        serviceStatus(for: serviceKinds(for: kind), in: snapshot)
    }

    static func serviceStatus(
        for tool: TokenUsageAITool,
        in snapshot: CloudServiceStatusSnapshot?
    ) -> CloudServiceStatusItem? {
        serviceStatus(for: serviceKinds(for: tool), in: snapshot)
    }

    static func hasCloudService(for tool: TokenUsageAITool?) -> Bool {
        guard let tool else {
            return false
        }
        return !serviceKinds(for: tool).isEmpty
    }

    static func serviceKinds(for kind: LocalAIToolKind) -> [CloudServiceKind] {
        switch kind {
        case .codex:
            return [.codex]
        case .claude:
            return [.claudeCode]
        case .antigravity:
            return [.antigravity]
        case .ollama:
            return []
        case .openAI:
            return [.openAI]
        }
    }

    static func serviceKinds(for tool: TokenUsageAITool) -> [CloudServiceKind] {
        switch tool {
        case .codex:
            return [.codex]
        case .claude:
            return [.claudeCode]
        case .antigravity:
            return [.antigravity]
        case .openAI:
            return [.openAI]
        case .unknown:
            return []
        }
    }

    private static func serviceStatus(
        for serviceKinds: [CloudServiceKind],
        in snapshot: CloudServiceStatusSnapshot?
    ) -> CloudServiceStatusItem? {
        guard !serviceKinds.isEmpty else {
            return nil
        }

        return snapshot?.items
            .filter { serviceKinds.contains($0.kind) }
            .sorted { lhs, rhs in
                lhs.health.serverStatusRank > rhs.health.serverStatusRank
            }
            .first
    }
}

extension CloudServiceHealth {
    var isServerIssue: Bool {
        switch self {
        case .degraded, .outage, .maintenance:
            return true
        case .operational, .unknown:
            return false
        }
    }

    var serverStatusRank: Int {
        switch self {
        case .outage:
            return 5
        case .degraded:
            return 4
        case .maintenance:
            return 3
        case .unknown:
            return 2
        case .operational:
            return 1
        }
    }

    var serverStatusHeaderTitle: String {
        serverStatusHeaderTitle(appLanguage: .persisted())
    }

    func serverStatusHeaderTitle(appLanguage: SpillAppLanguage) -> String {
        switch self {
        case .operational:
            return AppL10n.text(.operational, appLanguage: appLanguage)
        case .degraded:
            return AppL10n.text(.degraded, appLanguage: appLanguage)
        case .outage:
            return AppL10n.text(.outage, appLanguage: appLanguage)
        case .maintenance:
            return AppL10n.text(.maintenance, appLanguage: appLanguage)
        case .unknown:
            return AppL10n.text(.unknown, appLanguage: appLanguage)
        }
    }

    var serverStatusBadgeTitle: String {
        serverStatusBadgeTitle(appLanguage: .persisted())
    }

    func serverStatusBadgeTitle(appLanguage: SpillAppLanguage) -> String {
        switch self {
        case .operational:
            return AppL10n.text(.serverOK, appLanguage: appLanguage)
        case .degraded:
            return AppL10n.text(.degraded, appLanguage: appLanguage)
        case .outage:
            return AppL10n.text(.outage, appLanguage: appLanguage)
        case .maintenance:
            return AppL10n.text(.maint, appLanguage: appLanguage)
        case .unknown:
            return AppL10n.text(.unknown, appLanguage: appLanguage)
        }
    }

    var serverStatusSymbolName: String {
        switch self {
        case .outage:
            return "exclamationmark.triangle.fill"
        case .degraded:
            return "exclamationmark.circle.fill"
        case .maintenance:
            return "wrench.and.screwdriver.fill"
        case .operational:
            return "checkmark.circle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }

    var serverStatusTint: Color {
        switch self {
        case .outage:
            return .red
        case .degraded:
            return .orange
        case .maintenance:
            return .blue
        case .operational:
            return .green
        case .unknown:
            return .secondary
        }
    }
}

struct CloudServiceStatusBadge: View {
    let item: CloudServiceStatusItem
    var appLanguage: SpillAppLanguage = .persisted()

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: item.health.serverStatusSymbolName)
                .font(.system(size: 8, weight: .bold))

            Text(item.health.serverStatusBadgeTitle(appLanguage: appLanguage))
                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                .lineLimit(1)
        }
        .padding(.horizontal, 5)
        .frame(height: 18)
        .foregroundStyle(item.health.serverStatusTint)
        .background(item.health.serverStatusTint.opacity(0.13), in: Capsule())
        .help(helpText)
    }

    private var helpText: String {
        "\(item.title) \(AppL10n.text(.server, appLanguage: appLanguage)) \(item.health.serverStatusHeaderTitle(appLanguage: appLanguage)): \(item.detail)"
    }
}
