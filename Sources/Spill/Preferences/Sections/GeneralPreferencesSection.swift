import AppKit
import SwiftUI

struct GeneralPreferencesSection: View {
    @ObservedObject var settings: SpillSettings
    @ObservedObject var scanner: AXMenuBarItemScanner
    @ObservedObject var updateStore: UpdateCheckStore
    @Binding var accessibilityTrusted: Bool
    @Binding var loginItemError: String?
    let showPanelAction: () -> Void
    let language: SpillAppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            launchSettingsCard
            languageSettingsCard
            appearanceSettingsCard
            permissionsCard
            updatesCard
            legalAndPrivacyCard

            Divider()
                .background(Color.primary.opacity(0.04))

            openSourceFooter
        }
    }
}

private extension GeneralPreferencesSection {
    private var launchSettingsCard: some View {
        PreferenceCard(title: t(.launchSettings), symbolName: "play.circle.fill", iconColor: .blue) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(t(.launchAtLogin), isOn: launchAtLoginBinding)
                    .disabled(!LoginItemController.isAvailable)
                    .font(.system(size: 13, weight: .medium))

                if !LoginItemController.isAvailable {
                    Text(t(.launchAtLoginUnavailable))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                if let loginItemError {
                    Text(loginItemError)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var languageSettingsCard: some View {
        PreferenceCard(title: t(.languageSettings), symbolName: "globe", iconColor: .purple) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(t(.appLanguage))
                        .font(.system(size: 13, weight: .medium))

                    Spacer()

                    Picker("", selection: $settings.appLanguage) {
                        ForEach(SpillAppLanguage.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }

                Text(PreferencesL10n.languageDetail(settings.appLanguage, appLanguage: settings.appLanguage))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var appearanceSettingsCard: some View {
        PreferenceCard(title: t(.appearanceSettings), symbolName: "circle.lefthalf.filled", iconColor: .indigo) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(t(.appearanceTheme))
                        .font(.system(size: 13, weight: .medium))

                    Spacer()

                    Picker("", selection: $settings.appearanceTheme) {
                        ForEach(SpillAppearanceTheme.allCases) { theme in
                            Text(theme.title(appLanguage: language)).tag(theme)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }

                Text(t(.appearanceThemeDetail))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var permissionsCard: some View {
        PreferenceCard(title: t(.permissionsAndDiagnostics), symbolName: "lock.shield.fill", iconColor: .green) {
            AccessibilityPreferencesSection(
                scanner: scanner,
                accessibilityTrusted: $accessibilityTrusted,
                showPanelAction: showPanelAction
            )
        }
    }

    private var updatesCard: some View {
        PreferenceCard(title: t(.updates), symbolName: "arrow.down.circle.fill", iconColor: .orange) {
            UpdatePreferencesSection(store: updateStore)
        }
    }
}

private extension GeneralPreferencesSection {
    private var legalAndPrivacyCard: some View {
        PreferencesLegalLinksCard(language: language)
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding {
            settings.launchAtLogin
        } set: { enabled in
            do {
                try LoginItemController.setEnabled(enabled)
                settings.launchAtLogin = LoginItemController.isEnabled
                loginItemError = nil
            } catch {
                settings.launchAtLogin = LoginItemController.isEnabled
                loginItemError = error.localizedDescription
            }
        }
    }

    private func openSourceLink(source: String) {
        SpillTelemetry.shared.track(
            "open_source_link_clicked",
            props: ["source": "preferences_\(source)"]
        )
        if let url = URL(string: "https://github.com/taehwandev/Spill") {
            NSWorkspace.shared.open(url)
        }
    }

    private var openSourceFooter: some View {
        OpenSourceFooter(language: language, openSourceLinkAction: openSourceLink)
    }

    private func t(_ key: PreferencesTextKey) -> String {
        PreferencesL10n.text(key, appLanguage: language)
    }
}
