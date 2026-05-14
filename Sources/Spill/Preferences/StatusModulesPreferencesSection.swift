import SwiftUI

struct StatusModulesPreferencesSection: View {
    @ObservedObject var settings: SpillSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Label("Status Modules", systemImage: "gauge")
                Spacer()
                Text("\(settings.enabledStatusModules.count)/\(SpillStatusModule.allCases.count)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                ForEach(Array(settings.statusModuleOrder.enumerated()), id: \.element) { index, module in
                    moduleRow(module: module, index: index)
                }
            }
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
