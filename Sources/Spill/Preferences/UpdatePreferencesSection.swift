import SwiftUI

struct UpdatePreferencesSection: View {
    @ObservedObject var store: UpdateCheckStore
    @State private var didCopyInstallCommand = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Label("Current version", systemImage: "number")
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
                            didCopyInstallCommand ? "Copied" : "Copy Install Command",
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
                        Label("Notes", systemImage: "doc.text")
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
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.blue)

                Text("Terminal install command")
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
            Label("Checking for updates...", systemImage: "arrow.triangle.2.circlepath")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .upToDate(_, let latestVersion):
            Label("Spill is up to date (\(latestVersion)).", systemImage: "checkmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(.green)
        case .available(let update):
            Label(availableUpdateMessage(for: update), systemImage: availableUpdateSymbolName(for: update))
                .font(.footnote)
                .foregroundStyle(.blue)
        case .unsupported(let update, let currentMacOS):
            Label("Version \(update.latestVersion) requires macOS \(update.minimumMacOS ?? "newer than \(currentMacOS)").", systemImage: "exclamationmark.triangle.fill")
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
            return "Dashboard checks once per day. Use Check for Updates here to start the in-app updater."
        }

        return "Dashboard checks once per day. Manual checks use the latest GitHub release metadata."
    }

    private var checkButtonTitle: String {
        if store.isChecking {
            return "Checking"
        }

        if store.canOpenUpdate && store.usesInAppUpdater {
            return "Update Now"
        }

        return "Check for Updates"
    }

    private var openUpdateTitle: String {
        store.availableUpdate?.usesInstallerPackage == true
            ? "Open Installer"
            : "Download DMG"
    }

    private var openUpdateSymbolName: String {
        store.availableUpdate?.usesInstallerPackage == true
            ? "shippingbox.fill"
            : "arrow.down.circle"
    }

    private func availableUpdateMessage(for update: AvailableUpdate) -> String {
        if store.usesInAppUpdater {
            return "Version \(update.latestVersion) is available. Update inside the app."
        }

        if update.usesInstallerPackage {
            return "Version \(update.latestVersion) is available. Open the signed installer package to update."
        }

        return "Version \(update.latestVersion) is available. Copy the terminal command or download the DMG."
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
