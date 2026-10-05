import AppKit
import SwiftUI

@MainActor
struct ClockAreaStatusPreferencesSection: View {
    @ObservedObject var settings: SpillSettings

    func t(_ key: PreferencesTextKey) -> String {
        PreferencesL10n.text(key, appLanguage: settings.appLanguage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            clockAreaPreview

            Text(t(.clockAreaStatusDetail))
                .font(.footnote)
                .foregroundStyle(.secondary)

            VStack(spacing: 9) {
                ForEach(clockAreaItems) { item in
                    if SpillMenuBarStatusItem.graphPresentationSupported.contains(item) {
                        metricPresentationPicker(for: item)
                    } else {
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
            }

            if settings.isMenuBarStatusItemEnabled(.ai) {
                optionPicker(
                    title: t(.clockAreaTokenDisplay),
                    symbolName: "number.circle",
                    selection: $settings.menuBarTokenDisplayMode
                ) {
                    ForEach(MenuBarTokenDisplayMode.allCases) { mode in
                        Text(mode.title(appLanguage: settings.appLanguage)).tag(mode)
                    }
                }
            }

            optionPicker(
                title: t(.layout),
                symbolName: "rectangle.split.1x2",
                selection: $settings.menuBarStatusLayoutStyle
            ) {
                ForEach(MenuBarStatusLayoutStyle.allCases) { style in
                    Text(style.title(appLanguage: settings.appLanguage)).tag(style)
                }
            }

            modeToggle(
                title: t(.clockAreaCompactMode),
                detail: t(.clockAreaCompactModeDetail),
                systemImage: "rectangle.compress.vertical",
                isOn: $settings.menuBarStatusCompactMode
            )

            modeToggle(
                title: t(.clockAreaSplitGroups),
                detail: t(.clockAreaSplitGroupsDetail),
                systemImage: "rectangle.split.3x1",
                isOn: $settings.menuBarStatusSplitGroups
            )

            if settings.hasTextPresentedMenuBarStatusItems {
                HStack {
                    Label(t(.clockAreaTextBold), systemImage: "bold")
                        .font(.callout)
                    Spacer()
                    Toggle(t(.clockAreaTextBold), isOn: $settings.menuBarStatusTextBold)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label(t(.clockAreaTextSize), systemImage: "textformat.size")
                            .font(.callout)
                        Spacer()
                        Text(String(format: "%.1fpt", settings.menuBarStatusFontSize))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: $settings.menuBarStatusFontSize,
                        in: 10...15,
                        step: 0.5
                    )
                }

                optionPicker(
                    title: t(.decimals),
                    symbolName: "percent",
                    selection: $settings.menuBarStatusPrecision
                ) {
                    ForEach(MenuBarStatusPrecision.allCases) { precision in
                        Text(precision.title).tag(precision)
                    }
                }
            }

            optionPicker(
                title: t(.highlight),
                symbolName: "gauge.with.dots.needle.67percent",
                selection: $settings.menuBarStatusHighlightThreshold
            ) {
                ForEach(MenuBarStatusHighlightThreshold.allCases) { threshold in
                    Text(threshold.title).tag(threshold)
                }
            }
        }
    }

}

extension ClockAreaStatusPreferencesSection {
    var clockAreaItems: [SpillMenuBarStatusItem] {
        [.caffeine, .cpu, .memory, .network, .ai]
    }

    func menuBarStatusBinding(for item: SpillMenuBarStatusItem) -> Binding<Bool> {
        Binding {
            settings.isMenuBarStatusItemEnabled(item)
        } set: { enabled in
            settings.setMenuBarStatusItem(item, enabled: enabled)
        }
    }

    func metricPresentationBinding(
        for item: SpillMenuBarStatusItem
    ) -> Binding<MenuBarMetricPresentationMode> {
        Binding {
            settings.menuBarMetricPresentationMode(for: item)
        } set: { mode in
            settings.setMenuBarMetricPresentationMode(mode, for: item)
        }
    }

    func metricPresentationPicker(for item: SpillMenuBarStatusItem) -> some View {
        optionPicker(
            title: menuBarStatusTitle(for: item),
            symbolName: item.symbolName,
            selection: metricPresentationBinding(for: item)
        ) {
            ForEach(MenuBarMetricPresentationMode.allCases) { mode in
                Text(mode.title(appLanguage: settings.appLanguage)).tag(mode)
            }
        }
    }

    var clockAreaPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(t(.preview), systemImage: "clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(previewModeTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 5) {
                if settings.isMenuBarStatusItemEnabled(.caffeine) {
                    previewChip(
                        symbolName: SpillMenuBarStatusItem.caffeine.symbolName,
                        label: nil,
                        value: nil,
                        isTrigger: false
                    )
                }

                previewChip(
                    symbolName: settings.menuBarTriggerIconStyle.symbolName(isActive: false),
                    label: nil,
                    value: nil,
                    isTrigger: true,
                    triggerStyle: settings.menuBarTriggerIconStyle
                )

                ForEach(previewItems) { item in
                    let chartSeries = previewChartSeries(for: item)
                    previewChip(
                        symbolName: item.symbolName,
                        label: previewLabel(for: item),
                        value: chartSeries == nil ? previewValue(for: item) : nil,
                        isTrigger: false,
                        chartSeries: chartSeries
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.8)
            )
        }
    }

    var previewItems: [SpillMenuBarStatusItem] {
        let enabledItems = SpillMenuBarStatusItem.defaultOrder.filter {
            settings.enabledMenuBarStatusItems.contains($0)
                && SpillMenuBarStatusItem.glanceSupported.contains($0)
                && $0 != .caffeine
        }
        return enabledItems
    }
}
