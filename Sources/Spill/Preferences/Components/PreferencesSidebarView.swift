import SwiftUI

struct PreferencesSidebarView: View {
    let language: SpillAppLanguage
    let currentVersion: String
    let isCheckingForUpdates: Bool
    @ObservedObject var navigationState: PreferencesNavigationState
    let checkForUpdatesAction: () -> Void
    @State private var hoveredTab: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brandHeader
            navigationList
            Spacer()
            updateButton
        }
        .frame(width: 170)
        .background(
            LinearGradient(
                colors: [
                    Color.primary.opacity(0.005),
                    Color.primary.opacity(0.02)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var brandHeader: some View {
        SpillBrandLockupView(
            subtitle: "v\(currentVersion)",
            iconSize: 32,
            titleFontSize: 15,
            titleWeight: .bold,
            subtitleFontSize: 12,
            subtitleWeight: .semibold,
            subtitleDesign: .monospaced,
            subtitleColor: .secondary,
            spacing: 10
        )
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    private var navigationList: some View {
        VStack(spacing: 4) {
            sidebarItem(title: t(.general), imageName: "gearshape.fill", tag: "general")
            sidebarItem(title: t(.menuBar), imageName: "menubar.rectangle", tag: "menubar")
            sidebarItem(title: t(.tokenMetering), imageName: "chart.bar.xaxis", tag: "tokens")
            sidebarItem(title: t(.windowManagement), imageName: "macwindow", tag: "windows")
            sidebarItem(title: t(.statusAndCaffeine), imageName: "cup.and.saucer.fill", tag: "status_caffeine")
            if SpillBuildOptions.developerOptionsEnabled {
                sidebarItem(title: t(.developerOptions), imageName: "hammer.fill", tag: "developer")
            }
        }
        .padding(.horizontal, 8)
    }

    private var updateButton: some View {
        VStack(spacing: 8) {
            Divider()
                .background(Color.primary.opacity(0.06))
                .padding(.horizontal, 12)

            Button(action: checkForUpdatesAction) {
                HStack(spacing: 6) {
                    if isCheckingForUpdates {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.7)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    Text(isCheckingForUpdates ? t(.checkingForUpdates) : t(.checkForUpdates))
                        .font(.system(size: 12, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
    }

    private func sidebarItem(title: String, imageName: String, tag: String) -> some View {
        PreferencesSidebarItem(
            title: title,
            imageName: imageName,
            tag: tag,
            navigationState: navigationState,
            hoveredTab: $hoveredTab
        )
    }

    private func t(_ key: PreferencesTextKey) -> String {
        PreferencesL10n.text(key, appLanguage: language)
    }
}

private struct PreferencesSidebarItem: View {
    let title: String
    let imageName: String
    let tag: String
    @ObservedObject var navigationState: PreferencesNavigationState
    @Binding var hoveredTab: String?

    var body: some View {
        let isSelected = navigationState.selectedTab == tag
        let isHovered = hoveredTab == tag

        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                navigationState.selectedTab = tag
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: imageName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : (isHovered ? .primary : .primary.opacity(0.65)))
                    .frame(width: 16, height: 16)
                    .scaleEffect(isHovered && !isSelected ? 1.08 : 1.0)

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .white : (isHovered ? .primary : .primary.opacity(0.85)))

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.82)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.accentColor.opacity(0.24), radius: 4, x: 0, y: 1.5)
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
                }
            }
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                hoveredTab = hovering ? tag : nil
            }
        }
    }
}
