import SwiftUI

struct TokenMeteringDashboardAgentStatusPanel: View {
    @ObservedObject var aiStatusStore: AIStatusStore
    @ObservedObject var settings: SpillSettings
    let language: TokenMeteringLanguage
    let appLanguage: SpillAppLanguage
    @State private var expandedAgentIDs: Set<String> = []

    var body: some View {
        let summary = TokenMeteringDashboardAgentStatusSummary.make(statuses: visibleStatuses)

        TokenMeteringDashboardRailPanel(
            title: t(.agentConnectionStatus),
            infoTitle: t(.agentStatusInfoTitle),
            infoDetail: t(.agentStatusInfoDetail)
        ) {
            VStack(alignment: .leading, spacing: 9) {
                Text(t(.agentStatusSubtitle))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if summary.rows.isEmpty {
                    TokenMeteringDashboardEmptyMessage(
                        title: t(.noAgentStatusData),
                        detail: t(.noAgentStatusDetail)
                    )
                } else {
                    agentDetailsList(summary)
                }
            }
        }
    }

    private var visibleStatuses: [LocalAIToolStatus] {
        aiStatusStore.statuses.filter { status in
            settings.isLocalAIToolVisible(status.kind)
        }
    }
}

private extension TokenMeteringDashboardAgentStatusPanel {
    private func agentDetailsList(_ summary: TokenMeteringDashboardAgentStatusSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(summary.rows) { row in
                agentCard(row)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One compact card per agent: identity, state, and a single metrics line.
    /// Version, source, and per-process rows are diagnostics and stay behind a
    /// disclosure so three running agents do not fill the whole rail.
    private func agentCard(_ row: TokenMeteringDashboardAgentStatusRow) -> some View {
        let tint = row.kind.dashboardTint
        let isExpanded = expandedAgentIDs.contains(row.id)
        let hasDetails = !row.metadataRows.isEmpty || !row.processRows.isEmpty

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(tint.opacity(0.14))
                    Image(systemName: row.symbolName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(tint)
                }
                .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text(row.title)
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text(row.detail)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .layoutPriority(1)

                Spacer(minLength: 6)

                statusBadge(row, tint: tint)
            }

            metricsLine(row)

            if hasDetails {
                detailsToggle(agentID: row.id, isExpanded: isExpanded)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    if !row.metadataRows.isEmpty {
                        metadataStack(row.metadataRows)
                    }

                    if !row.processRows.isEmpty {
                        processStack(row.processRows)
                    }
                }
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(10)
        .background(
            row.isRunning ? tint.opacity(0.06) : Color.primary.opacity(0.025),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(row.isRunning ? tint.opacity(0.14) : Color.primary.opacity(0.05), lineWidth: 0.6)
        }
    }

    private func statusBadge(_ row: TokenMeteringDashboardAgentStatusRow, tint: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(tint)
                .frame(width: 5, height: 5)
            Text(row.statusValue)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 6)
        .frame(height: 18)
        .background(tint.opacity(row.isRunning ? 0.13 : 0.08), in: Capsule())
    }
}

private extension TokenMeteringDashboardAgentStatusPanel {
    private func metricsLine(_ row: TokenMeteringDashboardAgentStatusRow) -> some View {
        HStack(spacing: 10) {
            metric(
                title: AppL10n.text(.processes, appLanguage: appLanguage),
                value: TokenUsageDashboardSnapshot.formatCount(row.processCount)
            )
            metric(title: AppL10n.text(.cpu, appLanguage: appLanguage), value: row.cpuText)
            metric(title: AppL10n.text(.memory, appLanguage: appLanguage), value: row.memoryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func metric(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
        }
        .minimumScaleFactor(0.75)
    }

    private func detailsToggle(agentID: String, isExpanded: Bool) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                if isExpanded {
                    expandedAgentIDs.remove(agentID)
                } else {
                    expandedAgentIDs.insert(agentID)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(isExpanded ? t(.agentDetailsHide) : t(.agentDetailsShow))
                    .font(.system(size: 9.5, weight: .semibold))
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 7.5, weight: .bold))
            }
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }
}

private extension TokenMeteringDashboardAgentStatusPanel {
    private func metadataStack(_ rows: [TokenMeteringDashboardAgentMetadataRow]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(rows.prefix(3)) { row in
                HStack(spacing: 5) {
                    Text(row.label.uppercased())
                        .font(.system(size: 7.5, weight: .black))
                        .tracking(0.5)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .leading)
                    Text(row.value)
                        .font(.system(size: 9, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
        }
    }

    private func processStack(_ rows: [TokenMeteringDashboardAgentProcessRow]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(rows) { row in
                HStack(spacing: 5) {
                    Text(row.title)
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                    Text(row.detail)
                        .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .padding(.top, 1)
    }

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(key, language: language)
    }
}
