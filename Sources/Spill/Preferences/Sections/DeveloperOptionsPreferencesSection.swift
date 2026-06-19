import SwiftUI

struct DeveloperOptionsPreferencesSection: View {
    @ObservedObject var settings: SpillSettings
    let tokenUsageStore: TokenUsageStore
    let language: SpillAppLanguage

    var body: some View {
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

    private func t(_ key: PreferencesTextKey) -> String {
        PreferencesL10n.text(key, appLanguage: language)
    }
}
