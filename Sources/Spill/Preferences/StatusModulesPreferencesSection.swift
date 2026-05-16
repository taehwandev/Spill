import SwiftUI

struct StatusModulesPreferencesSection: View {
    @ObservedObject var settings: SpillSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            panelModulesSection

            Divider()

            menuBarGlanceSection
        }
    }

    private var panelModulesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Panel Status",
                symbolName: "gauge",
                trailing: "\(settings.enabledStatusModules.count)/\(SpillStatusModule.defaultOrder.count)"
            )

            VStack(spacing: 8) {
                ForEach(Array(settings.statusModuleOrder.enumerated()), id: \.element) { index, module in
                    moduleRow(module: module, index: index)
                }
            }
        }
    }

    private var menuBarGlanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Clock Area",
                symbolName: "menubar.rectangle",
                trailing: menuBarPreviewText
            )

            HStack(spacing: 18) {
                Toggle("CPU", isOn: menuBarStatusBinding(for: .cpu))
                    .toggleStyle(.switch)

                Toggle("Memory", isOn: menuBarStatusBinding(for: .memory))
                    .toggleStyle(.switch)
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

    private func moduleRow(module: SpillStatusModule, index: Int) -> some View {
        HStack(spacing: 10) {
            Toggle(isOn: enabledBinding(for: module)) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(module.title)
                            .font(.callout)
                        Text(module.preferenceSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: module.symbolName)
                }
            }
            .toggleStyle(.switch)

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                reorderButton(symbolName: "chevron.up") {
                    settings.moveStatusModule(module, direction: -1)
                }
                .disabled(index == 0)

                reorderButton(symbolName: "chevron.down") {
                    settings.moveStatusModule(module, direction: 1)
                }
                .disabled(index == settings.statusModuleOrder.count - 1)
            }
        }
        .padding(.vertical, 2)
    }

    private func enabledBinding(for module: SpillStatusModule) -> Binding<Bool> {
        Binding {
            settings.isStatusModuleEnabled(module)
        } set: { enabled in
            settings.setStatusModule(module, enabled: enabled)
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
        let parts = enabledItems.map { item in
            let value = settings.menuBarStatusPrecision.percentText(for: previewValues[item] ?? 0)
            return settings.menuBarStatusDisplayStyle.text(label: item.shortTitle, value: value)
        }

        return parts.isEmpty ? "Icon Only" : parts.joined(separator: "  ")
    }

    private func reorderButton(symbolName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbolName)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(symbolName == "chevron.up" ? "Move up" : "Move down")
    }
}
