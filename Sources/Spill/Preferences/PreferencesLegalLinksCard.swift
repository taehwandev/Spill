import SwiftUI

struct PreferencesLegalLinksCard: View {
    let language: SpillAppLanguage

    var body: some View {
        PreferenceCard(
            title: PreferencesLegalL10n.text(.legalAndPrivacy, appLanguage: language),
            symbolName: "hand.raised.fill",
            iconColor: .teal
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text(PreferencesLegalL10n.text(.legalAndPrivacyDetail, appLanguage: language))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                PreferencesLegalLinkButtons(
                    language: language,
                    source: "preferences_general",
                    style: .bordered
                )
            }
        }
    }
}
