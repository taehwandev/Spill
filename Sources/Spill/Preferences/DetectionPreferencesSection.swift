import SwiftUI

struct DetectionPreferencesSection: View {
    @ObservedObject var settings: SpillSettings
    @ObservedObject var scanner: AXMenuBarItemScanner
    @Binding var accessibilityTrusted: Bool

    private func t(_ key: PreferencesTextKey) -> String {
        PreferencesL10n.text(key)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Label(t(.detectedItems), systemImage: "menubar.rectangle")
                Spacer()
                Text("\(scanner.items.count)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)

                Button {
                    scanner.refresh()
                    accessibilityTrusted = AccessibilityPermission.isTrusted
                } label: {
                    Label(scanner.isScanning ? t(.scanning) : TokenMeteringL10n.text(.refresh), systemImage: "arrow.clockwise")
                }
                .disabled(!accessibilityTrusted || scanner.isScanning)
            }

            Picker(t(.panelItems), selection: $settings.displayMode) {
                ForEach(SpillDisplayMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Toggle(t(.autoRefresh), isOn: $settings.autoRefreshEnabled)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(t(.refreshInterval))
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
