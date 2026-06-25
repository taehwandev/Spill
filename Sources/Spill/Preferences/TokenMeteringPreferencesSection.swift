import AppKit
import SwiftUI

struct TokenMeteringPreferencesSection: View {
    @ObservedObject var settings: SpillSettings
    let tokenUsageStore: TokenUsageStore
    @ObservedObject var tokenHistoryImportCoordinator: TokenUsageHistoryImportCoordinator
    let openDashboardAction: () -> Void
    @StateObject private var privateUsageUploadStore: PrivateUsageUploadStore
    @State private var copiedTarget: String?
    @State private var adapterStatuses: [String: TokenMeteringAdapterConnectionStatus] = [:]

    init(
        settings: SpillSettings,
        tokenUsageStore: TokenUsageStore,
        tokenHistoryImportCoordinator: TokenUsageHistoryImportCoordinator,
        openDashboardAction: @escaping () -> Void
    ) {
        self.settings = settings
        self.tokenUsageStore = tokenUsageStore
        self.tokenHistoryImportCoordinator = tokenHistoryImportCoordinator
        self.openDashboardAction = openDashboardAction
        _privateUsageUploadStore = StateObject(
            wrappedValue: PrivateUsageUploadStore(
                settings: settings,
                usageStore: tokenUsageStore
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
                language: currentLanguage,
                copiedTarget: copiedTarget,
                adapterStatuses: adapterStatuses,
                copyToClipboardAction: copyToClipboard
            )

            // Step 2: Local history import (Optional)
            historyImportSection

            // Local sync status & display settings
            localSyncAndDisplaySettingsSection

            // Local & Cloud Sync Mode List
            VStack(spacing: 8) {
                ForEach(TokenMeteringPreferencesModel.modes) { mode in
                    TokenMeteringModeRow(mode: mode)
                }
            }

            if PrivateUsageUploadFeatureAvailability.isEnabledInCurrentBuild {
                privateUsageUploadSection
            }

            privacyBoundarySection
        }
        .onAppear {
            refreshAdapterStatuses()
            refreshPrivateUsageUploadIfAvailable()
        }
        .onReceive(NotificationCenter.default.publisher(for: TokenUsageStore.eventsDidChangeNotification)) { _ in
            refreshPrivateUsageUploadIfAvailable()
        }
        .onChange(of: settings.privateUsageUploadEnabled) { _, _ in
            refreshPrivateUsageUploadIfAvailable()
        }
    }
}

private extension TokenMeteringPreferencesSection {
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

    private var privateUsageUploadSection: some View {
        PrivateUsageUploadPreferencesSection(
            settings: settings,
            store: privateUsageUploadStore,
            language: currentLanguage,
            webConnectionURL: privateUsageWebConnectionURL,
            openWebConnectionAction: openPrivateUsageWebConnection
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
        guard let url = privateUsageWebConnectionURL else {
            return
        }

        privateUsageUploadStore.beginWebConnectionAttempt()
        NSWorkspace.shared.open(url)
    }

    private var privateUsageWebConnectionURL: URL? {
        PrivateUsageWebConnection.connectDeviceURL()
    }

    private func refreshAdapterStatuses() {
        adapterStatuses = Dictionary(
            uniqueKeysWithValues: TokenMeteringAdapterKit.hookAdapters.map { adapter in
                (adapter.id, TokenMeteringAdapterConnectionDiagnostics.status(for: adapter))
            }
        )
    }

    private var historyImportSection: some View {
        TokenUsageHistoryImportSection(
            snapshot: tokenHistoryImportCoordinator.snapshot,
            language: currentLanguage,
            startAllAction: {
                tokenHistoryImportCoordinator.startImport()
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
