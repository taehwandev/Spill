import SwiftUI

struct AutomaticUpdatePreferencesView: View {
    @ObservedObject var updater: SparkleUpdateController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Swift 6.2/6.3 release IRGen crashes on the actor-isolated method references here.
            Toggle(PreferencesL10n.text(.automaticUpdateChecks), isOn: Binding(
                get: { updater.automaticChecks },
                set: { isEnabled in updater.setAutomaticChecks(isEnabled) }
            ))
            Toggle(PreferencesL10n.text(.automaticUpdateInstall), isOn: Binding(
                get: { updater.automaticDownloads },
                set: { isEnabled in updater.setAutomaticDownloads(isEnabled) }
            ))
            .disabled(!updater.allowsAutomaticDownloads)
            Text(PreferencesL10n.text(.automaticUpdateDetail))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension PreferencesTextKey {
    static let automaticUpdateChecks = Self(rawValue: "automaticUpdateChecks")
    static let automaticUpdateInstall = Self(rawValue: "automaticUpdateInstall")
    static let automaticUpdateDetail = Self(rawValue: "automaticUpdateDetail")
}
