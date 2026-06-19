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
