import SwiftUI

struct GeneralPreferencesSection: View {
    @ObservedObject var settings: SpillSettings
    @Binding var loginItemError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Show count badge", isOn: $settings.showCountBadge)

            Toggle("Use spill animation", isOn: $settings.useSpillAnimation)

            Toggle("Keyboard shortcut", isOn: $settings.hotKeyEnabled)

            Text("Control + Option + Space")
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)

            Picker("Spill Bar Items", selection: $settings.displayMode) {
                ForEach(SpillDisplayMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Icon spacing")
                    Spacer()
                    Text("\(Int(settings.iconSpacing)) px")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Slider(value: $settings.iconSpacing, in: 2...16, step: 1)
            }

            Toggle("Launch at Login", isOn: launchAtLoginBinding)
                .disabled(!LoginItemController.isAvailable)

            if !LoginItemController.isAvailable {
                Text("Launch at Login is available after packaging Spill as a .app bundle.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let loginItemError {
                Text(loginItemError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding {
            settings.launchAtLogin
        } set: { enabled in
            do {
                try LoginItemController.setEnabled(enabled)
                settings.launchAtLogin = LoginItemController.isEnabled
                loginItemError = nil
            } catch {
                settings.launchAtLogin = LoginItemController.isEnabled
                loginItemError = error.localizedDescription
            }
        }
    }
}
