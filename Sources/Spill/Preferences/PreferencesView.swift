import SwiftUI

struct PreferencesView: View {
    @ObservedObject var settings: SpillSettings
    @ObservedObject var scanner: AXMenuBarItemScanner
    @ObservedObject var updateStore: UpdateCheckStore
    @ObservedObject var navigationState: PreferencesNavigationState
    let tokenUsageStore: TokenUsageStore
    @ObservedObject var tokenHistoryImportCoordinator: TokenUsageHistoryImportCoordinator
    @ObservedObject var aiStatusStore: AIStatusStore
    let showPanelAction: () -> Void
    let openTokenDashboardAction: () -> Void
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
                isCheckingForUpdates: updateStore.isChecking,
                navigationState: navigationState,
                checkForUpdatesAction: {
                    updateStore.checkForUpdates(source: "preferences_sidebar")
                }
            )

            Divider()
                .background(Color.primary.opacity(0.08))

            // Right Detail Panel
            VStack(alignment: .leading, spacing: 0) {
                // Top Tab Title
                HStack {
                    Text(tabTitle(for: navigationState.selectedTab))
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
    private func tabTitle(for tab: String) -> String {
        switch tab {
        case "general": return t(.general)
        case "menubar": return t(.menuBarAndNotch)
        case "tokens": return t(.tokenMetering)
        case "windows": return t(.windowManagement)
        case "status_caffeine": return t(.statusAndCaffeine)
        case "developer" where SpillBuildOptions.developerOptionsEnabled:
            return t(.developerOptions)
        default: return ""
        }
    }

    @ViewBuilder
    private func detailContent(for tab: String) -> some View {
        switch tab {
        case "general":
            GeneralPreferencesSection(
                settings: settings,
                scanner: scanner,
                updateStore: updateStore,
                accessibilityTrusted: $accessibilityTrusted,
                loginItemError: $loginItemError,
                showPanelAction: showPanelAction,
                language: settings.appLanguage
            )
        case "menubar":
            MenuBarPreferencesSection(
                settings: settings,
                language: settings.appLanguage
            )
        case "tokens":
            PreferenceCard(title: t(.tokenMetering), symbolName: "chart.bar.xaxis", iconColor: .teal) {
                TokenMeteringPreferencesSection(
                    settings: settings,
                    tokenUsageStore: tokenUsageStore,
                    tokenHistoryImportCoordinator: tokenHistoryImportCoordinator,
                    aiStatusStore: aiStatusStore,
                    openDashboardAction: openTokenDashboardAction
                )
            }
        case "windows":
            WindowManagementPreferencesSection(
                settings: settings,
                language: settings.appLanguage
            )
        case "status_caffeine":
            StatusCaffeinePreferencesSection(
                settings: settings,
                language: settings.appLanguage
            )
        case "developer" where SpillBuildOptions.developerOptionsEnabled:
            DeveloperOptionsPreferencesSection(
                settings: settings,
                tokenUsageStore: tokenUsageStore,
                language: settings.appLanguage
            )
        default:
            EmptyView()
        }
    }

    private func refreshPermissionState() {
        accessibilityTrusted = AccessibilityPermission.isTrusted
    }
}
