import SwiftUI

struct TokenMeteringLocalSyncSettingsSection: View {
    @ObservedObject var settings: SpillSettings
    let language: TokenMeteringLanguage
    let copiedTarget: String?
    let copyInboxPathAction: (String) -> Void

    private var inboxPath: String {
        TokenUsageStore.defaultInboxURL().path
    }

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(key, language: language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TokenMeteringOptionHeader(
                title: t(.localSyncStatusTitle),
                state: t(.defaultState),
                systemImage: "folder.badge.gearshape",
                tint: .blue
            )

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t(.menuBarTokenDisplayModeTitle))
                        .font(.system(size: 12, weight: .bold))
                    Text(t(.menuBarTokenDisplayModeDetail))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Picker("", selection: $settings.menuBarTokenDisplayMode) {
                    ForEach(MenuBarTokenDisplayMode.allCases) { mode in
                        Text(mode.title(appLanguage: settings.appLanguage)).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 140)
            }

            Divider().opacity(0.45)

            VStack(alignment: .leading, spacing: 6) {
                Text(t(.localEventQueue))
                    .font(.system(size: 12, weight: .bold))
                HStack(spacing: 8) {
                    Text(inboxPath)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)

                    Spacer(minLength: 8)

                    Button {
                        copyInboxPathAction(inboxPath)
                    } label: {
                        Label(
                            copiedTarget == "inbox" ? t(.copied) : t(.copyPath),
                            systemImage: copiedTarget == "inbox" ? "checkmark" : "doc.on.doc"
                        )
                    }
                    .font(.system(size: 12, weight: .semibold))
                }
            }
        }
        .padding(10)
        .background(tokenMeteringOptionBackground)
    }

    private var tokenMeteringOptionBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(NSColor.controlBackgroundColor).opacity(0.35))
    }
}
