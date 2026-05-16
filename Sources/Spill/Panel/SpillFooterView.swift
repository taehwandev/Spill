import SwiftUI

struct SpillFooterView: View {
    let isAccessibilityTrusted: Bool
    let isScanning: Bool
    @ObservedObject var sleepGuard: SleepGuardController
    let sleepGuardDefaultDuration: SleepGuardDuration
    let keepsDisplayAwake: Bool
    let showsPower: Bool
    let powerStatus: SystemPowerStatus
    let showsCountBadge: Bool
    let itemCount: Int
    let quitAction: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            footerBadge(
                symbolName: isAccessibilityTrusted ? "checkmark.shield.fill" : "exclamationmark.shield.fill",
                title: "AX",
                value: isAccessibilityTrusted ? "OK" : "Need",
                tint: isAccessibilityTrusted ? .green : .orange
            )

            footerBadge(
                symbolName: isScanning ? "arrow.triangle.2.circlepath" : "bolt.horizontal.fill",
                title: "Scan",
                value: isScanning ? "On" : "Idle",
                tint: isScanning ? Color.accentColor : Color.secondary
            )

            sleepGuardFooter

            if showsPower {
                powerFooter(status: powerStatus)
            }

            if showsCountBadge {
                footerBadge(
                    symbolName: "square.grid.2x2.fill",
                    title: "Items",
                    value: "\(itemCount)",
                    tint: .secondary
                )
            }

            Spacer()

            footerBadge(
                symbolName: "clock.fill",
                title: "Time",
                value: shortTime,
                tint: .secondary
            )

            quitButton
        }
        .padding(.horizontal, 9)
        .frame(height: 32)
        .background(.primary.opacity(0.06), in: Capsule())
        .overlay {
            Capsule()
                .stroke(.primary.opacity(0.08), lineWidth: 0.8)
        }
    }

    private func footerBadge(
        symbolName: String,
        title: String,
        value: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbolName)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 13, height: 13)

            Text(title)
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .foregroundStyle(tint)
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
            } else {
                Button("Start \(sleepGuardDefaultDuration.menuTitle)") {
                    sleepGuard.start(
                        duration: sleepGuardDefaultDuration,
                        keepDisplayAwake: keepsDisplayAwake
                    )
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

                Text("Sleep")
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                Text(sleepGuard.isActive ? sleepGuard.remainingLabel : "Off")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(sleepGuardTint)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(sleepGuardHelpText)
        .accessibilityLabel(sleepGuardHelpText)
        .accessibilityIdentifier("Sleep Guard")
    }

    private var quitButton: some View {
        Button(role: .destructive, action: quitAction) {
            HStack(spacing: 4) {
                Image(systemName: "power")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 13, height: 13)

                Text("Quit")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Quit Spill")
        .accessibilityLabel("Quit Spill")
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
        footerBadge(
            symbolName: status.symbolName,
            title: "Power",
            value: status.value,
            tint: status.state.panelTint
        )
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
