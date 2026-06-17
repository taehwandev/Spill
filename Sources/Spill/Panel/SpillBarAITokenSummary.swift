import SwiftUI

struct SpillBarAITokenSummary: View {
    @ObservedObject var settings: SpillSettings
    @ObservedObject var tokenUsageDashboardStore: TokenUsageDashboardStore
    let onboardingPreviewEnabled: Bool
    let tokenMeteringSettingsAction: () -> Void
    let tokenMeteringDetailAction: () -> Void
    @State private var isHovered = false

    var body: some View {
        if onboardingPreviewEnabled {
            setupPreview
        } else {
            tokenSummary
        }
    }

    private var tokenSummary: some View {
        let snapshot = tokenUsageDashboardStore.panelSummary
        let displayTotalTokens = snapshot.totalTokens
        let topTask = snapshot.taskRows.first
        let topSource = snapshot.sourceRows.first

        return Button {
            tokenMeteringDetailAction()
        } label: {
            HStack(spacing: 10) {
                statusIconBadge(symbolName: "chart.bar.xaxis", tint: .teal)

                VStack(alignment: .leading, spacing: 5) {
                    tokenSummaryHeader

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(TokenUsageDashboardSnapshot.formatTokens(displayTotalTokens))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .monospacedDigit()

                        Text(AppL10n.text(.tokens, appLanguage: settings.appLanguage))
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Text(tokenMeteringSubtitle(topTask: topTask, topSource: topSource, eventCount: snapshot.eventCount))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .foregroundStyle(.secondary)

                    if displayTotalTokens > 0 {
                        toolDistributionBar(rows: snapshot.toolRows)
                    }
                }

                Spacer(minLength: 8)

                Label(AppL10n.text(.details, appLanguage: settings.appLanguage), systemImage: "chevron.right")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minHeight: 80)
            .frame(maxWidth: .infinity)
            .scaleEffect(isHovered ? 1.012 : 1.0)
            .offset(y: isHovered ? -1.0 : 0)
            .background(tokenSummaryBackground)
            .overlay { tokenSummaryStroke }
            .shadow(
                color: Color.teal.opacity(isHovered ? 0.08 : 0.02),
                radius: isHovered ? 6 : 2,
                y: isHovered ? 3 : 1
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.72), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            tokenUsageDashboardStore.refreshPanelSummary()
        }
        .help(AppL10n.text(.openLocalTokenMeteringDetails, appLanguage: settings.appLanguage))
        .accessibilityLabel(
            AppL10n.tokenMeteringAccessibility(
                tokenCount: TokenUsageDashboardSnapshot.formatTokens(displayTotalTokens),
                appLanguage: settings.appLanguage
            )
        )
    }

    private var setupPreview: some View {
        Button {
            tokenMeteringSettingsAction()
        } label: {
            HStack(spacing: 10) {
                statusIconBadge(symbolName: "wand.and.stars", tint: .orange)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(AppL10n.text(.tokenMeteringSetupTitle, appLanguage: settings.appLanguage))
                            .font(.system(size: 11.5, weight: .semibold))
                            .lineLimit(1)

                        Text(AppL10n.text(.need, appLanguage: settings.appLanguage))
                            .font(.system(size: 8.5, weight: .bold))
                            .padding(.horizontal, 5)
                            .frame(height: 17)
                            .foregroundStyle(.orange)
                            .background(.orange.opacity(0.12), in: Capsule())
                    }

                    Text(AppL10n.text(.tokenMeteringSetupDetail, appLanguage: settings.appLanguage))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Label(AppL10n.text(.tokenMeteringSettings, appLanguage: settings.appLanguage), systemImage: "gearshape.fill")
                    .font(.system(size: 10, weight: .bold))
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .foregroundStyle(.orange)
                    .background(.orange.opacity(0.12), in: Capsule())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minHeight: 74)
            .frame(maxWidth: .infinity)
            .background(.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.orange.opacity(0.14), lineWidth: 0.6)
            }
        }
        .buttonStyle(.plain)
        .help(AppL10n.text(.tokenMeteringSettings, appLanguage: settings.appLanguage))
        .accessibilityLabel(AppL10n.text(.tokenMeteringSetupTitle, appLanguage: settings.appLanguage))
    }

    private var tokenSummaryHeader: some View {
        HStack(spacing: 6) {
            Text(AppL10n.text(.tokenMetering, appLanguage: settings.appLanguage))
                .font(.system(size: 11.5, weight: .semibold))
                .lineLimit(1)

            Text(AppL10n.text(.local, appLanguage: settings.appLanguage))
                .font(.system(size: 8.5, weight: .bold))
                .padding(.horizontal, 5)
                .frame(height: 17)
                .foregroundStyle(.teal)
                .background(.teal.opacity(0.12), in: Capsule())

            Text(settings.menuBarTokenDisplayMode.title(appLanguage: settings.appLanguage))
                .font(.system(size: 8.5, weight: .semibold))
                .padding(.horizontal, 6)
                .frame(height: 17)
                .foregroundStyle(.secondary)
                .background(Color.primary.opacity(0.06), in: Capsule())
        }
    }

    private var tokenSummaryBackground: some View {
        ZStack {
            VisualEffectView(material: .sidebar, blendingMode: .withinWindow)
                .opacity(0.2)
            LinearGradient(
                colors: [
                    Color.teal.opacity(isHovered ? 0.08 : 0.04),
                    Color.blue.opacity(isHovered ? 0.04 : 0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if isHovered {
                Color.teal.opacity(0.04)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var tokenSummaryStroke: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: isHovered
                        ? [Color.teal.opacity(0.35), Color.blue.opacity(0.15)]
                        : [Color.teal.opacity(0.18), Color.blue.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.8
            )
    }

    @ViewBuilder
    private func toolDistributionBar(rows: [TokenUsageDashboardBarRow]) -> some View {
        let activeTools = rows.filter { $0.ratio > 0 }
        if !activeTools.isEmpty {
            GeometryReader { barGeo in
                HStack(spacing: 2) {
                    ForEach(activeTools) { row in
                        let color = toolColor(for: row.id)
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [color, color.opacity(0.75)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: Swift.max(CGFloat(2), (barGeo.size.width - CGFloat((activeTools.count - 1) * 2)) * CGFloat(row.ratio)))
                    }
                }
            }
            .frame(height: 3.5)
            .padding(.top, 2)
        }
    }

    private func tokenMeteringSubtitle(
        topTask: TokenUsageDashboardBarRow?,
        topSource: TokenUsageDashboardBarRow?,
        eventCount: Int
    ) -> String {
        guard eventCount > 0 else {
            return AppL10n.text(.openSetupPrompt, appLanguage: settings.appLanguage)
        }

        let task = topTask.map { "\($0.title) \($0.value)" }
            ?? AppL10n.text(.noTaskSplit, appLanguage: settings.appLanguage)
        let source = topSource.map { "\($0.title) \($0.value)" }
            ?? AppL10n.text(.noSourceSplit, appLanguage: settings.appLanguage)
        return AppL10n.eventsSummary(eventCount: eventCount, task: task, source: source, appLanguage: settings.appLanguage)
    }

    private func statusIconBadge(symbolName: String, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(tint.opacity(0.14))

            Image(systemName: symbolName)
                .font(.system(size: 17, weight: .bold))
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: 30, height: 30)
    }

    private func toolColor(for toolID: String) -> Color {
        TokenUsageAITool(rawValue: toolID.lowercased())?.dashboardTint ?? .secondary
    }
}
