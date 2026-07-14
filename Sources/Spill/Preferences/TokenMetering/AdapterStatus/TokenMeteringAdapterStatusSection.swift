import SwiftUI

struct TokenMeteringAdapterStatusSection: View {
    let language: TokenMeteringLanguage
    let copiedTarget: String?
    let installedTools: Set<TokenUsageAITool>
    let adapterStatuses: [String: TokenMeteringAdapterConnectionStatus]
    let copyToClipboardAction: (String, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(t(.agentConnectionStatus), systemImage: "bolt.horizontal.circle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)

            VStack(spacing: 7) {
                if installedAdapters.isEmpty {
                    Text(TokenMeteringSetupL10n.text(.aiToolVisibilityNoInstalledTools, language: language))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                } else {
                    ForEach(installedAdapters) { adapter in
                        TokenMeteringAdapterStatusRow(
                            adapter: adapter,
                            status: status(for: adapter),
                            language: language,
                            copiedTarget: copiedTarget,
                            copyToClipboardAction: copyToClipboardAction
                        )
                    }
                }
            }
        }
    }

    private var installedAdapters: [TokenMeteringAdapter] {
        TokenMeteringAdapterKit.localRuntimeAdapters.filter { installedTools.contains($0.aiTool) }
    }

    private func status(for adapter: TokenMeteringAdapter) -> TokenMeteringAdapterConnectionStatus {
        adapterStatuses[adapter.id] ?? .missing
    }

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(key, language: language)
    }
}

private struct TokenMeteringAdapterStatusRow: View {
    let adapter: TokenMeteringAdapter
    let status: TokenMeteringAdapterConnectionStatus
    let language: TokenMeteringLanguage
    let copiedTarget: String?
    let copyToClipboardAction: (String, String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: status.isActive ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(status.isActive ? .green : .orange)

            VStack(alignment: .leading, spacing: 1) {
                Text(adapter.title)
                    .font(.system(size: 12, weight: .bold))
                Text(adapterStatusDetail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            trailingStatusControl
        }
        .padding(8)
        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.04), lineWidth: 0.5)
        }
    }

    @ViewBuilder
    private var trailingStatusControl: some View {
        if !status.isActive,
           let config = adapter.hookConfig(
               installedAt: TokenMeteringAdapterKit.defaultInstallURL(for: adapter)
           ) {
            Button {
                copyToClipboardAction(config, "prompt_\(adapter.id)")
            } label: {
                Label(
                    copiedTarget == "prompt_\(adapter.id)" ? t(.copied) : t(.copyPrompt),
                    systemImage: copiedTarget == "prompt_\(adapter.id)" ? "checkmark" : "doc.on.doc"
                )
            }
            .buttonStyle(.bordered)
            .font(.system(size: 11, weight: .semibold))
        } else if !status.isActive {
            Text(t(.adapterSetupRequired))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.orange)
        } else {
            Text(t(.active))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.green)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.green.opacity(0.12)))
        }
    }

    private var adapterStatusDetail: String {
        if adapter.aiTool == .antigravity, status.isActive {
            return adapter.subtitle
        }

        if !status.scriptInstalled {
            return t(.adapterSetupRequired)
        }

        if adapter.aiTool == .antigravity {
            return t(.adapterSetupRequired)
        }

        if !status.hookConfigured {
            return t(.adapterHookMissing)
        }

        return TokenMeteringL10n.adapterInstalled(
            TokenMeteringAdapterKit.defaultInstallURL(for: adapter).lastPathComponent,
            language: language
        )
    }

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(key, language: language)
    }
}
