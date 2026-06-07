import AppKit
import SwiftUI

private struct TokenUsageClearRequest: Identifiable {
    let id = UUID()
    let scope: TokenUsageClearScope
    let preview: TokenUsageClearPreview
}

struct TokenMeteringDashboardView: View {
    @ObservedObject var store: TokenUsageDashboardStore
    @ObservedObject var cloudServiceStatusStore: CloudServiceStatusStore
    @ObservedObject private var settings: SpillSettings
    @State private var isCalendarPickerPresented = false
    @State private var isServiceStatusPresented = false
    @State private var pendingClearRequest: TokenUsageClearRequest?
    @State private var aliasText = ""
    @State private var resolvedLanguage: TokenMeteringLanguage
    private let refreshAction: () -> Void
    private let settingsAction: () -> Void
    private let titleDidChange: () -> Void

    init(
        store: TokenUsageDashboardStore,
        cloudServiceStatusStore: CloudServiceStatusStore = CloudServiceStatusStore(),
        settings: SpillSettings = .shared,
        refreshAction: @escaping () -> Void = {},
        settingsAction: @escaping () -> Void = {},
        titleDidChange: @escaping () -> Void = {}
    ) {
        self.store = store
        self.cloudServiceStatusStore = cloudServiceStatusStore
        _settings = ObservedObject(wrappedValue: settings)
        _resolvedLanguage = State(initialValue: TokenMeteringLanguage.current(appLanguage: settings.appLanguage))
        self.refreshAction = refreshAction
        self.settingsAction = settingsAction
        self.titleDidChange = titleDidChange
    }

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(
            key,
            language: currentLanguage
        )
    }

    private var currentLanguage: TokenMeteringLanguage {
        resolvedLanguage
    }

    private var selectedControlAccent: Color {
        Color(red: 0.08, green: 0.54, blue: 0.57)
    }

    private var selectedControlAccentHighlight: Color {
        Color(red: 0.11, green: 0.65, blue: 0.68)
    }

    var body: some View {
        VStack(spacing: 0) {
            topHeader

            Divider()
                .background(Color.primary.opacity(0.05))

            topFilterBar

            Divider()
                .background(Color.primary.opacity(0.05))

            HStack(alignment: .top, spacing: 16) {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        kpiStrip
                        analyticsGrid
                        sessionsTable
                    }
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }

                if let selectedSession = store.snapshot.selectedSession {
                    detailPanel(for: selectedSession, snapshot: store.snapshot)
                        .frame(width: 320)
                } else {
                    rightRail
                        .frame(width: 286)
                }
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background {
            ZStack {
                VisualEffectView(material: .sidebar, blendingMode: .withinWindow)
                LinearGradient(
                    colors: [
                        Color.teal.opacity(0.04),
                        Color.blue.opacity(0.03),
                        Color.purple.opacity(0.04)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .frame(minWidth: 1060, minHeight: 640)
        .onAppear {
            let language = TokenMeteringLanguage.current(appLanguage: settings.appLanguage)
            resolvedLanguage = language
            titleDidChange()
            store.setLanguage(language)
            store.refresh()
        }
        .onChange(of: settings.appLanguage) { _, appLanguage in
            let language = TokenMeteringLanguage.current(appLanguage: appLanguage)
            resolvedLanguage = language
            titleDidChange()
            store.setLanguage(language)
        }
        .onChange(of: store.selectedSessionID) { _, newID in
            if let newID {
                aliasText = settings.tokenUsageLocalAliases[newID] ?? ""
            } else {
                aliasText = ""
            }
        }
        .alert(
            t(.deleteTokenDataTitle),
            isPresented: Binding(
                get: { pendingClearRequest != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingClearRequest = nil
                    }
                }
            ),
            presenting: pendingClearRequest
        ) { request in
            Button(t(.deleteTokenDataCancel), role: .cancel) {
                pendingClearRequest = nil
            }
            Button(t(.deleteTokenDataConfirm), role: .destructive) {
                store.clearEvents(in: request.scope)
                pendingClearRequest = nil
            }
        } message: { request in
            Text(TokenMeteringL10n.deleteTokenDataMessage(
                scope: request.preview.scopeTitle,
                eventCount: request.preview.eventCount,
                tokens: TokenUsageDashboardSnapshot.formatTokens(request.preview.totalTokens),
                language: currentLanguage
            ))
        }
    }

    private var topHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.teal, Color.teal.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.teal.opacity(0.3), radius: 4, x: 0, y: 2)

                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(t(.dashboardTitle))
                        .font(.system(size: 18, weight: .bold))
                    alphaBadge
                    localOnlyBadge
                }

                HStack(spacing: 6) {
                    Text(t(.dashboardSubtitle))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let overallUpdated = store.snapshot.overallLastUpdatedString {
                        Text("•")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary.opacity(0.5))

                        Text("\(t(.lastUpdatedLabel)): \(overallUpdated)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 16)

            HStack(spacing: 8) {
                TokenMeteringInfoButton(
                    title: t(.displayModeInfoTitle),
                    detail: t(.displayModeInfoDetail)
                )

                serviceStatusButton
                    .frame(width: 116)
            }
            .frame(height: 30)

            Picker("", selection: Binding(
                get: { store.displayMode },
                set: { store.setDisplayMode($0) }
            )) {
                ForEach(TokenUsageDisplayMode.allCases) { mode in
                    Text(mode.localizedTitle(language: currentLanguage)).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 240)
            .focusEffectDisabled()

            HStack(spacing: 8) {
                Button {
                    refreshLocalTokenData()
                } label: {
                    Label(t(.refresh), systemImage: "arrow.clockwise")
                }

                Button {
                    settingsAction()
                } label: {
                    Label(AppL10n.text(.settings, appLanguage: settings.appLanguage), systemImage: "gearshape")
                }

            }
            .buttonStyle(.bordered)
            .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var topFilterBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(t(.aiToolHeader))
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.0)
                    .foregroundStyle(.secondary)
                    .frame(width: 78, alignment: .leading)

                ForEach(store.snapshot.toolFilters) { filter in
                    topToolTab(filter)
                }
            }

            HStack(spacing: 8) {
                activeWindowHeader

                Spacer(minLength: 8)

                ForEach(store.snapshot.periodFilters) { filter in
                    periodPill(filter)
                }

                HStack(spacing: 6) {
                    Button {
                        isCalendarPickerPresented.toggle()
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
                    .popover(isPresented: $isCalendarPickerPresented, arrowEdge: .bottom) {
                        calendarPickerPanel
                            .padding(14)
                            .frame(width: 264)
                    }

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
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var serviceStatusButton: some View {
        Button {
            openServiceStatusDetails()
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(serviceStatusTint)
                    .frame(width: 5, height: 5)

                Image(systemName: serviceStatusSymbolName)
                    .font(.system(size: 9, weight: .bold))

                Text(serviceStatusButtonTitle)
                    .font(.system(size: 10, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .padding(.horizontal, 9)
            .frame(height: 26)
            .foregroundStyle(serviceStatusTint)
            .background(serviceStatusTint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(serviceStatusTint.opacity(0.13), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .popover(isPresented: $isServiceStatusPresented, arrowEdge: .top) {
            CloudServiceStatusDashboardView(store: cloudServiceStatusStore)
        }
        .help(serviceStatusHelpText)
        .accessibilityLabel(
            AppL10n.serviceStatusAccessibility(
                status: serviceStatusButtonTitle,
                appLanguage: settings.appLanguage
            )
        )
    }

    private func refreshLocalTokenData() {
        refreshAction()
        store.refresh()
    }

    private func openServiceStatusDetails() {
        isServiceStatusPresented = true
        refreshServerStatus()
    }

    private func refreshServerStatus(force: Bool = false) {
        cloudServiceStatusStore.refreshIfNeeded(force: force)
    }

    private var serviceStatusButtonTitle: String {
        if cloudServiceStatusStore.isLoading {
            return AppL10n.text(.checking, appLanguage: settings.appLanguage)
        }

        guard let aggregateHealth = aggregateServiceHealth else {
            return AppL10n.text(.serverStatus, appLanguage: settings.appLanguage)
        }

        return aggregateHealth.serverStatusHeaderTitle(appLanguage: settings.appLanguage)
    }

    private var serviceStatusHelpText: String {
        guard let snapshot = cloudServiceStatusStore.snapshot else {
            return AppL10n.text(.fetchOfficialServiceStatus, appLanguage: settings.appLanguage)
        }

        let aggregateHealth = CloudServiceStatusPresentation.aggregateHealth(for: snapshot.items)
        let issueCount = serviceStatusIssueItems.count
        let statusText = issueCount == 0
            ? String(
                format: AppL10n.text(.serverStatusNoIssues, appLanguage: settings.appLanguage),
                aggregateHealth.serverStatusHeaderTitle(appLanguage: settings.appLanguage).lowercased()
            )
            : AppL10n.serverStatusWithIssues(
                status: aggregateHealth.serverStatusHeaderTitle(appLanguage: settings.appLanguage).lowercased(),
                issueCount: issueCount,
                appLanguage: settings.appLanguage
            )

        return "\(statusText). \(AppL10n.lastChecked(fullServiceCheckTime(snapshot.fetchedAt), age: relativeServiceAge(from: snapshot.fetchedAt), appLanguage: settings.appLanguage)) \(AppL10n.text(.clickForPerServiceDetails, appLanguage: settings.appLanguage))"
    }

    private var serviceStatusSymbolName: String {
        if cloudServiceStatusStore.isLoading {
            return "arrow.triangle.2.circlepath"
        }

        guard let aggregateHealth = aggregateServiceHealth else {
            return "cloud.fill"
        }

        return aggregateHealth.serverStatusSymbolName
    }

    private var serviceStatusTint: Color {
        if cloudServiceStatusStore.isLoading {
            return .blue
        }

        guard let aggregateHealth = aggregateServiceHealth else {
            return .secondary
        }

        return aggregateHealth.serverStatusTint
    }

    private var serviceStatusIssueItems: [CloudServiceStatusItem] {
        cloudServiceStatusStore.snapshot?.items.filter { $0.health.isServerIssue } ?? []
    }

    private var aggregateServiceHealth: CloudServiceHealth? {
        cloudServiceStatusStore.snapshot.map {
            CloudServiceStatusPresentation.aggregateHealth(for: $0.items)
        }
    }

    private func fullServiceCheckTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = .current

        if Calendar.current.isDateInToday(date) {
            formatter.setLocalizedDateFormatFromTemplate("jm")
        } else {
            formatter.setLocalizedDateFormatFromTemplate("MMM d, jm")
        }

        return formatter.string(from: date)
    }

    private func relativeServiceAge(from date: Date) -> String {
        let elapsed = max(0, Date().timeIntervalSince(date))
        if elapsed < 60 {
            return AppL10n.text(.justNow, appLanguage: settings.appLanguage)
        }

        let minutes = Int(elapsed / 60)
        if minutes < 60 {
            return AppL10n.minutesAgo(minutes, appLanguage: settings.appLanguage)
        }

        return AppL10n.hoursAgo(max(1, minutes / 60), appLanguage: settings.appLanguage)
    }

    private var calendarPickerPanel: some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                Button {
                    store.showPreviousCalendarMonth()
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .disabled(!store.snapshot.canNavigatePreviousCalendarMonth)
                .help(t(.previousMonth))

                Text(store.snapshot.calendarMonthTitle)
                    .font(.system(size: 11, weight: .bold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)

                Button {
                    store.showNextCalendarMonth()
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .disabled(!store.snapshot.canNavigateNextCalendarMonth)
                .help(t(.nextMonth))
            }

            Button {
                store.selectTodayCalendarDay()
                isCalendarPickerPresented = false
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
                    if day.isPlaceholder {
                        Color.clear
                            .frame(height: 24)
                    } else {
                        Button {
                            store.selectCalendarDay(day.id)
                            isCalendarPickerPresented = false
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
        }
    }

    private var kpiStrip: some View {
        HStack(spacing: 12) {
            ForEach(store.snapshot.kpis) { kpi in
                let liveUpdateID = "kpi:\(kpi.id)"
                let isLiveUpdated = store.isLiveUpdated(liveUpdateID)
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 6) {
                        Text(kpi.title.uppercased())
                            .font(.system(size: 9, weight: .black))
                            .tracking(1.0)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        TokenMeteringLiveUpdateDot(isActive: isLiveUpdated, marker: store.liveUpdateMarker)
                        Spacer(minLength: 0)
                        if kpi.id == "total",
                           let comparison = store.snapshot.comparisonTotalTokens,
                           comparison > 0 {
                            let delta = store.snapshot.totalTokens - comparison
                            let pct = Double(delta) / Double(comparison) * 100
                            HStack(spacing: 2) {
                                Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                                    .font(.system(size: 7, weight: .black))
                                Text(String(format: "%.0f%%", abs(pct)))
                                    .font(.system(size: 8, weight: .black))
                            }
                            .foregroundStyle(delta >= 0 ? Color.green : Color.red)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background((delta >= 0 ? Color.green : Color.red).opacity(0.1), in: Capsule())
                        }
                    }
                    Text(kpi.value)
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(kpi.id == "total" ? .teal : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.35), value: kpi.value)
                    HStack(spacing: 4) {
                        Text(kpi.detail)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if kpi.id == "total",
                           let comparison = store.snapshot.comparisonTotalTokens {
                            Text("· \(comparisonPeriodLabel): \(TokenUsageDashboardSnapshot.formatTokens(comparison))")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary.opacity(0.6))
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.07), lineWidth: 0.5)
                }
                .modifier(TokenMeteringLiveUpdateEffect(isActive: isLiveUpdated, marker: store.liveUpdateMarker, cornerRadius: 12))
            }
        }
    }

    private var comparisonPeriodLabel: String {
        switch store.selectedPeriod {
        case .today:
            return t(.relativeYesterday)
        case .sevenDays:
            return t(.relativePreviousWeek)
        case .thirtyDays:
            return t(.relativePreviousMonth)
        case .all:
            return ""
        }
    }

    private var analyticsGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                dashboardPanel(
                    title: t(.aiToolDistribution),
                    subtitle: t(.aiToolDistributionSubtitle),
                    infoTitle: t(.aiToolInfoTitle),
                    infoDetail: t(.aiToolInfoDetail)
                ) {
                    barRows(
                        store.snapshot.toolRows,
                        emptyText: t(.noAIToolData),
                        idPrefix: "tool",
                        tint: .teal,
                        serviceStatus: { row in serviceStatus(for: row) }
                    )
                }

                dashboardPanel(
                    title: t(.workflowBreakdown),
                    subtitle: t(.workflowBreakdownSubtitle),
                    infoTitle: t(.workflowInfoTitle),
                    infoDetail: t(.workflowInfoDetail)
                ) {
                    barRows(store.snapshot.taskRows, emptyText: t(.noWorkflowData), idPrefix: "task", tint: .blue)
                }
            }

            HStack(alignment: .top, spacing: 14) {
                dashboardPanel(
                    title: t(.stageBreakdown),
                    subtitle: t(.stageBreakdownSubtitle),
                    infoTitle: t(.stageInfoTitle),
                    infoDetail: t(.stageInfoDetail)
                ) {
                    barRows(store.snapshot.stageRows, emptyText: t(.noStageData), idPrefix: "stage", tint: .purple)
                }

                dashboardPanel(
                    title: t(.sourceBreakdown),
                    subtitle: t(.sourceBreakdownSubtitle),
                    infoTitle: t(.sourceInfoTitle),
                    infoDetail: t(.sourceInfoDetail)
                ) {
                    barRows(store.snapshot.sourceRows, emptyText: t(.noSourceBreakdown), idPrefix: "source", tint: .orange)
                }
            }
        }
    }

    private var rightRail: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                modelPanel
                sourcePanel
                receiverPanel
                privacyPanel
            }
            .padding(.vertical, 18)
        }
    }

    private var modelPanel: some View {
        railPanel(
            title: t(.modelBreakdown),
            infoTitle: t(.modelInfoTitle),
            infoDetail: t(.modelInfoDetail)
        ) {
            VStack(spacing: 8) {
                compactSummaryRows(store.snapshot.modelRows.prefix(5), emptyText: t(.noModelData), idPrefix: "model")
            }
        }
    }

    private var receiverPanel: some View {
        railPanel(title: t(.receivers)) {
            VStack(spacing: 8) {
                receiverTile(title: t(.localQueue), state: t(.defaultState), systemImage: "tray.and.arrow.down", tint: .green)
                receiverTile(title: t(.adapters), state: t(.onDemand), systemImage: "bolt.horizontal", tint: .teal)
            }
        }
    }

    private var sourcePanel: some View {
        railPanel(
            title: t(.sourceDetail),
            infoTitle: t(.sourceInfoTitle),
            infoDetail: t(.sourceInfoDetail)
        ) {
            VStack(spacing: 8) {
                compactSummaryRows(store.snapshot.sourceRows.prefix(5), emptyText: t(.noSourceBuckets), idPrefix: "source")
            }
        }
    }

    private var privacyPanel: some View {
        railPanel(title: t(.privacyBoundary)) {
            VStack(alignment: .leading, spacing: 9) {
                Text(t(.privacyBoundaryDetail))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                FlowingTokenMeteringLabels(
                    labels: Array(TokenMeteringL10n.forbiddenContentLabels(language: currentLanguage).prefix(6))
                )
            }
        }
    }

    private var sessionsTable: some View {
        dashboardPanel(
            title: t(.runs),
            subtitle: t(.runsSubtitle),
            infoTitle: t(.runsInfoTitle),
            infoDetail: t(.runsInfoDetail)
        ) {
            if store.snapshot.sessions.isEmpty {
                emptyMessage(
                    title: t(.noLocalTokenEvents),
                    detail: t(.noLocalTokenEventsDetail)
                )
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        tableHeader(t(.run))
                        tableHeader(t(.events))
                            .frame(width: 150, alignment: .leading)
                        tableHeader(t(.tokens))
                            .frame(width: 96, alignment: .trailing)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)

                    ForEach(store.snapshot.sessions.prefix(8)) { session in
                        let isSelected = store.selectedSessionID == session.id
                        let liveUpdateID = "session:\(session.id)"
                        let isLiveUpdated = store.isLiveUpdated(liveUpdateID)
                        Button {
                            if isSelected {
                                store.clearWorkItemSelection()
                            } else {
                                store.selectSession(session.id)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                HStack(spacing: 6) {
                                    TokenMeteringLiveUpdateDot(isActive: isLiveUpdated, marker: store.liveUpdateMarker)
                                    Text(session.title)
                                        .font(.system(size: 11, weight: .bold))
                                        .lineLimit(1)
                                }
                                Text(session.detail)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(isSelected ? .white.opacity(0.82) : .secondary)
                                    .lineLimit(1)
                                    .frame(width: 150, alignment: .leading)
                                Text(session.value)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .frame(width: 96, alignment: .trailing)
                                    .contentTransition(.numericText())
                                    .animation(.snappy(duration: 0.35), value: session.value)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .foregroundStyle(isSelected ? .white : .primary)
                            .background(
                                isSelected ? selectedControlAccent : Color.primary.opacity(0.025),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(isSelected ? selectedControlAccent.opacity(0.26) : Color.primary.opacity(0.04), lineWidth: 0.5)
                            }
                            .modifier(TokenMeteringLiveUpdateEffect(isActive: isLiveUpdated && !isSelected, marker: store.liveUpdateMarker, cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 6)
                        .contextMenu {
                            Button(role: .destructive) {
                                requestClear(.workItem(session.id))
                                if store.selectedSessionID == session.id {
                                    store.clearWorkItemSelection()
                                }
                            } label: {
                                Label(t(.clearSelectedWorkItem), systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
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

    private var datePickerTitle: String {
        store.snapshot.selectedCalendarDayTitle ?? t(.pickDate)
    }

    private func detailPanel(
        for session: TokenUsageDashboardSessionRow,
        snapshot detailSnapshot: TokenUsageDashboardSnapshot
    ) -> some View {
        let detailSession = detailSnapshot.selectedSession ?? session
        let kpisByID = Dictionary(uniqueKeysWithValues: detailSnapshot.kpis.map { ($0.id, $0) })
        let sourceRows = detailSnapshot.sourceRows
        let hasDetailedSources = sourceRows.contains { row in
            row.id != "unknown" && row.ratio > 0
        }
        let isRuntimeTotalOnly = !hasDetailedSources && detailSnapshot.totalTokens > 0

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t(.selectedWorkItemHeader))
                            .font(.system(size: 9, weight: .black))
                            .tracking(1.0)
                            .foregroundStyle(.secondary)
                        Text(detailSession.title)
                            .font(.system(size: 14, weight: .bold))
                            .lineLimit(2)
                        Text(detailSession.detail)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Button {
                        store.clearWorkItemSelection()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text(t(.localAlias))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        TextField(
                            t(.localAliasPlaceholder),
                            text: $aliasText
                        )
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                        .onSubmit {
                            store.updateAlias(for: session.id, alias: aliasText)
                        }

                        Button(t(.applyAlias)) {
                            store.updateAlias(for: session.id, alias: aliasText)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.teal)
                        .font(.system(size: 10, weight: .bold))

                        if !aliasText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button(t(.clearAlias)) {
                                aliasText = ""
                                store.updateAlias(for: session.id, alias: "")
                            }
                            .buttonStyle(.bordered)
                            .font(.system(size: 10, weight: .medium))
                        }
                    }

                    Text(t(.localAliasDetail))
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.04), lineWidth: 0.5)
                }

                VStack(spacing: 8) {
                    HStack {
                        metricPill(
                            title: t(.total),
                            value: kpisByID["total"]?.value ?? detailSession.value,
                            liveUpdateID: "session:\(detailSession.id)"
                        )
                        metricPill(
                            title: t(.events),
                            value: "\(detailSession.eventCount)",
                            liveUpdateID: "session:\(detailSession.id)"
                        )
                    }
                    HStack {
                        metricPill(
                            title: t(.input),
                            value: kpisByID["input"]?.value ?? "-"
                        )
                        metricPill(
                            title: t(.output),
                            value: kpisByID["output"]?.value ?? "-"
                        )
                    }
                }

                workItemPopoverSection(
                    title: t(.aiTool),
                    rows: detailSnapshot.toolRows.prefix(4),
                    emptyText: t(.noAIToolData),
                    idPrefix: "tool"
                )

                workItemPopoverSection(
                    title: t(.modelBreakdown),
                    rows: detailSnapshot.modelRows.prefix(4),
                    emptyText: t(.noModelData),
                    idPrefix: "model"
                )

                workItemPopoverSection(
                    title: t(.workflowBreakdown),
                    rows: detailSnapshot.taskRows.prefix(4),
                    emptyText: t(.noWorkflowData),
                    idPrefix: "task"
                )

                workItemPopoverSection(
                    title: t(.stageBreakdown),
                    rows: detailSnapshot.stageRows.prefix(4),
                    emptyText: t(.noStageData),
                    idPrefix: "stage"
                )

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 6) {
                        Text(t(.sourceBreakdown).uppercased())
                            .font(.system(size: 8.5, weight: .black))
                            .tracking(0.9)
                            .foregroundStyle(.secondary)

                        Spacer()

                        if isRuntimeTotalOnly {
                            HStack(spacing: 4) {
                                Text(t(.cumulativeOnlyBadge))
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(Color.orange.opacity(0.12), in: Capsule())

                                TokenMeteringInfoButton(
                                    title: t(.cumulativeOnlyInfoTitle),
                                    detail: t(.cumulativeOnlyInfoDetail)
                                )
                            }
                        }
                    }

                    compactSummaryRows(detailSnapshot.sourceRows.prefix(4), emptyText: t(.noSourceBreakdown), idPrefix: "source")
                }
                .padding(10)
                .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.04), lineWidth: 0.5)
                }

                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(t(.diagnosticsSessionID)): \(session.id)")
                        Text("\(t(.diagnosticsRunID)): \(session.runID)")
                    }
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                } label: {
                    Text(t(.diagnosticsCodes))
                        .font(.system(size: 10, weight: .semibold))
                }
                .padding(10)
                .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 6) {
                    Text(t(.privacyBoundary))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text(t(.privacyBoundaryDetail))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(.vertical, 18)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private func workItemPopoverSection<T: Collection>(
        title: String,
        rows: T,
        emptyText: String,
        idPrefix: String
    ) -> some View where T.Element == TokenUsageDashboardBarRow {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.system(size: 8.5, weight: .black))
                .tracking(0.9)
                .foregroundStyle(.secondary)
            compactSummaryRows(rows, emptyText: emptyText, idPrefix: idPrefix)
        }
        .padding(10)
        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.04), lineWidth: 0.5)
        }
    }

    private func dashboardPanel<Content: View>(
        title: String,
        subtitle: String,
        infoTitle: String? = nil,
        infoDetail: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if let infoTitle, let infoDetail {
                    TokenMeteringInfoButton(title: infoTitle, detail: infoDetail)
                }
            }

            content()
        }
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .topLeading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.07), lineWidth: 0.5)
        }
    }

    private func railPanel<Content: View>(
        title: String,
        infoTitle: String? = nil,
        infoDetail: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 6) {
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.0)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                if let infoTitle, let infoDetail {
                    TokenMeteringInfoButton(title: infoTitle, detail: infoDetail)
                }
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.07), lineWidth: 0.5)
        }
    }

    private func topToolTab(_ filter: TokenUsageDashboardToolFilter) -> some View {
        let liveUpdateID = "filter:tool:\(filter.id)"
        let isLiveUpdated = store.isLiveUpdated(liveUpdateID)
        let toolLastUpdated = lastUpdatedString(for: filter.tool)
        let detail = toolLastUpdated.map { "\(filter.detail) · \($0)" } ?? filter.detail
        let serviceStatus: CloudServiceStatusItem?
        if let tool = filter.tool {
            serviceStatus = self.serviceStatus(for: tool)
        } else {
            serviceStatus = nil
        }

        return Button {
            store.setSelectedTool(filter.tool)
        } label: {
            HStack(spacing: 9) {
                Circle()
                    .fill(filter.isSelected ? .white : Color.teal.opacity(0.75))
                    .frame(width: 7, height: 7)

                topToolTabLabel(
                    filter: filter,
                    detail: detail,
                    serviceStatus: serviceStatus,
                    isActive: isLiveUpdated,
                    marker: store.liveUpdateMarker
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            .foregroundStyle(filter.isSelected ? .white : .primary)
            .background {
                if filter.isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [selectedControlAccentHighlight, selectedControlAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: selectedControlAccent.opacity(0.16), radius: 4, x: 0, y: 1.5)
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.035))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.055), lineWidth: 0.5)
            }
            .modifier(TokenMeteringLiveUpdateEffect(isActive: isLiveUpdated && !filter.isSelected, marker: store.liveUpdateMarker, cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }

    private func topToolTabLabel(
        filter: TokenUsageDashboardToolFilter,
        detail: String,
        serviceStatus: CloudServiceStatusItem?,
        isActive: Bool,
        marker: TokenUsageLiveUpdateMarker
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                topToolTitle(filter)

                if hasServiceStatusAccessory(serviceStatus: serviceStatus, tool: filter.tool) {
                    toolServiceStatusAccessory(serviceStatus: serviceStatus, tool: filter.tool)
                }

                Spacer(minLength: 0)
            }

            topToolDetailLine(
                filter: filter,
                detail: detail,
                isActive: isActive,
                marker: marker
            )
        }
    }

    private func topToolTitle(_ filter: TokenUsageDashboardToolFilter) -> some View {
        Text(filter.title)
            .font(.system(size: 11, weight: filter.isSelected ? .bold : .semibold))
            .lineLimit(1)
            .layoutPriority(1)
            .minimumScaleFactor(0.78)
    }

    private func topToolDetailLine(
        filter: TokenUsageDashboardToolFilter,
        detail: String,
        isActive: Bool,
        marker: TokenUsageLiveUpdateMarker
    ) -> some View {
        HStack(spacing: 5) {
            topToolDetailText(filter: filter, detail: detail)

            TokenMeteringLiveUpdateDot(
                isActive: isActive,
                marker: marker,
                tint: filter.isSelected ? .white : .teal
            )

            Spacer(minLength: 0)
        }
    }

    private func topToolDetailText(
        filter: TokenUsageDashboardToolFilter,
        detail: String
    ) -> some View {
        Text(detail)
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(filter.isSelected ? .white.opacity(0.78) : .secondary)
            .lineLimit(1)
            .contentTransition(.numericText())
            .animation(.snappy(duration: 0.35), value: filter.detail)
    }

    private func hasServiceStatusAccessory(
        serviceStatus: CloudServiceStatusItem?,
        tool: TokenUsageAITool?
    ) -> Bool {
        serviceStatus != nil || CloudServiceStatusPresentation.hasCloudService(for: tool)
    }

    @ViewBuilder
    private func toolServiceStatusAccessory(
        serviceStatus: CloudServiceStatusItem?,
        tool: TokenUsageAITool?
    ) -> some View {
        if let serviceStatus {
            CloudServiceStatusBadge(item: serviceStatus, appLanguage: settings.appLanguage)
                .fixedSize(horizontal: true, vertical: false)
        } else if CloudServiceStatusPresentation.hasCloudService(for: tool) {
            aiServerPendingBadge()
                .fixedSize(horizontal: true, vertical: false)
        }
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

    private func requestClear(_ scope: TokenUsageClearScope) {
        let preview = store.clearPreview(for: scope)
        guard preview.hasEvents else {
            return
        }
        pendingClearRequest = TokenUsageClearRequest(scope: scope, preview: preview)
    }

    private func lastUpdatedString(for tool: TokenUsageAITool?) -> String? {
        guard let tool else { return nil }
        switch tool {
        case .codex:
            return store.snapshot.codexLastUpdatedString
        case .claude:
            return store.snapshot.claudeLastUpdatedString
        case .antigravity:
            return store.snapshot.antigravityLastUpdatedString
        default:
            return nil
        }
    }

    private func serviceStatus(for row: TokenUsageDashboardBarRow) -> CloudServiceStatusItem? {
        guard let tool = TokenUsageAITool(rawValue: row.id) else {
            return nil
        }

        return serviceStatus(for: tool)
    }

    private func serviceStatus(for tool: TokenUsageAITool) -> CloudServiceStatusItem? {
        CloudServiceStatusPresentation.serviceStatus(
            for: tool,
            in: cloudServiceStatusStore.snapshot
        )
    }

    private func aiServerPendingBadge() -> some View {
        let tint = cloudServiceStatusStore.isLoading ? Color.blue : Color.secondary
        let value = cloudServiceStatusStore.isLoading
            ? AppL10n.text(.checking, appLanguage: settings.appLanguage)
            : AppL10n.text(.server, appLanguage: settings.appLanguage)

        return HStack(spacing: 4) {
            Image(systemName: cloudServiceStatusStore.isLoading ? "arrow.triangle.2.circlepath" : "cloud.fill")
                .font(.system(size: 8, weight: .bold))

            Text(value)
                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                .lineLimit(1)
        }
        .padding(.horizontal, 5)
        .frame(height: 18)
        .foregroundStyle(tint)
        .background(tint.opacity(0.10), in: Capsule())
        .help(AppL10n.text(.serverStatusPendingHelp, appLanguage: settings.appLanguage))
    }

    private func receiverTile(title: String, state: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(tint.opacity(0.12))

                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tint)
            }
            .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                Text(state)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.04), lineWidth: 0.5)
        }
    }

    private func barRows(
        _ rows: [TokenUsageDashboardBarRow],
        emptyText: String,
        idPrefix: String,
        tint: Color = .teal,
        serviceStatus: ((TokenUsageDashboardBarRow) -> CloudServiceStatusItem?)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            if rows.isEmpty {
                emptyMessage(title: emptyText, detail: t(.waitingForEvents))
            } else {
                ForEach(rows.prefix(6)) { row in
                    let liveUpdateID = "\(idPrefix):\(row.id)"
                    let isLiveUpdated = store.isLiveUpdated(liveUpdateID)
                    let rowServiceStatus = serviceStatus?(row)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            HStack(spacing: 6) {
                                TokenMeteringLiveUpdateDot(isActive: isLiveUpdated, marker: store.liveUpdateMarker)
                                Text(row.title)
                                    .font(.system(size: 11, weight: .semibold))
                                    .lineLimit(1)
                            }
                            Spacer()
                            if let rowServiceStatus {
                                CloudServiceStatusBadge(item: rowServiceStatus, appLanguage: settings.appLanguage)
                            }
                            Text(row.value)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                                .animation(.snappy(duration: 0.35), value: row.value)
                        }

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Color.primary.opacity(0.06))
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [tint, tint.opacity(0.65)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(8, geometry.size.width * row.ratio))
                                    .animation(.snappy(duration: 0.35), value: row.ratio)
                            }
                        }
                        .frame(height: 9)
                    }
                    .padding(.vertical, 2)
                    .modifier(TokenMeteringLiveUpdateEffect(isActive: isLiveUpdated, marker: store.liveUpdateMarker, cornerRadius: 7))
                }
            }
        }
    }

    private func compactSummaryRows<T: Collection>(
        _ rows: T,
        emptyText: String,
        idPrefix: String? = nil
    ) -> some View where T.Element == TokenUsageDashboardBarRow {
        let rowsArray = Array(rows)

        return VStack(alignment: .leading, spacing: 7) {
            if rowsArray.isEmpty {
                Text(emptyText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rowsArray) { row in
                    let liveUpdateID = idPrefix.map { "\($0):\(row.id)" }
                    let isLiveUpdated = liveUpdateID.map { store.isLiveUpdated($0) } ?? false
                    HStack(spacing: 8) {
                        HStack(spacing: 5) {
                            TokenMeteringLiveUpdateDot(isActive: isLiveUpdated, marker: store.liveUpdateMarker)
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
                    .modifier(TokenMeteringLiveUpdateEffect(isActive: isLiveUpdated, marker: store.liveUpdateMarker, cornerRadius: 7))
                }
            }
        }
    }

    private func metricPill(title: String, value: String, liveUpdateID: String? = nil) -> some View {
        let isLiveUpdated = liveUpdateID.map { store.isLiveUpdated($0) } ?? false
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Text(title.uppercased())
                    .font(.system(size: 8, weight: .black))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                TokenMeteringLiveUpdateDot(isActive: isLiveUpdated, marker: store.liveUpdateMarker)
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
        .modifier(TokenMeteringLiveUpdateEffect(isActive: isLiveUpdated, marker: store.liveUpdateMarker, cornerRadius: 8))
    }

    private func tableHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 9, weight: .black))
            .tracking(1.0)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func emptyMessage(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
            Text(detail)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 9))
    }

    private var alphaBadge: some View {
        Text(t(.previewBadge))
            .font(.system(size: 8.5, weight: .black))
            .tracking(0.9)
            .foregroundStyle(.orange)
            .padding(.horizontal, 8)
            .frame(height: 21)
            .background(Color.orange.opacity(0.11), in: Capsule(style: .continuous))
    }

    private var localOnlyBadge: some View {
        Text(t(.localOnly))
            .font(.system(size: 8.5, weight: .black))
            .tracking(0.9)
            .foregroundStyle(.green)
            .padding(.horizontal, 8)
            .frame(height: 21)
            .background(Color.green.opacity(0.11), in: Capsule(style: .continuous))
    }

    private var dashboardCardBackground: some ShapeStyle {
        .regularMaterial
    }
}

