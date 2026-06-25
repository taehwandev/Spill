import SwiftUI

struct PowerPreferencesSection: View {
    @ObservedObject var settings: SpillSettings

    private func t(_ key: PreferencesTextKey) -> String {
        PreferencesL10n.text(key, appLanguage: settings.appLanguage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker(t(.defaultDuration), selection: $settings.sleepGuardDefaultDuration) {
                ForEach(settings.availableSleepGuardDurations) { duration in
                    Text(AppL10n.sleepDurationTitle(duration, appLanguage: settings.appLanguage))
                        .tag(duration)
                }
            }
            .pickerStyle(.menu)

            Toggle(t(.keepDisplayAwakeDuringCaffeine), isOn: $settings.sleepGuardKeepsDisplayAwake)

            Toggle(t(.showRemainingTimeInClockArea), isOn: $settings.sleepGuardShowsRemainingInMenuBar)

            Toggle(t(.warningShowNeverDuration), isOn: $settings.sleepGuardAllowsIndefinite)

            if settings.sleepGuardAllowsIndefinite {
                Text(t(.neverCaffeineWarning))
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }
}
