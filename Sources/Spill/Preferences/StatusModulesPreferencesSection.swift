import SwiftUI

struct StatusModulesPreferencesSection: View {
    @ObservedObject var settings: SpillSettings

    private func t(_ key: PreferencesTextKey) -> String {
        PreferencesL10n.text(key, appLanguage: settings.appLanguage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            panelStatusSection
            Divider()
            menuBarGlanceSection
        }
    }

    private var panelStatusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: t(.panelStatus),
                symbolName: "waveform.path.ecg",
                trailing: settings.showsCPUCoreChart ? t(.coreBars) : t(.aggregate)
            )

            HStack {
                Label(t(.cpuCoreBars), systemImage: "cpu")
                    .font(.callout)
                Spacer()
                Toggle(t(.cpuCoreBars), isOn: $settings.showsCPUCoreChart)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }
    }

    private var menuBarGlanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: t(.clockAreaStatus),
                symbolName: "menubar.rectangle",
                trailing: menuBarPreviewText
            )

            VStack(spacing: 8) {
                ForEach(clockAreaItems) { item in
                    HStack {
                        Label(menuBarStatusTitle(for: item), systemImage: item.symbolName)
                            .font(.callout)
                        Spacer()
                        Toggle(menuBarStatusTitle(for: item), isOn: menuBarStatusBinding(for: item))
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }
            }

            Picker(t(.layout), selection: $settings.menuBarStatusLayoutStyle) {
                ForEach(MenuBarStatusLayoutStyle.allCases) { layout in
                    Text(layout.title(appLanguage: settings.appLanguage)).tag(layout)
                }
            }
            .pickerStyle(.segmented)

            Picker(t(.format), selection: $settings.menuBarStatusDisplayStyle) {
                ForEach(MenuBarStatusDisplayStyle.allCases) { style in
                    Text(style.title(appLanguage: settings.appLanguage)).tag(style)
                }
            }
            .pickerStyle(.segmented)

            Picker(t(.decimals), selection: $settings.menuBarStatusPrecision) {
                ForEach(MenuBarStatusPrecision.allCases) { precision in
                    Text(precision.title).tag(precision)
                }
            }
            .pickerStyle(.segmented)

            Picker(t(.highlight), selection: $settings.menuBarStatusHighlightThreshold) {
                ForEach(MenuBarStatusHighlightThreshold.allCases) { threshold in
                    Text(threshold.title).tag(threshold)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var clockAreaItems: [SpillMenuBarStatusItem] {
        [.cpu, .memory, .caffeine, .ai]
    }

    private func sectionHeader(title: String, symbolName: String, trailing: String) -> some View {
        HStack(spacing: 10) {
            Label(title, systemImage: symbolName)
            Spacer()
            Text(trailing)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func menuBarStatusBinding(for item: SpillMenuBarStatusItem) -> Binding<Bool> {
        Binding {
            settings.isMenuBarStatusItemEnabled(item)
        } set: { enabled in
            settings.setMenuBarStatusItem(item, enabled: enabled)
        }
    }

    private var menuBarPreviewText: String {
        let enabledItems = SpillMenuBarStatusItem.defaultOrder.filter {
            settings.enabledMenuBarStatusItems.contains($0) && SpillMenuBarStatusItem.glanceSupported.contains($0)
        }
        let previewValues: [SpillMenuBarStatusItem: Double] = [
            .cpu: 0.34,
            .memory: 0.62
        ]
        let parts = enabledItems.compactMap { item -> String? in
            if item == .caffeine {
                return nil
            }

            if item == .ai {
                return item.shortTitle
            }

            let value = settings.menuBarStatusPrecision.percentText(for: previewValues[item] ?? 0)
            if settings.menuBarStatusLayoutStyle == .stacked {
                return "\(stackedPreviewTitle(for: item)) \(value)"
            }

            return settings.menuBarStatusDisplayStyle.text(label: item.shortTitle, value: value)
        }

        return parts.isEmpty ? t(.iconOnly) : parts.joined(separator: "  ")
    }

    private func stackedPreviewTitle(for item: SpillMenuBarStatusItem) -> String {
        item == .memory ? "RAM" : item.shortTitle
    }

    private func menuBarStatusTitle(for item: SpillMenuBarStatusItem) -> String {
        switch item {
        case .cpu:
            return "CPU"
        case .memory:
            return AppL10n.statusModuleTitle(.memory, appLanguage: settings.appLanguage)
        case .caffeine:
            return AppL10n.text(.caffeine, appLanguage: settings.appLanguage)
        case .gpu:
            return "GPU"
        case .network:
            return AppL10n.statusModuleTitle(.network, appLanguage: settings.appLanguage)
        case .ai:
            return "AI"
        }
    }
}
