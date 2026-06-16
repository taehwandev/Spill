import SwiftUI

struct PanelStatusPreferencesSection: View {
    @ObservedObject var settings: SpillSettings

    private func t(_ key: PreferencesTextKey) -> String {
        PreferencesL10n.text(key, appLanguage: settings.appLanguage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t(.panelStatusDetail))
                .font(.footnote)
                .foregroundStyle(.secondary)

            panelStatusPreview

            // Status value bold
            HStack {
                Label(t(.statusValueBold), systemImage: "bold")
                    .font(.callout)
                Spacer()
                Toggle(t(.statusValueBold), isOn: $settings.statusValueBold)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            // Font design
            HStack(alignment: .center) {
                Label(t(.statusFontDesign), systemImage: "textformat")
                    .font(.callout)
                Spacer()
                Picker("", selection: $settings.statusFontDesign) {
                    ForEach(SpillStatusFontDesign.allCases) { design in
                        Text(design.title(appLanguage: settings.appLanguage)).tag(design)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                .labelsHidden()
            }

            // Value font size slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label(t(.statusValueSize), systemImage: "textformat.size")
                        .font(.callout)
                    Spacer()
                    Text("\(Int(settings.statusValueFontSize))pt")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: $settings.statusValueFontSize,
                    in: 12...24,
                    step: 1
                )
            }

            // Panel section spacing
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label(t(.panelSectionSpacing), systemImage: "arrow.up.and.down")
                        .font(.callout)
                    Spacer()
                    Text("\(Int(settings.panelSectionSpacing))pt")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: $settings.panelSectionSpacing,
                    in: 6...24,
                    step: 1
                )
            }
        }
    }

    private var panelStatusPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(t(.preview), systemImage: "rectangle.and.text.magnifyingglass")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: panelPreviewSpacing) {
                panelPreviewRow(symbolName: "cpu", title: "CPU", value: "34.0%")
                panelPreviewRow(
                    symbolName: "memorychip",
                    title: AppL10n.statusModuleTitle(.memory, appLanguage: settings.appLanguage),
                    value: "62.0%"
                )
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.8)
            )
        }
    }

    private func panelPreviewRow(symbolName: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 18)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(
                    .system(
                        size: CGFloat(settings.statusValueFontSize),
                        weight: settings.statusValueBold ? .bold : .regular,
                        design: settings.statusFontDesign.fontDesign
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var panelPreviewSpacing: CGFloat {
        let spacing = CGFloat(settings.panelSectionSpacing)
        return min(max(spacing, 6), 24)
    }
}

struct ClockAreaStatusPreferencesSection: View {
    @ObservedObject var settings: SpillSettings

    private func t(_ key: PreferencesTextKey) -> String {
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
                title: t(.layout),
                symbolName: "rectangle.split.2x1",
                selection: $settings.menuBarStatusLayoutStyle
            ) {
                ForEach(MenuBarStatusLayoutStyle.allCases) { layout in
                    Text(layout.title(appLanguage: settings.appLanguage)).tag(layout)
                }
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

    private var clockAreaItems: [SpillMenuBarStatusItem] {
        [.caffeine, .cpu, .memory, .ai]
    }

    private func menuBarStatusBinding(for item: SpillMenuBarStatusItem) -> Binding<Bool> {
        Binding {
            settings.isMenuBarStatusItemEnabled(item)
        } set: { enabled in
            settings.setMenuBarStatusItem(item, enabled: enabled)
        }
    }

    private var clockAreaPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(t(.preview), systemImage: "clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(settings.menuBarStatusLayoutStyle.title(appLanguage: settings.appLanguage))
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

                previewChip(symbolName: "drop.fill", label: nil, value: nil, isTrigger: true)

                ForEach(previewItems) { item in
                    previewChip(
                        symbolName: item.symbolName,
                        label: previewLabel(for: item),
                        value: previewValue(for: item),
                        isTrigger: false
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

    private var previewItems: [SpillMenuBarStatusItem] {
        let enabledItems = SpillMenuBarStatusItem.defaultOrder.filter {
            settings.enabledMenuBarStatusItems.contains($0)
                && SpillMenuBarStatusItem.glanceSupported.contains($0)
                && $0 != .caffeine
        }
        return enabledItems
    }

    @ViewBuilder
    private func previewChip(
        symbolName: String,
        label: String?,
        value: String?,
        isTrigger: Bool
    ) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbolName)
                .font(.system(size: 10.5, weight: .semibold))
                .symbolRenderingMode(.hierarchical)

            if settings.menuBarStatusLayoutStyle == .stacked, !isTrigger, value != nil {
                VStack(spacing: 0) {
                    if let label {
                        Text(label)
                            .font(.system(size: max(clockPreviewTextSize * 0.56, 7), weight: .semibold))
                    }

                    if let value {
                        Text(value)
                            .font(.system(
                                size: max(clockPreviewTextSize * 0.80, 9),
                                weight: settings.menuBarStatusTextBold ? .semibold : .regular,
                                design: .monospaced
                            ))
                    }
                }
            } else {
                if let label {
                    Text(label)
                        .font(.system(
                            size: max(clockPreviewTextSize - 2.5, 8),
                            weight: settings.menuBarStatusTextBold ? .semibold : .regular,
                            design: .rounded
                        ))
                }

                if let value {
                    Text(value)
                        .font(.system(
                            size: clockPreviewTextSize,
                            weight: settings.menuBarStatusTextBold ? .semibold : .regular,
                            design: .monospaced
                        ))
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .foregroundStyle(isTrigger ? Color.accentColor : Color.primary.opacity(0.84))
        .padding(.horizontal, isTrigger ? 7 : 8)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(isTrigger ? 0.04 : 0.075), in: Capsule())
    }

    private var clockPreviewTextSize: CGFloat {
        let size = CGFloat(settings.menuBarStatusFontSize)
        return min(max(size, 10), 15)
    }

    private func previewLabel(for item: SpillMenuBarStatusItem) -> String? {
        switch item {
        case .caffeine:
            return nil
        case .memory where settings.menuBarStatusLayoutStyle == .stacked:
            return "RAM"
        default:
            return item.shortTitle
        }
    }

    private func previewValue(for item: SpillMenuBarStatusItem) -> String? {
        let previewValues: [SpillMenuBarStatusItem: Double] = [
            .cpu: 0.34,
            .memory: 0.62
        ]
        switch item {
        case .caffeine:
            return nil
        case .ai:
            return "1.44M"
        case .cpu, .memory:
            let value = settings.menuBarStatusPrecision.percentText(for: previewValues[item] ?? 0)
            return value
        case .gpu, .network:
            return nil
        }
    }

    private func optionPicker<Value: Hashable, Content: View>(
        title: String,
        symbolName: String,
        selection: Binding<Value>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 10) {
            Label(title, systemImage: symbolName)
                .font(.callout)

            Spacer()

            Picker(title, selection: selection, content: content)
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: 210)
        }
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
