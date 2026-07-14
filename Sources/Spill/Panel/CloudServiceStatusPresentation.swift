import Foundation
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

    static func controlState(
        snapshot: CloudServiceStatusSnapshot?,
        isLoading: Bool,
        appLanguage: SpillAppLanguage,
        now: Date = Date()
    ) -> CloudServiceStatusControlState {
        let health = snapshot.map { aggregateHealth(for: $0.items) }
        let issueCount = snapshot?.items.filter { $0.health.isServerIssue }.count ?? 0
        let title: String
        let symbolName: String

        if isLoading {
            title = AppL10n.text(.checking, appLanguage: appLanguage)
            symbolName = "arrow.triangle.2.circlepath"
        } else if let health {
            title = health.serverStatusHeaderTitle(appLanguage: appLanguage)
            symbolName = health.serverStatusSymbolName
        } else {
            title = AppL10n.text(.serverStatus, appLanguage: appLanguage)
            symbolName = "cloud.fill"
        }

        return CloudServiceStatusControlState(
            title: title,
            helpText: serviceStatusHelpText(
                snapshot: snapshot,
                health: health,
                issueCount: issueCount,
                appLanguage: appLanguage,
                now: now
            ),
            symbolName: symbolName,
            health: health,
            issueCount: issueCount,
            isLoading: isLoading
        )
    }
}

extension CloudServiceStatusPresentation {
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

    private static func serviceStatusHelpText(
        snapshot: CloudServiceStatusSnapshot?,
        health: CloudServiceHealth?,
        issueCount: Int,
        appLanguage: SpillAppLanguage,
        now: Date
    ) -> String {
        guard let snapshot, let health else {
            return AppL10n.text(.fetchOfficialServiceStatus, appLanguage: appLanguage)
        }

        let statusTitle = health.serverStatusHeaderTitle(appLanguage: appLanguage).lowercased()
        let statusText = issueCount == 0
            ? String(
                format: AppL10n.text(.serverStatusNoIssues, appLanguage: appLanguage),
                statusTitle
            )
            : AppL10n.serverStatusWithIssues(
                status: statusTitle,
                issueCount: issueCount,
                appLanguage: appLanguage
            )
        return "\(statusText). \(AppL10n.lastChecked(fullServiceCheckTime(snapshot.fetchedAt), age: relativeServiceAge(from: snapshot.fetchedAt, now: now, appLanguage: appLanguage), appLanguage: appLanguage)) \(AppL10n.text(.clickForPerServiceDetails, appLanguage: appLanguage))"
    }

    private static func fullServiceCheckTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = .current

        if Calendar.current.isDateInToday(date) {
            formatter.setLocalizedDateFormatFromTemplate("jm")
        } else {
            formatter.setLocalizedDateFormatFromTemplate("MMM d, jm")
        }

        return formatter.string(from: date)
    }

    private static func relativeServiceAge(
        from date: Date,
        now: Date,
        appLanguage: SpillAppLanguage
    ) -> String {
        let elapsed = max(0, now.timeIntervalSince(date))
        if elapsed < 60 {
            return AppL10n.text(.justNow, appLanguage: appLanguage)
        }

        let minutes = Int(elapsed / 60)
        if minutes < 60 {
            return AppL10n.minutesAgo(minutes, appLanguage: appLanguage)
        }

        return AppL10n.hoursAgo(max(1, minutes / 60), appLanguage: appLanguage)
    }
}

struct CloudServiceStatusControlState {
    let title: String
    let helpText: String
    let symbolName: String
    let health: CloudServiceHealth?
    let issueCount: Int
    let isLoading: Bool

    var hasServerIssue: Bool {
        !isLoading && (health?.isServerIssue ?? false)
    }

    var tint: Color {
        if isLoading {
            return .blue
        }

        return health?.serverStatusTint ?? .secondary
    }

    var backgroundOpacity: Double {
        if hasServerIssue {
            return 0.20
        }

        return isLoading ? 0.14 : 0.10
    }

    var borderOpacity: Double {
        if hasServerIssue {
            return 0.38
        }

        return isLoading ? 0.22 : 0.13
    }

    var shadowOpacity: Double {
        hasServerIssue ? 0.15 : 0
    }
}

struct CloudServiceStatusButton: View {
    let state: CloudServiceStatusControlState
    var appLanguage: SpillAppLanguage = .persisted()
    var height: CGFloat = 26
    var fontSize: CGFloat = 10
    var horizontalPadding: CGFloat = 9
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Circle()
                    .fill(state.tint)
                    .frame(width: 5, height: 5)

                Image(systemName: state.symbolName)
                    .font(.system(size: max(8, fontSize - 1), weight: .bold))

                Text(state.title)
                    .font(.system(size: fontSize, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .padding(.horizontal, horizontalPadding)
            .frame(height: height)
            .foregroundStyle(state.tint)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(state.tint.opacity(state.backgroundOpacity))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(state.tint.opacity(state.borderOpacity), lineWidth: 0.75)
            }
            .shadow(
                color: state.tint.opacity(state.shadowOpacity),
                radius: state.hasServerIssue ? 6 : 0,
                x: 0,
                y: 1.5
            )
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .help(state.helpText)
        .accessibilityLabel(
            AppL10n.serviceStatusAccessibility(
                status: state.title,
                appLanguage: appLanguage
            )
        )
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
        .background(
            item.health.serverStatusTint.opacity(item.health.isServerIssue ? 0.20 : 0.13),
            in: Capsule()
        )
        .overlay {
            Capsule()
                .stroke(
                    item.health.serverStatusTint.opacity(item.health.isServerIssue ? 0.32 : 0),
                    lineWidth: 0.65
                )
        }
        .help(helpText)
    }

    private var helpText: String {
        "\(item.title) \(AppL10n.text(.server, appLanguage: appLanguage)) \(item.health.serverStatusHeaderTitle(appLanguage: appLanguage)): \(item.detail)"
    }
}
