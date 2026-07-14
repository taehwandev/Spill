import SwiftUI

struct TokenMeteringDashboardToolTab: View {
    let filter: TokenUsageDashboardToolFilter
    @ObservedObject var store: TokenUsageDashboardStore
    @ObservedObject var cloudServiceStatusStore: CloudServiceStatusStore
    let appLanguage: SpillAppLanguage
    let selectedControlAccent: Color
    let selectedControlAccentHighlight: Color
    @State private var isHovered = false
}

extension TokenMeteringDashboardToolTab {
    var body: some View {
        let liveUpdateID = "filter:tool:\(filter.id)"
        let isLiveUpdated = store.isLiveUpdated(liveUpdateID)
        let isSelected = store.selectedTool == filter.tool
        let toolLastUpdated = lastUpdatedString(for: filter.tool)
        let serviceStatus = filter.tool.flatMap(serviceStatus)
        let hasServerIssue = serviceStatus?.health.isServerIssue ?? false
        let statusTint = serviceStatus?.health.serverStatusTint ?? Color.teal
        let toolTint = filter.tool?.dashboardTint ?? selectedControlAccent
        let tabAccent = hasServerIssue ? statusTint : toolTint

        return Button {
            store.setSelectedTool(filter.tool)
        } label: {
            HStack(spacing: 9) {
                Circle()
                    .fill(tabAccent)
                    .frame(width: 7, height: 7)

                tabLabel(
                    detail: filter.detail,
                    shareLabel: filter.shareLabel,
                    lastUpdated: toolLastUpdated,
                    serviceStatus: serviceStatus,
                    isActive: isLiveUpdated,
                    isSelected: isSelected,
                    tint: tabAccent
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            .foregroundStyle(isSelected ? tabAccent : .primary)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tabAccent.opacity(0.14))
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(hasServerIssue ? tabAccent.opacity(0.12) : Color.primary.opacity(isHovered ? 0.075 : 0.035))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        isSelected ? tabAccent.opacity(0.28) : (hasServerIssue ? tabAccent.opacity(0.36) : Color.primary.opacity(isHovered ? 0.12 : 0.055)),
                        lineWidth: isSelected ? 0.8 : (hasServerIssue ? 0.8 : 0.5)
                    )
            }
            .onHover { hovering in
                isHovered = hovering
            }
            .modifier(TokenMeteringLiveUpdateEffect(isActive: isLiveUpdated && !isSelected, marker: store.liveUpdateMarker, cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }
}

extension TokenMeteringDashboardToolTab {
    private func tabLabel(
        detail: String,
        shareLabel: String?,
        lastUpdated: String?,
        serviceStatus: CloudServiceStatusItem?,
        isActive: Bool,
        isSelected: Bool,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(filter.title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .semibold))
                    .lineLimit(1)
                    .layoutPriority(1)
                    .minimumScaleFactor(0.78)

                if hasServiceStatusAccessory(serviceStatus: serviceStatus, tool: filter.tool) {
                    toolServiceStatusAccessory(serviceStatus: serviceStatus, tool: filter.tool)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 5) {
                Text(detail)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isSelected ? tint.opacity(0.85) : .secondary)
                    .lineLimit(1)
                    .layoutPriority(1)

                if let shareLabel {
                    toolShareBadge(shareLabel, isSelected: isSelected, tint: tint)
                }

                if let lastUpdated {
                    Text("· \(lastUpdated)")
                        .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? tint.opacity(0.78) : .secondary)
                        .lineLimit(1)
                        .layoutPriority(0.8)
                }

                TokenMeteringLiveUpdateDot(
                    isActive: isActive,
                    marker: store.liveUpdateMarker,
                    tint: tint
                )

                Spacer(minLength: 0)
            }
        }
    }

    private func toolShareBadge(
        _ value: String,
        isSelected: Bool,
        tint: Color
    ) -> some View {
        Text(value)
            .font(.system(size: 8.5, weight: .black, design: .rounded))
            .lineLimit(1)
            .padding(.horizontal, 5)
            .frame(height: 16)
            .foregroundStyle(tint)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? tint.opacity(0.18) : tint.opacity(0.12))
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(isSelected ? tint.opacity(0.28) : tint.opacity(0.2), lineWidth: 0.5)
            }
    }
}

extension TokenMeteringDashboardToolTab {
    private func hasServiceStatusAccessory(
        serviceStatus: CloudServiceStatusItem?,
        tool: TokenUsageAITool?
    ) -> Bool {
        serviceStatus != nil || CloudServiceStatusPresentation.hasCloudService(for: tool)
    }

    @ViewBuilder
    private func toolServiceStatusAccessory(
        serviceStatus: CloudServiceStatusItem?,
        tool: TokenUsageAITool?
    ) -> some View {
        if let serviceStatus {
            CloudServiceStatusBadge(item: serviceStatus, appLanguage: appLanguage)
                .fixedSize(horizontal: true, vertical: false)
        } else if CloudServiceStatusPresentation.hasCloudService(for: tool) {
            aiServerPendingBadge()
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func lastUpdatedString(for tool: TokenUsageAITool?) -> String? {
        guard let tool else { return nil }
        switch tool {
        case .codex:
            return store.snapshot.codexLastUpdatedString
        case .claude:
            return store.snapshot.claudeLastUpdatedString
        case .antigravity:
            return store.snapshot.antigravityLastUpdatedString
        default:
            return nil
        }
    }

    private func serviceStatus(for tool: TokenUsageAITool) -> CloudServiceStatusItem? {
        CloudServiceStatusPresentation.serviceStatus(
            for: tool,
            in: cloudServiceStatusStore.snapshot
        )
    }

    private func aiServerPendingBadge() -> some View {
        let tint = cloudServiceStatusStore.isLoading ? Color.blue : Color.secondary
        let value = cloudServiceStatusStore.isLoading
            ? AppL10n.text(.checking, appLanguage: appLanguage)
            : AppL10n.text(.server, appLanguage: appLanguage)

        return HStack(spacing: 4) {
            Image(systemName: cloudServiceStatusStore.isLoading ? "arrow.triangle.2.circlepath" : "cloud.fill")
                .font(.system(size: 8, weight: .bold))

            Text(value)
                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                .lineLimit(1)
        }
        .padding(.horizontal, 5)
        .frame(height: 18)
        .foregroundStyle(tint)
        .background(tint.opacity(0.10), in: Capsule())
        .help(AppL10n.text(.serverStatusPendingHelp, appLanguage: appLanguage))
    }
}
