import SwiftUI

/// Daily or monthly usage trend. A single-day scope (Today or a picked
/// calendar day) has nothing to trend, so the section renders nothing there.
struct TokenMeteringDashboardTrendSection: View {
    @ObservedObject var store: TokenUsageDashboardStore
    let language: TokenMeteringLanguage
    let showsPlaceholder: Bool
    @State private var selectedTrendBucketID: String? = nil

    var body: some View {
        if shouldShowTrendChart {
            if showsPlaceholder {
                TokenMeteringDashboardPanel(
                    title: t(.trendTitle),
                    subtitle: t(.trendSubtitle)
                ) {
                    TokenMeteringDashboardChartPlaceholder(
                        tint: .teal,
                        rowCount: TokenMeteringDashboardChartPlaceholder.rowCount(fitting: 160)
                    )
                    .frame(height: 160, alignment: .top)
                }
                .accessibilityHidden(true)
            } else {
                trendChart
            }
        }
    }
}

extension TokenMeteringDashboardTrendSection {
    private var shouldShowTrendChart: Bool {
        guard store.snapshot.selectedCalendarDayID == nil else {
            return false
        }

        switch store.selectedPeriod {
        case .sevenDays, .thirtyDays, .all:
            return true
        case .today:
            return false
        }
    }

    private var trendChart: some View {
        let trendBuckets = store.snapshot.trendBuckets
        let hasData = trendBuckets.contains { $0.hasEvents }
        let selectedBucket = selectedTrendBucket(in: trendBuckets)

        return TokenMeteringDashboardPanel(
            title: t(.trendTitle),
            subtitle: t(.trendSubtitle)
        ) {
            if !hasData {
                TokenMeteringDashboardEmptyMessage(
                    title: t(.noTrendData),
                    detail: t(.waitingForEvents)
                )
            } else {
                VStack(alignment: .leading, spacing: 11) {
                    TokenMeteringDashboardTrendChart(
                        buckets: trendBuckets,
                        selectedBucketID: $selectedTrendBucketID,
                        defaultSelectedBucketID: selectedBucket?.id,
                        language: language
                    )

                    if let selectedBucket {
                        TokenMeteringDashboardTrendBucketSummary(bucket: selectedBucket, language: language)
                    }
                }
            }
        }
    }

    private func selectedTrendBucket(in buckets: [TokenUsageDashboardTrendBucket]) -> TokenUsageDashboardTrendBucket? {
        if let selectedTrendBucketID,
           let selectedBucket = buckets.first(where: { $0.id == selectedTrendBucketID && $0.hasEvents }) {
            return selectedBucket
        }

        return buckets.last { $0.hasEvents }
    }

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(key, language: language)
    }
}
