import SwiftUI

struct GeneralPreferencesSection: View {
    @ObservedObject var settings: SpillSettings
    @Binding var loginItemError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Use spill animation", isOn: $settings.useSpillAnimation)

            Toggle("Keyboard shortcut", isOn: $settings.hotKeyEnabled)

            Text("\(WindowActionShortcutModifier.standard.title) + Space")
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)

            windowShortcutsSection

            HStack {
                Label("Menu bar actions", systemImage: "camera.viewfinder")
                Spacer()
                Text("Notch candidates")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

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

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Screen Time", systemImage: "hourglass")
                    Spacer()
                    Button {
                        ScreenTimeSettings.open()
                    } label: {
                        Label("Open Screen Time", systemImage: "gearshape.fill")
                    }
                }

                Text("If App Limits or Downtime block Spill, macOS can prevent launch or place a Time Limit shield above the app. Add Spill to Always Allowed or disable the relevant limit. Launch Spill from Applications/Finder instead of a blocked launcher app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var windowShortcutsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Window shortcuts", systemImage: "macwindow")
                Spacer()
                Text("Grouped modifiers")
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
            }

            ForEach(WindowActionKind.panelOrder, id: \.self) { kind in
                HStack(spacing: 10) {
                    Label(kind.title, systemImage: kind.symbolName)
                        .font(.callout)

                    Spacer()

                    Text(kind.shortcutModifier.glyph)
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)

                    Picker("", selection: shortcutBinding(for: kind)) {
                        ForEach(WindowActionShortcutKey.allCases) { key in
                            Text(key.pickerTitle).tag(key)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 74)
                }
            }
        }
    }

    private func shortcutBinding(for kind: WindowActionKind) -> Binding<WindowActionShortcutKey> {
        Binding {
            settings.shortcutKey(for: kind)
        } set: { key in
            settings.setWindowActionShortcut(key, for: kind)
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
