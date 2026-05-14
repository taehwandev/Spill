import SwiftUI

struct PanelFallbackPreferencesSection: View {
    @ObservedObject var scanner: AXMenuBarItemScanner
    @Binding var accessibilityTrusted: Bool
    let showPanelAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Label("Controls", systemImage: "switch.2")
                Spacer()
                statePill(
                    title: accessibilityTrusted ? "Access On" : "Access Off",
                    symbolName: accessibilityTrusted ? "checkmark.shield.fill" : "exclamationmark.shield.fill",
                    tint: accessibilityTrusted ? .green : .orange
                )
                statePill(
                    title: "\(scanner.items.count)",
                    symbolName: "square.grid.2x2.fill",
                    tint: .secondary
                )
            }

            HStack(spacing: 8) {
                Button {
                    showPanelAction()
                    refreshPermissionState()
                } label: {
                    Label("Open Panel", systemImage: "rectangle.on.rectangle")
                }

                Button {
                    refreshItems()
                } label: {
                    Label(scanner.isScanning ? "Scanning" : "Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(!accessibilityTrusted || scanner.isScanning)

                if !accessibilityTrusted {
                    Button {
                        AccessibilityPermission.openSystemSettings()
                    } label: {
                        Label("Access", systemImage: "hand.raised.fill")
                    }
                }
            }
        }
    }

    private func refreshItems() {
        refreshPermissionState()

        if accessibilityTrusted {
            scanner.refresh()
        }
    }

    private func refreshPermissionState() {
        accessibilityTrusted = AccessibilityPermission.isTrusted
    }

    private func statePill(title: String, symbolName: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbolName)
            Text(title)
                .monospacedDigit()
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.1), in: Capsule())
        .overlay {
            Capsule()
                .stroke(tint.opacity(0.18), lineWidth: 0.8)
        }
    }
}
