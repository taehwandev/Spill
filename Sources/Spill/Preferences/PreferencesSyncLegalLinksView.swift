import SwiftUI

struct PreferencesSyncLegalLinksView: View {
    let language: SpillAppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(PreferencesLegalL10n.text(.syncDataLegalDetail, appLanguage: language))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            PreferencesLegalLinkButtons(
                language: language,
                source: "preferences_private_usage_upload",
                style: .accent
            )
        }
        .padding(.top, 2)
    }
}
