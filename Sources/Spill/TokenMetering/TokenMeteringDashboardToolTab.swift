import SwiftUI

struct TokenMeteringDashboardToolTab: View {
    let filter: TokenUsageDashboardToolFilter
    @ObservedObject var store: TokenUsageDashboardStore
    @ObservedObject var cloudServiceStatusStore: CloudServiceStatusStore
    let appLanguage: SpillAppLanguage
    let selectedControlAccent: Color
    let selectedControlAccentHighlight: Color

    var body: some View {
        let liveUpdateID = "filter:tool:\(filter.id)"
        let isLiveUpdated = store.isLiveUpdated(liveUpdateID)
        let toolLastUpdated = lastUpdatedString(for: filter.tool)
        let detail = toolLastUpdated.map { "\(filter.detail) · \($0)" } ?? filter.detail
        let serviceStatus = filter.tool.flatMap(serviceStatus)
        let hasServerIssue = serviceStatus?.health.isServerIssue ?? false
        let statusTint = serviceStatus?.health.serverStatusTint ?? Color.teal
        let tabAccent = hasServerIssue ? statusTint : Color.teal

        return Button {
            store.setSelectedTool(filter.tool)
        } label: {
            HStack(spacing: 9) {
                Circle()
                    .fill(filter.isSelected ? .white : tabAccent.opacity(0.82))
                    .frame(width: 7, height: 7)

                tabLabel(
                    detail: detail,
                    serviceStatus: serviceStatus,
                    isActive: isLiveUpdated
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            .foregroundStyle(filter.isSelected ? .white : .primary)
            .background {
                if filter.isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    hasServerIssue ? tabAccent.opacity(0.86) : selectedControlAccentHighlight,
                                    hasServerIssue ? tabAccent.opacity(0.68) : selectedControlAccent
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: tabAccent.opacity(hasServerIssue ? 0.18 : 0.16), radius: 4, x: 0, y: 1.5)
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(hasServerIssue ? tabAccent.opacity(0.12) : Color.primary.opacity(0.035))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        hasServerIssue ? tabAccent.opacity(0.36) : Color.primary.opacity(0.055),
                        lineWidth: hasServerIssue ? 0.8 : 0.5
                    )
            }
            .modifier(TokenMeteringLiveUpdateEffect(isActive: isLiveUpdated && !filter.isSelected, marker: store.liveUpdateMarker, cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }

    private func tabLabel(
        detail: String,
        serviceStatus: CloudServiceStatusItem?,
        isActive: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(filter.title)
                    .font(.system(size: 11, weight: filter.isSelected ? .bold : .semibold))
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
                    .foregroundStyle(filter.isSelected ? .white.opacity(0.78) : .secondary)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.35), value: filter.detail)

                TokenMeteringLiveUpdateDot(
                    isActive: isActive,
                    marker: store.liveUpdateMarker,
                    tint: filter.isSelected ? .white : .teal
                )

                Spacer(minLength: 0)
            }
        }
    }

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
