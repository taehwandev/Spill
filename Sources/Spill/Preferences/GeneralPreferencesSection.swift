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

            windowShortcutsSection

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

    private var windowShortcutsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Window shortcuts", systemImage: "macwindow")
                Spacer()
                Text("Control + Option")
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
            }

            ForEach(WindowActionKind.panelOrder, id: \.self) { kind in
                HStack(spacing: 10) {
                    Label(kind.title, systemImage: kind.symbolName)
                        .font(.callout)

                    Spacer()

                    Picker("", selection: shortcutBinding(for: kind)) {
                        ForEach(WindowActionShortcutKey.allCases) { key in
                            Text(key.pickerTitle).tag(key)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 112)
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
