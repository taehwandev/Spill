import SwiftUI

struct StatusCaffeinePreferencesSection: View {
    @ObservedObject var settings: SpillSettings
    let language: SpillAppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PreferenceCard(title: t(.panelStatus), symbolName: "waveform.path.ecg", iconColor: .purple) {
                PanelStatusPreferencesSection(settings: settings)
            }

            PreferenceCard(title: t(.caffeineSettings), symbolName: "cup.and.saucer.fill", iconColor: .orange) {
                PowerPreferencesSection(settings: settings)
            }
        }
    }

    private func t(_ key: PreferencesTextKey) -> String {
        PreferencesL10n.text(key, appLanguage: language)
    }
}
