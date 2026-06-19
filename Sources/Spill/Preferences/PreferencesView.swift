import AppKit
import SwiftUI

// Frosted Glass Effect Wrapper
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// Sophisticated Container for Settings Sections
struct PreferenceCard<Content: View>: View {
    let title: String
    let symbolName: String
    let iconColor: Color
    let content: Content

    init(title: String, symbolName: String, iconColor: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.symbolName = symbolName
        self.iconColor = iconColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [iconColor, iconColor.opacity(0.78)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: iconColor.opacity(0.3), radius: 3, x: 0, y: 1.5)

                    Image(systemName: symbolName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 22, height: 22)

                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
            }
            .padding(.bottom, 2)

            content
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.07), lineWidth: 0.5)
        }
    }
}

@MainActor
final class PreferencesNavigationState: ObservableObject {
    @Published var selectedTab: String = "general"
}

struct PreferencesView: View {
    @ObservedObject var settings: SpillSettings
    @ObservedObject var scanner: AXMenuBarItemScanner
    @ObservedObject var updateStore: UpdateCheckStore
    @ObservedObject var navigationState: PreferencesNavigationState
    let tokenUsageStore: TokenUsageStore
    @ObservedObject var tokenHistoryImportCoordinator: TokenUsageHistoryImportCoordinator
    let showPanelAction: () -> Void
    let openTokenDashboardAction: () -> Void
    @State private var accessibilityTrusted = AccessibilityPermission.isTrusted
    @State private var loginItemError: String?
    @State private var hoveredTab: String? = nil

