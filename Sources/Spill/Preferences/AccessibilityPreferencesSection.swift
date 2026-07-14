import SwiftUI

struct AccessibilityPreferencesSection: View {
    @ObservedObject var scanner: AXMenuBarItemScanner
    @Binding var accessibilityTrusted: Bool
    let showPanelAction: () -> Void

    private func t(_ key: PreferencesTextKey) -> String {
        PreferencesL10n.text(key)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label(
                    accessibilityTrusted ? t(.accessibilityActive) : t(.accessibilityNeeded),
                    systemImage: accessibilityTrusted ? "checkmark.shield.fill" : "exclamationmark.shield.fill"
                )
                .font(.body.weight(.medium))
                .foregroundStyle(accessibilityTrusted ? .green : .orange)

                Spacer()

                statePill(
                    title: accessibilityTrusted ? t(.on) : t(.off),
                    tint: accessibilityTrusted ? .green : .orange
                )

                statePill(
                    title: PreferencesL10n.itemCount(scanner.items.count),
                    tint: .secondary
                )
            }

            if accessibilityTrusted {
                HStack(spacing: 8) {
                    Button {
                        showPanelAction()
                    } label: {
                        Label(t(.openPanel), systemImage: "rectangle.on.rectangle")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        refreshScanner()
                    } label: {
                        Label(scanner.isScanning ? t(.scanning) : t(.refreshScanner), systemImage: "arrow.clockwise")
                    }
                    .disabled(scanner.isScanning)
                }
            } else {
                Text(t(.accessibilityPermissionDetail))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(t(.accessibilityPermissionRelaunch))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Button {
                        requestPermission()
                    } label: {
                        Label(t(.requestAccess), systemImage: "hand.raised.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        SpillTelemetry.shared.track(
                            "accessibility_system_settings_opened",
                            props: ["source": "preferences"]
                        )
                        AccessibilityPermission.openSystemSettings()
                    } label: {
                        Label(t(.systemSettings), systemImage: "gearshape.fill")
                    }

                    Button {
                        refreshPermissionState()
                    } label: {
                        Label(t(.recheck), systemImage: "arrow.clockwise")
                    }

                    Button {
                        SpillTelemetry.shared.track(
                            "app_relaunch_requested",
                            props: ["source": "accessibility_preferences"]
                        )
                        AppRelauncher.relaunch()
                    } label: {
                        Label(t(.relaunch), systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            }

            Divider()
                .background(Color.primary.opacity(0.04))

            DisclosureGroup {
                VStack(alignment: .leading, spacing: 5) {
                    diagnosticRow(t(.bundleID), PermissionDiagnostics.bundleIdentifier)
                    diagnosticRow(t(.bundle), PermissionDiagnostics.bundlePath)
                    diagnosticRow(t(.executable), PermissionDiagnostics.executablePath)
                    diagnosticRow(t(.pid), PermissionDiagnostics.processIdentifier)
                    diagnosticRow(t(.appBundleLaunch), PermissionDiagnostics.isAppBundle)
                    diagnosticRow(t(.axTrusted), accessibilityTrusted ? "true" : "false")
                }
                .padding(.top, 4)
            } label: {
                Label(t(.permissionDiagnostics), systemImage: "stethoscope")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private extension AccessibilityPreferencesSection {
    private func refreshPermissionState() {
        accessibilityTrusted = AccessibilityPermission.isTrusted
        SpillTelemetry.shared.track(
            "accessibility_rechecked",
            props: [
                "source": "preferences",
                "result": accessibilityTrusted ? "trusted" : "not_trusted"
            ]
        )
        if accessibilityTrusted {
            scanner.refresh()
        }
    }

    private func requestPermission() {
        SpillTelemetry.shared.track(
            "accessibility_permission_requested",
            props: ["source": "preferences"]
        )
        accessibilityTrusted = AccessibilityPermission.request()
        SpillTelemetry.shared.track(
            "accessibility_permission_result",
            props: [
                "source": "preferences",
                "result": accessibilityTrusted ? "trusted" : "not_trusted"
            ]
        )
        if accessibilityTrusted {
            scanner.refresh()
        } else {
            SpillTelemetry.shared.track(
                "accessibility_system_settings_opened",
                props: ["source": "request_access"]
            )
            AccessibilityPermission.openSystemSettings()
        }
    }

    private func refreshScanner() {
        SpillTelemetry.shared.track(
            "menu_bar_scan_requested",
            props: ["source": "accessibility_preferences"]
        )
        scanner.refresh()
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
