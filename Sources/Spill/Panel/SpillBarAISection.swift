import SwiftUI

struct SpillBarAISection: View {
    @ObservedObject var panelStore: PanelStore
    @ObservedObject var settings: SpillSettings
    @ObservedObject var aiStatusStore: AIStatusStore
    @ObservedObject var cloudServiceStatusStore: CloudServiceStatusStore
    @ObservedObject var tokenUsageDashboardStore: TokenUsageDashboardStore
    let onboardingPreviewEnabled: Bool
    let tokenMeteringSettingsAction: () -> Void
    let tokenMeteringDetailAction: () -> Void
    @State private var showsServiceStatusDashboard = false

    var body: some View {
        VStack(spacing: 7) {
            aiSectionHeader

            SpillBarAITokenSummary(
                settings: settings,
                tokenUsageDashboardStore: tokenUsageDashboardStore,
                onboardingPreviewEnabled: onboardingPreviewEnabled,
                tokenMeteringSettingsAction: tokenMeteringSettingsAction,
                tokenMeteringDetailAction: tokenMeteringDetailAction
            )

            if !aiStatusStore.statuses.isEmpty {
                LazyVGrid(columns: aiToolColumns, alignment: .leading, spacing: 7) {
                    ForEach(aiStatusStore.statuses) { status in
                        let serviceStatus = serviceStatus(for: status.kind)
                        let helpText = aiToolHelpText(status, serviceStatus: serviceStatus)

                        Button {
                            panelStore.send(.setStatusDetailTarget(.ai(status.kind)))
                        } label: {
                            SpillBarAIToolCard(
                                status: status,
                                serviceStatus: serviceStatus,
                                tokenUsage: toolTokenUsage(for: status.kind),
                                appLanguage: settings.appLanguage,
                                isServerStatusLoading: cloudServiceStatusStore.isLoading
                            )
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: detailBinding(for: .ai(status.kind)), arrowEdge: .top) {
                            aiStatusDetailPopover(for: status)
                        }
                        .help(helpText)
                        .accessibilityLabel(helpText)
                    }
                }
            }
        }
    }

    private var aiToolColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 0), spacing: 7),
            GridItem(.flexible(minimum: 0), spacing: 7)
        ]
    }

    private var aiSectionHeader: some View {
        HStack(spacing: 8) {
            Text("AI")
                .font(.system(size: 9.5, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(.secondary.opacity(0.7))

            if !aiStatusStore.statuses.isEmpty {
                Text(AppL10n.aiProcessSummary(
                    runningToolCount: runningToolCount,
                    processCount: runningProcessCount,
                    appLanguage: settings.appLanguage
                ))
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary.opacity(0.7))
                .monospacedDigit()
            }

            Spacer()

            CloudServiceStatusButton(
                state: serviceStatusControlState,
                appLanguage: settings.appLanguage,
                height: 22,
                fontSize: 9.5,
                horizontalPadding: 7
            ) {
                showsServiceStatusDashboard = true
                cloudServiceStatusStore.refreshIfNeeded()
            }
            .popover(isPresented: $showsServiceStatusDashboard, arrowEdge: .top) {
                CloudServiceStatusDashboardView(store: cloudServiceStatusStore)
            }

            Image(systemName: "sparkles")
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(.secondary.opacity(0.7))
        }
    }

    private var serviceStatusControlState: CloudServiceStatusControlState {
        CloudServiceStatusPresentation.controlState(
            snapshot: activeToolsCloudSnapshot,
            isLoading: cloudServiceStatusStore.isLoading,
            appLanguage: settings.appLanguage
        )
    }

    private var activeToolsCloudSnapshot: CloudServiceStatusSnapshot? {
        guard let snapshot = cloudServiceStatusStore.snapshot else { return nil }
        let activeKinds = Set(aiStatusStore.statuses.flatMap {
            CloudServiceStatusPresentation.serviceKinds(for: $0.kind)
        })
        guard !activeKinds.isEmpty else { return snapshot }
        let filtered = snapshot.items.filter { activeKinds.contains($0.kind) }
        return CloudServiceStatusSnapshot(fetchedAt: snapshot.fetchedAt, items: filtered)
    }

    private var runningToolCount: Int {
        aiStatusStore.statuses.filter(\.hasRunningProcesses).count
    }

    private var runningProcessCount: Int {
        aiStatusStore.statuses.reduce(0) { $0 + $1.processSummary.processCount }
    }

    private func serviceStatus(for kind: LocalAIToolKind) -> CloudServiceStatusItem? {
        CloudServiceStatusPresentation.serviceStatus(
            for: kind,
            in: cloudServiceStatusStore.snapshot
        )
    }

    private func toolTokenUsage(for kind: LocalAIToolKind) -> SpillBarAIToolTokenUsage {
        let snapshot = tokenUsageDashboardStore.panelSummary
        let rawValue = tokenUsageRawValue(for: kind)

        if let row = snapshot.toolRows.first(where: { $0.id == rawValue }) {
            return SpillBarAIToolTokenUsage(value: row.value, ratio: row.ratio)
        }
        return SpillBarAIToolTokenUsage(value: "0", ratio: 0)
    }

    private func tokenUsageRawValue(for kind: LocalAIToolKind) -> String {
        switch kind {
        case .codex:
            return TokenUsageAITool.codex.rawValue
        case .claude:
            return TokenUsageAITool.claude.rawValue
        case .antigravity:
            return TokenUsageAITool.antigravity.rawValue
        case .openAI:
            return TokenUsageAITool.openAI.rawValue
        case .ollama:
            return "ollama"
        }
    }

    private func detailBinding(for target: SpillStatusDetailTarget) -> Binding<Bool> {
        Binding {
            panelStore.state.statusDetailTarget == target
        } set: { isPresented in
            if isPresented {
                panelStore.send(.setStatusDetailTarget(target))
            } else if panelStore.state.statusDetailTarget == target {
                panelStore.send(.setStatusDetailTarget(nil))
            }
        }
    }

    private func aiStatusDetailPopover(for status: LocalAIToolStatus) -> some View {
        SpillStatusDetailPopover(
            title: status.title,
            symbolName: status.symbolName,
            tint: aiStatusDetailTint(for: status),
            rows: SpillStatusDetailRows.rows(for: status),
            showsInMenuBar: nil
        )
    }

    private func aiStatusDetailTint(for status: LocalAIToolStatus) -> Color {
        switch status.state {
        case .warning, .unavailable:
            return status.state.panelTint
        case .active, .normal, .refreshing:
            return status.kind.dashboardTint
        }
    }

    private func statusHelpText(title: String, value: String, subtitle: String?) -> String {
        var parts = [title, value]

        if let subtitle, !subtitle.isEmpty {
            parts.append(subtitle)
        }

        return parts.joined(separator: " - ")
    }

    private func aiToolHelpText(_ status: LocalAIToolStatus, serviceStatus: CloudServiceStatusItem?) -> String {
        var text = statusHelpText(title: status.title, value: status.value, subtitle: status.subtitle)

        if let serviceStatus {
            text += " - \(AppL10n.text(.server, appLanguage: settings.appLanguage)) \(serviceStatus.health.serverStatusHeaderTitle)"
        }

        return text
    }
}
