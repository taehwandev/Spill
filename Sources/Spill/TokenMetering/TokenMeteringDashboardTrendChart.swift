import SwiftUI

struct TokenMeteringDashboardTrendChart: View {
    let buckets: [TokenUsageDashboardTrendBucket]
    let language: TokenMeteringLanguage
    @State private var hoveredBucketID: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            if let hoveredID = hoveredBucketID,
               let bucket = buckets.first(where: { $0.id == hoveredID }) {
                HStack(spacing: 5) {
                    Text(bucket.title)
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Text(":")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary.opacity(0.4))

                    Text(bucket.detail)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.teal)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                Text(TokenMeteringL10n.text(.trendHoverGuide, language: language))
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.35))
                    .transition(.opacity)
            }

            GeometryReader { geometry in
                let chartHeight = Swift.max(CGFloat(1), geometry.size.height - 20)
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(buckets) { bucket in
                        let isHovered = hoveredBucketID == bucket.id
                        let barHeight = bucket.hasEvents
                            ? Swift.max(CGFloat(4), chartHeight * CGFloat(bucket.ratio))
                            : CGFloat(2)

                        VStack(spacing: 4) {
                            Spacer(minLength: 0)

                            ZStack(alignment: .top) {
                                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: isHovered
                                                ? [Color.teal, Color.teal.opacity(0.85), Color.blue.opacity(0.45)]
                                                : [Color.teal.opacity(0.85), Color.teal.opacity(0.45)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .opacity(bucket.hasEvents ? 1.0 : 0.18)
                                    .shadow(color: Color.teal.opacity(isHovered ? 0.35 : 0.0), radius: 4, x: 0, y: 1)

                                if isHovered && bucket.hasEvents {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 3.5, height: 3.5)
                                        .shadow(color: Color.teal, radius: 2)
                                        .padding(.top, 2)
                                }
                            }
                            .frame(height: barHeight)
                            .scaleEffect(x: isHovered ? 1.15 : 1.0, y: isHovered ? 1.05 : 1.0, anchor: .bottom)
                            .animation(.spring(response: 0.2, dampingFraction: 0.72), value: isHovered)

                            Text(bucket.title)
                                .font(.system(size: 7.5, weight: isHovered ? .bold : .semibold, design: .monospaced))
                                .foregroundStyle(isHovered ? Color.primary : (bucket.hasEvents ? Color.secondary : Color.secondary.opacity(0.4)))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            withAnimation(.easeOut(duration: 0.12)) {
                                hoveredBucketID = hovering ? bucket.id : nil
                            }
                        }
                        .accessibilityLabel(bucket.detail)
                    }
                }
            }
        }
        .frame(height: 165)
    }
}
