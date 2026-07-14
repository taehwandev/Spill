import SwiftUI

struct TokenMeteringDashboardTrendChart: View {
    let buckets: [TokenUsageDashboardTrendBucket]
    @Binding var selectedBucketID: String?
    let defaultSelectedBucketID: String?
    let language: TokenMeteringLanguage
    @State private var hoveredBucketID: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            hoverSummary
            chart
        }
        .frame(height: 165)
    }
}

private extension TokenMeteringDashboardTrendChart {
    @ViewBuilder
    var hoverSummary: some View {
        if let hoveredID = hoveredBucketID,
           let bucket = buckets.first(where: { $0.id == hoveredID }) {
            HStack(spacing: 6) {
                Text(bucket.title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)

                Text(":")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary.opacity(0.3))

                Text(bucket.detail)
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.teal)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color.teal.opacity(0.06), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.teal.opacity(0.12), lineWidth: 0.5)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        } else {
            Text(TokenMeteringL10n.text(.trendHoverGuide, language: language))
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.secondary.opacity(0.35))
                .transition(.opacity)
        }
    }
}

private extension TokenMeteringDashboardTrendChart {
    var chart: some View {
        GeometryReader { geometry in
            let chartHeight = Swift.max(CGFloat(1), geometry.size.height - 20)
            let width = geometry.size.width

            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    ForEach(0..<3) { idx in
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: 0))
                            path.addLine(to: CGPoint(x: width, y: 0))
                        }
                        .stroke(style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        .foregroundStyle(Color.primary.opacity(0.05))
                        .frame(height: 1)

                        Spacer(minLength: 0)
                    }
                }
                .frame(height: chartHeight)
                .padding(.bottom, 20)

                HStack(alignment: .bottom, spacing: buckets.count > 15 ? 2.5 : 5.0) {
                    ForEach(buckets) { bucket in
                        chartBar(bucket, chartHeight: chartHeight)
                    }
                }
            }
        }
    }

    func chartBar(_ bucket: TokenUsageDashboardTrendBucket, chartHeight: CGFloat) -> some View {
        let isHovered = hoveredBucketID == bucket.id
        let isSelected = selectedBucketID == bucket.id || (selectedBucketID == nil && defaultSelectedBucketID == bucket.id)
        let isHighlighted = isHovered || isSelected
        let barHeight = bucket.hasEvents
            ? Swift.max(CGFloat(4), chartHeight * CGFloat(bucket.ratio))
            : CGFloat(0)

        return VStack(spacing: 4) {
            Spacer(minLength: 0)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(Color.primary.opacity(0.022))
                    .frame(height: chartHeight)

                if bucket.hasEvents {
                    ZStack(alignment: .top) {
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: isHighlighted
                                        ? [Color.teal, Color.cyan, Color.blue.opacity(0.8)]
                                        : [Color.teal.opacity(0.55), Color.teal.opacity(0.25)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        if isHighlighted {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 3.5, height: 3.5)
                                .padding(.top, 2)
                        }
                    }
                    .frame(height: barHeight)
                }
            }
            .frame(height: chartHeight)

            Text(bucket.title)
                .font(.system(size: 7.5, weight: isHighlighted ? .bold : .semibold, design: .monospaced))
                .foregroundStyle(isHighlighted ? Color.primary : (bucket.hasEvents ? Color.secondary : Color.secondary.opacity(0.4)))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .contentShape(Rectangle())
        .onTapGesture {
            if bucket.hasEvents {
                selectedBucketID = bucket.id
            }
        }
        .onHover { hovering in
            hoveredBucketID = hovering ? bucket.id : nil
        }
        .accessibilityLabel(bucket.detail)
    }
}
