import SwiftUI

struct MenuBarPreferencesSection: View {
    @ObservedObject var settings: SpillSettings
    let language: SpillAppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PreferenceCard(title: t(.menuBarIconAnimation), symbolName: "paintpalette.fill", iconColor: .pink) {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(t(.useSpillAnimation), isOn: $settings.useSpillAnimation)
                        .font(.system(size: 13, weight: .medium))

                    Divider()
                        .background(Color.primary.opacity(0.04))

                    menuBarTriggerIconControl
                }
            }

            PreferenceCard(title: t(.clockAreaStatus), symbolName: "menubar.rectangle", iconColor: .teal) {
                ClockAreaStatusPreferencesSection(settings: settings)
            }
        }
    }

    private var menuBarTriggerIconControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(t(.menuBarTriggerIcon))
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Text(settings.menuBarTriggerIconStyle.title)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            if MenuBarTriggerIconStyle.selectableCases.count > 1 {
                Picker(t(.menuBarTriggerIcon), selection: $settings.menuBarTriggerIconStyle) {
                    ForEach(MenuBarTriggerIconStyle.selectableCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            MenuBarTriggerIconPreview(
                style: settings.menuBarTriggerIconStyle,
                isAnimated: settings.useSpillAnimation
            )

            Text(settings.menuBarTriggerIconStyle.subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func t(_ key: PreferencesTextKey) -> String {
        PreferencesL10n.text(key, appLanguage: language)
    }
}
