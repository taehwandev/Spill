import SwiftUI

struct TokenMeteringDashboardOnboardingGuide: View {
    let language: TokenMeteringLanguage
    let showsDeveloperOptions: Bool
    let settingsAction: () -> Void
    let developerOptionsAction: () -> Void

    var body: some View {
        TokenMeteringDashboardPanel(
            title: t(.dashboardEmptyGuideTitle),
            subtitle: t(.dashboardEmptyGuideDetail)
        ) {
            HStack(alignment: .top, spacing: 10) {
                TokenMeteringDashboardGuideTile(
                    systemImage: "bolt.horizontal.circle.fill",
                    title: t(.dashboardEmptyAutomaticTitle),
                    detail: t(.dashboardEmptyAutomaticDetail),
                    tint: .teal
                )
                TokenMeteringDashboardGuideTile(
                    systemImage: "gearshape.fill",
                    title: t(.dashboardEmptySetupTitle),
                    detail: t(.dashboardEmptySetupDetail),
                    tint: .blue
                )
                TokenMeteringDashboardGuideTile(
                    systemImage: "lock.shield.fill",
                    title: t(.dashboardEmptyPrivacyTitle),
                    detail: t(.dashboardEmptyPrivacyDetail),
                    tint: .indigo
                )
            }

            Divider()
                .opacity(0.45)

            HStack(spacing: 10) {
                Button {
                    settingsAction()
                } label: {
                    Label(t(.dashboardEmptyOpenSettings), systemImage: "gearshape.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

                if showsDeveloperOptions {
                    Button {
                        developerOptionsAction()
                    } label: {
                        Label(t(.developerOptions), systemImage: "hammer.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }

                Spacer(minLength: 0)
            }

            if showsDeveloperOptions {
                Text(t(.dashboardEmptyPreviewDetail))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(key, language: language)
    }
}