    private func t(_ key: PreferencesTextKey) -> String {
        PreferencesL10n.text(key, appLanguage: settings.appLanguage)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left Sidebar
            VStack(alignment: .leading, spacing: 0) {
                // Header Brand Section
                HStack(spacing: 10) {
                    SpillBrandIconView()
                        .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Spill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.primary)
                        Text("v\(updateStore.currentVersion)")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 16)

                // Navigation List
                VStack(spacing: 4) {
                    sidebarItem(title: t(.general), imageName: "gearshape.fill", tag: "general")
                    sidebarItem(title: t(.menuBar), imageName: "menubar.rectangle", tag: "menubar")
                    sidebarItem(title: t(.tokenMetering), imageName: "chart.bar.xaxis", tag: "tokens")
                    sidebarItem(title: t(.windowManagement), imageName: "macwindow", tag: "windows")
                    sidebarItem(title: t(.statusAndCaffeine), imageName: "cup.and.saucer.fill", tag: "status_caffeine")
                    if SpillBuildOptions.developerOptionsEnabled {
                        sidebarItem(title: t(.developerOptions), imageName: "hammer.fill", tag: "developer")
                    }
                }
                .padding(.horizontal, 8)

                Spacer()

                // Bottom Check for Updates
                VStack(spacing: 8) {
                    Divider()
                        .background(Color.primary.opacity(0.06))
                        .padding(.horizontal, 12)

                    Button {
                        updateStore.checkForUpdates(source: "preferences_sidebar")
                    } label: {
                        HStack(spacing: 6) {
                            if updateStore.isChecking {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.7)
                                    .frame(width: 12, height: 12)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            Text(updateStore.isChecking ? t(.checkingForUpdates) : t(.checkForUpdates))
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 16)
                }
            }
            .frame(width: 170)
            .background(
                LinearGradient(
                    colors: [
                        Color.primary.opacity(0.005),
                        Color.primary.opacity(0.02)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            Divider()
                .background(Color.primary.opacity(0.08))

            // Right Detail Panel
            VStack(alignment: .leading, spacing: 0) {
                // Top Tab Title
                HStack {
                    Text(tabTitle(for: navigationState.selectedTab))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 14)

                // Scrollable Content
                ScrollView(.vertical, showsIndicators: false) {
                    detailContent(for: navigationState.selectedTab)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                VisualEffectView(material: .windowBackground, blendingMode: .withinWindow)
            )
        }
        .background(VisualEffectView(material: .sidebar, blendingMode: .withinWindow)) // Frosted Glass Window Base
        .frame(width: 720, height: 560)
        .onAppear {
            refreshPermissionState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissionState()
        }
    }

    private func sidebarItem(title: String, imageName: String, tag: String) -> some View {
        let isSelected = navigationState.selectedTab == tag
        let isHovered = hoveredTab == tag

        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                navigationState.selectedTab = tag
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: imageName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : (isHovered ? .primary : .secondary))
                    .frame(width: 16, height: 16)
                    .scaleEffect(isHovered && !isSelected ? 1.08 : 1.0)

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .white : (isHovered ? .primary : .primary.opacity(0.85)))

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.82)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.accentColor.opacity(0.24), radius: 4, x: 0, y: 1.5)
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
                }
            }
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                hoveredTab = hovering ? tag : nil
            }
        }
    }

    private func tabTitle(for tab: String) -> String {
        switch tab {
        case "general": return t(.general)
        case "menubar": return t(.menuBarAndNotch)
        case "tokens": return t(.tokenMetering)
        case "windows": return t(.windowManagement)
        case "status_caffeine": return t(.statusAndCaffeine)
        case "developer" where SpillBuildOptions.developerOptionsEnabled:
            return t(.developerOptions)
        default: return ""
        }
    }

    @ViewBuilder
    private func detailContent(for tab: String) -> some View {
        switch tab {
        case "general":
            generalTab
        case "menubar":
            menuBarTab
        case "tokens":
            tokensTab
        case "windows":
            windowsTab
        case "status_caffeine":
            statusCaffeineTab
        case "developer" where SpillBuildOptions.developerOptionsEnabled:
            developerOptionsTab
        default:
            EmptyView()
        }
    }

    // MARK: - Tab Views

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            PreferenceCard(title: t(.launchSettings), symbolName: "play.circle.fill", iconColor: .blue) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(t(.launchAtLogin), isOn: launchAtLoginBinding)
                        .disabled(!LoginItemController.isAvailable)
                        .font(.system(size: 13, weight: .medium))

                    if !LoginItemController.isAvailable {
                        Text(t(.launchAtLoginUnavailable))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    if let loginItemError {
                       Text(loginItemError)
                           .font(.system(size: 12))
                           .foregroundStyle(.red)
                    }

                }
            }

            PreferenceCard(title: t(.languageSettings), symbolName: "globe", iconColor: .purple) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(t(.appLanguage))
                            .font(.system(size: 13, weight: .medium))

                        Spacer()

                        Picker("", selection: $settings.appLanguage) {
                            ForEach(SpillAppLanguage.allCases) { language in
                                Text(language.title).tag(language)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }

                    Text(PreferencesL10n.languageDetail(settings.appLanguage, appLanguage: settings.appLanguage))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            PreferenceCard(title: t(.permissionsAndDiagnostics), symbolName: "lock.shield.fill", iconColor: .green) {
                AccessibilityPreferencesSection(
                    scanner: scanner,
                    accessibilityTrusted: $accessibilityTrusted,
                    showPanelAction: showPanelAction
                )
            }

            PreferenceCard(title: t(.updates), symbolName: "arrow.down.circle.fill", iconColor: .orange) {
                UpdatePreferencesSection(store: updateStore)
            }

            Divider()
                .background(Color.primary.opacity(0.04))

            openSourceFooter
        }
    }

    private var menuBarTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            PreferenceCard(title: t(.menuBarIconAnimation), symbolName: "paintpalette.fill", iconColor: .pink) {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(t(.useSpillAnimation), isOn: $settings.useSpillAnimation)
                        .font(.system(size: 13, weight: .medium))

                    Divider()
                        .background(Color.primary.opacity(0.04))

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(t(.menuBarTriggerIcon))
                                .font(.system(size: 12, weight: .bold))
                            Spacer()
                            Text(settings.menuBarTriggerIconStyle.title)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                        if MenuBarTriggerIconStyle.selectableCases.count > 1 {
                            Picker(t(.menuBarTriggerIcon), selection: $settings.menuBarTriggerIconStyle) {
                                ForEach(MenuBarTriggerIconStyle.selectableCases) { style in
                                    Text(style.title).tag(style)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                        }

                        MenuBarTriggerIconPreview(
                            style: settings.menuBarTriggerIconStyle,
                            isAnimated: settings.useSpillAnimation
                        )

                        Text(settings.menuBarTriggerIconStyle.subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Divider()
                        .background(Color.primary.opacity(0.04))

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(t(.menuBarIconSpacing))
                                .font(.system(size: 12, weight: .bold))
                            Spacer()
                            Text("\(Int(settings.iconSpacing)) px")
                                .font(.system(size: 12).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $settings.iconSpacing, in: 2...16, step: 1)
                    }
                }
            }

            PreferenceCard(title: t(.clockAreaStatus), symbolName: "menubar.rectangle", iconColor: .teal) {
                ClockAreaStatusPreferencesSection(settings: settings)
            }
        }
    }

    private var tokensTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            PreferenceCard(title: t(.tokenMetering), symbolName: "chart.bar.xaxis", iconColor: .teal) {
                TokenMeteringPreferencesSection(
                    settings: settings,
                    tokenUsageStore: tokenUsageStore,
                    tokenHistoryImportCoordinator: tokenHistoryImportCoordinator,
                    openDashboardAction: openTokenDashboardAction
                )
            }
        }
    }

    private var developerOptionsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            PreferenceCard(title: t(.developerOptions), symbolName: "hammer.fill", iconColor: .orange) {
                VStack(alignment: .leading, spacing: 12) {
                    Label(t(.debugOnly), systemImage: "ladybug.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.orange)

                    Text(t(.developerOptionsDetail))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()
                        .background(Color.primary.opacity(0.04))

                    developerToggle(
                        title: t(.dashboardOnboardingPreview),
                        detail: t(.dashboardOnboardingPreviewDetail),
                        isOn: $settings.panelOnboardingPreviewEnabled
                    )

                    Divider()
                        .background(Color.primary.opacity(0.04))

                    developerToggle(
                        title: t(.aiDashboardOnboardingPreview),
                        detail: t(.aiDashboardOnboardingPreviewDetail),
                        isOn: $settings.tokenUsageDashboardOnboardingPreviewEnabled
                    )

                    Divider()
                        .background(Color.primary.opacity(0.04))

                    TokenMeteringLocalDataManagementSection(
                        settings: settings,
                        tokenUsageStore: tokenUsageStore
                    )
                }
            }
        }
    }

    private func developerToggle(
        title: String,
        detail: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))

                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(.switch)
    }

    private var windowsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            PreferenceCard(title: t(.globalShortcut), symbolName: "keyboard", iconColor: .indigo) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(t(.keyboardShortcut), isOn: $settings.hotKeyEnabled)
                        .font(.system(size: 13, weight: .medium))

                    if settings.hotKeyEnabled {
                        Text("\(WindowActionShortcutModifier.standard.title) + Space")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 20)
                    }
                }
            }

            PreferenceCard(title: t(.windowSnapShortcuts), symbolName: "macwindow", iconColor: .blue) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(WindowActionKind.panelOrder, id: \.self) { kind in
                        HStack(spacing: 10) {
                            Label(kind.title, systemImage: kind.symbolName)
                                .font(.system(size: 12))

                            Spacer()

                            Text(kind.shortcutModifier.glyph)
                                .font(.system(size: 12, design: .monospaced))
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
        }
    }

    private var statusCaffeineTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            PreferenceCard(title: t(.panelStatus), symbolName: "waveform.path.ecg", iconColor: .purple) {
                PanelStatusPreferencesSection(settings: settings)
            }

            PreferenceCard(title: t(.caffeineSettings), symbolName: "cup.and.saucer.fill", iconColor: .orange) {
                PowerPreferencesSection(settings: settings)
            }
        }
    }

    // MARK: - Bindings & Helpers

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

    private func openSourceLink(source: String) {
        SpillTelemetry.shared.track(
            "open_source_link_clicked",
            props: ["source": "preferences_\(source)"]
        )
        if let url = URL(string: "https://github.com/taehwandev/Spill") {
            NSWorkspace.shared.open(url)
        }
    }

    private var openSourceFooter: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Button {
                    openSourceLink(source: "feedback")
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 11))
                        Text(t(.feedbackContribution))
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Text("•")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary.opacity(0.5))

                Button {
                    openSourceLink(source: "github")
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.forward.app.fill")
                            .font(.system(size: 11))
                        Text(t(.githubOpenSource))
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text(t(.openSourceLicense))
                .font(.system(size: 11))
                .foregroundStyle(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 8)
    }

    private func refreshPermissionState() {
        accessibilityTrusted = AccessibilityPermission.isTrusted
    }
}

// MARK: - Redefined Trigger Preview for split view self-containment
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
                Text(PreferencesL10n.text(.preview))
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
