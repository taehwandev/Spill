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

            if store.canOpenUpdate {
                installCommandView
            }

            HStack(spacing: 8) {
                Button {
                    store.checkForUpdates(source: "preferences")
                } label: {
                    Label(checkButtonTitle, systemImage: "arrow.clockwise")
                }
                .disabled(store.isChecking)

                if store.canOpenUpdate {
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
            Text(store.usesInAppUpdater
                ? "Updates can be downloaded and installed inside the app."
                : "Manual checks use the latest GitHub release metadata.")
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
            Label(availableUpdateMessage(for: update), systemImage: update.usesInstallerPackage ? "shippingbox.fill" : "arrow.down.circle.fill")
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

    private var checkButtonTitle: String {
        store.isChecking ? "Checking" : "Check for Updates"
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
        if update.usesInstallerPackage {
            return "Version \(update.latestVersion) is available. Open the signed installer package to update."
        }

        return "Version \(update.latestVersion) is available. Copy the terminal command or download the DMG."
    }

    private func copyInstallCommand() {
        store.copyInstallCommand(source: "preferences")
        didCopyInstallCommand = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            didCopyInstallCommand = false
        }
    }
}
