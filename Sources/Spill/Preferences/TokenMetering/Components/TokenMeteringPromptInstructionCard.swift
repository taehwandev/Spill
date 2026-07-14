import SwiftUI

struct TokenMeteringPromptInstructionCard: View {
    @ObservedObject var setupActionStore: TokenMeteringSetupActionStore
    let installedTools: Set<TokenUsageAITool>
    let language: TokenMeteringLanguage
    let copiedTarget: String?
    let copyInstallPromptAction: (String) -> Void

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(key, language: language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.teal.opacity(0.15), Color.blue.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)

                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.teal, Color.blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(t(.promptInstructionCardTitle))
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(t(.promptInstructionCardDetail))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(TokenMeteringSetupL10n.text(setupActionStore.statusTextKey, language: language))
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(.teal)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            TokenMeteringSetupActionControls(
                store: setupActionStore,
                installedTools: installedTools,
                language: language,
                isSetupPromptCopied: copiedTarget == "prompt",
                copySetupPromptAction: {
                    copyInstallPromptAction(TokenMeteringGlobalSetup.workflowPrompt)
                }
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            Color.primary.opacity(0.015),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.04), lineWidth: 0.5)
        }
    }
}
