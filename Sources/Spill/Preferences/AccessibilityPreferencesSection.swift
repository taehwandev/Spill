import SwiftUI

struct AccessibilityPreferencesSection: View {
    @ObservedObject var scanner: AXMenuBarItemScanner
    @Binding var accessibilityTrusted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Label(
                    accessibilityTrusted ? "Accessibility Enabled" : "Accessibility Needed",
                    systemImage: accessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                )
                .foregroundStyle(accessibilityTrusted ? .green : .orange)

                Spacer()

                Button {
                    refreshPermissionState()
                } label: {
                    Label("Recheck", systemImage: "arrow.clockwise")
                }

                if !accessibilityTrusted {
                    Button {
                        requestPermission()
                    } label: {
                        Label("Request", systemImage: "hand.raised.fill")
                    }

                    Button {
                        AccessibilityPermission.openSystemSettings()
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }

                    Button {
                        AppRelauncher.relaunch()
                    } label: {
                        Label("Relaunch", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            }

            if !accessibilityTrusted {
                Text("Spill needs Accessibility to discover and activate menu bar items owned by other apps.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("After granting Accessibility, relaunch Spill if this still stays off. macOS can keep the current process untrusted until restart.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            DisclosureGroup {
                VStack(alignment: .leading, spacing: 5) {
                    diagnosticRow("Bundle ID", PermissionDiagnostics.bundleIdentifier)
                    diagnosticRow("Bundle", PermissionDiagnostics.bundlePath)
                    diagnosticRow("Executable", PermissionDiagnostics.executablePath)
                    diagnosticRow("PID", PermissionDiagnostics.processIdentifier)
                    diagnosticRow("App bundle launch", PermissionDiagnostics.isAppBundle)
                    diagnosticRow("AX trusted", accessibilityTrusted ? "true" : "false")
                }
                .padding(.top, 4)
            } label: {
                Label("Permission Diagnostics", systemImage: "stethoscope")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func refreshPermissionState() {
        accessibilityTrusted = AccessibilityPermission.isTrusted

        if accessibilityTrusted {
            scanner.refresh()
        }
    }

    private func requestPermission() {
        accessibilityTrusted = AccessibilityPermission.request()

        if accessibilityTrusted {
            scanner.refresh()
        } else {
            AccessibilityPermission.openSystemSettings()
        }
    }

    private func diagnosticRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }
}
