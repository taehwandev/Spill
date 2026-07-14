import AppKit
import SwiftUI

struct TokenMeteringDashboardSetupPanel: View {
    @ObservedObject var aiStatusStore: AIStatusStore
    let language: TokenMeteringLanguage
    @State private var isSetupPromptCopied = false
    @ObservedObject private var setupActionStore = TokenMeteringSetupActionStore.shared

    var body: some View {
        TokenMeteringDashboardRailPanel(
            title: TokenMeteringSetupL10n.text(.setupDashboardTitle, language: language)
        ) {
            VStack(alignment: .leading, spacing: 9) {
                Text(TokenMeteringSetupL10n.text(setupActionStore.statusTextKey, language: language))
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                TokenMeteringSetupActionControls(
                    store: setupActionStore,
                    installedTools: installedTokenTools,
                    language: language,
                    isSetupPromptCopied: isSetupPromptCopied,
                    copySetupPromptAction: copySetupPrompt
                )
            }
        }
        .onAppear {
            setupActionStore.refresh(installedTools: installedTokenTools)
        }
        .onChange(of: aiStatusStore.statuses) { _, _ in
            setupActionStore.refresh(installedTools: installedTokenTools)
        }
    }

    private var installedTokenTools: Set<TokenUsageAITool> {
        TokenMeteringToolAvailability.installedTools(from: aiStatusStore.statuses)
    }

    private func copySetupPrompt() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(TokenMeteringGlobalSetup.workflowPrompt, forType: .string)
        isSetupPromptCopied = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            isSetupPromptCopied = false
        }
    }
}
