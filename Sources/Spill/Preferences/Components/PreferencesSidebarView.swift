import SwiftUI

struct PreferencesSidebarView: View {
    let language: SpillAppLanguage
    let currentVersion: String
    @ObservedObject var navigationState: PreferencesNavigationState
    @State private var hoveredTab: PreferencesTab?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brandHeader
            navigationList
            Spacer()
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
            markStyle: .spill,
            iconSize: 26,
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
            ForEach(PreferencesTab.available) { tab in
                PreferencesSidebarItem(
                    title: t(tab.sidebarTitleKey),
                    tab: tab,
                    navigationState: navigationState,
                    hoveredTab: $hoveredTab
                )
            }
        }
        .padding(.horizontal, 8)
    }

    private func t(_ key: PreferencesTextKey) -> String {
        PreferencesL10n.text(key, appLanguage: language)
    }
}

private struct PreferencesSidebarItem: View {
    let title: String
    let tab: PreferencesTab
    @ObservedObject var navigationState: PreferencesNavigationState
    @Binding var hoveredTab: PreferencesTab?

    var body: some View {
        let isSelected = navigationState.selectedTab == tab
        let isHovered = hoveredTab == tab

        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                navigationState.selectedTab = tab
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: tab.symbolName)
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
                hoveredTab = hovering ? tab : nil
            }
        }
    }
}
