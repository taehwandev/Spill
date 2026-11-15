import SwiftUI

struct TokenMeteringDashboardTrendBucketSummary: View {
    let bucket: TokenUsageDashboardTrendBucket
    let language: TokenMeteringLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(bucket.detail)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 8)

                Text(TokenMeteringL10n.localEventsDetail(eventCount: bucket.eventCount, language: language))
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            let visibleRows = Array(bucket.toolRows.filter { $0.ratio > 0 }.prefix(3))
            if !visibleRows.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(visibleRows) { row in
                        let tint = toolTint(for: row)
                        HStack(spacing: 7) {
                            Circle()
                                .fill(tint)
                                .frame(width: 6, height: 6)

                            Text(row.title)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(Color.primary.opacity(0.085))
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(tint.opacity(0.85))
                                        .frame(width: Swift.max(CGFloat(5), geometry.size.width * CGFloat(row.ratio)))
                                }
                            }
                            .frame(height: 6.5)

                            Text(row.value)
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func toolTint(for row: TokenUsageDashboardBarRow) -> Color {
        TokenUsageAITool(rawValue: row.id.lowercased())?.dashboardTint ?? .secondary
    }
}
