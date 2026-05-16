import SwiftUI

struct PowerPreferencesSection: View {
    @ObservedObject var settings: SpillSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Label("Caffeine", systemImage: "cup.and.saucer.fill")
                Spacer()
            }

            Picker("Default duration", selection: $settings.sleepGuardDefaultDuration) {
                ForEach(settings.availableSleepGuardDurations) { duration in
                    Text(duration.menuTitle)
                        .tag(duration)
                }
            }
            .pickerStyle(.menu)

            Toggle("Keep display awake during Caffeine", isOn: $settings.sleepGuardKeepsDisplayAwake)

            Toggle("Show remaining time in clock area", isOn: $settings.sleepGuardShowsRemainingInMenuBar)

            Toggle("Warning: show Never duration", isOn: $settings.sleepGuardAllowsIndefinite)

            if settings.sleepGuardAllowsIndefinite {
                Text("Never keeps Caffeine active until you stop it manually.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }
}
