import AppKit
import SwiftUI

struct GeneralPreferencesSection: View {
    @ObservedObject var settings: SpillSettings
    @ObservedObject var updateStore: UpdateCheckStore
    @Binding var loginItemError: String?
    @State private var showsWindowShortcuts = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Launch at Login - at the absolute top!
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Launch at Login", isOn: launchAtLoginBinding)
                    .disabled(!LoginItemController.isAvailable)
                    .font(.body.weight(.medium))

                if !LoginItemController.isAvailable {
                    Text("Launch at Login is available after packaging Spill as a .app bundle.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let loginItemError {
                    Text(loginItemError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Divider()
                .background(Color.primary.opacity(0.04))

            UpdatePreferencesSection(store: updateStore)

            Divider()
                .background(Color.primary.opacity(0.04))

            // Main Animation & Global Shortcut Toggles
            Toggle("Use spill animation", isOn: $settings.useSpillAnimation)

            triggerIconSection

            VStack(alignment: .leading, spacing: 4) {
                Toggle("Keyboard shortcut", isOn: $settings.hotKeyEnabled)

                if settings.hotKeyEnabled {
                    Text("\(WindowActionShortcutModifier.standard.title) + Space")
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                        .padding(.leading, 20)
                }
            }

            Divider()
                .background(Color.primary.opacity(0.04))

            // Menu Bar Layout Customization
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Menu bar icon spacing", systemImage: "camera.viewfinder")
                        .font(.body.weight(.medium))
                    Spacer()
                    Text("\(Int(settings.iconSpacing)) px")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Slider(value: $settings.iconSpacing, in: 2...16, step: 1)
            }

            Divider()
                .background(Color.primary.opacity(0.04))

            // Window Snap Shortcuts under an elegant DisclosureGroup
            DisclosureGroup(isExpanded: $showsWindowShortcuts) {
                windowShortcutsSection
                    .padding(.top, 8)
            } label: {
                Label("Window Snap Shortcuts", systemImage: "macwindow")
                    .font(.body.weight(.medium))
            }
        }
    }

    private var windowShortcutsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(WindowActionKind.panelOrder, id: \.self) { kind in
                HStack(spacing: 10) {
                    Label(kind.title, systemImage: kind.symbolName)
                        .font(.callout)

                    Spacer()

                    Text(kind.shortcutModifier.glyph)
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)

                    Picker("", selection: shortcutBinding(for: kind)) {
                        ForEach(WindowActionShortcutKey.allCases) { key in
                            Text(key.pickerTitle).tag(key)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 74)
                }
            }
        }
    }

    private var triggerIconSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Menu bar trigger icon", systemImage: "menubar.rectangle")
                    .font(.body.weight(.medium))
                Spacer()
                Text(settings.menuBarTriggerIconStyle.title)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Picker("Menu bar trigger icon", selection: $settings.menuBarTriggerIconStyle) {
                ForEach(MenuBarTriggerIconStyle.selectableCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            MenuBarTriggerIconPreview(
                style: settings.menuBarTriggerIconStyle,
                isAnimated: settings.useSpillAnimation
            )

            Text(settings.menuBarTriggerIconStyle.subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func shortcutBinding(for kind: WindowActionKind) -> Binding<WindowActionShortcutKey> {
        Binding {
            settings.shortcutKey(for: kind)
        } set: { key in
            settings.setWindowActionShortcut(key, for: kind)
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding {
            settings.launchAtLogin
        } set: { enabled in
            do {
                try LoginItemController.setEnabled(enabled)
                settings.launchAtLogin = LoginItemController.isEnabled
                loginItemError = nil
            } catch {
                settings.launchAtLogin = LoginItemController.isEnabled
                loginItemError = error.localizedDescription
            }
        }
    }
}

@MainActor
private struct MenuBarTriggerIconPreview: View {
    private static let appliedTriggerIconSize: CGFloat = 18

    let style: MenuBarTriggerIconStyle
    let isAnimated: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: !isAnimated || !style.animates)) { context in
            let phase = isAnimated ? phase(for: context.date) : 0.18
            let usageRatio = previewUsageRatio(for: style, phase: phase)

            HStack(spacing: 10) {
                Text("Preview")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    triggerImage(style: style, phase: phase, usageRatio: usageRatio)
                        .frame(width: Self.appliedTriggerIconSize, height: Self.appliedTriggerIconSize)

                    Text("12:45")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(.regularMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                )

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func triggerImage(style: MenuBarTriggerIconStyle, phase: CGFloat, usageRatio: Double) -> some View {
        Group {
            if let image = MenuBarTriggerIconRenderer.image(
                style: style,
                tintColor: .controlAccentColor,
                usageRatio: usageRatio,
                phase: phase,
                size: Self.appliedTriggerIconSize
            ) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
            } else {
                Image(systemName: style.symbolName(isActive: false))
                    .font(.system(size: 16, weight: .semibold))
            }
        }
        .foregroundStyle(Color.accentColor)
    }

    private func phase(for date: Date) -> CGFloat {
        CGFloat(date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1))
    }

    private func previewUsageRatio(for style: MenuBarTriggerIconStyle, phase: CGFloat) -> Double {
        guard style.usesPerformanceEffect else {
            return 0.35
        }

        let wave = (sin(Double(phase) * .pi * 2) + 1) / 2
        return 0.35 + wave * 0.45
    }
}
