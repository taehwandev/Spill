import SwiftUI

struct TokenMeteringAIToolVisibilitySection: View {
    @ObservedObject var settings: SpillSettings
    @ObservedObject var aiStatusStore: AIStatusStore
    let language: TokenMeteringLanguage

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(key, language: language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TokenMeteringOptionHeader(
                title: t(.aiToolVisibilityTitle),
                state: t(.aiToolVisibilityState),
                systemImage: "eye",
                tint: .teal
            )

            Text(t(.aiToolVisibilityDetail))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                ForEach(visibleToolKinds, id: \.self) { kind in
                    visibilityRow(for: kind)
                }
            }
        }
        .padding(10)
        .background(tokenMeteringOptionBackground)
    }

    private var visibleToolKinds: [LocalAIToolKind] {
        let detectedKinds = aiStatusStore.statuses.map(\.kind)
        if detectedKinds.isEmpty {
            return TokenUsageAITool.dashboardTools.compactMap(\.localAIToolKind)
        }
        return LocalAIToolKind.allCases.filter { detectedKinds.contains($0) }
    }

    private func visibilityRow(for kind: LocalAIToolKind) -> some View {
        let isVisible = settings.isLocalAIToolVisible(kind)
        let tint = kind.dashboardTint

        return HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(tint.opacity(isVisible ? 0.95 : 0.28))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isVisible ? .primary : .secondary)
                Text(isVisible ? t(.aiToolVisibilityVisible) : t(.aiToolVisibilityHidden))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isVisible ? tint : .secondary)
            }

            Spacer(minLength: 8)

            Toggle(
                "",
                isOn: Binding(
                    get: { settings.isLocalAIToolVisible(kind) },
                    set: { settings.setLocalAITool(kind, isVisible: $0) }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(isVisible ? 0.035 : 0.018))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(isVisible ? 0.13 : 0.05), lineWidth: 0.5)
        }
    }

    private var tokenMeteringOptionBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(NSColor.controlBackgroundColor).opacity(0.35))
    }
}
