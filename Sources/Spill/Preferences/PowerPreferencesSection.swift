import SwiftUI

struct PowerPreferencesSection: View {
    @ObservedObject var settings: SpillSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Label("Power", systemImage: "powerplug")
                Spacer()
            }

            Toggle("Show power footer", isOn: $settings.showPowerFooter)

            Picker("Sleep Guard default", selection: $settings.sleepGuardDefaultDuration) {
                ForEach(SleepGuardDuration.allCases) { duration in
                    Text(duration.menuTitle)
                        .tag(duration)
                }
            }
            .pickerStyle(.menu)

            Toggle("Keep display awake during Sleep Guard", isOn: $settings.sleepGuardKeepsDisplayAwake)
        }
    }
}
