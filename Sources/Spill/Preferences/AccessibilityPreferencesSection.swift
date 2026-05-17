import SwiftUI

struct AccessibilityPreferencesSection: View {
    @ObservedObject var scanner: AXMenuBarItemScanner
    @Binding var accessibilityTrusted: Bool
    let showPanelAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label(
                    accessibilityTrusted ? "Accessibility Active" : "Accessibility Needed",
                    systemImage: accessibilityTrusted ? "checkmark.shield.fill" : "exclamationmark.shield.fill"
                )
                .font(.body.weight(.medium))
                .foregroundStyle(accessibilityTrusted ? .green : .orange)

                Spacer()

                statePill(
                    title: accessibilityTrusted ? "ON" : "OFF",
                    tint: accessibilityTrusted ? .green : .orange
                )

                statePill(
                    title: "\(scanner.items.count) items",
                    tint: .secondary
                )
            }

            if accessibilityTrusted {
                HStack(spacing: 8) {
                    Button {
                        showPanelAction()
                    } label: {
                        Label("Open Panel", systemImage: "rectangle.on.rectangle")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        scanner.refresh()
                    } label: {
                        Label(scanner.isScanning ? "Scanning" : "Refresh Scanner", systemImage: "arrow.clockwise")
                    }
                    .disabled(scanner.isScanning)
                }
            } else {
                Text("Spill needs Accessibility permission to discover and activate menu bar items owned by other apps.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("After granting permission in System Settings, relaunch Spill if it still shows as inactive.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Button {
                        requestPermission()
                    } label: {
                        Label("Request Access", systemImage: "hand.raised.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        AccessibilityPermission.openSystemSettings()
                    } label: {
                        Label("System Settings", systemImage: "gearshape.fill")
                    }

                    Button {
                        refreshPermissionState()
                    } label: {
                        Label("Recheck", systemImage: "arrow.clockwise")
                    }

                    Button {
                        AppRelauncher.relaunch()
                    } label: {
                        Label("Relaunch", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            }

            Divider()
                .background(Color.primary.opacity(0.04))

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
                    .font(.footnote)
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

    private func statePill(title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.12), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(tint.opacity(0.2), lineWidth: 0.8)
            }
    }

    private func diagnosticRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption2.monospaced())
                .textSelection(.enabled)
        }
    }
}
