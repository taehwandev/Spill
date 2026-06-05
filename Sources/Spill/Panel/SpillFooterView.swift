import SwiftUI

struct SpillFooterView: View {
    let isAccessibilityTrusted: Bool
    let isScanning: Bool
    @ObservedObject var sleepGuard: SleepGuardController
    let sleepGuardDefaultDuration: SleepGuardDuration
    let allowsIndefiniteDuration: Bool
    let keepsDisplayAwake: Bool
    let setSleepGuardDefaultDuration: (SleepGuardDuration) -> Void
    let showsPower: Bool
    let powerStatus: SystemPowerStatus
    let showsCountBadge: Bool
    let itemCount: Int

    var body: some View {
        HStack(spacing: 8) {
            footerBadge(
                symbolName: isAccessibilityTrusted ? "checkmark.shield.fill" : "exclamationmark.shield.fill",
                title: AppL10n.text(.ax),
                value: isAccessibilityTrusted ? AppL10n.text(.ok) : AppL10n.text(.need),
                style: .accessibility(isTrusted: isAccessibilityTrusted)
            )

            footerBadge(
                symbolName: isScanning ? "arrow.triangle.2.circlepath" : "bolt.horizontal.fill",
                title: AppL10n.text(.scan),
                value: isScanning ? AppL10n.text(.on) : AppL10n.text(.idle),
                style: .scan(isScanning: isScanning)
            )

            sleepGuardFooter

            if showsPower {
                powerFooter(status: powerStatus)
            }

            if showsCountBadge {
                footerBadge(
                    symbolName: "square.grid.2x2.fill",
                    title: AppL10n.text(.items),
                    value: "\(itemCount)",
                    style: .count
                )
            }

            Spacer()

            footerBadge(
                symbolName: "clock.fill",
                title: AppL10n.text(.time),
                value: shortTime,
                style: .time
            )
        }
        .padding(.horizontal, 9)
        .frame(height: 32)
    }

    private func footerBadge(
        symbolName: String,
        title: String,
        value: String,
        style: SpillFooterBadgeStyle
    ) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbolName)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 14, height: 14)
                .spillFooterForeground(style.symbolRole)

            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .spillFooterForeground(style.titleRole)

            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .spillFooterForeground(style.valueRole)
        }
    }

    private var sleepGuardFooter: some View {
        HStack(spacing: 4) {
            Button {
                toggleSleepGuardFromFooter()
            } label: {
                sleepGuardLabel
            }
            .buttonStyle(.plain)
            .accessibilityLabel(caffeineHelpText)
            .accessibilityIdentifier("CaffeineToggle")

            Menu {
                sleepGuardMenuItems
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .frame(width: 12, height: 20)
                    .spillFooterForeground(sleepGuardStyle.valueRole)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .frame(width: 14, height: 22)
            .accessibilityLabel(AppL10n.text(.chooseCaffeineDuration))
        }
        .frame(minWidth: 66, minHeight: 22, maxHeight: 22, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
        .contentShape(Rectangle())
        .help(caffeineHelpText)
        .accessibilityIdentifier("Caffeine")
    }

    private var sleepGuardLabel: some View {
        HStack(spacing: 5) {
            Image(systemName: sleepGuard.isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 14, height: 14)
                .spillFooterForeground(sleepGuardStyle.symbolRole)

            Text(sleepGuardFooterValue)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(minWidth: 28, maxWidth: 48, alignment: .leading)
                .spillFooterForeground(sleepGuardStyle.valueRole)
        }
        .frame(height: 22)
        .contentShape(Rectangle())
    }

    private var sleepGuardFooterValue: String {
        sleepGuard.isActive ? sleepGuard.remainingLabel : AppL10n.text(.off)
    }

    @ViewBuilder
    private var sleepGuardMenuItems: some View {
        if sleepGuard.isActive {
            Button(role: .destructive) {
                stopSleepGuard(source: "panel_footer_menu")
            } label: {
                Text(AppL10n.text(.stopCaffeine))
            }

            Divider()
        } else {
            Button(String(format: AppL10n.text(.startDuration), AppL10n.sleepDurationTitle(sleepGuardDefaultDuration))) {
                startSleepGuard(
                    duration: sleepGuardDefaultDuration,
                    updatesDefaultDuration: false,
                    source: "panel_footer_menu_default"
                )
            }

            Divider()
        }

        ForEach(SleepGuardDuration.availableDurations(allowsIndefinite: allowsIndefiniteDuration)) { duration in
            Button(AppL10n.sleepDurationTitle(duration)) {
                startSleepGuard(
                    duration: duration,
                    updatesDefaultDuration: true,
                    source: "panel_footer_menu_duration"
                )
            }
        }
    }

    private var sleepGuardStyle: SpillFooterBadgeStyle {
        SpillFooterBadgeStyle.sleepGuard(
            isActive: sleepGuard.isActive,
            hasError: sleepGuard.errorMessage != nil
        )
    }

    private func powerFooter(status: SystemPowerStatus) -> some View {
        footerBadge(
            symbolName: status.symbolName,
            title: AppL10n.text(.power),
            value: status.value,
            style: .power(state: status.state)
        )
        .help(powerHelpText(for: status))
        .accessibilityLabel(powerHelpText(for: status))
    }

    private func toggleSleepGuardFromFooter() {
        if sleepGuard.isActive {
            stopSleepGuard(source: "panel_footer")
            return
        }

        startSleepGuard(
            duration: sleepGuardDefaultDuration,
            updatesDefaultDuration: false,
            source: "panel_footer"
        )
    }

    private func startSleepGuard(
        duration: SleepGuardDuration,
        updatesDefaultDuration: Bool,
        source: String
    ) {
        if updatesDefaultDuration {
            setSleepGuardDefaultDuration(duration)
        }

        let didStart = sleepGuard.start(
            duration: duration,
            keepDisplayAwake: keepsDisplayAwake
        )
        SpillTelemetry.shared.track(
            "sleep_guard_started",
            props: [
                "source": source,
                "duration": duration.rawValue.description,
                "keep_display_awake": keepsDisplayAwake ? "true" : "false",
                "result": didStart ? "success" : "failed"
            ]
        )
    }

    private func stopSleepGuard(source: String) {
        SpillTelemetry.shared.track("sleep_guard_stopped", props: ["source": source])
        sleepGuard.stop()
    }

    private var shortTime: String {
        Self.timeFormatter.string(from: Date())
    }

    private var caffeineHelpText: String {
        if let errorMessage = sleepGuard.errorMessage {
            return "\(AppL10n.text(.caffeine)) - \(errorMessage)"
        }

        guard sleepGuard.isActive else {
            return AppL10n.text(.caffeineOff)
        }

        if sleepGuard.activeDuration?.isIndefinite == true {
            return sleepGuard.keepsDisplayAwake
                ? AppL10n.text(.caffeineUntilStopped)
                : AppL10n.text(.caffeineUntilStoppedDisplayMaySleep)
        }

        return sleepGuard.keepsDisplayAwake
            ? String(format: AppL10n.text(.caffeineRemainingHelp), sleepGuard.remainingLabel)
            : String(format: AppL10n.text(.caffeineRemainingDisplayMaySleepHelp), sleepGuard.remainingLabel)
    }

    private func powerHelpText(for status: SystemPowerStatus) -> String {
        var parts = [AppL10n.text(.power), status.value]

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
