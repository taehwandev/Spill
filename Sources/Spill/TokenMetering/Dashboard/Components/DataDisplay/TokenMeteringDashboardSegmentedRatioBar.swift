import SwiftUI

struct TokenMeteringDashboardSegmentedRatioBar: View {
    let rows: [TokenUsageDashboardBarRow]
    var showsLegend = true

    private var visibleRows: [TokenUsageDashboardBarRow] {
        Array(rows.filter { $0.ratio > 0 }.prefix(6))
    }

    private var ratioTotal: Double {
        visibleRows.reduce(0.0) { $0 + $1.ratio }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(Array(visibleRows.enumerated()), id: \.element.id) { index, row in
                        let normalizedRatio = ratioTotal > 0 ? row.ratio / ratioTotal : 0
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(chartColor(for: row, at: index))
                            .frame(width: Swift.max(CGFloat(5), geometry.size.width * CGFloat(normalizedRatio)))
                            .animation(.snappy(duration: 0.35), value: normalizedRatio)
                    }
                }
            }
            .frame(height: showsLegend ? 18 : nil)

            if showsLegend {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(visibleRows.enumerated()), id: \.element.id) { index, row in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(chartColor(for: row, at: index))
                                .frame(width: 7, height: 7)
                            Text(row.title)
                                .font(.system(size: 9, weight: .semibold))
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(row.value)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func chartColor(for row: TokenUsageDashboardBarRow, at index: Int) -> Color {
        if let aiTool = TokenUsageAITool(rawValue: row.id.lowercased()) {
            return aiTool.dashboardTint
        }

        let colors: [Color] = [.teal, .blue, .purple, .green, .orange, .red]
        return colors[index % colors.count]
    }
}
