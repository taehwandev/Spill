import SwiftUI

struct TokenMeteringDashboardFilterBar: View {
    @ObservedObject var store: TokenUsageDashboardStore
    @ObservedObject var cloudServiceStatusStore: CloudServiceStatusStore
    @ObservedObject var aiStatusStore: AIStatusStore
    @Binding var isCalendarPickerPresented: Bool
    let language: TokenMeteringLanguage
    let appLanguage: SpillAppLanguage
    let selectedControlAccent: Color
    let selectedControlAccentHighlight: Color
    let limitsPresentation: TokenMeteringDashboardLimitsPresentation
    @State private var hoveredPeriodID: String? = nil
}

extension TokenMeteringDashboardFilterBar {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Tool tabs split the column evenly, so two or three tools fill
            // the row instead of leaving a gap. All keeps a compact fixed
            // width because it carries no limit line.
            EqualToolTabsLayout(spacing: 8) {
                ForEach(store.snapshot.toolFilters) { filter in
                    TokenMeteringDashboardToolTab(
                        filter: filter,
                        store: store,
                        cloudServiceStatusStore: cloudServiceStatusStore,
                        aiStatusStore: aiStatusStore,
                        appLanguage: appLanguage,
                        selectedControlAccent: selectedControlAccent,
                        selectedControlAccentHighlight: selectedControlAccentHighlight,
                        limitsPresentation: limitsPresentation
                    )
                    .layoutValue(key: FixedToolTabWidth.self, value: filter.tool == nil ? Self.allTabWidth : nil)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(t(.aiToolHeader))

            // The column narrows beside the rail, so the period row steps
            // down: first the period totals go, then the "period" label.
            ViewThatFits(in: .horizontal) {
                periodRow(showsLabel: true, showsTotals: true)
                periodRow(showsLabel: true, showsTotals: false)
                periodRow(showsLabel: false, showsTotals: false)
            }
        }
        .padding(.vertical, 12)
    }

    private static let allTabWidth: CGFloat = 138
}

/// One row of tool tabs: a tab tagged with `FixedToolTabWidth` keeps that
/// width and every other tab gets an exactly equal share of the rest. An
/// `HStack` cannot promise that — it hands extra room to whichever tab has
/// the widest fixed-size content, so a tab with two limit gauges squeezed its
/// neighbour's share badge. Every tab takes the row's tallest height.
private struct EqualToolTabsLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? subviews.reduce(0) { $0 + $1.sizeThatFits(.unspecified).width }
        let widths = columnWidths(totalWidth: width, subviews: subviews)
        let height = zip(subviews, widths)
            .map { subview, width in subview.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }
            .max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        for (subview, width) in zip(subviews, columnWidths(totalWidth: bounds.width, subviews: subviews)) {
            subview.place(
                at: CGPoint(x: x, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: width, height: bounds.height)
            )
            x += width + spacing
        }
    }

    private func columnWidths(totalWidth: CGFloat, subviews: Subviews) -> [CGFloat] {
        guard !subviews.isEmpty else { return [] }
        let fixed = subviews.map { $0[FixedToolTabWidth.self] }
        let flexibleCount = fixed.filter { $0 == nil }.count
        let available = totalWidth - spacing * CGFloat(subviews.count - 1) - fixed.compactMap { $0 }.reduce(0, +)
        let share = flexibleCount > 0 ? max(0, available / CGFloat(flexibleCount)) : 0
        return fixed.map { $0 ?? share }
    }
}

private struct FixedToolTabWidth: LayoutValueKey {
    static let defaultValue: CGFloat? = nil
}

