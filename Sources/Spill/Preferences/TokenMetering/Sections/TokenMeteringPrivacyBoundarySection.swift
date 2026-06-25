import SwiftUI

struct TokenMeteringPrivacyBoundarySection: View {
    let language: TokenMeteringLanguage

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(key, language: language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TokenMeteringOptionHeader(
                title: t(.neverCollectedOrUploaded),
                state: t(.localOnly),
                systemImage: "lock.shield.fill",
                tint: .indigo
            )

            Text(t(.privacyBoundaryDetail))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            FlowingTokenMeteringLabels(labels: TokenMeteringPreferencesModel.forbiddenContentLabels)
        }
        .padding(10)
        .background(tokenMeteringOptionBackground)
    }

    private var tokenMeteringOptionBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(NSColor.controlBackgroundColor).opacity(0.35))
    }
}
