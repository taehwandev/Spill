import SwiftUI

struct UpdatePreferencesSection: View {
    @ObservedObject var store: UpdateCheckStore
    @State private var didCopyInstallCommand = false

    private func t(_ key: PreferencesTextKey) -> String {
        PreferencesL10n.text(key)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Label(t(.currentVersion), systemImage: "number")
                    .font(.body.weight(.medium))

                Spacer()

                Text(store.currentVersion)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            updateStatus

            if showsManualFallbackActions {
                installCommandView
            }

            HStack(spacing: 8) {
                checkForUpdatesButton

                if showsManualFallbackActions {
                    Button {
                        copyInstallCommand()
                    } label: {
                        Label(
                            didCopyInstallCommand ? t(.copied) : t(.copyInstallCommand),
                            systemImage: didCopyInstallCommand ? "checkmark.circle.fill" : "terminal.fill"
                        )
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        store.openUpdate(source: "preferences")
                    } label: {
                        Label(openUpdateTitle, systemImage: openUpdateSymbolName)
                    }
                }

                if store.availableUpdate?.releaseNotesURL != nil {
                    Button {
                        store.openReleaseNotes(source: "preferences")
                    } label: {
                        Label(t(.notes), systemImage: "doc.text")
                    }
                }
            }
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private var checkForUpdatesButton: some View {
        if store.canOpenUpdate && store.usesInAppUpdater {
            Button {
                store.checkForUpdates(source: "preferences")
            } label: {
                Label(checkButtonTitle, systemImage: "arrow.down.circle")
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isChecking)
        } else {
            Button {
                store.checkForUpdates(source: "preferences")
            } label: {
                Label(checkButtonTitle, systemImage: "arrow.clockwise")
            }
            .disabled(store.isChecking)
        }
    }

    private var installCommandView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.blue)

                Text(t(.terminalInstallCommand))
                    .font(.footnote.weight(.semibold))
            }

            Text(store.installCommand)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(2)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    @ViewBuilder
    private var updateStatus: some View {
        switch store.state {
        case .idle:
            Text(idleStatusMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .checking:
            Label(t(.checkingForUpdates), systemImage: "arrow.triangle.2.circlepath")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .upToDate(_, let latestVersion):
            Label(PreferencesL10n.upToDate(version: latestVersion), systemImage: "checkmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(.green)
        case .available(let update):
            Label(availableUpdateMessage(for: update), systemImage: availableUpdateSymbolName(for: update))
                .font(.footnote)
                .foregroundStyle(.blue)
        case .unsupported(let update, let currentMacOS):
            Label(
                PreferencesL10n.unsupportedVersion(
                    version: update.latestVersion,
                    requirement: update.minimumMacOS ?? PreferencesL10n.newerThanVersion(currentMacOS)
                ),
                systemImage: "exclamationmark.triangle.fill"
            )
                .font(.footnote)
                .foregroundStyle(.orange)
        case .failed(_, let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(.red)
        }
    }

    private var showsManualFallbackActions: Bool {
        store.canOpenUpdate && !store.usesInAppUpdater
    }

    private var idleStatusMessage: String {
        if store.usesInAppUpdater {
            return t(.dashboardChecksInApp)
        }

        return t(.dashboardChecksGitHub)
    }

    private var checkButtonTitle: String {
        if store.isChecking {
            return t(.checking)
        }

        if store.canOpenUpdate && store.usesInAppUpdater {
            return t(.updateNow)
        }

        return t(.checkForUpdates)
    }

    private var openUpdateTitle: String {
        store.availableUpdate?.usesInstallerPackage == true
            ? t(.openInstaller)
            : t(.downloadDMG)
    }

    private var openUpdateSymbolName: String {
        store.availableUpdate?.usesInstallerPackage == true
            ? "shippingbox.fill"
            : "arrow.down.circle"
    }

    private func availableUpdateMessage(for update: AvailableUpdate) -> String {
        if store.usesInAppUpdater {
            return PreferencesL10n.availableUpdateMessage(version: update.latestVersion, key: .updateInsideApp)
        }

        if update.usesInstallerPackage {
            return PreferencesL10n.availableUpdateMessage(version: update.latestVersion, key: .updateWithInstaller)
        }

        return PreferencesL10n.availableUpdateMessage(version: update.latestVersion, key: .updateWithCommandOrDMG)
    }

    private func availableUpdateSymbolName(for update: AvailableUpdate) -> String {
        if store.usesInAppUpdater {
            return "arrow.down.circle.fill"
        }

        return update.usesInstallerPackage ? "shippingbox.fill" : "arrow.down.circle.fill"
    }

    private func copyInstallCommand() {
        store.copyInstallCommand(source: "preferences")
        didCopyInstallCommand = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            didCopyInstallCommand = false
        }
    }
}
