import SwiftUI

struct SpillGlancePreferencesSection: View {
    @ObservedObject var settings: SpillSettings
    let language: SpillAppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(t(.showSpillGlance), systemImage: "rectangle.topthird.inset.filled")
                    .font(.callout)

                Spacer()

                Toggle(t(.showSpillGlance), isOn: $settings.glanceEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            Text(t(.spillGlanceDetail))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Label(t(.spillGlanceDisplay), systemImage: "rectangle.split.3x1")
                        .font(.callout)

                    Spacer()

                    Picker(t(.spillGlanceDisplay), selection: $settings.glanceDisplayStyle) {
                        Text(t(.spillGlanceDisplayAll)).tag(SpillGlanceDisplayStyle.all)
                        Text(t(.spillGlanceDisplayTicker)).tag(SpillGlanceDisplayStyle.ticker)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }

                HStack {
                    Label(t(.spillGlanceReactiveRotation), systemImage: "waveform.path.ecg")
                        .font(.callout)

                    Spacer()

                    Toggle(
                        t(.spillGlanceReactiveRotation),
                        isOn: $settings.glanceReactiveRotationEnabled
                    )
                    .labelsHidden()
                    .toggleStyle(.switch)
                }

                Text(t(.spillGlanceReactiveRotationDetail))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Label(t(.spillGlanceShowInFullScreen), systemImage: "rectangle.inset.filled")
                        .font(.callout)

                    Spacer()

                    Toggle(
                        t(.spillGlanceShowInFullScreen),
                        isOn: $settings.glanceShowInFullScreen
                    )
                    .labelsHidden()
                    .toggleStyle(.switch)
                }

                Text(t(.spillGlanceShowInFullScreenDetail))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .disabled(!settings.glanceEnabled)
            .opacity(settings.glanceEnabled ? 1 : 0.55)

            Divider()
                .background(Color.primary.opacity(0.04))

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Label(t(.spillGlanceWorkRotation), systemImage: "repeat")
                        .font(.callout)

                    Spacer()

                    Toggle(
                        t(.spillGlanceWorkRotation),
                        isOn: $settings.glanceWorkRotationEnabled
                    )
                    .labelsHidden()
                    .toggleStyle(.switch)
                }

                Text(t(.spillGlanceWorkRotationDetail))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .disabled(!settings.glanceEnabled)
            .opacity(settings.glanceEnabled ? 1 : 0.55)

            Divider()
                .background(Color.primary.opacity(0.04))

            VStack(spacing: 9) {
                ForEach(SpillGlanceModule.configurableToolModules) { module in
                    HStack {
                        Label(title(for: module), systemImage: symbolName(for: module))
                            .font(.callout)

                        Spacer()

                        Toggle(title(for: module), isOn: moduleBinding(for: module))
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }
            }
            .disabled(!settings.glanceEnabled)
            .opacity(settings.glanceEnabled ? 1 : 0.55)
        }
    }

    private func moduleBinding(for module: SpillGlanceModule) -> Binding<Bool> {
        Binding {
            settings.isGlanceModuleEnabled(module)
        } set: { enabled in
            settings.setGlanceModule(module, enabled: enabled)
        }
    }

    private func title(for module: SpillGlanceModule) -> String {
        switch module {
        case .codexToday:
            return t(.spillGlanceCodex)
        case .claudeToday:
            return t(.spillGlanceClaude)
        case .antigravityToday:
            return t(.spillGlanceAntigravity)
        case .allToday, .workType:
            return ""
        }
    }

    private func symbolName(for module: SpillGlanceModule) -> String {
        switch module {
        case .codexToday:
            return "terminal.fill"
        case .claudeToday:
            return "brain.head.profile"
        case .antigravityToday:
            return "sparkles"
        case .allToday, .workType:
            return "circle"
        }
    }

    private func t(_ key: PreferencesTextKey) -> String {
        PreferencesL10n.text(key, appLanguage: language)
    }
}
