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

                // Section 2: Status Modules
                PreferenceCard(title: "Status Modules", symbolName: "waveform.path.ecg", iconColor: .purple) {
                    StatusModulesPreferencesSection(settings: settings)
                }

                // Section 3: Caffeine Options
                PreferenceCard(title: "Caffeine Settings", symbolName: "cup.and.saucer.fill", iconColor: .orange) {
                    PowerPreferencesSection(settings: settings)
                }

                // Section 4: System Permissions & Diagnostics
                PreferenceCard(title: "Permissions & Diagnostics", symbolName: "lock.shield.fill", iconColor: .green) {
                    AccessibilityPreferencesSection(
                        scanner: scanner,
                        accessibilityTrusted: $accessibilityTrusted,
                        showPanelAction: showPanelAction
                    )
                }

                Divider()
                    .background(Color.primary.opacity(0.04))

                // Section 5: Agent Cat Promo Card
                AgentCatCard()

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

struct AgentCatCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: "https://agentcat.app/assets/app-icon.png")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                    default:
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(red: 29/255, green: 26/255, blue: 22/255))
                            Image(systemName: "cat.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Agent Cat for Local AI Work")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)

                    Text("https://agentcat.app")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.orange)
                }
            }

            Text("A companion app for visualizing local AI agent activity across Codex, Claude Code, Antigravity CLI, and other development tools.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                SpillTelemetry.shared.track(
                    "agentcat_link_clicked",
                    props: ["source": "preferences"]
                )
                if let url = URL(string: "https://agentcat.app/") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 6) {
                    Text("Visit AgentCat")
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [Color.orange, Color.orange.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .shadow(color: Color.orange.opacity(0.2), radius: 2, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(16)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)

                LinearGradient(
                    colors: [Color.orange.opacity(0.04), Color.purple.opacity(0.03)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(14)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.25), Color.purple.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }
}
