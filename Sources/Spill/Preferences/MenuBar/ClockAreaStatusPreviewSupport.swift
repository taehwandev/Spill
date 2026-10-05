import AppKit
import SwiftUI

// The sample clock-area strip shown above the controls: chips, icons and the placeholder values
// they display. Values are fixed samples so the preview never depends on live system state.

extension ClockAreaStatusPreferencesSection {
    @ViewBuilder
    func previewChip(
        symbolName: String,
        label: String?,
        value: String?,
        isTrigger: Bool,
        triggerStyle: MenuBarTriggerIconStyle? = nil,
        chartSeries: [[Double]]? = nil
    ) -> some View {
        Group {
            if let chartSeries, previewUsesStackedLayout {
                VStack(spacing: 0) {
                    if let label {
                        Text(label)
                            .font(.system(size: max(clockPreviewTextSize * 0.56, 7), weight: .semibold))
                    }

                    ClockAreaPreviewChart(series: chartSeries)
                }
            } else {
                HStack(spacing: 4) {
                    previewIcon(symbolName: symbolName, triggerStyle: triggerStyle)

                    if let chartSeries {
                        ClockAreaPreviewChart(series: chartSeries)
                    } else if previewUsesStackedLayout, !isTrigger, value != nil {
                        VStack(spacing: 0) {
                            if let label {
                                Text(label)
                                    .font(.system(size: max(clockPreviewTextSize * 0.56, 7), weight: .semibold))
                            }

                            if let value {
                                Text(value)
                                    .font(.system(
                                        size: max(clockPreviewTextSize * 0.80, 9),
                                        weight: settings.menuBarStatusTextBold ? .semibold : .regular,
                                        design: .monospaced
                                    ))
                            }
                        }
                    } else {
                        if let label {
                            Text(label)
                                .font(.system(
                                    size: max(clockPreviewTextSize - 2.5, 8),
                                    weight: settings.menuBarStatusTextBold ? .semibold : .regular,
                                    design: .rounded
                                ))
                        }

                        if let value {
                            Text(value)
                                .font(.system(
                                    size: clockPreviewTextSize,
                                    weight: settings.menuBarStatusTextBold ? .semibold : .regular,
                                    design: .monospaced
                                ))
                        }
                    }
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .foregroundStyle(isTrigger ? Color.accentColor : Color.primary.opacity(0.84))
        .padding(.horizontal, isTrigger ? 7 : 8)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(isTrigger ? 0.04 : 0.075), in: Capsule())
    }

    @ViewBuilder
    func previewIcon(
        symbolName: String,
        triggerStyle: MenuBarTriggerIconStyle?
    ) -> some View {
        if let triggerStyle,
           let image = MenuBarTriggerIconRenderer.image(
               style: triggerStyle,
               size: 11
           )
        {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .frame(width: 10.5, height: 10.5)
        } else {
            Image(systemName: symbolName)
                .font(.system(size: 10.5, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
        }
    }

    var clockPreviewTextSize: CGFloat {
        let size = CGFloat(settings.menuBarStatusFontSize)
        return min(max(size, 10), 15)
    }

    func previewLabel(for item: SpillMenuBarStatusItem) -> String? {
        switch item {
        case .caffeine:
            return nil
        case .memory where previewUsesStackedLayout:
            return "RAM"
        default:
            return item.shortTitle
        }
    }

}

extension ClockAreaStatusPreferencesSection {
    func previewValue(for item: SpillMenuBarStatusItem) -> String? {
        let previewValues: [SpillMenuBarStatusItem: Double] = [
            .cpu: 0.34,
            .memory: 0.62
        ]
        switch item {
        case .caffeine:
            return nil
        case .ai:
            return "1.44M"
        case .cpu, .memory:
            let value = settings.menuBarStatusPrecision.percentText(for: previewValues[item] ?? 0)
            return value
        case .network:
            return "↓ 1.2 MB/s ↑ 320 KB/s"
        case .gpu:
            return nil
        }
    }

    func previewChartSeries(for item: SpillMenuBarStatusItem) -> [[Double]]? {
        guard settings.menuBarStatusPresentationStyle(for: item) == .chart else {
            return nil
        }

        switch item {
        case .cpu:
            return [[0.16, 0.38, 0.24, 0.72, 0.34]]
        case .memory:
            return [[0.48, 0.53, 0.57, 0.55, 0.62]]
        case .network:
            return [
                [0.12, 0.58, 0.22, 0.82, 0.42],
                [0.08, 0.24, 0.14, 0.36, 0.18]
            ]
        case .caffeine, .gpu, .ai:
            return nil
        }
    }

    var previewUsesStackedLayout: Bool {
        settings.menuBarStatusLayoutStyle == .stacked
    }

    var previewModeTitle: String {
        var parts = [
            settings.menuBarStatusLayoutStyle.title(appLanguage: settings.appLanguage)
        ]
        if settings.menuBarStatusSplitGroups {
            parts.append(PreferencesL10n.text(.clockAreaSplitGroups, appLanguage: settings.appLanguage))
        }
        return parts.joined(separator: " / ")
    }
}
