import AppKit
import SwiftUI

struct PreferencesView: View {
    @ObservedObject var settings: SpillSettings
    @ObservedObject var scanner: AXMenuBarItemScanner
    @State private var accessibilityTrusted = AccessibilityPermission.isTrusted
    @State private var loginItemError: String?

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

                GeneralPreferencesSection(settings: settings, loginItemError: $loginItemError)

                Divider()

                DetectionPreferencesSection(
                    settings: settings,
                    scanner: scanner,
                    accessibilityTrusted: $accessibilityTrusted
                )

                Divider()

                DetectedItemsListView(items: scanner.items, settings: settings)

                Divider()

                AccessibilityPreferencesSection(scanner: scanner, accessibilityTrusted: $accessibilityTrusted)
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
        if accessibilityTrusted {
            scanner.refresh()
        }
    }
}
