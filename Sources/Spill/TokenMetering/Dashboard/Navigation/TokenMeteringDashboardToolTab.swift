import SwiftUI

struct TokenMeteringDashboardToolTab: View {
    let filter: TokenUsageDashboardToolFilter
    @ObservedObject var store: TokenUsageDashboardStore
    @ObservedObject var cloudServiceStatusStore: CloudServiceStatusStore
    @ObservedObject var aiStatusStore: AIStatusStore
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
            HStack(spacing: 8) {
                leadingStatusIndicator(tabAccent: tabAccent)

                tabLabel(
                    detail: filter.detail,
                    shareLabel: filter.shareLabel,
                    lastUpdated: toolLastUpdated,
                    serviceStatus: serviceStatus,
                    isActive: isLiveUpdated,
                    isSelected: isSelected,
                    tint: tabAccent
                )
            }
            .padding(.horizontal, 11)
            .frame(minWidth: filter.tool == nil ? 88 : 124, minHeight: 46, alignment: .leading)
            .foregroundStyle(isSelected ? tabAccent : .primary)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tabAccent.opacity(0.14))
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(hasServerIssue ? tabAccent.opacity(0.10) : Color.primary.opacity(isHovered ? 0.06 : 0.03))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isSelected ? tabAccent.opacity(0.28) : (hasServerIssue ? tabAccent.opacity(0.30) : Color.primary.opacity(isHovered ? 0.10 : 0.045)),
                        lineWidth: isSelected ? 0.75 : 0.5
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
    @ViewBuilder
    private func leadingStatusIndicator(tabAccent: Color) -> some View {
        let dropHeight: CGFloat = 13
        let dropWidth: CGFloat = dropHeight * WaterDropletOutline.aspectRatio

        ZStack(alignment: .bottomTrailing) {
            WaterDropletShape()
                .fill(
                    LinearGradient(
                        colors: [
                            tabAccent.opacity(0.85),
                            tabAccent
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: dropWidth, height: dropHeight)

            if filter.tool != nil {
                // AI tool tab: sparkle accessory
                Image(systemName: "sparkle")
                    .font(.system(size: 6.5, weight: .bold))
                    .foregroundStyle(
                        isToolRunning
                            ? Color.green
                            : Color(red: 0.35, green: 0.85, blue: 0.95)
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 1, x: 0, y: 0.5)
                    .offset(x: 3.5, y: 2.5)
            } else if isToolRunning {
                // All tab running status dot
                Circle()
                    .fill(Color.green)
                    .frame(width: 4.5, height: 4.5)
                    .shadow(color: Color.green.opacity(0.4), radius: 1)
                    .offset(x: 2, y: 2)
            }
        }
        .frame(width: 16, height: 16)
    }

    private func tabLabel(
        detail: String,
        shareLabel: String?,
        lastUpdated: String?,
        serviceStatus: CloudServiceStatusItem?,
        isActive: Bool,
        isSelected: Bool,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 2.5) {
            HStack(spacing: 5) {
                Text(filter.title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .semibold))
                    .lineLimit(1)
                    .layoutPriority(1)
                    .minimumScaleFactor(0.78)

                toolAgentStatusBadge(localStatus: localStatus)

                if hasServiceStatusAccessory(serviceStatus: serviceStatus, tool: filter.tool) {
                    toolServiceStatusAccessory(serviceStatus: serviceStatus, tool: filter.tool)
                }
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

extension TokenMeteringDashboardToolTab {
    private var localStatus: LocalAIToolStatus? {
        guard let kind = filter.tool?.localAIToolKind else { return nil }
        return aiStatusStore.statuses.first(where: { $0.kind == kind })
    }

    private var isToolRunning: Bool {
        localStatus?.hasRunningProcesses ?? false
    }

    private var runningToolCount: Int {
        visibleStatuses.filter(\.hasRunningProcesses).count
    }

    private var visibleStatuses: [LocalAIToolStatus] {
        let visibleKinds = Set(store.snapshot.toolFilters.compactMap { $0.tool?.localAIToolKind })
        return aiStatusStore.statuses.filter { visibleKinds.contains($0.kind) }
    }

    @ViewBuilder
    private func toolAgentStatusBadge(localStatus: LocalAIToolStatus?) -> some View {
        if let localStatus {
            let isRunning = localStatus.hasRunningProcesses
            let procCount = localStatus.processSummary.processCount
            let badgeText: String = {
                if isRunning {
                    return procCount > 1 ? "\(procCount) proc" : localStatus.value
                } else {
                    return localStatus.value.isEmpty ? AppL10n.text(.idle, appLanguage: appLanguage) : localStatus.value
                }
            }()
            agentStatusBadge(text: badgeText, isRunning: isRunning)
        } else if filter.tool == nil {
            let runningCount = runningToolCount
            if runningCount > 0 {
                agentStatusBadge(text: String(runningCount), isRunning: true)
                    .accessibilityLabel(AppL10n.aiProcessSummary(
                        runningToolCount: runningCount,
                        processCount: visibleStatuses.reduce(0) { $0 + $1.processSummary.processCount },
                        appLanguage: appLanguage
                    ))
            }
        }
    }

    private func agentStatusBadge(text: String, isRunning: Bool) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(isRunning ? Color.green : Color.secondary.opacity(0.5))
                .frame(width: isRunning ? 4.5 : 3.5, height: isRunning ? 4.5 : 3.5)
            Text(text)
                .font(.system(size: 8, weight: isRunning ? .bold : .medium, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(isRunning ? Color.green : Color.secondary.opacity(0.8))
        .padding(.horizontal, 4.5)
        .frame(height: 15)
        .background(
            Capsule(style: .continuous)
                .fill(isRunning ? Color.green.opacity(0.12) : Color.primary.opacity(0.04))
        )
        .overlay {
            Capsule(style: .continuous)
                .stroke(isRunning ? Color.green.opacity(0.24) : Color.primary.opacity(0.06), lineWidth: 0.5)
        }
    }
}
