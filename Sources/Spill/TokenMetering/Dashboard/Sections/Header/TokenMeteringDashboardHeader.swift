import SwiftUI

/// Window toolbar row: brand, maturity and sync state, last update time, and
/// the service-status, web, refresh, and settings actions. The dashboard's
/// one-line description lives in the brand tooltip instead of taking a column.
struct TokenMeteringDashboardHeader<ServiceStatus: View>: View {
    let language: TokenMeteringLanguage
    let appLanguage: SpillAppLanguage
    let lastUpdated: String?
    let isPrivateUsageUploadActive: Bool
    let isRefreshing: Bool
    let isWebDashboardAvailable: Bool
    let onOpenWebDashboard: () -> Void
    let onRefresh: () -> Void
    let onOpenSettings: () -> Void
    @ViewBuilder let serviceStatus: () -> ServiceStatus

    var body: some View {
        HStack(spacing: 12) {
            SpillBrandLockupView(
                subtitle: nil,
                markStyle: nil,
                showsAIMark: true,
                iconSize: 28,
                titleFontSize: 18,
                titleWeight: .bold,
                subtitleFontSize: 11,
                subtitleWeight: .semibold,
                subtitleColor: .secondary,
                spacing: 12
            )
            .help(t(.dashboardSubtitle))
            .accessibilityHint(Text(t(.dashboardSubtitle)))

            HStack(spacing: 8) {
                TokenMeteringDashboardStatusBadge(text: t(.previewBadge), tint: .orange)
                syncStateBadge

                if let lastUpdated {
                    Text("\(t(.lastUpdatedLabel)): \(lastUpdated)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 16)

            HStack(spacing: 8) {
                serviceStatus()

                TokenMeteringDashboardHeaderActionButton(
                    systemImage: "safari",
                    accessibilityLabel: t(.privateUsageUploadOpenDashboard),
                    helpText: t(.privateUsageUploadOpenDashboardDetail),
                    isEnabled: isWebDashboardAvailable,
                    action: onOpenWebDashboard
                )

                TokenMeteringDashboardHeaderActionButton(
                    systemImage: isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise",
                    accessibilityLabel: t(.refresh),
                    helpText: t(.refresh),
                    isEnabled: !isRefreshing,
                    action: onRefresh
                )

                TokenMeteringDashboardHeaderActionButton(
                    systemImage: "gearshape",
                    accessibilityLabel: AppL10n.text(.settings, appLanguage: appLanguage),
                    helpText: AppL10n.text(.settings, appLanguage: appLanguage),
                    action: onOpenSettings
                )
            }
        }
        .padding(.leading, 78)
        .padding(.trailing, 18)
        .padding(.vertical, 14)
    }
}

extension TokenMeteringDashboardHeader {
    private var syncStateBadge: some View {
        TokenMeteringDashboardStatusBadge(
            text: isPrivateUsageUploadActive ? t(.webSyncEnabled) : t(.localOnly),
            tint: isPrivateUsageUploadActive ? .blue : .green,
            showsDot: true
        )
    }

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(key, language: language)
    }
}
