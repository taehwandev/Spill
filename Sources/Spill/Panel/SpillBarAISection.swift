import SwiftUI

struct SpillBarAISection: View {
    @ObservedObject var settings: SpillSettings
    @ObservedObject var aiStatusStore: AIStatusStore
    @ObservedObject var cloudServiceStatusStore: CloudServiceStatusStore
    @ObservedObject var tokenUsageDashboardStore: TokenUsageDashboardStore
    let tokenMeteringDetailAction: () -> Void
    @State private var showsServiceStatusDashboard = false

    var body: some View {
        VStack(spacing: 7) {
            aiSectionHeader

            SpillBarAITokenSummary(
                settings: settings,
                tokenUsageDashboardStore: tokenUsageDashboardStore,
                tokenMeteringDetailAction: tokenMeteringDetailAction
            )
        }
    }
}

private extension SpillBarAISection {
    private var aiSectionHeader: some View {
        HStack(spacing: 8) {
            Text("AI")
                .font(.system(size: 9.5, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(.secondary.opacity(0.7))

            if !visibleStatuses.isEmpty {
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
        let activeKinds = Set(visibleStatuses.flatMap {
            CloudServiceStatusPresentation.serviceKinds(for: $0.kind)
        })
        guard !activeKinds.isEmpty else { return snapshot }
        let filtered = snapshot.items.filter { activeKinds.contains($0.kind) }
        return CloudServiceStatusSnapshot(fetchedAt: snapshot.fetchedAt, items: filtered)
    }

    private var runningToolCount: Int {
        visibleStatuses.filter(\.hasRunningProcesses).count
    }

    private var runningProcessCount: Int {
        visibleStatuses.reduce(0) { $0 + $1.processSummary.processCount }
    }

    private var visibleStatuses: [LocalAIToolStatus] {
        aiStatusStore.statuses.filter { status in
            status.kind.isTokenDashboardAgentTool
                && settings.isLocalAIToolVisible(status.kind)
        }
    }
}
