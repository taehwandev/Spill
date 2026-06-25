import SwiftUI

struct TokenMeteringDashboardFilterBar: View {
    @ObservedObject var store: TokenUsageDashboardStore
    @ObservedObject var cloudServiceStatusStore: CloudServiceStatusStore
    @Binding var isCalendarPickerPresented: Bool
    let language: TokenMeteringLanguage
    let appLanguage: SpillAppLanguage
    let selectedControlAccent: Color
    let selectedControlAccentHighlight: Color
    @State private var hoveredPeriodID: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(t(.aiToolHeader))
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.0)
                    .foregroundStyle(.secondary)
                    .frame(width: 78, alignment: .leading)

                ForEach(store.snapshot.toolFilters) { filter in
                    TokenMeteringDashboardToolTab(
                        filter: filter,
                        store: store,
                        cloudServiceStatusStore: cloudServiceStatusStore,
                        appLanguage: appLanguage,
                        selectedControlAccent: selectedControlAccent,
                        selectedControlAccentHighlight: selectedControlAccentHighlight
                    )
                }
            }

            HStack(spacing: 8) {
                activeWindowHeader

                Spacer(minLength: 8)

                ForEach(store.snapshot.periodFilters) { filter in
                    periodPill(filter)
                }

                TokenMeteringDashboardCalendarControl(
                    store: store,
                    isPresented: $isCalendarPickerPresented,
                    language: language,
                    selectedControlAccent: selectedControlAccent
                )
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

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

    private var activeWindowHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.teal)
            Text("\(t(.activeWindowLabel)): \(activeAccumulationWindowText)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)

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

    private func periodPill(_ filter: TokenUsageDashboardPeriodFilter) -> some View {
        let isHovered = hoveredPeriodID == filter.id
        let isSelected = store.selectedCalendarDayID == nil && store.selectedPeriod == filter.period
        return Button {
            store.setSelectedPeriod(filter.period)
        } label: {
            HStack(spacing: 6) {
                Text(filter.title)
                    .font(.system(size: 10, weight: .bold))
                    .lineLimit(1)
                Text(filter.detail)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(isSelected ? selectedControlAccent.opacity(0.82) : .secondary)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? selectedControlAccent : .primary)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                isSelected
                    ? selectedControlAccent.opacity(0.14)
                    : Color.primary.opacity(isHovered ? 0.075 : 0.045),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        isSelected
                            ? selectedControlAccent.opacity(0.28)
                            : Color.primary.opacity(isHovered ? 0.12 : 0.06),
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
