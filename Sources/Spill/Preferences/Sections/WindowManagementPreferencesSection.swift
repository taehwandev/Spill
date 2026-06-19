import SwiftUI

struct WindowManagementPreferencesSection: View {
    @ObservedObject var settings: SpillSettings
    let language: SpillAppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PreferenceCard(title: t(.globalShortcut), symbolName: "keyboard", iconColor: .indigo) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(t(.keyboardShortcut), isOn: $settings.hotKeyEnabled)
                        .font(.system(size: 13, weight: .medium))

                    if settings.hotKeyEnabled {
                        Text("\(WindowActionShortcutModifier.standard.title) + Space")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 20)
                    }
                }
            }

            PreferenceCard(title: t(.windowSnapShortcuts), symbolName: "macwindow", iconColor: .blue) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(WindowActionKind.panelOrder, id: \.self) { kind in
                        HStack(spacing: 10) {
                            Label(kind.title, systemImage: kind.symbolName)
                                .font(.system(size: 12))

                            Spacer()

                            Text(kind.shortcutModifier.glyph)
                                .font(.system(size: 12, design: .monospaced))
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
        }
    }

    private func shortcutBinding(for kind: WindowActionKind) -> Binding<WindowActionShortcutKey> {
        Binding {
            settings.shortcutKey(for: kind)
        } set: { key in
            settings.setWindowActionShortcut(key, for: kind)
        }
    }

    private func t(_ key: PreferencesTextKey) -> String {
        PreferencesL10n.text(key, appLanguage: language)
    }
}
