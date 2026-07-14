import AppKit
import SwiftUI

struct TokenMeteringSetupActionControls: View {
    @ObservedObject var store: TokenMeteringSetupActionStore
    let installedTools: Set<TokenUsageAITool>
    let language: TokenMeteringLanguage
    let isSetupPromptCopied: Bool
    let copySetupPromptAction: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            Button {
                store.installOrRepair(installedTools: installedTools)
            } label: {
                Label(setupText(primaryActionKey), systemImage: primaryActionIcon)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
            .disabled(store.isRunning || installedTools.isEmpty)

            Button(action: copySetupPromptAction) {
                Label(
                    isSetupPromptCopied ? t(.copied) : t(.copyInstallPrompt),
                    systemImage: isSetupPromptCopied ? "checkmark" : "doc.on.doc"
                )
            }
            .buttonStyle(.bordered)
            .disabled(store.isRunning)
        }
        .font(.system(size: 11, weight: .semibold))
        .onAppear {
            store.refresh(installedTools: installedTools)
        }
        .onChange(of: installedTools) { _, tools in
            store.refresh(installedTools: tools)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.refresh(installedTools: installedTools)
        }
    }

    private var primaryActionKey: TokenMeteringSetupL10n.Key {
        if store.isRunning {
            return .setupInstalling
        }
        return store.isInstalled ? .setupReinstall : .setupInstall
    }

    private var primaryActionIcon: String {
        if store.isRunning {
            return "progress.indicator"
        }
        return store.isInstalled ? "arrow.clockwise" : "square.and.arrow.down"
    }

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(key, language: language)
    }

    private func setupText(_ key: TokenMeteringSetupL10n.Key) -> String {
        TokenMeteringSetupL10n.text(key, language: language)
    }
}

extension TokenMeteringSetupActionStore {
    var statusTextKey: TokenMeteringSetupL10n.Key {
        switch operationState {
        case .running:
            return .setupStatusInstalling
        case .succeeded:
            return .setupStatusSucceeded
        case .failed:
            return .setupStatusFailed
        case .idle:
            return isInstalled ? .setupStatusInstalled : .setupStatusNotInstalled
        }
    }
}
