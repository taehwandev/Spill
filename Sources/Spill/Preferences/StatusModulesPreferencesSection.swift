import SwiftUI

struct StatusModulesPreferencesSection: View {
    @ObservedObject var settings: SpillSettings

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
                title: "Panel Status",
                symbolName: "waveform.path.ecg",
                trailing: settings.showsCPUCoreChart ? "Core Bars" : "Aggregate"
            )

            HStack {
                Label("CPU Core Bars", systemImage: "cpu")
                    .font(.callout)
                Spacer()
                Toggle("CPU Core Bars", isOn: $settings.showsCPUCoreChart)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }
    }

    private var menuBarGlanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Clock Area Status",
                symbolName: "menubar.rectangle",
                trailing: menuBarPreviewText
            )

            VStack(spacing: 8) {
                ForEach(clockAreaItems) { item in
                    HStack {
                        Label(item.title, systemImage: item.symbolName)
                            .font(.callout)
                        Spacer()
                        Toggle(item.title, isOn: menuBarStatusBinding(for: item))
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }
            }

            Picker("Format", selection: $settings.menuBarStatusDisplayStyle) {
                ForEach(MenuBarStatusDisplayStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)

            Picker("Decimals", selection: $settings.menuBarStatusPrecision) {
                ForEach(MenuBarStatusPrecision.allCases) { precision in
                    Text(precision.title).tag(precision)
                }
            }
            .pickerStyle(.segmented)

            Picker("Highlight", selection: $settings.menuBarStatusHighlightThreshold) {
                ForEach(MenuBarStatusHighlightThreshold.allCases) { threshold in
                    Text(threshold.title).tag(threshold)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var clockAreaItems: [SpillMenuBarStatusItem] {
        [.cpu, .memory, .caffeine]
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

            let value = settings.menuBarStatusPrecision.percentText(for: previewValues[item] ?? 0)
            return settings.menuBarStatusDisplayStyle.text(label: item.shortTitle, value: value)
        }

        return parts.isEmpty ? "Icon Only" : parts.joined(separator: "  ")
    }
}
