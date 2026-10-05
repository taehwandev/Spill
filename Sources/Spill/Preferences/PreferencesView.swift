import SwiftUI

struct PreferencesView: View {
    @ObservedObject var settings: SpillSettings
    @ObservedObject var updateStore: UpdateCheckStore
    @ObservedObject var navigationState: PreferencesNavigationState
    let tokenUsageStore: TokenUsageStore
    @ObservedObject var tokenHistoryImportCoordinator: TokenUsageHistoryImportCoordinator
    @ObservedObject var aiStatusStore: AIStatusStore
    let openTokenDashboardAction: () -> Void
    let preparePrivateUsageUploadAction: @MainActor () async -> Void
    @State private var accessibilityTrusted = AccessibilityPermission.isTrusted
    @State private var loginItemError: String?

    private func t(_ key: PreferencesTextKey) -> String {
        PreferencesL10n.text(key, appLanguage: settings.appLanguage)
    }

    var body: some View {
        HStack(spacing: 0) {
            PreferencesSidebarView(
                language: settings.appLanguage,
                currentVersion: updateStore.currentVersion,
                navigationState: navigationState
            )

            Divider()
                .background(Color.primary.opacity(0.08))

            // Right Detail Panel
            VStack(alignment: .leading, spacing: 0) {
                // Top Tab Title
                HStack {
                    Text(t(navigationState.selectedTab.pageTitleKey))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 14)

                // Scrollable Content
                ScrollView(.vertical) {
                    detailContent(for: navigationState.selectedTab)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                VisualEffectView(material: .windowBackground, blendingMode: .withinWindow)
            )
        }
        .background(VisualEffectView(material: .sidebar, blendingMode: .withinWindow)) // Frosted Glass Window Base
        .frame(width: 720, height: 560)
        .onAppear {
            refreshPermissionState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissionState()
        }
    }
}

private extension PreferencesView {
    @ViewBuilder
    private func detailContent(for tab: PreferencesTab) -> some View {
        switch tab {
        case .general:
            GeneralPreferencesSection(
                settings: settings,
                updateStore: updateStore,
                loginItemError: $loginItemError,
                language: settings.appLanguage
            )
        case .menuBar:
            MenuBarPreferencesSection(
                settings: settings,
                language: settings.appLanguage
            )
        case .tokenMetering:
            PreferenceCard(title: t(.tokenMetering), symbolName: tab.symbolName, iconColor: .teal) {
                TokenMeteringPreferencesSection(
                    settings: settings,
                    tokenUsageStore: tokenUsageStore,
                    tokenHistoryImportCoordinator: tokenHistoryImportCoordinator,
                    aiStatusStore: aiStatusStore,
                    openDashboardAction: openTokenDashboardAction,
                    preparePrivateUsageUploadAction: preparePrivateUsageUploadAction
                )
            }
        case .windowManagement:
            WindowManagementPreferencesSection(
                settings: settings,
                accessibilityTrusted: $accessibilityTrusted,
                language: settings.appLanguage
            )
        case .statusCaffeine:
            StatusCaffeinePreferencesSection(
                settings: settings,
                language: settings.appLanguage
            )
        case .developer where tab.isAvailable:
            DeveloperOptionsPreferencesSection(
                settings: settings,
                tokenUsageStore: tokenUsageStore,
                language: settings.appLanguage
            )
        case .developer:
            EmptyView()
        }
    }

    private func refreshPermissionState() {
        accessibilityTrusted = AccessibilityPermission.isTrusted
    }
}
