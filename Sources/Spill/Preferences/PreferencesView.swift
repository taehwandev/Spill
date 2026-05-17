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

// Official Spill Wave Logo Shape (extracted from generate-app-icon.swift Bezier curves)
struct SpillLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        var path = Path()

        path.move(to: CGPoint(x: width * 0.22, y: height * 0.43))
        path.addCurve(
            to: CGPoint(x: width * 0.39, y: height * 0.56),
            control1: CGPoint(x: width * 0.22, y: height * 0.52),
            control2: CGPoint(x: width * 0.30, y: height * 0.58)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.54, y: height * 0.51),
            control1: CGPoint(x: width * 0.45, y: height * 0.55),
            control2: CGPoint(x: width * 0.48, y: height * 0.50)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.80, y: height * 0.47),
            control1: CGPoint(x: width * 0.64, y: height * 0.55),
            control2: CGPoint(x: width * 0.79, y: height * 0.57)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.65, y: height * 0.31),
            control1: CGPoint(x: width * 0.81, y: height * 0.36),
            control2: CGPoint(x: width * 0.74, y: height * 0.31)
        )
        path.addLine(to: CGPoint(x: width * 0.34, y: height * 0.31))
        path.addCurve(
            to: CGPoint(x: width * 0.22, y: height * 0.43),
            control1: CGPoint(x: width * 0.25, y: height * 0.31),
            control2: CGPoint(x: width * 0.21, y: height * 0.36)
        )
        path.closeSubpath()

        // Flip Y-axis perfectly from AppKit (bottom-left origin) to SwiftUI (top-left origin)
        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -height)
        return path.applying(transform)
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
    @State private var isAgentCatInstalled = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Header Brand Section
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.teal, .indigo],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .indigo.opacity(0.2), radius: 2, y: 1)

                        SpillLogoShape()
                            .fill(.white)
                    }
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

                // Section 5: Agent Cat Connection Card
                AgentCatCard(isInstalled: isAgentCatInstalled)

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
        isAgentCatInstalled = AgentCatDetector.isInstalled
    }

    private var advancedDetectionSection: some View {
        DisclosureGroup(isExpanded: $showsAdvancedDetection) {
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
                    if let url = URL(string: "https://github.com/taehwankwon/Spill") {
                        NSWorkspace.shared.open(url)
                    }
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
                    if let url = URL(string: "https://github.com/taehwankwon/Spill") {
                        NSWorkspace.shared.open(url)
                    }
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
}// Dynamic Agent Cat Installation Detector
struct AgentCatDetector {
    static var isInstalled: Bool {
        // 1. Check standard bundle IDs (com.trappist.agentcat is the official Agent Cat ID)
        if NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.trappist.agentcat") != nil {
            return true
        }
        if NSWorkspace.shared.urlForApplication(withBundleIdentifier: "app.agentcat") != nil {
            return true
        }
        if NSWorkspace.shared.urlForApplication(withBundleIdentifier: "app.agentcat.AgentCat") != nil {
            return true
        }

        // 2. Check standard paths (supporting space in 'Agent Cat.app')
        let fileManager = FileManager.default
        let paths = [
            "/Applications/Agent Cat.app",
            "/Applications/AgentCat.app",
            "\(NSHomeDirectory())/Applications/Agent Cat.app",
            "\(NSHomeDirectory())/Applications/AgentCat.app"
        ]
        for path in paths {
            if fileManager.fileExists(atPath: path) {
                return true
            }
        }
        return false
    }
}

// Gorgeous Responsive Connection Card for Agent Cat
struct AgentCatCard: View {
    let isInstalled: Bool

    var body: some View {
        if isInstalled {
            connectedCard
        } else {
            promoCard
        }
    }

    // Sleek and modern promo card for installing Agent Cat
    private var promoCard: some View {
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
                    Text("Connect Local AI with Agent Cat")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)

                    Text("https://agentcat.app")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.orange)
                }
            }

            Text("A powerful local connector that brings real-time telemetry, advanced monitoring, and visual dashboards to local AI agents like Codex, Claude Code, and Gemini CLI. Install Agent Cat to unlock a rich visual analytics workspace.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                if let url = URL(string: "https://agentcat.app/") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 6) {
                    Text("Get Free AgentCat")
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

    // Sleek and modern card when Agent Cat is successfully connected
    private var connectedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
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

                    // Connected green badge dot
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1.5)
                        )
                        .offset(x: 2, y: 2)
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text("Agent Cat Connected")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.primary)

                        Text("● Active")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.12), in: Capsule())
                    }

                    Text("https://agentcat.app")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }

            Text("Your local AI workflows (Codex, Claude Code, Gemini CLI) are currently being tracked and visualized inside Agent Cat's rich visual telemetry workspace.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                launchAgentCat()
            } label: {
                HStack(spacing: 6) {
                    Text("Launch Agent Cat Dashboard")
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 10, weight: .bold))
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [Color.green, Color.green.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .shadow(color: Color.green.opacity(0.2), radius: 2, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(16)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)

                LinearGradient(
                    colors: [Color.green.opacity(0.04), Color.teal.opacity(0.03)],
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
                        colors: [Color.green.opacity(0.25), Color.teal.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }

    private func launchAgentCat() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.trappist.agentcat") ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: "app.agentcat.AgentCat") ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: "app.agentcat") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        } else {
            let paths = [
                "/Applications/Agent Cat.app",
                "/Applications/AgentCat.app",
                "\(NSHomeDirectory())/Applications/Agent Cat.app",
                "\(NSHomeDirectory())/Applications/AgentCat.app"
            ]
            for path in paths {
                if FileManager.default.fileExists(atPath: path) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: path))
                    return
                }
            }
        }
    }
}
