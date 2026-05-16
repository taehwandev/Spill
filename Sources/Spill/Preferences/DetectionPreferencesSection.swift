import SwiftUI

struct DetectionPreferencesSection: View {
    @ObservedObject var settings: SpillSettings
    @ObservedObject var scanner: AXMenuBarItemScanner
    @Binding var accessibilityTrusted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Label("Detected Items", systemImage: "menubar.rectangle")
                Spacer()
                Text("\(scanner.items.count)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)

                Button {
                    scanner.refresh()
                    accessibilityTrusted = AccessibilityPermission.isTrusted
                } label: {
                    Label(scanner.isScanning ? "Scanning" : "Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(!accessibilityTrusted || scanner.isScanning)
            }

            Toggle("Auto refresh", isOn: $settings.autoRefreshEnabled)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Refresh interval")
                    Spacer()
                    Text("\(Int(settings.refreshInterval))s")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Slider(value: $settings.refreshInterval, in: 5...60, step: 5)
                    .disabled(!settings.autoRefreshEnabled)
            }

            Text(scanner.scanMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
    }
}
