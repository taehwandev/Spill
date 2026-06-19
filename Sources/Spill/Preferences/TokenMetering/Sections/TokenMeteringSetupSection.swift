import SwiftUI

struct TokenMeteringSetupSection: View {
    let language: TokenMeteringLanguage
    let copiedTarget: String?
    let adapterStatuses: [String: TokenMeteringAdapterConnectionStatus]
    let copyToClipboardAction: (String, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.teal)
                Text(t(.step1Title))
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Text(t(.recommended))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.teal)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.teal.opacity(0.12), in: Capsule())
            }

            TokenMeteringPromptInstructionCard(
                language: language,
                copiedTarget: copiedTarget,
                copyInstallPromptAction: { prompt in
                    copyToClipboardAction(prompt, "prompt")
                }
            )

            Divider().opacity(0.45)

            TokenMeteringAdapterStatusSection(
                language: language,
                copiedTarget: copiedTarget,
                adapterStatuses: adapterStatuses,
                copyToClipboardAction: copyToClipboardAction
            )
        }
        .padding(10)
        .background(tokenMeteringOptionBackground)
    }

    private var tokenMeteringOptionBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(NSColor.controlBackgroundColor).opacity(0.35))
    }

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(key, language: language)
    }
}
