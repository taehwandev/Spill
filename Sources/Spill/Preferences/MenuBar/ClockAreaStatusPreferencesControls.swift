import SwiftUI

// Shared row builders and titles for the clock-area controls.

extension ClockAreaStatusPreferencesSection {
    func optionPicker<Value: Hashable, Content: View>(
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

    func modeToggle(
        title: String,
        detail: String,
        systemImage: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.callout)

            VStack(alignment: .leading, spacing: 2) {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Toggle(title, isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }

    func menuBarStatusTitle(for item: SpillMenuBarStatusItem) -> String {
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
