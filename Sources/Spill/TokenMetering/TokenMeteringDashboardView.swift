import AppKit
import SwiftUI

private struct TokenUsageClearRequest: Identifiable {
    let id = UUID()
    let scope: TokenUsageClearScope
    let preview: TokenUsageClearPreview
}

struct TokenMeteringDashboardView: View {
    @ObservedObject var store: TokenUsageDashboardStore
    @ObservedObject private var settings: SpillSettings
    @State private var copiedTarget: String?
    @State private var isDiagnosticsExpanded = false
    @State private var hoveredFilterTitle: String? = nil
    @State private var pendingClearRequest: TokenUsageClearRequest?
    @State private var presentedWorkItemID: String?
    private let titleDidChange: () -> Void

    init(
        store: TokenUsageDashboardStore,
        settings: SpillSettings = .shared,
        titleDidChange: @escaping () -> Void = {}
    ) {
        self.store = store
        _settings = ObservedObject(wrappedValue: settings)
        self.titleDidChange = titleDidChange
    }

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(
            key,
            language: currentLanguage
        )
    }

    private var currentLanguage: TokenMeteringLanguage {
        TokenMeteringLanguage.current(appLanguage: settings.appLanguage)
    }

    var body: some View {
        VStack(spacing: 0) {
            topHeader

            Divider()
                .background(Color.primary.opacity(0.05))

            HStack(alignment: .top, spacing: 16) {
                leftRail
                    .frame(width: 224)

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        kpiStrip
                        analyticsGrid
                        sessionsTable
                    }
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }

                rightRail
                    .frame(width: 286)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(VisualEffectView(material: .windowBackground, blendingMode: .withinWindow))
        .frame(minWidth: 1060, minHeight: 640)
        .onAppear {
            titleDidChange()
            store.setLanguage(currentLanguage)
            store.refresh()
        }
        .onChange(of: settings.appLanguage) { _, _ in
            titleDidChange()
            store.setLanguage(currentLanguage)
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

            TokenMeteringInfoButton(
                title: t(.displayModeInfoTitle),
                detail: t(.displayModeInfoDetail)
            )

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
                    store.refresh()
                } label: {
                    Label(t(.refresh), systemImage: "arrow.clockwise")
                }

                Button {
                    copyToClipboard(
                        TokenMeteringGlobalSetup.prompt(
                            allowsLocalDisplayNames: settings.tokenMeteringPromptAllowsLocalDisplayNames
                        ),
                        target: "prompt"
                    )
                } label: {
                    Label(copiedTarget == "prompt" ? t(.copied) : t(.copyPrompt), systemImage: copiedTarget == "prompt" ? "checkmark" : "doc.on.doc")
                }

            }
            .buttonStyle(.bordered)
            .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var leftRail: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                railPanel(title: t(.period)) {
                    VStack(spacing: 7) {
                        ForEach(store.snapshot.periodFilters) { filter in
                            railFilterButton(
                                title: filter.title,
                                detail: filter.detail,
                                isSelected: filter.isSelected
                            ) {
                                store.setSelectedPeriod(filter.period)
                            }
                        }
                    }
                }

                recentMonthPanel

                railPanel(title: t(.aiTool)) {
                    VStack(spacing: 7) {
                        ForEach(store.snapshot.toolFilters) { filter in
                            let toolLastUpdated = lastUpdatedString(for: filter.tool)
                            railFilterButton(
                                title: filter.title,
                                detail: filter.detail,
                                lastUpdated: toolLastUpdated,
                                isSelected: filter.isSelected,
                                liveUpdateID: "filter:tool:\(filter.id)"
                            ) {
                                store.setSelectedTool(filter.tool)
                            }
                        }
                    }
                }

                railPanel(title: t(.workflowFocus)) {
                    VStack(spacing: 8) {
                        compactSummaryRows(store.snapshot.taskRows.prefix(3), emptyText: t(.noTaskSplit), idPrefix: "task")
                        Divider().opacity(0.35)
                        compactSummaryRows(store.snapshot.stageRows.prefix(3), emptyText: t(.noStageSplit), idPrefix: "stage")
                    }
                }

                railPanel(title: t(.receivers)) {
                    VStack(spacing: 8) {
                        receiverTile(title: t(.localQueue), state: t(.defaultState), systemImage: "tray.and.arrow.down", tint: .green)
                        receiverTile(title: t(.adapters), state: t(.onDemand), systemImage: "bolt.horizontal", tint: .teal)
                    }
                }

                diagnostics
            }
            .padding(.vertical, 18)
        }
    }

    private var recentMonthPanel: some View {
        railPanel(title: t(.recentMonth)) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Button {
                        store.showPreviousCalendarMonth()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.borderless)
                    .disabled(!store.snapshot.canNavigatePreviousCalendarMonth)
                    .help(t(.previousMonth))

                    Text(store.snapshot.calendarMonthTitle)
                        .font(.system(size: 10, weight: .bold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)

                    Button {
                        store.showNextCalendarMonth()
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.borderless)
                    .disabled(!store.snapshot.canNavigateNextCalendarMonth)
                    .help(t(.nextMonth))
                }

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
                            VStack(spacing: 2) {
                                Text(day.title)
                                    .font(.system(size: 8, weight: day.hasEvents ? .bold : .medium, design: .monospaced))
                                    .foregroundStyle(day.isCurrentMonth ? Color.primary : Color.secondary.opacity(0.55))
                                Capsule(style: .continuous)
                                    .fill(day.hasEvents ? Color.teal : Color.primary.opacity(0.08))
                                    .frame(height: 4)
                                    .opacity(day.hasEvents ? max(0.35, min(1.0, day.ratio)) : 1.0)
                            }
                            .frame(height: 24)
                            .help(day.detail)
                        }
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
                    }
                    Text(kpi.value)
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(kpi.id == "total" ? .teal : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.35), value: kpi.value)
                    Text(kpi.detail)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
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

    private var analyticsGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                dashboardPanel(
                    title: t(.aiToolDistribution),
                    subtitle: t(.aiToolDistributionSubtitle),
                    infoTitle: t(.aiToolInfoTitle),
                    infoDetail: t(.aiToolInfoDetail)
                ) {
                    barRows(store.snapshot.toolRows, emptyText: t(.noAIToolData), idPrefix: "tool")
                }

                dashboardPanel(
                    title: t(.workflowBreakdown),
                    subtitle: t(.workflowBreakdownSubtitle),
                    infoTitle: t(.workflowInfoTitle),
                    infoDetail: t(.workflowInfoDetail)
                ) {
                    barRows(store.snapshot.taskRows, emptyText: t(.noWorkflowData), idPrefix: "task")
                }
            }

            HStack(alignment: .top, spacing: 14) {
                dashboardPanel(
                    title: t(.stageBreakdown),
                    subtitle: t(.stageBreakdownSubtitle),
                    infoTitle: t(.stageInfoTitle),
                    infoDetail: t(.stageInfoDetail)
                ) {
                    barRows(store.snapshot.stageRows, emptyText: t(.noStageData), idPrefix: "stage")
                }

                dashboardPanel(
                    title: t(.sourceBreakdown),
                    subtitle: t(.sourceBreakdownSubtitle),
                    infoTitle: t(.sourceInfoTitle),
                    infoDetail: t(.sourceInfoDetail)
                ) {
                    barRows(store.snapshot.sourceRows, emptyText: t(.noSourceBreakdown), idPrefix: "source")
                }
            }
        }
    }

    private var rightRail: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                modelPanel
                sourcePanel
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
                        let isSelected = presentedWorkItemID == session.id
                        let liveUpdateID = "session:\(session.id)"
                        let isLiveUpdated = store.isLiveUpdated(liveUpdateID)
                        Button {
                            store.clearWorkItemSelection()
                            presentedWorkItemID = session.id
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
                                isSelected ? Color.teal : Color.primary.opacity(0.025),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(isSelected ? Color.teal.opacity(0.35) : Color.primary.opacity(0.04), lineWidth: 0.5)
                            }
                            .modifier(TokenMeteringLiveUpdateEffect(isActive: isLiveUpdated && !isSelected, marker: store.liveUpdateMarker, cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 6)
                        .popover(
                            isPresented: Binding(
                                get: {
                                    presentedWorkItemID == session.id
                                },
                                set: { isPresented in
                                    if !isPresented, presentedWorkItemID == session.id {
                                        presentedWorkItemID = nil
                                    }
                                }
                            ),
                            arrowEdge: .trailing
                        ) {
                            workItemPopover(session)
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                requestClear(.workItem(session.id))
                                if presentedWorkItemID == session.id {
                                    presentedWorkItemID = nil
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

    private func workItemPopover(_ session: TokenUsageDashboardSessionRow) -> some View {
        let detailSnapshot = store.snapshotForWorkItem(session.id)
        let detailSession = detailSnapshot.selectedSession ?? session
        let kpisByID = Dictionary(uniqueKeysWithValues: detailSnapshot.kpis.map { ($0.id, $0) })

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t(.selectedRun).uppercased())
                            .font(.system(size: 9, weight: .black))
                            .tracking(1.0)
                            .foregroundStyle(.secondary)
                        Text(detailSession.title)
                            .font(.system(size: 13, weight: .bold))
                            .lineLimit(2)
                        Text(detailSession.detail)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Button {
                        presentedWorkItemID = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
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
                workItemPopoverSection(
                    title: t(.sourceBreakdown),
                    rows: detailSnapshot.sourceRows.prefix(4),
                    emptyText: t(.noSourceBreakdown),
                    idPrefix: "source"
                )

            }
            .padding(14)
        }
        .frame(width: 380, alignment: .leading)
        .frame(maxHeight: 560, alignment: .topLeading)
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

    private var diagnostics: some View {
        DisclosureGroup(isExpanded: $isDiagnosticsExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                Text(t(.diagnosticsDetail))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Task {
                        await store.runLocalQueueSelfTest()
                    }
                } label: {
                    Label(store.isRunningSelfTest ? t(.writing) : t(.queueTest), systemImage: store.isRunningSelfTest ? "hourglass" : "tray.and.arrow.down")
                }
                .disabled(store.isRunningSelfTest)

                if let selfTestMessage = store.selfTestMessage {
                    Text(selfTestMessage.text)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(selfTestMessage.isSuccess ? .green : .red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let lastError = store.lastError {
                    Text(lastError)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 8)
        } label: {
            Label(t(.diagnostics), systemImage: "stethoscope")
                .font(.system(size: 11, weight: .semibold))
        }
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

    private func railFilterButton(
        title: String,
        detail: String,
        lastUpdated: String? = nil,
        isSelected: Bool,
        liveUpdateID: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        let isHovered = hoveredFilterTitle == title
        let isLiveUpdated = liveUpdateID.map { store.isLiveUpdated($0) } ?? false
        return Button(action: action) {
            HStack(spacing: 9) {
                Circle()
                    .fill(isSelected ? .white : (isHovered ? Color.teal : Color.primary.opacity(0.12)))
                    .frame(width: 6, height: 6)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                        .lineLimit(1)
                    Text(detail)
                        .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.35), value: detail)
                    if let lastUpdated {
                        Text(lastUpdated)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(isSelected ? .white.opacity(0.6) : .secondary.opacity(0.8))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
                TokenMeteringLiveUpdateDot(
                    isActive: isLiveUpdated,
                    marker: store.liveUpdateMarker,
                    tint: isSelected ? .white : .teal
                )
            }
            .padding(.horizontal, 10)
            .frame(height: lastUpdated != nil ? 44 : 38)
            .foregroundStyle(isSelected ? .white : .primary)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.teal, Color.teal.opacity(0.82)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.teal.opacity(0.25), radius: 4, x: 0, y: 1.5)
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isHovered ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03))
                }
            }
            .modifier(TokenMeteringLiveUpdateEffect(isActive: isLiveUpdated && !isSelected, marker: store.liveUpdateMarker, cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                hoveredFilterTitle = hovering ? title : nil
            }
        }
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

    private func barRows(_ rows: [TokenUsageDashboardBarRow], emptyText: String, idPrefix: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if rows.isEmpty {
                emptyMessage(title: emptyText, detail: t(.waitingForEvents))
            } else {
                ForEach(rows.prefix(6)) { row in
                    let liveUpdateID = "\(idPrefix):\(row.id)"
                    let isLiveUpdated = store.isLiveUpdated(liveUpdateID)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            HStack(spacing: 6) {
                                TokenMeteringLiveUpdateDot(isActive: isLiveUpdated, marker: store.liveUpdateMarker)
                                Text(row.title)
                                    .font(.system(size: 11, weight: .semibold))
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(row.value)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                                .animation(.snappy(duration: 0.35), value: row.value)
                        }

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule(style: .continuous)
                                    .fill(Color.primary.opacity(0.07))
                                Capsule(style: .continuous)
                                    .fill(Color.teal)
                                    .frame(width: max(6, geometry.size.width * row.ratio))
                                    .animation(.snappy(duration: 0.35), value: row.ratio)
                            }
                        }
                        .frame(height: 7)
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
        Text("ALPHA")
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

    private func copyToClipboard(_ text: String, target: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedTarget = target

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            if copiedTarget == target {
                copiedTarget = nil
            }
        }
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
                    .fill(Color.teal.opacity(isActive && isFlashing ? 0.10 : 0.0))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.teal.opacity(isActive && isFlashing ? 0.34 : 0.0), lineWidth: 0.8)
            }
            .scaleEffect(isActive && isFlashing ? 1.006 : 1.0)
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
