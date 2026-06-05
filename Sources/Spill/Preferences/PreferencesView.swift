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
                        .fill(iconColor)

                    Image(systemName: symbolName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 22, height: 22)

                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
            }
            .padding(.bottom, 4)

            content
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
        .cornerRadius(12)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

struct PreferencesView: View {
    @ObservedObject var settings: SpillSettings
    @ObservedObject var scanner: AXMenuBarItemScanner
    @ObservedObject var updateStore: UpdateCheckStore
    let showPanelAction: () -> Void
    let openTokenDashboardAction: () -> Void
    @State private var accessibilityTrusted = AccessibilityPermission.isTrusted
    @State private var loginItemError: String?
    @State private var showsAdvancedDetection = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Header Brand Section
                HStack(spacing: 12) {
                    SpillBrandIconView()
                        .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Spill")
                            .font(.system(size: 16, weight: .bold))
                        Text("Menu bar overflow, under the notch.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()
                    .background(Color.primary.opacity(0.04))

                // Section 1: General Settings (Launch at Login, Animations, Shortcuts)
                PreferenceCard(title: "General & Launch", symbolName: "gearshape.fill", iconColor: .blue) {
                    GeneralPreferencesSection(
                        settings: settings,
                        updateStore: updateStore,
                        loginItemError: $loginItemError
                    )
                }

                // Section 2: Token Metering
                PreferenceCard(title: "Token Metering", symbolName: "chart.bar.xaxis", iconColor: .teal) {
                    TokenMeteringPreferencesSection(
                        settings: settings,
                        openDashboardAction: openTokenDashboardAction
                    )
                }

                // Section 3: Status Modules
                PreferenceCard(title: "Status Modules", symbolName: "waveform.path.ecg", iconColor: .purple) {
                    StatusModulesPreferencesSection(settings: settings)
                }

                // Section 4: Caffeine Options
                PreferenceCard(title: "Caffeine Settings", symbolName: "cup.and.saucer.fill", iconColor: .orange) {
                    PowerPreferencesSection(settings: settings)
                }

                // Section 5: System Permissions & Diagnostics
                PreferenceCard(title: "Permissions & Diagnostics", symbolName: "lock.shield.fill", iconColor: .green) {
                    AccessibilityPreferencesSection(
                        scanner: scanner,
                        accessibilityTrusted: $accessibilityTrusted,
                        showPanelAction: showPanelAction
                    )
                }

                Divider()
                    .background(Color.primary.opacity(0.04))

                // Section 6: Advanced Detection
                advancedDetectionSection

                Divider()
                    .background(Color.primary.opacity(0.04))

                // Section 7: Open Source Footer
                openSourceFooter
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(VisualEffectView(material: .sidebar, blendingMode: .withinWindow)) // Frosted Glass Window Base
        .frame(minWidth: 500, minHeight: 560)
        .onAppear {
            refreshPermissionState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissionState()
        }
    }

    private func refreshPermissionState() {
        accessibilityTrusted = AccessibilityPermission.isTrusted
    }

    private var advancedDetectionSection: some View {
        DisclosureGroup(isExpanded: advancedDetectionBinding) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Best-effort menu bar scanning is an advanced pinning and diagnostics tool. It is not required for normal panel use.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                DetectionPreferencesSection(
                    settings: settings,
                    scanner: scanner,
                    accessibilityTrusted: $accessibilityTrusted
                )

                DetectedItemsListView(items: scanner.items, settings: settings)
            }
            .padding(.top, 8)
        } label: {
            Label("Advanced Menu Bar Scan", systemImage: "menubar.rectangle")
                .font(.system(size: 9.5, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(.secondary.opacity(0.7))
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
                            .font(.system(size: 9))
                        Text("Feedback & Contribution")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Text("•")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary.opacity(0.5))

                Button {
                    openSourceLink(source: "github")
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.forward.app.fill")
                            .font(.system(size: 9))
                        Text("GitHub Open Source")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text("Spill is proudly open-source under the MIT license.")
                .font(.system(size: 9))
                .foregroundStyle(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 8)
    }

    private var advancedDetectionBinding: Binding<Bool> {
        Binding {
            showsAdvancedDetection
        } set: { isExpanded in
            guard showsAdvancedDetection != isExpanded else {
                return
            }

            showsAdvancedDetection = isExpanded
            SpillTelemetry.shared.track(
                "settings_section_toggled",
                props: [
                    "section": "advanced_menu_scan",
                    "state": isExpanded ? "open" : "closed"
                ]
            )
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
}
