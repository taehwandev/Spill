import SwiftUI

struct OpenSourceFooter: View {
    let language: SpillAppLanguage
    let openSourceLinkAction: (String) -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                footerButton(
                    title: t(.feedbackContribution),
                    symbolName: "hand.thumbsup.fill",
                    source: "feedback"
                )

                Text("•")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary.opacity(0.5))

                footerButton(
                    title: t(.githubOpenSource),
                    symbolName: "arrow.up.forward.app.fill",
                    source: "github"
                )
            }

            Text(t(.openSourceLicense))
                .font(.system(size: 11))
                .foregroundStyle(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 8)
    }

    private func footerButton(title: String, symbolName: String, source: String) -> some View {
        Button {
            openSourceLinkAction(source)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: symbolName)
                    .font(.system(size: 11))
                Text(title)
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    private func t(_ key: PreferencesTextKey) -> String {
        PreferencesL10n.text(key, appLanguage: language)
    }
}
