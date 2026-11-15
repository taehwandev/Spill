import SwiftUI

/// One AI tool filter tab. The tab answers "how much did this tool use and
/// how much is left": usage on top, the tool's limit readings underneath.
/// Running state stays a small sparkle on the droplet, and the cloud service
/// badge appears only when the provider reports a problem. Process counts and
/// healthy service states live in the Agent Connection Status rail.
///
/// Selecting the tool and opening limit detail are two sibling buttons inside
/// one card, never nested, so each keeps its own hit area and focus.
struct TokenMeteringDashboardToolTab: View {
    let filter: TokenUsageDashboardToolFilter
    @ObservedObject var store: TokenUsageDashboardStore
    @ObservedObject var cloudServiceStatusStore: CloudServiceStatusStore
    @ObservedObject var aiStatusStore: AIStatusStore
    let appLanguage: SpillAppLanguage
    let selectedControlAccent: Color
    let selectedControlAccentHighlight: Color
    let limitsPresentation: TokenMeteringDashboardLimitsPresentation
    @State private var isHovered = false
}

extension TokenMeteringDashboardToolTab {
    var body: some View {
        let liveUpdateID = "filter:tool:\(filter.id)"
        let isLiveUpdated = store.isLiveUpdated(liveUpdateID)
        let isSelected = store.selectedTool == filter.tool
        let serviceStatus = filter.tool.flatMap(serviceStatus)
        let hasServerIssue = serviceStatus?.health.isServerIssue ?? false
        let statusTint = serviceStatus?.health.serverStatusTint ?? Color.teal
        let toolTint = filter.tool?.dashboardTint ?? selectedControlAccent
        let tabAccent = hasServerIssue ? statusTint : toolTint
        let limitGroup = filter.tool.flatMap(limitsPresentation.group(for:))

        return VStack(alignment: .leading, spacing: 10) {
            Button {
                store.setSelectedTool(filter.tool)
            } label: {
                HStack(spacing: 8) {
                    leadingStatusIndicator(tabAccent: tabAccent)

                    tabLabel(
                        detail: filter.detail,
                        shareLabel: filter.shareLabel,
                        issueStatus: hasServerIssue ? serviceStatus : nil,
                        isActive: isLiveUpdated,
                        isSelected: isSelected,
                        tint: tabAccent
                    )

                    Spacer(minLength: 0)
                }
                .foregroundStyle(isSelected ? tabAccent : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .help(lastUpdatedHelp)
            .accessibilityValue(Text(runningAccessibilityValue))

            if let limitGroup {
                TokenMeteringDashboardToolTabLimits(group: limitGroup, presentation: limitsPresentation)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tabBackground(isSelected: isSelected, hasServerIssue: hasServerIssue, tabAccent: tabAccent))
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

    private func tabBackground(isSelected: Bool, hasServerIssue: Bool, tabAccent: Color) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                isSelected
                    ? tabAccent.opacity(0.14)
                    : (hasServerIssue ? tabAccent.opacity(0.10) : Color.primary.opacity(isHovered ? 0.06 : 0.03))
            )
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
                // AI tool tab: the sparkle turns green while the tool runs.
                Image(systemName: "sparkle")
                    .font(.system(size: 6.5, weight: .bold))
                    .foregroundStyle(
                        isToolRunning
                            ? Color.green
                            : Color(red: 0.35, green: 0.85, blue: 0.95)
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 1, x: 0, y: 0.5)
                    .offset(x: 3.5, y: 2.5)
            }
        }
        .frame(width: 16, height: 16)
    }

    private func tabLabel(
        detail: String,
        shareLabel: String?,
        issueStatus: CloudServiceStatusItem?,
        isActive: Bool,
        isSelected: Bool,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Text(filter.title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .semibold))
                    .lineLimit(1)
                    .layoutPriority(1)
                    .minimumScaleFactor(0.78)

                if let issueStatus {
                    CloudServiceStatusBadge(item: issueStatus, appLanguage: appLanguage)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }

            HStack(spacing: 5) {
                // All has no limit line, so its "records / tokens" summary
                // stacks one part per line in the free vertical space instead
                // of widening the tab or truncating.
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(detailLines(detail), id: \.self) { line in
                        Text(line)
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(isSelected ? tint.opacity(0.85) : .secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .layoutPriority(1)

                if let shareLabel {
                    toolShareBadge(shareLabel, isSelected: isSelected, tint: tint)
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
            .fixedSize()
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
    /// The per-tool capture time moved off the tab face to make room for
    /// limits; it stays one hover away.
    private func detailLines(_ detail: String) -> [String] {
        guard filter.tool == nil else { return [detail] }
        let parts = detail
            .split(separator: "/")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? [detail] : parts
    }

    private var lastUpdatedHelp: String {
        guard let lastUpdated = lastUpdatedString(for: filter.tool) else {
            return filter.title
        }
        return "\(filter.title) · \(lastUpdated)"
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

    private var localStatus: LocalAIToolStatus? {
        guard let kind = filter.tool?.localAIToolKind else { return nil }
        return aiStatusStore.statuses.first(where: { $0.kind == kind })
    }

    private var isToolRunning: Bool {
        localStatus?.hasRunningProcesses ?? false
    }

    /// The visual running cue is a color change only, so VoiceOver gets the
    /// same state as text.
    private var runningAccessibilityValue: String {
        guard let localStatus else { return "" }
        if localStatus.hasRunningProcesses {
            return localStatus.value
        }
        return localStatus.value.isEmpty ? AppL10n.text(.idle, appLanguage: appLanguage) : localStatus.value
    }
}
