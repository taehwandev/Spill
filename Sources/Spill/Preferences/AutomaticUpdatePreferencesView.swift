import SwiftUI

struct AutomaticUpdatePreferencesView: View {
    @ObservedObject var updater: SparkleUpdateController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(PreferencesL10n.text(.automaticUpdateChecks), isOn: Binding(
                get: { updater.automaticChecks }, set: updater.setAutomaticChecks
            ))
            Toggle(PreferencesL10n.text(.automaticUpdateInstall), isOn: Binding(
                get: { updater.automaticDownloads }, set: updater.setAutomaticDownloads
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
