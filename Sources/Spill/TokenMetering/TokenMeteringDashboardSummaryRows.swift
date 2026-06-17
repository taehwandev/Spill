import SwiftUI

struct TokenMeteringDashboardCompactSummaryRows<Rows: Collection>: View where Rows.Element == TokenUsageDashboardBarRow {
    private let rows: [TokenUsageDashboardBarRow]
    private let emptyText: String
    private let idPrefix: String?
    private let marker: TokenUsageLiveUpdateMarker
    private let isLiveUpdated: (String) -> Bool

    init(
        rows: Rows,
        emptyText: String,
        idPrefix: String? = nil,
        marker: TokenUsageLiveUpdateMarker,
        isLiveUpdated: @escaping (String) -> Bool
    ) {
        self.rows = Array(rows)
        self.emptyText = emptyText
        self.idPrefix = idPrefix
        self.marker = marker
        self.isLiveUpdated = isLiveUpdated
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if rows.isEmpty {
                Text(emptyText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rows) { row in
                    let liveUpdateID = idPrefix.map { "\($0):\(row.id)" }
                    let isActive = liveUpdateID.map(isLiveUpdated) ?? false
                    HStack(spacing: 8) {
                        HStack(spacing: 5) {
                            TokenMeteringLiveUpdateDot(isActive: isActive, marker: marker)
                            Text(row.title)
                                .font(.system(size: 10, weight: .semibold))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        Text(row.value)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                            .animation(.snappy(duration: 0.35), value: row.value)
                    }
                    .modifier(TokenMeteringLiveUpdateEffect(isActive: isActive, marker: marker, cornerRadius: 7))
                }
            }
        }
    }
}

struct TokenMeteringDashboardMetricPill: View {
    let title: String
    let value: String
    let isLiveUpdated: Bool
    let marker: TokenUsageLiveUpdateMarker

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Text(title.uppercased())
                    .font(.system(size: 8, weight: .black))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                TokenMeteringLiveUpdateDot(isActive: isLiveUpdated, marker: marker)
            }
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.35), value: value)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.04), lineWidth: 0.5)
        }
        .modifier(TokenMeteringLiveUpdateEffect(isActive: isLiveUpdated, marker: marker, cornerRadius: 8))
    }
}

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