private struct TokenMeteringInfoButton: View {
    let title: String
    let detail: String

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .focusEffectDisabled()
        .accessibilityLabel(title)
        .accessibilityHint(detail)
        .help(detail)
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(width: 260, alignment: .leading)
        }
    }
}

private struct TokenMeteringLiveUpdateDot: View {
    let isActive: Bool
    let marker: TokenUsageLiveUpdateMarker
    var tint: Color = .teal

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.24))
                .scaleEffect(isPulsing ? 2.25 : 0.8)
                .opacity(isActive ? (isPulsing ? 0.0 : 0.55) : 0.0)
            Circle()
                .fill(tint)
                .scaleEffect(isActive && isPulsing ? 1.28 : 0.82)
                .opacity(isActive ? 1.0 : 0.0)
        }
        .frame(width: 7, height: 7)
        .animation(.easeOut(duration: 0.42), value: isPulsing)
        .animation(.easeOut(duration: 0.14), value: isActive)
        .onAppear {
            triggerPulse()
        }
        .onChange(of: marker.sequence) { _, _ in
            triggerPulse()
        }
    }

    private func triggerPulse() {
        guard isActive else {
            isPulsing = false
            return
        }

        isPulsing = false
        DispatchQueue.main.async {
            guard isActive else {
                return
            }
            isPulsing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                isPulsing = false
            }
        }
    }
}

private struct TokenMeteringLiveUpdateEffect: ViewModifier {
    let isActive: Bool
    let marker: TokenUsageLiveUpdateMarker
    let cornerRadius: CGFloat

    @State private var isFlashing = false

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.teal.opacity(isActive && isFlashing ? 0.05 : 0.0))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.teal.opacity(isActive && isFlashing ? 0.12 : 0.0), lineWidth: 0.8)
            }
            .animation(.easeOut(duration: 0.34), value: isFlashing)
            .animation(.easeOut(duration: 0.14), value: isActive)
            .onAppear {
                triggerFlash()
            }
            .onChange(of: marker.sequence) { _, _ in
                triggerFlash()
            }
    }

    private func triggerFlash() {
        guard isActive else {
            isFlashing = false
            return
        }

        isFlashing = false
        DispatchQueue.main.async {
            guard isActive else {
                return
            }
            isFlashing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
                isFlashing = false
            }
        }
    }
}
