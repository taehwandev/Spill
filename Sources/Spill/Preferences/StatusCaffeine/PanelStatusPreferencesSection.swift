import AppKit
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

            Toggle("GPU", isOn: Binding(
                get: { settings.isStatusModuleEnabled(.gpu) },
                set: { settings.setStatusModule(.gpu, enabled: $0) }
            ))
            .toggleStyle(.switch)

            // Status value bold
            HStack {
                Label(t(.statusValueBold), systemImage: "bold")
                    .font(.callout)
                Spacer()
                Toggle(t(.statusValueBold), isOn: $settings.panelStatusValueBold)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            // Font design
            HStack(alignment: .center) {
                Label(t(.statusFontDesign), systemImage: "textformat")
                    .font(.callout)
                Spacer()
                Picker("", selection: $settings.panelStatusFontDesign) {
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
                    Text("\(Int(settings.panelStatusValueFontSize))pt")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: $settings.panelStatusValueFontSize,
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

}

extension PanelStatusPreferencesSection {
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
                        size: CGFloat(settings.panelStatusValueFontSize),
                        weight: settings.panelStatusValueBold ? .bold : .regular,
                        design: settings.panelStatusFontDesign.fontDesign
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
