import SwiftUI

struct SpillFooterView: View {
    let isAccessibilityTrusted: Bool
    let isScanning: Bool
    @ObservedObject var sleepGuard: SleepGuardController
    let sleepGuardDefaultDuration: SleepGuardDuration
    let allowsIndefiniteDuration: Bool
    let keepsDisplayAwake: Bool
    let showsPower: Bool
    let powerStatus: SystemPowerStatus
    let showsCountBadge: Bool
    let itemCount: Int

    var body: some View {
        HStack(spacing: 8) {
            footerBadge(
                symbolName: isAccessibilityTrusted ? "checkmark.shield.fill" : "exclamationmark.shield.fill",
                title: "AX",
                value: isAccessibilityTrusted ? "OK" : "Need",
                tint: isAccessibilityTrusted ? .mint : .orange
            )

            footerBadge(
                symbolName: isScanning ? "arrow.triangle.2.circlepath" : "bolt.horizontal.fill",
                title: "Scan",
                value: isScanning ? "On" : "Idle",
                tint: isScanning ? .blue : .secondary
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
        }
        .padding(.horizontal, 9)
        .frame(height: 32)
        .background(.primary.opacity(0.06), in: Capsule())
        .shadow(color: .black.opacity(0.02), radius: 1, y: 0.5)
    }

    private func footerBadge(
        symbolName: String,
        title: String,
        value: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbolName)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 14, height: 14)

            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
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
                    SpillTelemetry.shared.track("sleep_guard_stopped", props: ["source": "panel_footer"])
                    sleepGuard.stop()
                } label: {
                    Text("Stop Caffeine")
                }

                Divider()
            } else {
                Button("Start \(sleepGuardDefaultDuration.menuTitle)") {
                    startSleepGuard(duration: sleepGuardDefaultDuration)
                }

                Divider()
            }

            ForEach(SleepGuardDuration.availableDurations(allowsIndefinite: allowsIndefiniteDuration)) { duration in
                Button(duration.menuTitle) {
                    startSleepGuard(duration: duration)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: sleepGuard.isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 14, height: 14)

                Text("Caf")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                Text(sleepGuard.isActive ? sleepGuard.remainingLabel : "Off")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(sleepGuardTint)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(caffeineHelpText)
        .accessibilityLabel(caffeineHelpText)
        .accessibilityIdentifier("Caffeine")
    }

    private var sleepGuardTint: Color {
        if sleepGuard.isActive {
            return .blue
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

    private func startSleepGuard(duration: SleepGuardDuration) {
        let didStart = sleepGuard.start(
            duration: duration,
            keepDisplayAwake: keepsDisplayAwake
        )
        SpillTelemetry.shared.track(
            "sleep_guard_started",
            props: [
                "source": "panel_footer",
                "result": didStart ? "success" : "failed"
            ]
        )
    }

    private var shortTime: String {
        Self.timeFormatter.string(from: Date())
    }

    private var caffeineHelpText: String {
        if let errorMessage = sleepGuard.errorMessage {
            return "Caffeine - \(errorMessage)"
        }

        guard sleepGuard.isActive else {
            return "Caffeine Off"
        }

        if sleepGuard.activeDuration?.isIndefinite == true {
            return "Caffeine - on until stopped"
        }

        return "Caffeine - \(sleepGuard.remainingLabel) remaining"
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
