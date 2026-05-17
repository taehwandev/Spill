import SwiftUI

struct GeneralPreferencesSection: View {
    @ObservedObject var settings: SpillSettings
    @Binding var loginItemError: String?
    @State private var showsWindowShortcuts = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Launch at Login - at the absolute top!
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Launch at Login", isOn: launchAtLoginBinding)
                    .disabled(!LoginItemController.isAvailable)
                    .font(.body.weight(.medium))

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

            Divider()
                .background(Color.primary.opacity(0.04))

            // Main Animation & Global Shortcut Toggles
            Toggle("Use spill animation", isOn: $settings.useSpillAnimation)

            VStack(alignment: .leading, spacing: 4) {
                Toggle("Keyboard shortcut", isOn: $settings.hotKeyEnabled)

                if settings.hotKeyEnabled {
                    Text("\(WindowActionShortcutModifier.standard.title) + Space")
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                        .padding(.leading, 20)
                }
            }

            Divider()
                .background(Color.primary.opacity(0.04))

            // Menu Bar Layout Customization
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Menu bar icon spacing", systemImage: "camera.viewfinder")
                        .font(.body.weight(.medium))
                    Spacer()
                    Text("\(Int(settings.iconSpacing)) px")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Slider(value: $settings.iconSpacing, in: 2...16, step: 1)
            }

            Divider()
                .background(Color.primary.opacity(0.04))

            // Window Snap Shortcuts under an elegant DisclosureGroup
            DisclosureGroup(isExpanded: $showsWindowShortcuts) {
                windowShortcutsSection
                    .padding(.top, 8)
            } label: {
                Label("Window Snap Shortcuts", systemImage: "macwindow")
                    .font(.body.weight(.medium))
            }
        }
    }

    private var windowShortcutsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
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
