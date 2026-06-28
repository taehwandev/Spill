import SwiftUI

struct PrivateUsageUploadPreferencesSection: View {
    @ObservedObject var settings: SpillSettings
    @ObservedObject var store: PrivateUsageUploadStore
    let language: TokenMeteringLanguage
    let webConnectionURL: URL?
    let openWebConnectionAction: () -> Void

    var body: some View {
        let status = store.status
        let stateText = status.isConnected
            ? (settings.privateUsageUploadEnabled ? t(.privateUsageUploadStateEnabled) : t(.privateUsageUploadStateConnected))
            : t(.privateUsageUploadStateOptional)
        let stateColor: Color = status.isConnected
            ? (settings.privateUsageUploadEnabled ? .green : .teal)
            : .secondary

        VStack(alignment: .leading, spacing: 10) {
            TokenMeteringOptionHeader(
                title: t(.privateUsageUploadTitle),
                state: stateText,
                systemImage: status.isConnected ? "checkmark.shield.fill" : "lock.shield.fill",
                tint: status.isConnected ? stateColor : .indigo
            )

            Text(t(.privateUsageUploadDetail))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            if status.isConnected {
                webConnectionConnectedState
            } else {
                webConnectionPrompt
            }

            Toggle(isOn: $settings.privateUsageUploadEnabled) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t(.privateUsageUploadToggleTitle))
                        .font(.system(size: 12, weight: .bold))
                    Text(t(.privateUsageUploadToggleDetail))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .disabled(!status.isConnected)

            PrivateUsageUploadMetricsRow(status: status, language: language)

            PrivateUsageUploadActionsRow(
                settings: settings,
                store: store,
                status: status,
                language: language
            )

            if let message = store.message {
                statusMessage(message, systemImage: "checkmark.circle.fill", color: .green)
            }

            if let errorMessage = store.errorMessage ?? status.lastFailureReason {
                statusMessage(errorMessage, systemImage: "exclamationmark.triangle.fill", color: .orange)
            }
        }
        .padding(10)
        .background(tokenMeteringOptionBackground)
    }

    private var webConnectionPrompt: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: openWebConnectionAction) {
                Label(t(.privateUsageUploadOpenWeb), systemImage: store.isConnecting ? "hourglass" : "safari")
            }
            .buttonStyle(.borderedProminent)
            .font(.system(size: 12, weight: .semibold))
            .disabled(webConnectionURL == nil)

            Text(t(.privateUsageUploadOpenWebDetail))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var webConnectionConnectedState: some View {
        HStack(alignment: .top, spacing: 10) {
            Label(
                settings.privateUsageUploadEnabled
                    ? t(.privateUsageUploadStateEnabled)
                    : t(.privateUsageUploadStateConnected),
                systemImage: "checkmark.circle.fill"
            )
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(settings.privateUsageUploadEnabled ? .green : .teal)

            Text(
                settings.privateUsageUploadEnabled
                    ? t(.privateUsageUploadConnectedMessage)
                    : t(.privateUsageUploadConnectedDetail)
            )
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statusMessage(_ message: String, systemImage: String, color: Color) -> some View {
        Label(message, systemImage: systemImage)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var tokenMeteringOptionBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(NSColor.controlBackgroundColor).opacity(0.35))
    }

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(key, language: language)
    }
}

private struct PrivateUsageUploadMetricsRow: View {
    let status: PrivateUsageUploadStatus
    let language: TokenMeteringLanguage

    var body: some View {
        HStack(spacing: 10) {
            PrivateUsageUploadMetric(
                title: t(.privateUsageUploadQueued),
                value: TokenUsageDashboardSnapshot.formatCount(status.queuedBucketCount)
            )
            PrivateUsageUploadMetric(
                title: t(.privateUsageUploadLastBackup),
                value: formatUploadDate(status.lastSuccessfulUploadAt)
            )
            PrivateUsageUploadMetric(
                title: t(.privateUsageUploadNextAuto),
                value: formatUploadDate(status.nextAutomaticAttemptAfter)
            )
        }
    }

    private func formatUploadDate(_ date: Date?) -> String {
        guard let date else {
            return t(.privateUsageUploadNone)
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: language.rawValue)
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(key, language: language)
    }
}

private struct PrivateUsageUploadActionsRow: View {
    @ObservedObject var settings: SpillSettings
    @ObservedObject var store: PrivateUsageUploadStore
    let status: PrivateUsageUploadStatus
    let language: TokenMeteringLanguage

    var body: some View {
        HStack(spacing: 8) {
            Button {
                Task { @MainActor in
                    await store.syncNow()
                }
            } label: {
                if store.isSyncing {
                    Label(t(.privateUsageUploadSyncing), systemImage: "hourglass")
                } else {
                    Label(t(.privateUsageUploadSyncNow), systemImage: "arrow.clockwise")
                }
            }
            .buttonStyle(.bordered)
            .font(.system(size: 12, weight: .semibold))
            .disabled(!status.isConnected || !settings.privateUsageUploadEnabled || store.isSyncing)

            Button(role: .destructive) {
                store.disconnect()
            } label: {
                Label(t(.privateUsageUploadDisconnect), systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)
            .font(.system(size: 12, weight: .semibold))
            .disabled(!status.isConnected)
        }
    }

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(key, language: language)
    }
}
