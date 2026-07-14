import SwiftUI

struct TokenMeteringLocalSyncSettingsSection: View {
    @ObservedObject var settings: SpillSettings
    let language: TokenMeteringLanguage

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(key, language: language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TokenMeteringOptionHeader(
                title: t(.localSyncStatusTitle),
                state: t(.defaultState),
                systemImage: "slider.horizontal.3",
                tint: .blue
            )

            usageInputScopeRow

            Divider()

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t(.menuBarTokenDisplayModeTitle))
                        .font(.system(size: 12, weight: .bold))
                    Text(t(.menuBarTokenDisplayModeDetail))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Picker("", selection: $settings.menuBarTokenDisplayMode) {
                    ForEach(MenuBarTokenDisplayMode.allCases) { mode in
                        Text(mode.title(appLanguage: settings.appLanguage)).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 140)
            }
        }
        .padding(10)
        .background(tokenMeteringOptionBackground)
    }

    private var usageInputScopeRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 3) {
                    Text(t(.usageInputScopeTitle))
                        .font(.system(size: 12, weight: .bold))
                    TokenMeteringInfoButton(
                        title: t(.usageInputScopeInfoTitle),
                        detail: t(.usageInputScopeInfoDetail)
                    )
                }
                Text(t(.usageInputScopeDetail))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Picker("", selection: $settings.tokenUsageInputScope) {
                Text(t(.usageInputScopeIncludeCache))
                    .tag(TokenUsageInputScope.includeCache)
                Text(t(.usageInputScopeFreshOnly))
                    .tag(TokenUsageInputScope.freshOnly)
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 140)
            .accessibilityLabel(t(.usageInputScopeTitle))
        }
    }

    private var tokenMeteringOptionBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(NSColor.controlBackgroundColor).opacity(0.35))
    }
}
