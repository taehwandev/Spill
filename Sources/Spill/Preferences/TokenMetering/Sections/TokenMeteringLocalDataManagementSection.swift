import SwiftUI

struct TokenMeteringLocalDataManagementSection: View {
    @ObservedObject var settings: SpillSettings
    let tokenUsageStore: TokenUsageStore
    @State private var showsDeleteControls = false
    @State private var localDataPreview = TokenUsageClearPreview(scopeTitle: "", eventCount: 0, totalTokens: 0)
    @State private var pendingClearAllPreview: TokenUsageClearPreview?
    @State private var clearAllError: String?

    private var currentLanguage: TokenMeteringLanguage {
        TokenMeteringLanguage.current(appLanguage: settings.appLanguage)
    }

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(key, language: currentLanguage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            TokenMeteringOptionHeader(
                title: t(.dataManagement),
                state: t(.localOnly),
                systemImage: "externaldrive.fill",
                tint: .orange
            )

            Label(t(.debugOnly), systemImage: "ladybug.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.orange)

            Text(TokenMeteringL10n.eventsTokensDetail(
                eventCount: localDataPreview.eventCount,
                tokens: TokenUsageDashboardSnapshot.formatTokens(localDataPreview.totalTokens),
                language: currentLanguage
            ))
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(.secondary)

            if localDataPreview.hasEvents {
                DisclosureGroup(isExpanded: $showsDeleteControls) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(t(.localDataManagementDetail))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Button(role: .destructive) {
                            let preview = makeAllLocalDataPreview()
                            localDataPreview = preview
                            if preview.hasEvents {
                                pendingClearAllPreview = preview
                            }
                        } label: {
                            Label(t(.reviewLocalDataDelete), systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .font(.system(size: 12, weight: .semibold))
                        .tint(.red)
                    }
                    .padding(.top, 4)
                } label: {
                    Label(t(.localDataDeleteOptions), systemImage: "trash")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            } else {
                Label(t(.noLocalTokenEvents), systemImage: "checkmark.circle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            if let clearAllError {
                Text(clearAllError)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(tokenMeteringOptionBackground)
        .onAppear {
            refreshLocalDataPreview()
        }
        .onReceive(NotificationCenter.default.publisher(for: TokenUsageStore.eventsDidChangeNotification)) { _ in
            refreshLocalDataPreview()
        }
        .alert(
            t(.deleteTokenDataTitle),
            isPresented: Binding(
                get: { pendingClearAllPreview != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingClearAllPreview = nil
                    }
                }
            ),
            presenting: pendingClearAllPreview
        ) { _ in
            Button(t(.deleteTokenDataCancel), role: .cancel) {
                pendingClearAllPreview = nil
            }
            Button(t(.deleteTokenDataConfirm), role: .destructive) {
                clearAllLocalTokenData()
            }
        } message: { preview in
            Text(TokenMeteringL10n.deleteTokenDataMessage(
                scope: preview.scopeTitle,
                eventCount: preview.eventCount,
                tokens: TokenUsageDashboardSnapshot.formatTokens(preview.totalTokens),
                language: currentLanguage
            ))
        }
    }
}

private extension TokenMeteringLocalDataManagementSection {
    private var tokenMeteringOptionBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(NSColor.controlBackgroundColor).opacity(0.35))
    }

    private func refreshLocalDataPreview() {
        let preview = makeAllLocalDataPreview()
        localDataPreview = preview
        if !preview.hasEvents {
            showsDeleteControls = false
        }
    }

    private func makeAllLocalDataPreview() -> TokenUsageClearPreview {
        let summary = tokenUsageStore.dashboardSummary(dashboardToolsOnly: false)
        return TokenUsageClearPreview(
            scopeTitle: t(.allLocalData),
            eventCount: summary.eventCount,
            totalTokens: summary.totalTokens
        )
    }

    private func clearAllLocalTokenData() {
        guard SpillBuildOptions.developerOptionsEnabled else {
            pendingClearAllPreview = nil
            return
        }
        do {
            try tokenUsageStore.clearEvents()
            clearAllError = nil
            pendingClearAllPreview = nil
            showsDeleteControls = false
            refreshLocalDataPreview()
        } catch {
            clearAllError = TokenMeteringL10n.text(.clearFailed, language: currentLanguage)
            pendingClearAllPreview = nil
        }
    }
}
