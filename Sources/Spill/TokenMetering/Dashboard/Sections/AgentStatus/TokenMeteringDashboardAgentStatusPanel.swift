import SwiftUI

struct TokenMeteringDashboardAgentStatusPanel: View {
    @ObservedObject var aiStatusStore: AIStatusStore
    @ObservedObject var settings: SpillSettings
    let language: TokenMeteringLanguage
    let appLanguage: SpillAppLanguage
    @State private var showsDetails = false

    private static let summaryColumns = [
        GridItem(.flexible(minimum: 88), spacing: 6),
        GridItem(.flexible(minimum: 88), spacing: 6)
    ]

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
                    compactAgentStatus(summary)
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
    private func compactAgentStatus(_ summary: TokenMeteringDashboardAgentStatusSummary) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            summaryGrid(summary)
            compactAgentStrip(summary)
            detailsButton
                .frame(maxWidth: .infinity, alignment: .trailing)

            if showsDetails {
                VStack(alignment: .leading, spacing: 10) {
                    Divider()
                        .opacity(0.45)
                    agentDetailsList(summary)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func summaryGrid(_ summary: TokenMeteringDashboardAgentStatusSummary) -> some View {
        LazyVGrid(columns: Self.summaryColumns, alignment: .leading, spacing: 6) {
            summaryPill(
                title: t(.agentStatusDetected),
                value: TokenUsageDashboardSnapshot.formatCount(summary.detectedToolCount),
                systemImage: "sparkles",
                tint: .teal
            )
            summaryPill(
                title: AppL10n.text(.processes, appLanguage: appLanguage),
                value: TokenUsageDashboardSnapshot.formatCount(summary.processCount),
                systemImage: "cpu",
                tint: .blue
            )
            summaryPill(
                title: AppL10n.text(.cpu, appLanguage: appLanguage),
                value: summary.cpuText,
                systemImage: "speedometer",
                tint: .purple
            )
            summaryPill(
                title: AppL10n.text(.memory, appLanguage: appLanguage),
                value: summary.memoryText,
                systemImage: "memorychip",
                tint: .green
            )
        }
    }

    private func compactAgentStrip(_ summary: TokenMeteringDashboardAgentStatusSummary) -> some View {
        VStack(spacing: 6) {
            ForEach(summary.rows) { row in
                compactAgentChip(row)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var detailsButton: some View {
        Button {
            withAnimation(.snappy(duration: 0.22)) {
                showsDetails.toggle()
            }
        } label: {
            HStack(spacing: 5) {
                Text(AppL10n.text(.details, appLanguage: appLanguage))
                    .font(.system(size: 9, weight: .bold))
                Image(systemName: showsDetails ? "chevron.up" : "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(Color.primary.opacity(showsDetails ? 0.07 : 0.04), in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .focusable(false)
        .focusEffectDisabled()
        .accessibilityLabel(AppL10n.text(.details, appLanguage: appLanguage))
        .help(t(.agentStatusInfoDetail))
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

    private func summaryPill(title: String, value: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 1) {
                Text(title.uppercased())
                    .font(.system(size: 7.5, weight: .black))
                    .tracking(0.7)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(value)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 32)
        .background(tint.opacity(0.075), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(tint.opacity(0.09), lineWidth: 0.5)
        }
    }

    private func compactAgentChip(_ row: TokenMeteringDashboardAgentStatusRow) -> some View {
        let tint = row.kind.dashboardTint

        return HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 5, height: 5)

            Image(systemName: row.symbolName)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(tint)

            Text(row.title)
                .font(.system(size: 9.5, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(row.statusValue)
                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 25)
        .background(tint.opacity(row.isRunning ? 0.08 : 0.045), in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(tint.opacity(row.isRunning ? 0.12 : 0.06), lineWidth: 0.5)
        }
    }
}

private extension TokenMeteringDashboardAgentStatusPanel {
    private func agentCard(_ row: TokenMeteringDashboardAgentStatusRow) -> some View {
        let tint = row.kind.dashboardTint

        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(tint.opacity(0.14))
                    Image(systemName: row.symbolName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(tint)
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
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

            HStack(spacing: 6) {
                miniMetric(
                    title: AppL10n.text(.processes, appLanguage: appLanguage),
                    value: TokenUsageDashboardSnapshot.formatCount(row.processCount)
                )
                miniMetric(title: AppL10n.text(.cpu, appLanguage: appLanguage), value: row.cpuText)
                miniMetric(title: AppL10n.text(.memory, appLanguage: appLanguage), value: row.memoryText)
            }

            if !row.metadataRows.isEmpty {
                metadataStack(row.metadataRows)
            }

            if !row.processRows.isEmpty {
                processStack(row.processRows)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(12)
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

    private func miniMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 7.5, weight: .black))
                .tracking(0.5)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
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
                        .frame(width: 46, alignment: .leading)
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
