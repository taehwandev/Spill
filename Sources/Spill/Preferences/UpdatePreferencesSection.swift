import SwiftUI

struct UpdatePreferencesSection: View {
    @ObservedObject var store: UpdateCheckStore

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

            HStack(spacing: 8) {
                Button {
                    store.checkForUpdates()
                } label: {
                    Label(checkButtonTitle, systemImage: "arrow.clockwise")
                }
                .disabled(store.isChecking)

                if store.canOpenUpdate {
                    Button {
                        store.openUpdate()
                    } label: {
                        Label("Update", systemImage: "arrow.down.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }

                if store.availableUpdate?.releaseNotesURL != nil {
                    Button {
                        store.openReleaseNotes()
                    } label: {
                        Label("Notes", systemImage: "doc.text")
                    }
                }
            }
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private var updateStatus: some View {
        switch store.state {
        case .idle:
            Text("Manual checks use the latest GitHub release metadata.")
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
            Label("Version \(update.latestVersion) is available.", systemImage: "arrow.down.circle.fill")
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
}