extension TokenMeteringDashboardFilterBar {
    private var activeAccumulationWindowText: String {
        if let selectedCalendarDayTitle = store.snapshot.selectedCalendarDayTitle {
            return selectedCalendarDayTitle
        }

        let formatter = TokenUsageDashboardSnapshot.cachedDateFormatter(
            dateStyle: .medium,
            timeStyle: .none,
            locale: .current,
            timeZone: .current
        )

        let now = Date()
        let calendar = Calendar.current
        let offset = store.periodOffset

        switch store.selectedPeriod {
        case .today:
            let targetDate = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) ?? now
            return formatter.string(from: targetDate)
        case .sevenDays:
            let baseStart = TokenUsageDashboardSnapshot.periodStartDate(dayCount: 7, now: now, calendar: calendar)
            if let start = calendar.date(byAdding: .day, value: offset * 7, to: baseStart),
               let end = calendar.date(byAdding: .day, value: 6, to: start) {
                return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
            }
            return t(.periodSevenDays)
        case .thirtyDays:
            let baseStart = TokenUsageDashboardSnapshot.periodStartDate(dayCount: 30, now: now, calendar: calendar)
            if let start = calendar.date(byAdding: .day, value: offset * 30, to: baseStart),
               let end = calendar.date(byAdding: .day, value: 29, to: start) {
                return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
            }
            return t(.periodThirtyDays)
        case .all:
            if offset == 0 {
                return t(.periodAllHistory)
            } else {
                let targetYear = calendar.component(.year, from: now) + offset
                return "\(targetYear)"
            }
        }
    }

    private func periodRow(showsLabel: Bool, showsTotals: Bool) -> some View {
        HStack(spacing: 8) {
            activeWindowHeader(showsLabel: showsLabel)

            Spacer(minLength: 8)

            ForEach(store.snapshot.periodFilters) { filter in
                periodPill(filter, showsTotal: showsTotals)
            }

            TokenMeteringDashboardCalendarControl(
                store: store,
                isPresented: $isCalendarPickerPresented,
                language: language,
                selectedControlAccent: selectedControlAccent
            )
        }
    }

    private func activeWindowHeader(showsLabel: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.teal)
            Text(showsLabel ? "\(t(.activeWindowLabel)): \(activeAccumulationWindowText)" : activeAccumulationWindowText)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()

            if store.selectedCalendarDayID == nil {
                HStack(spacing: 4) {
                    Button {
                        store.showPreviousPeriod()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(store.snapshot.canNavigatePreviousPeriod ? Color.primary : Color.secondary.opacity(0.3))
                            .frame(width: 18, height: 18)
                            .background(Color.primary.opacity(store.snapshot.canNavigatePreviousPeriod ? 0.06 : 0.02), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!store.snapshot.canNavigatePreviousPeriod)
                    .help("Move to previous period")

                    Button {
                        store.showNextPeriod()
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(store.snapshot.canNavigateNextPeriod ? Color.primary : Color.secondary.opacity(0.3))
                            .frame(width: 18, height: 18)
                            .background(Color.primary.opacity(store.snapshot.canNavigateNextPeriod ? 0.06 : 0.02), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!store.snapshot.canNavigateNextPeriod)
                    .help("Move to next period")
                }
                .padding(.leading, 4)
            }
        }
        .padding(.horizontal, 4)
    }
}

extension TokenMeteringDashboardFilterBar {
    private func periodPill(_ filter: TokenUsageDashboardPeriodFilter, showsTotal: Bool) -> some View {
        let isHovered = hoveredPeriodID == filter.id
        let isSelected = store.selectedCalendarDayID == nil && store.selectedPeriod == filter.period
        return Button {
            store.setSelectedPeriod(filter.period)
        } label: {
            HStack(spacing: 6) {
                Text(filter.title)
                    .font(.system(size: 10, weight: .bold))
                    .lineLimit(1)
                // Period totals stay for at-a-glance comparison, but read as a
                // caption so the period name remains the control's label.
                if showsTotal {
                    Text(filter.detail)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(isSelected ? selectedControlAccent.opacity(0.7) : Color.secondary.opacity(0.75))
                        .lineLimit(1)
                }
            }
            .fixedSize()
            .foregroundStyle(isSelected ? selectedControlAccent : .primary)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                isSelected
                    ? selectedControlAccent.opacity(0.12)
                    : Color.primary.opacity(isHovered ? 0.06 : 0.03),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        isSelected
                            ? selectedControlAccent.opacity(0.26)
                            : Color.primary.opacity(isHovered ? 0.10 : 0.05),
                        lineWidth: 0.5
                    )
            }
            .onHover { hovering in
                hoveredPeriodID = hovering ? filter.id : nil
            }
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(key, language: language)
    }
}
