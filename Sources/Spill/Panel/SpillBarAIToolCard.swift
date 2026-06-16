import SwiftUI

struct SpillBarAIToolTokenUsage: Equatable {
    let value: String
    let ratio: Double
}

struct SpillBarAIToolCard: View {
    let status: LocalAIToolStatus
    let serviceStatus: CloudServiceStatusItem?
    let tokenUsage: SpillBarAIToolTokenUsage
    let appLanguage: SpillAppLanguage
    let isServerStatusLoading: Bool

    var body: some View {
        let tint = status.state.panelTint
        let isActive = status.state == .active || status.state == .refreshing
        let isUnavailable = status.state == .unavailable
        let hasServerIssue = serviceStatus?.health.isServerIssue ?? false
        let cardTint = hasServerIssue ? serviceStatus?.health.serverStatusTint ?? tint : tint

        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center, spacing: 6) {
                aiToolIconBadge(symbolName: status.symbolName, tint: tint)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(status.title)
                        .font(.system(size: 10.5, weight: .bold))
                        .lineLimit(1)
                        .foregroundStyle(isUnavailable ? .secondary : .primary)

                    if let subtitle = status.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary.opacity(0.8))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)

                aiStatusBadge
            }

            Divider()
                .opacity(0.4)

            HStack(alignment: .center, spacing: 4) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(tokenUsage.value)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.primary)
                    Text(AppL10n.text(.tokens, appLanguage: appLanguage))
                        .font(.system(size: 7.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                aiProcessStateChip

                Spacer(minLength: 3)

                let percentage = Int((tokenUsage.ratio * 100).rounded())
                Text("\(percentage)%")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.teal)
                    .padding(.horizontal, 4)
                    .frame(height: 14)
                    .background(.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(height: 72)
        .frame(maxWidth: .infinity)
        .background(
            hasServerIssue ? cardTint.opacity(0.12) : isActive ? tint.opacity(0.06) : Color.primary.opacity(0.03),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    hasServerIssue ? cardTint.opacity(0.36) : isActive ? tint.opacity(0.12) : Color.primary.opacity(0.04),
                    lineWidth: hasServerIssue ? 0.8 : 0.5
                )
        }
    }

    private var aiProcessStateChip: some View {
        let tint = status.state.panelTint
        let isMoving = status.state == .active || status.state == .refreshing
        return HStack(spacing: 3) {
            AgentActivityWaveView(isActive: isMoving, tint: tint)

            Text(aiProcessStateTitle(status.state))
                .font(.system(size: 7.8, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 4)
        .frame(height: 14)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
    }

    @ViewBuilder
    private var aiStatusBadge: some View {
        if let serviceStatus {
            CloudServiceStatusBadge(item: serviceStatus, appLanguage: appLanguage)
        } else if CloudServiceStatusPresentation.serviceKinds(for: status.kind).isEmpty {
            aiLocalStatusBadge
        } else {
            aiServerPendingBadge
        }
    }

    private var aiLocalStatusBadge: some View {
        let tint = status.state.panelTint
        let isRunning = status.state == .active
        let value = isRunning ? status.value : AppL10n.text(.local, appLanguage: appLanguage)

        return HStack(spacing: 4) {
            Circle()
                .fill(tint)
                .frame(width: 5, height: 5)

            Text(value)
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .lineLimit(1)
                .monospacedDigit()
        }
        .padding(.horizontal, 6)
        .frame(height: 18)
        .fixedSize(horizontal: true, vertical: false)
        .foregroundStyle(isRunning ? tint : .secondary)
        .background(
            tint.opacity(isRunning ? 0.13 : 0.07),
            in: Capsule()
        )
    }

    private var aiServerPendingBadge: some View {
        let tint = isServerStatusLoading ? Color.blue : Color.secondary
        let value = isServerStatusLoading
            ? AppL10n.text(.checking, appLanguage: appLanguage)
            : AppL10n.text(.server, appLanguage: appLanguage)

        return HStack(spacing: 4) {
            Image(systemName: isServerStatusLoading ? "arrow.triangle.2.circlepath" : "cloud.fill")
                .font(.system(size: 8, weight: .bold))

            Text(value)
                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                .lineLimit(1)
        }
        .padding(.horizontal, 5)
        .frame(height: 18)
        .foregroundStyle(tint)
        .background(tint.opacity(0.10), in: Capsule())
        .help(AppL10n.text(.serverStatusPendingHelp, appLanguage: appLanguage))
    }

    private func aiToolIconBadge(symbolName: String, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(tint.opacity(0.14))

            Image(systemName: symbolName)
                .font(.system(size: 11, weight: .bold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
        }
        .frame(width: 24, height: 24)
    }

    private func aiProcessStateTitle(_ state: SpillStatusState) -> String {
        switch state {
        case .active:
            return AppL10n.text(.active, appLanguage: appLanguage)
        case .normal:
            return AppL10n.text(.normal, appLanguage: appLanguage)
        case .warning:
            return AppL10n.text(.warning, appLanguage: appLanguage)
        case .unavailable:
            return AppL10n.text(.unavailable, appLanguage: appLanguage)
        case .refreshing:
            return AppL10n.text(.checking, appLanguage: appLanguage)
        }
    }
}

struct AgentActivityWaveView: View {
    let isActive: Bool
    let tint: Color

    @State private var bar1: CGFloat = 0.3
    @State private var bar2: CGFloat = 0.5
    @State private var bar3: CGFloat = 0.2
    @State private var bar4: CGFloat = 0.4

    var body: some View {
        HStack(spacing: 1.5) {
            bar(height: bar1)
            bar(height: bar2)
            bar(height: bar3)
            bar(height: bar4)
        }
        .frame(width: 12, height: 9, alignment: .bottom)
        .onAppear {
            updateAnimation(isActive: isActive)
        }
        .onChange(of: isActive) { _, isActive in
            updateAnimation(isActive: isActive)
        }
    }

    private func bar(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 0.75, style: .continuous)
            .fill(tint)
            .frame(width: 1.5, height: max(1.5, height * 9))
    }

    private func updateAnimation(isActive: Bool) {
        if isActive {
            withAnimation(.linear(duration: 0.6).repeatForever(autoreverses: true)) {
                bar1 = 0.95
            }
            withAnimation(.linear(duration: 0.75).repeatForever(autoreverses: true)) {
                bar2 = 0.25
            }
            withAnimation(.linear(duration: 0.5).repeatForever(autoreverses: true)) {
                bar3 = 0.85
            }
            withAnimation(.linear(duration: 0.65).repeatForever(autoreverses: true)) {
                bar4 = 0.35
            }
        } else {
            withAnimation(.linear(duration: 0.15)) {
                bar1 = 0.15
                bar2 = 0.15
                bar3 = 0.15
                bar4 = 0.15
            }
        }
    }
}
