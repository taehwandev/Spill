import SwiftUI

struct TokenMeteringDashboardTrendChart: View {
    let buckets: [TokenUsageDashboardTrendBucket]

    var body: some View {
        GeometryReader { geometry in
            let chartHeight = Swift.max(CGFloat(1), geometry.size.height - 20)
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(buckets) { bucket in
                    let barHeight = bucket.hasEvents
                        ? Swift.max(CGFloat(4), chartHeight * CGFloat(bucket.ratio))
                        : CGFloat(2)
                    VStack(spacing: 4) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.teal, Color.teal.opacity(0.6)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .opacity(bucket.hasEvents ? 1.0 : 0.22)
                            .frame(height: barHeight)
                            .animation(.snappy(duration: 0.35), value: bucket.ratio)

                        Text(bucket.title)
                            .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(bucket.hasEvents ? Color.secondary : Color.secondary.opacity(0.45))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .accessibilityLabel(bucket.detail)
                }
            }
        }
        .frame(height: 140)
    }
}
