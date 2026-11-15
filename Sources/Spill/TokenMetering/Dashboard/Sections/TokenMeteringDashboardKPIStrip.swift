import AppKit
import SwiftUI

/// Headline usage tiles (total, input, output). The total tile carries the
/// change against the previous comparable period.
struct TokenMeteringDashboardKPIStrip: View {
    let kpis: [TokenUsageDashboardKPI]
    /// Change of the total against the previous comparable period, if any.
    let totalComparison: (delta: Int, percentage: Double)?
    /// Pre-formatted "<period>: <tokens>" caption for the comparison period.
    let comparisonCaption: String?
    let accent: Color
    let showsPlaceholder: Bool
    let marker: TokenUsageLiveUpdateMarker
    let isLiveUpdated: (String) -> Bool
    @State private var hoveredKPI: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            ForEach(kpis) { kpi in
                kpiTile(kpi)
            }
        }
        .redacted(reason: showsPlaceholder ? .placeholder : [])
    }
}

extension TokenMeteringDashboardKPIStrip {
    private func kpiTile(_ kpi: TokenUsageDashboardKPI) -> some View {
        let liveUpdateID = "kpi:\(kpi.id)"
        let isTileLiveUpdated = isLiveUpdated(liveUpdateID)
        let isHovered = hoveredKPI == kpi.id
        let isTotal = kpi.id == "total"

        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: kpiIcon(for: kpi.id))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(kpiColor(for: kpi.id))

                Text(kpi.title.uppercased())
                    .font(.system(size: 9.5, weight: .black))
                    .tracking(1.0)
                    .foregroundStyle(.secondary.opacity(0.85))
                    .lineLimit(1)
                TokenMeteringLiveUpdateDot(isActive: isTileLiveUpdated, marker: marker)
                Spacer(minLength: 0)
                if isTotal, let totalComparison {
                    comparisonBadge(totalComparison)
                }
            }
            Text(kpi.value)
                .font(.system(size: 23, weight: .heavy, design: .rounded))
                .foregroundStyle(isTotal ? accent : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.35), value: kpi.value)
            HStack(spacing: 4) {
                Text(kpi.detail)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.8))
                    .lineLimit(1)
                if isTotal, let comparisonCaption {
                    Text("· \(comparisonCaption)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    isHovered
                        ? (isTotal ? accent.opacity(0.08) : Color.primary.opacity(0.05))
                        : Color(NSColor.controlBackgroundColor).opacity(0.65)
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: isHovered
                            ? (isTotal ? [accent.opacity(0.35), accent.opacity(0.12)] : [Color.primary.opacity(0.12), Color.primary.opacity(0.04)])
                            : [Color.primary.opacity(0.09), Color.primary.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        }
        .onHover { hovering in
            hoveredKPI = hovering ? kpi.id : nil
        }
        .modifier(TokenMeteringLiveUpdateEffect(isActive: isTileLiveUpdated && !isHovered, marker: marker, cornerRadius: 12))
    }

    private func comparisonBadge(_ comparison: (delta: Int, percentage: Double)) -> some View {
        let isIncrease = comparison.delta >= 0
        return HStack(spacing: 2) {
            Image(systemName: isIncrease ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 7, weight: .black))
            Text(String(format: "%.0f%%", abs(comparison.percentage)))
                .font(.system(size: 8, weight: .black))
        }
        .foregroundStyle(isIncrease ? Color.green : Color.red)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background((isIncrease ? Color.green : Color.red).opacity(0.1), in: Capsule())
    }

    private func kpiIcon(for id: String) -> String {
        switch id {
        case "total": return "sparkles"
        case "input": return "arrow.down.right.circle.fill"
        case "output": return "arrow.up.right.circle.fill"
        default: return "chart.bar.fill"
        }
    }

    private func kpiColor(for id: String) -> Color {
        switch id {
        case "total": return accent
        case "input": return Color.blue
        case "output": return Color.purple
        default: return .primary
        }
    }
}
