import SwiftUI

struct SpillFooterView: View {
    let isAccessibilityTrusted: Bool
    let isScanning: Bool
    @ObservedObject var sleepGuard: SleepGuardController
    let keepsDisplayAwake: Bool
    let showsPower: Bool
    let powerStatus: SystemPowerStatus
    let showsCountBadge: Bool
    let itemCount: Int

    var body: some View {
        HStack(spacing: 12) {
            footerItem(symbolName: isAccessibilityTrusted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .foregroundStyle(isAccessibilityTrusted ? .green : .orange)

            footerItem(symbolName: isScanning ? "arrow.triangle.2.circlepath" : "bolt.horizontal.fill")
                .foregroundStyle(isScanning ? Color.accentColor : Color.secondary)

            sleepGuardFooter

            if showsPower {
                powerFooter(status: powerStatus)
            }

            if showsCountBadge {
                HStack(spacing: 4) {
                    Image(systemName: "square.grid.2x2.fill")
                    Text("\(itemCount)")
                        .monospacedDigit()
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(shortTime)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 11)
        .frame(height: 28)
        .background(.primary.opacity(0.06), in: Capsule())
        .overlay {
            Capsule()
                .stroke(.primary.opacity(0.08), lineWidth: 0.8)
        }
    }

    private func footerItem(symbolName: String) -> some View {
        Image(systemName: symbolName)
            .font(.system(size: 11, weight: .semibold))
            .frame(width: 13, height: 13)
    }

    private var sleepGuardFooter: some View {
        Menu {
            if sleepGuard.isActive {
                Button(role: .destructive) {
                    sleepGuard.stop()
                } label: {
                    Text("Stop Sleep Guard")
                }

                Divider()
            }

            ForEach(SleepGuardDuration.allCases) { duration in
                Button(duration.menuTitle) {
                    sleepGuard.start(
                        duration: duration,
                        keepDisplayAwake: keepsDisplayAwake
                    )
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: sleepGuard.isActive ? "moon.fill" : "moon")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 13, height: 13)

                if sleepGuard.isActive {
                    Text(sleepGuard.remainingLabel)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
            .foregroundStyle(sleepGuardTint)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(sleepGuardHelpText)
        .accessibilityLabel(sleepGuardHelpText)
    }

    private var sleepGuardTint: Color {
        if sleepGuard.isActive {
            return .accentColor
        }

        if sleepGuard.errorMessage != nil {
            return .orange
        }

        return .secondary
    }

    private func powerFooter(status: SystemPowerStatus) -> some View {
        HStack(spacing: 4) {
            Image(systemName: status.symbolName)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 13, height: 13)

            Text(status.value)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .foregroundStyle(status.state.panelTint)
        .help(powerHelpText(for: status))
        .accessibilityLabel(powerHelpText(for: status))
    }

    private var shortTime: String {
        Self.timeFormatter.string(from: Date())
    }

    private var sleepGuardHelpText: String {
        if let errorMessage = sleepGuard.errorMessage {
            return "Sleep Guard - \(errorMessage)"
        }

        guard sleepGuard.isActive else {
            return "Sleep Guard Off"
        }

        return "Sleep Guard - \(sleepGuard.remainingLabel) remaining"
    }

    private func powerHelpText(for status: SystemPowerStatus) -> String {
        var parts = ["Power", status.value]

        if let subtitle = status.subtitle, !subtitle.isEmpty {
            parts.append(subtitle)
        }

        return parts.joined(separator: " - ")
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
}
