import SwiftUI

struct TokenMeteringDashboardCalendarControl: View {
    @ObservedObject var store: TokenUsageDashboardStore
    @Binding var isPresented: Bool
    let language: TokenMeteringLanguage
    let selectedControlAccent: Color
}

extension TokenMeteringDashboardCalendarControl {
    var body: some View {
        HStack(spacing: 6) {
            calendarButton
            clearCalendarSelectionButton
        }
    }

    private var calendarButton: some View {
        Button {
            isPresented.toggle()
        } label: {
            Label(datePickerTitle, systemImage: "calendar")
                .lineLimit(1)
        }
        .buttonStyle(.plain)
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(store.snapshot.selectedCalendarDayID == nil ? Color.primary : Color.white)
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            store.snapshot.selectedCalendarDayID == nil
                ? Color.primary.opacity(0.045)
                : selectedControlAccent,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        }
        .focusEffectDisabled()
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            calendarPickerPanel
                .padding(14)
                .frame(width: 264)
        }
    }

    @ViewBuilder
    private var clearCalendarSelectionButton: some View {
        if store.snapshot.selectedCalendarDayID != nil {
            Button {
                store.clearSelectedCalendarDay()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .black))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .background(Color.primary.opacity(0.045), in: Circle())
            .help(t(.clearSelection))
            .focusEffectDisabled()
        }
    }
}

extension TokenMeteringDashboardCalendarControl {
    private var calendarPickerPanel: some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                calendarMonthButton(systemImage: "chevron.left", isEnabled: store.snapshot.canNavigatePreviousCalendarMonth) {
                    store.showPreviousCalendarMonth()
                }
                .help(t(.previousMonth))

                Text(store.snapshot.calendarMonthTitle)
                    .font(.system(size: 11, weight: .bold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)

                calendarMonthButton(systemImage: "chevron.right", isEnabled: store.snapshot.canNavigateNextCalendarMonth) {
                    store.showNextCalendarMonth()
                }
                .help(t(.nextMonth))
            }

            todayCalendarButton

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
                spacing: 4
            ) {
                ForEach(Array(store.snapshot.calendarWeekdayTitles.enumerated()), id: \.offset) { _, title in
                    Text(title)
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(.secondary)
                        .frame(height: 14)
                }

                ForEach(store.snapshot.calendarDays) { day in
                    calendarDayCell(day)
                }
            }
        }
    }

    private func calendarMonthButton(
        systemImage: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

extension TokenMeteringDashboardCalendarControl {
    private var todayCalendarButton: some View {
        Button {
            store.selectTodayCalendarDay()
            isPresented = false
        } label: {
            HStack(spacing: 6) {
                Text(t(.periodToday).uppercased())
                    .font(.system(size: 8, weight: .black))
                    .tracking(0.8)
                Text(store.snapshot.todayCalendarDayTitle)
                    .font(.system(size: 10, weight: .bold))
                Spacer(minLength: 0)
                if store.snapshot.selectedCalendarDayID == store.snapshot.todayCalendarDayID {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10, weight: .bold))
                }
            }
            .foregroundStyle(store.snapshot.selectedCalendarDayID == store.snapshot.todayCalendarDayID ? .white : .primary)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                store.snapshot.selectedCalendarDayID == store.snapshot.todayCalendarDayID
                    ? selectedControlAccent
                    : Color.primary.opacity(0.045),
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .help(store.snapshot.todayCalendarDayTitle)
    }

    @ViewBuilder
    private func calendarDayCell(_ day: TokenUsageDashboardCalendarDay) -> some View {
        if day.isPlaceholder {
            Color.clear
                .frame(height: 24)
        } else {
            Button {
                store.selectCalendarDay(day.id)
                isPresented = false
            } label: {
                VStack(spacing: 2) {
                    Text(day.title)
                        .font(.system(size: 8, weight: day.hasEvents || day.isSelected ? .bold : .medium, design: .monospaced))
                        .foregroundStyle(day.isSelected ? Color.white : (day.isCurrentMonth ? Color.primary : Color.secondary.opacity(0.55)))
                    Capsule(style: .continuous)
                        .fill(day.hasEvents ? (day.isSelected ? Color.white : Color.teal) : Color.primary.opacity(0.08))
                        .frame(height: 4)
                        .opacity(day.hasEvents ? max(0.35, min(1.0, day.ratio)) : 1.0)
                }
                .frame(maxWidth: .infinity, minHeight: 24)
                .background(
                    day.isSelected ? selectedControlAccent : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(day.isToday && !day.isSelected ? selectedControlAccent.opacity(0.65) : Color.clear, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .help(day.detail)
            .accessibilityLabel(day.detail)
        }
    }
}

extension TokenMeteringDashboardCalendarControl {
    private var datePickerTitle: String {
        store.snapshot.selectedCalendarDayTitle ?? t(.pickDate)
    }

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(key, language: language)
    }
}
