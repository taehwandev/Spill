import AppKit
import SwiftUI

struct PreferencesView: View {
    @ObservedObject var settings: SpillSettings
    @ObservedObject var scanner: AXMenuBarItemScanner
    let showPanelAction: () -> Void
    @State private var accessibilityTrusted = AccessibilityPermission.isTrusted
    @State private var loginItemError: String?
    @State private var showsAdvancedDetection = false

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 34)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Spill")
                            .font(.title2.weight(.semibold))
                        Text("Menu bar overflow, under the notch.")
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                PanelFallbackPreferencesSection(
                    scanner: scanner,
                    accessibilityTrusted: $accessibilityTrusted,
                    showPanelAction: showPanelAction
                )

                Divider()

                GeneralPreferencesSection(settings: settings, loginItemError: $loginItemError)

                Divider()

                StatusModulesPreferencesSection(settings: settings)

                Divider()

                PowerPreferencesSection(settings: settings)

                Divider()

                AccessibilityPreferencesSection(scanner: scanner, accessibilityTrusted: $accessibilityTrusted)

                Divider()

                advancedDetectionSection
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 460, minHeight: 320)
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
            Label("Advanced Detection", systemImage: "menubar.rectangle")
                .font(.headline)
        }
    }
}
