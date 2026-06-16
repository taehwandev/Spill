import SwiftUI

struct TokenMeteringDashboardFilterBar: View {
    @ObservedObject var store: TokenUsageDashboardStore
    @ObservedObject var cloudServiceStatusStore: CloudServiceStatusStore
    @Binding var isCalendarPickerPresented: Bool
    let language: TokenMeteringLanguage
    let appLanguage: SpillAppLanguage
    let selectedControlAccent: Color
    let selectedControlAccentHighlight: Color

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

        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let now = Date()
        let calendar = Calendar.current

        switch store.selectedPeriod {
        case .today:
            return formatter.string(from: now)
        case .sevenDays:
            if let startDate = calendar.date(byAdding: .day, value: -7, to: now) {
                return "\(formatter.string(from: startDate)) – \(formatter.string(from: now))"
            }
            return t(.periodSevenDays)
        case .thirtyDays:
            if let startDate = calendar.date(byAdding: .day, value: -30, to: now) {
                return "\(formatter.string(from: startDate)) – \(formatter.string(from: now))"
            }
            return t(.periodThirtyDays)
        case .all:
            return t(.periodAllHistory)
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
        }
        .padding(.horizontal, 4)
    }

    private func periodPill(_ filter: TokenUsageDashboardPeriodFilter) -> some View {
        Button {
            store.setSelectedPeriod(filter.period)
        } label: {
            HStack(spacing: 6) {
                Text(filter.title)
                    .font(.system(size: 10, weight: .bold))
                    .lineLimit(1)
                Text(filter.detail)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(filter.isSelected ? .white.opacity(0.78) : .secondary)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.35), value: filter.detail)
            }
            .foregroundStyle(filter.isSelected ? .white : .primary)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                filter.isSelected ? selectedControlAccent : Color.primary.opacity(0.045),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(key, language: language)
    }
}
