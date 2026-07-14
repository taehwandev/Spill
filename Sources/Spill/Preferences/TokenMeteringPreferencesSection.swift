import AppKit
import SwiftUI

struct TokenMeteringPreferencesSection: View {
    @ObservedObject var settings: SpillSettings
    let tokenUsageStore: TokenUsageStore
    @ObservedObject var tokenHistoryImportCoordinator: TokenUsageHistoryImportCoordinator
    @ObservedObject var aiStatusStore: AIStatusStore
    let openDashboardAction: () -> Void
    let preparePrivateUsageUploadAction: @MainActor () async -> Void
    @StateObject private var privateUsageUploadStore: PrivateUsageUploadStore
    @ObservedObject private var setupActionStore = TokenMeteringSetupActionStore.shared
    @State private var copiedTarget: String?
    @State private var adapterStatuses: [String: TokenMeteringAdapterConnectionStatus] = [:]
    @State private var adapterStatusRefreshTask: Task<Void, Never>?
    @State private var adapterStatusRefreshGeneration = 0

    init(
        settings: SpillSettings,
        tokenUsageStore: TokenUsageStore,
        tokenHistoryImportCoordinator: TokenUsageHistoryImportCoordinator,
        aiStatusStore: AIStatusStore,
        openDashboardAction: @escaping () -> Void,
        preparePrivateUsageUploadAction: @escaping @MainActor () async -> Void = {}
    ) {
        self.settings = settings
        self.tokenUsageStore = tokenUsageStore
        self.tokenHistoryImportCoordinator = tokenHistoryImportCoordinator
        self.aiStatusStore = aiStatusStore
        self.openDashboardAction = openDashboardAction
        self.preparePrivateUsageUploadAction = preparePrivateUsageUploadAction
        _privateUsageUploadStore = StateObject(
            wrappedValue: PrivateUsageUploadStore(
                settings: settings,
                usageStore: tokenUsageStore,
                prepareForUpload: preparePrivateUsageUploadAction
            )
        )
    }

    private var currentLanguage: TokenMeteringLanguage {
        TokenMeteringLanguage.current(appLanguage: settings.appLanguage)
    }

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(key, language: currentLanguage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(t(.preferencesTitle))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)

                Text(t(.preferencesSubtitle))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TokenMeteringSetupSection(
                setupActionStore: setupActionStore,
                installedTools: installedTokenTools,
                language: currentLanguage,
                copiedTarget: copiedTarget,
                adapterStatuses: adapterStatuses,
                copyToClipboardAction: copyToClipboard
            )

            // Step 2: Local history import (Optional)
            historyImportSection

            // Local sync status & display settings
            localSyncAndDisplaySettingsSection

            aiToolVisibilitySection

            if PrivateUsageUploadFeatureAvailability.isEnabledInCurrentBuild {
                privateUsageUploadSection
            }

            privacyBoundarySection
        }
        .onAppear {
            aiStatusStore.refreshInBackground()
            refreshAdapterStatuses()
            refreshPrivateUsageUploadIfAvailable()
        }
        .onDisappear {
            adapterStatusRefreshTask?.cancel()
            adapterStatusRefreshTask = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: TokenUsageStore.eventsDidChangeNotification)) { _ in
            refreshPrivateUsageUploadIfAvailable()
        }
        .onChange(of: settings.privateUsageUploadEnabled) { _, _ in
            refreshPrivateUsageUploadIfAvailable()
        }
        .onChange(of: setupActionStore.operationState) { _, state in
            if state == .succeeded {
                refreshAdapterStatuses()
            }
        }
    }
}

private extension TokenMeteringPreferencesSection {
    private var installedTokenTools: Set<TokenUsageAITool> {
        TokenMeteringToolAvailability.installedTools(from: aiStatusStore.statuses)
    }

    private var localSyncAndDisplaySettingsSection: some View {
        TokenMeteringLocalSyncSettingsSection(
            settings: settings,
            language: currentLanguage,
            copiedTarget: copiedTarget,
            copyInboxPathAction: { path in
                copyToClipboard(path, target: "inbox")
            }
        )
    }

    private var aiToolVisibilitySection: some View {
        TokenMeteringAIToolVisibilitySection(
            settings: settings,
            aiStatusStore: aiStatusStore,
            language: currentLanguage
        )
    }

    private var privateUsageUploadSection: some View {
        PrivateUsageUploadPreferencesSection(
            settings: settings,
            store: privateUsageUploadStore,
            language: currentLanguage,
            webConnectionURL: privateUsageWebConnectionURL,
            webDashboardURL: privateUsageWebDashboardURL,
            openWebConnectionAction: openPrivateUsageWebConnection,
            openWebDashboardAction: openPrivateUsageWebDashboard
        )
    }

    private var privacyBoundarySection: some View {
        TokenMeteringPrivacyBoundarySection(language: currentLanguage)
    }

    private func copyToClipboard(_ text: String, target: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedTarget = target

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            if copiedTarget == target {
                copiedTarget = nil
            }
        }
    }

    private func refreshPrivateUsageUploadIfAvailable() {
        guard PrivateUsageUploadFeatureAvailability.isEnabledInCurrentBuild else {
            return
        }

        privateUsageUploadStore.refresh()
    }

    private func openPrivateUsageWebConnection() {
        guard !privateUsageUploadStore.status.isConnected else {
            privateUsageUploadStore.refresh()
            return
        }

        guard let url = privateUsageWebConnectionURL else {
            return
        }

        privateUsageUploadStore.beginWebConnectionAttempt()
        NSWorkspace.shared.open(url)
    }

    private var privateUsageWebConnectionURL: URL? {
        PrivateUsageWebConnection.connectDeviceURL()
    }

    private func openPrivateUsageWebDashboard() {
        guard let url = privateUsageWebDashboardURL else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private var privateUsageWebDashboardURL: URL? {
        PrivateUsageWebConnection.dashboardURL()
    }
}

private extension TokenMeteringPreferencesSection {
    private func refreshAdapterStatuses() {
        adapterStatusRefreshTask?.cancel()
        adapterStatusRefreshGeneration += 1
        let generation = adapterStatusRefreshGeneration
        let installedTools = installedTokenTools
        adapterStatusRefreshTask = Task {
            let statuses = await Task.detached(priority: .utility) {
                Dictionary(
                    uniqueKeysWithValues: TokenMeteringAdapterKit.localRuntimeAdapters.map { adapter in
                        (
                            adapter.id,
                            TokenMeteringSetupInstallationDiagnostics.connectionStatus(
                                for: adapter.aiTool,
                                runtimeInstalled: installedTools.contains(adapter.aiTool)
                            )
                        )
                    }
                )
            }.value

            await MainActor.run {
                guard !Task.isCancelled,
                      adapterStatusRefreshGeneration == generation
                else {
                    return
                }
                adapterStatuses = statuses
            }
        }
    }

    private var historyImportSection: some View {
        let installedTools = TokenMeteringToolAvailability.installedHistoryImportTools(
            from: aiStatusStore.statuses
        )
        return TokenUsageHistoryImportSection(
            snapshot: tokenHistoryImportCoordinator.snapshot,
            availableTools: installedTools,
            language: currentLanguage,
            startAllAction: {
                tokenHistoryImportCoordinator.startImport(for: installedTools)
            },
            cancelAction: {
                tokenHistoryImportCoordinator.cancelImport()
            },
            startToolAction: { tool in
                tokenHistoryImportCoordinator.startImport(for: tool)
            }
        )
    }
}
