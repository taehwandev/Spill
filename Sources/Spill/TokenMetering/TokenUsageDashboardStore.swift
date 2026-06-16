@preconcurrency import Foundation

struct TokenUsageClearPreview: Equatable {
    let scopeTitle: String
    let eventCount: Int
    let totalTokens: Int

    var hasEvents: Bool {
        eventCount > 0
    }
}

enum TokenUsageDashboardLoadState: Equatable {
    case idle
    case loading
    case loaded
    case previewingEmpty
}

private enum TokenUsageDashboardPreviewDataSource {
    static let onboardingEvents: [TokenUsageEvent] = []
}

enum TokenUsageClearScope: Equatable, Identifiable {
    case all
    case currentScope
    case tool(TokenUsageAITool)
    case period(TokenUsageDashboardPeriod)
    case workItem(String)

    var id: String {
        switch self {
        case .all:
            return "all"
        case .currentScope:
            return "current_scope"
        case let .tool(tool):
            return "tool_\(tool.rawValue)"
        case let .period(period):
            return "period_\(period.rawValue)"
        case let .workItem(id):
            return "work_item_\(id)"
        }
    }
}

@MainActor
final class TokenUsageDashboardStore: ObservableObject {
    @Published private(set) var snapshot = TokenUsageDashboardSnapshot.empty
    @Published private(set) var unfilteredSnapshot = TokenUsageDashboardSnapshot.empty
    @Published private(set) var panelSummary = TokenUsagePanelSummarySnapshot.empty
    @Published private(set) var liveUpdateMarker = TokenUsageLiveUpdateMarker.empty
    @Published private(set) var loadState: TokenUsageDashboardLoadState = .idle
    @Published private(set) var isOnboardingPreviewEnabled = false
    @Published private(set) var selectedTool: TokenUsageAITool?
    @Published private(set) var selectedPeriod: TokenUsageDashboardPeriod = .today
    @Published private(set) var selectedCalendarDayID: String?
    @Published private(set) var selectedProjectID: String?
    @Published private(set) var selectedSessionID: String?
    @Published private(set) var calendarMonthStart: Date?
    @Published private(set) var displayMode: TokenUsageDisplayMode = .tokens
    @Published private(set) var language: TokenMeteringLanguage = .current()
    @Published private(set) var lastError: String?
    @Published private(set) var isRunningSelfTest = false
    @Published private(set) var selfTestMessage: TokenUsageSelfTestMessage?

    private let usageStore: TokenUsageStore
    private var events: [TokenUsageEvent] = []
    private var eventsDidChangeObserver: NSObjectProtocol?
    private var distributedEventsDidChangeObserver: NSObjectProtocol?
    private var collectionDidFinishObserver: NSObjectProtocol?
    private var hasRebuiltSnapshot = false
    private var clearLiveUpdateTask: Task<Void, Never>?
    private var scheduledRefreshTask: Task<Void, Never>?
    private var asyncRefreshGeneration = 0

    init(
        usageStore: TokenUsageStore,
        collectionCoordinator: AnyObject? = nil
    ) {
        self.usageStore = usageStore
        eventsDidChangeObserver = NotificationCenter.default.addObserver(
            forName: TokenUsageStore.eventsDidChangeNotification,
            object: usageStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleRefresh()
            }
        }
        distributedEventsDidChangeObserver = DistributedNotificationCenter.default().addObserver(
            forName: TokenUsageStore.distributedEventsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleRefresh()
            }
        }
        collectionDidFinishObserver = NotificationCenter.default.addObserver(
            forName: TokenUsageCollectorCoordinator.collectionDidFinishNotification,
            object: collectionCoordinator,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleRefresh()
            }
        }
        refreshPanelSummary()
    }

    var hasDashboardEvents: Bool {
        let showAdvancedTools = SpillSettings.shared.tokenUsageShowAdvancedTools
        return displayEvents(for: events).contains { event in
            showAdvancedTools || event.aiTool.isDashboardTool
        }
    }

    deinit {
        if let eventsDidChangeObserver {
            NotificationCenter.default.removeObserver(eventsDidChangeObserver)
        }
        if let distributedEventsDidChangeObserver {
            DistributedNotificationCenter.default().removeObserver(distributedEventsDidChangeObserver)
        }
        if let collectionDidFinishObserver {
            NotificationCenter.default.removeObserver(collectionDidFinishObserver)
        }
        clearLiveUpdateTask?.cancel()
        scheduledRefreshTask?.cancel()
    }

    func refresh(trackLiveUpdates: Bool = true) {
        scheduledRefreshTask?.cancel()
        scheduledRefreshTask = nil
        asyncRefreshGeneration += 1
        let previousEvents = events
        let shouldTrackLiveUpdates = trackLiveUpdates && (
            hasRebuiltSnapshot || (previousEvents.isEmpty && panelSummary.eventCount == 0)
        )
        events = usageStore.loadEvents()
        rebuildSnapshot(
            trackLiveUpdates: shouldTrackLiveUpdates,
            previousEvents: previousEvents
        )
    }

    func refreshAsync(trackLiveUpdates: Bool = true) {
        scheduledRefreshTask?.cancel()
        scheduledRefreshTask = nil
        asyncRefreshGeneration += 1
        let generation = asyncRefreshGeneration
        let previousEvents = events
        let previousSnapshot = snapshot
        let previousUnfilteredSnapshot = unfilteredSnapshot
        let shouldTrackLiveUpdates = trackLiveUpdates && !isOnboardingPreviewEnabled && (
            hasRebuiltSnapshot || (previousEvents.isEmpty && panelSummary.eventCount == 0)
        )
        let request = snapshotBuildRequest()
        let usesPreviewDataSource = isOnboardingPreviewEnabled
        let usageStore = usageStore
        loadState = usesPreviewDataSource ? .previewingEmpty : .loading

        DispatchQueue.global(qos: .userInitiated).async {
            let loadedEvents = usageStore.loadEvents()
            let displayEvents = usesPreviewDataSource ? TokenUsageDashboardPreviewDataSource.onboardingEvents : loadedEvents
            let snapshotPair = Self.buildSnapshotPair(events: displayEvents, request: request)

            DispatchQueue.main.async { [weak self] in
                guard let self, self.asyncRefreshGeneration == generation else {
                    return
                }

                self.applySnapshotPair(
                    snapshotPair,
                    loadedEvents: loadedEvents,
                    trackLiveUpdates: shouldTrackLiveUpdates,
                    previousEvents: previousEvents,
                    previousSnapshot: previousSnapshot,
                    previousUnfilteredSnapshot: previousUnfilteredSnapshot
                )
            }
        }
    }

    func refreshPanelSummary() {
        scheduledRefreshTask?.cancel()
        scheduledRefreshTask = nil
        let summary = usageStore.dashboardSummary(
            dashboardToolsOnly: !SpillSettings.shared.tokenUsageShowAdvancedTools
        )
        panelSummary = TokenUsagePanelSummarySnapshot(
            summary: summary,
            displayMode: displayMode,
            language: language
        )
        lastError = nil
    }

    private func scheduleRefresh(trackLiveUpdates: Bool = true) {
        scheduledRefreshTask?.cancel()
        scheduledRefreshTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: 250_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else {
                return
            }
            self?.refreshAsync(trackLiveUpdates: trackLiveUpdates)
        }
    }

    func rebuildSnapshot(
        trackLiveUpdates: Bool = false,
        previousEvents: [TokenUsageEvent]? = nil
    ) {
        asyncRefreshGeneration += 1
        let previousSnapshot = snapshot
        let previousUnfilteredSnapshot = unfilteredSnapshot
        let displayEvents = displayEvents(for: events)
        let snapshotPair = Self.buildSnapshotPair(
            events: displayEvents,
            request: snapshotBuildRequest()
        )
        applySnapshotPair(
            snapshotPair,
            loadedEvents: events,
            trackLiveUpdates: trackLiveUpdates && !isOnboardingPreviewEnabled,
            previousEvents: previousEvents,
            previousSnapshot: previousSnapshot,
            previousUnfilteredSnapshot: previousUnfilteredSnapshot
        )
    }

    private func applySnapshotPair(
        _ snapshotPair: TokenUsageDashboardSnapshotPair,
        loadedEvents: [TokenUsageEvent],
        trackLiveUpdates: Bool,
        previousEvents: [TokenUsageEvent]?,
        previousSnapshot: TokenUsageDashboardSnapshot,
        previousUnfilteredSnapshot: TokenUsageDashboardSnapshot
    ) {
        events = loadedEvents
        calendarMonthStart = snapshotPair.calendarMonthStart
        let filteredSnapshot = snapshotPair.filtered
        selectedProjectID = filteredSnapshot.selectedProjectID
        selectedSessionID = filteredSnapshot.selectedSession?.id
        snapshot = filteredSnapshot
        unfilteredSnapshot = snapshotPair.unfiltered
        panelSummary = TokenUsagePanelSummarySnapshot(snapshot: unfilteredSnapshot)
        lastError = nil
        loadState = isOnboardingPreviewEnabled ? .previewingEmpty : .loaded
        if trackLiveUpdates, let previousEvents {
            publishLiveUpdates(
                previousEvents: previousEvents,
                nextEvents: events,
                previousSnapshot: previousSnapshot,
                nextSnapshot: filteredSnapshot,
                previousUnfilteredSnapshot: previousUnfilteredSnapshot,
                nextUnfilteredSnapshot: unfilteredSnapshot
            )
        }
        hasRebuiltSnapshot = true
    }

    private func displayEvents(for loadedEvents: [TokenUsageEvent]) -> [TokenUsageEvent] {
        isOnboardingPreviewEnabled ? TokenUsageDashboardPreviewDataSource.onboardingEvents : loadedEvents
    }

    private func snapshotBuildRequest() -> TokenUsageDashboardBuildRequest {
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 1
        return TokenUsageDashboardBuildRequest(
            selectedTool: selectedTool,
            selectedPeriod: selectedPeriod,
            selectedCalendarDayID: selectedCalendarDayID,
            selectedProjectID: selectedProjectID,
            selectedSessionID: selectedSessionID,
            displayMode: displayMode,
            language: language,
            localAliases: SpillSettings.shared.tokenUsageLocalAliases,
            showAdvancedTools: SpillSettings.shared.tokenUsageShowAdvancedTools,
            now: Date(),
            proposedCalendarMonthStart: calendarMonthStart,
            calendar: calendar
        )
    }

    nonisolated private static func buildSnapshotPair(
        events: [TokenUsageEvent],
        request: TokenUsageDashboardBuildRequest
    ) -> TokenUsageDashboardSnapshotPair {
        TokenUsageDashboardSnapshot.buildPair(
            events: events,
            selectedTool: request.selectedTool,
            selectedPeriod: request.selectedPeriod,
            selectedCalendarDayID: request.selectedCalendarDayID,
            selectedProjectID: request.selectedProjectID,
            selectedSessionID: request.selectedSessionID,
            displayMode: request.displayMode,
            language: request.language,
            localAliases: request.localAliases,
            showAdvancedTools: request.showAdvancedTools,
            now: request.now,
            proposedCalendarMonthStart: request.proposedCalendarMonthStart,
            calendar: request.calendar
        )
    }

    func setOnboardingPreviewEnabled(_ enabled: Bool) {
        guard isOnboardingPreviewEnabled != enabled else {
            return
        }

        isOnboardingPreviewEnabled = enabled
        selectedSessionID = nil
        liveUpdateMarker = .empty
        if enabled {
            rebuildSnapshot(trackLiveUpdates: false)
        } else {
            refreshAsync(trackLiveUpdates: false)
        }
    }

    func setSelectedTool(_ tool: TokenUsageAITool?) {
        selectedTool = tool?.isDashboardTool == true ? tool : nil
        rebuildSnapshot()
    }

    func setSelectedProjectID(_ projectID: String?) {
        selectedProjectID = projectID
        selectedSessionID = nil
        rebuildSnapshot()
    }

    func setSelectedPeriod(_ period: TokenUsageDashboardPeriod) {
        selectedPeriod = period
        selectedCalendarDayID = nil
        selectedSessionID = nil
        rebuildSnapshot()
    }

    func selectCalendarDay(_ dayID: String) {
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 1
        guard TokenUsageDashboardSnapshot.date(forDayID: dayID, calendar: calendar) != nil else {
            return
        }

        selectedCalendarDayID = dayID
        selectedSessionID = nil
        if let date = TokenUsageDashboardSnapshot.date(forDayID: dayID, calendar: calendar) {
            calendarMonthStart = TokenUsageDashboardSnapshot.monthStart(for: date, calendar: calendar)
        }
        rebuildSnapshot()
    }

    func selectTodayCalendarDay() {
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 1
        let now = Date()
        selectedCalendarDayID = TokenUsageDashboardSnapshot.dayID(for: now, calendar: calendar)
        selectedSessionID = nil
        calendarMonthStart = TokenUsageDashboardSnapshot.monthStart(for: now, calendar: calendar)
        rebuildSnapshot()
    }

    func clearSelectedCalendarDay() {
        selectedCalendarDayID = nil
        selectedSessionID = nil
        rebuildSnapshot()
    }

    func selectSession(_ sessionID: String) {
        selectedSessionID = sessionID
        rebuildSnapshot()
    }

    func clearWorkItemSelection() {
        selectedSessionID = nil
        rebuildSnapshot()
    }

    func updateAlias(for workItemID: String, alias: String) {
        var updated = SpillSettings.shared.tokenUsageLocalAliases
        let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            updated.removeValue(forKey: workItemID)
        } else {
            updated[workItemID] = trimmed
        }
        SpillSettings.shared.tokenUsageLocalAliases = updated
        rebuildSnapshot()
    }

    func setAdvancedToolsEnabled(_ enabled: Bool) {
        SpillSettings.shared.tokenUsageShowAdvancedTools = enabled
        if hasRebuiltSnapshot {
            rebuildSnapshot()
        } else {
            refreshPanelSummary()
        }
    }

    func snapshotForWorkItem(_ sessionID: String) -> TokenUsageDashboardSnapshot {
        let now = Date()
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 1
        let displayCalendarMonth = TokenUsageDashboardSnapshot.normalizedCalendarMonthStart(
            events: events.filter { $0.aiTool.isDashboardTool },
            now: now,
            proposedMonthStart: calendarMonthStart,
            calendar: calendar
        )
        return TokenUsageDashboardSnapshot(
            events: events,
            selectedTool: selectedTool,
            selectedPeriod: selectedPeriod,
            selectedCalendarDayID: selectedCalendarDayID,
            selectedProjectID: selectedProjectID,
            selectedSessionID: sessionID,
            displayMode: displayMode,
            language: language,
            localAliases: SpillSettings.shared.tokenUsageLocalAliases,
            showAdvancedTools: SpillSettings.shared.tokenUsageShowAdvancedTools,
            now: now,
            calendarMonthStart: displayCalendarMonth,
            calendar: calendar
        )
    }

    func showPreviousCalendarMonth() {
        moveCalendarMonth(by: -1)
    }

    func showNextCalendarMonth() {
        moveCalendarMonth(by: 1)
    }

    func setDisplayMode(_ mode: TokenUsageDisplayMode) {
        displayMode = mode
        if hasRebuiltSnapshot {
            rebuildSnapshot()
        } else {
            refreshPanelSummary()
        }
    }

    func setLanguage(_ language: TokenMeteringLanguage) {
        guard self.language != language else {
            return
        }
        self.language = language
        if hasRebuiltSnapshot {
            rebuildSnapshot()
        } else {
            refreshPanelSummary()
        }
    }

    func clearLocalEvents() {
        do {
            try usageStore.clearEvents()
            selfTestMessage = nil
            liveUpdateMarker = .empty
            isOnboardingPreviewEnabled = false
            refresh(trackLiveUpdates: false)
        } catch {
            lastError = TokenMeteringL10n.text(.clearFailed, language: language)
        }
    }

    func clearPreview(for scope: TokenUsageClearScope) -> TokenUsageClearPreview {
        let matchingEvents = events(matching: scope)
        let totalTokens = matchingEvents.reduce(0) { $0 + $1.totalTokens }
        return TokenUsageClearPreview(
            scopeTitle: scopeTitle(for: scope),
            eventCount: matchingEvents.count,
            totalTokens: totalTokens
        )
    }

    func clearEvents(in scope: TokenUsageClearScope) {
        do {
            if scope == .all {
                try usageStore.clearEvents()
            } else {
                let matchingSpanIDs = Set(events(matching: scope).map(\.spanID))
                let remainingEvents = events.filter { !matchingSpanIDs.contains($0.spanID) }
                try usageStore.replaceEvents(remainingEvents)
            }
            selfTestMessage = nil
            liveUpdateMarker = .empty
            isOnboardingPreviewEnabled = false
            if selectedSessionID != nil,
               snapshot.selectedSession == nil || scope.id.contains(selectedSessionID ?? "") {
                selectedSessionID = nil
            }
            refresh(trackLiveUpdates: false)
        } catch {
            lastError = TokenMeteringL10n.text(.clearFailed, language: language)
        }
    }

    private func events(matching scope: TokenUsageClearScope) -> [TokenUsageEvent] {
        let now = Date()
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 1
        let dashboardEvents = events.filter { $0.aiTool.isDashboardTool }

        switch scope {
        case .all:
            return events
        case .currentScope:
            let periodEvents = TokenUsageDashboardSnapshot.filterEvents(
                dashboardEvents,
                selectedPeriod: selectedPeriod,
                selectedCalendarDayID: selectedCalendarDayID,
                now: now,
                calendar: calendar
            )
            let visibleEvents = selectedTool.map { tool in
                periodEvents.filter { $0.aiTool == tool }
            } ?? periodEvents
            let projectEvents = selectedProjectID.map { projectID in
                visibleEvents.filter { $0.projectID == projectID }
            } ?? visibleEvents
            guard let selectedSessionID else {
                return projectEvents
            }
            return projectEvents.filter {
                TokenUsageDashboardSnapshot.workItemID(for: $0, calendar: calendar) == selectedSessionID
            }
        case let .tool(tool):
            return dashboardEvents.filter { $0.aiTool == tool }
        case let .period(period):
            return TokenUsageDashboardSnapshot.filterEvents(
                dashboardEvents,
                selectedPeriod: period,
                now: now,
                calendar: calendar
            )
        case let .workItem(id):
            return dashboardEvents.filter {
                TokenUsageDashboardSnapshot.workItemID(for: $0, calendar: calendar) == id
            }
        }
    }

    private func scopeTitle(for scope: TokenUsageClearScope) -> String {
        switch scope {
        case .all:
            return TokenMeteringL10n.text(.allLocalData, language: language)
        case .currentScope:
            if let selectedSessionID,
               let selectedSession = snapshot.sessions.first(where: { $0.id == selectedSessionID }) {
                return selectedSession.title
            }
            if let selectedCalendarDayTitle = snapshot.selectedCalendarDayTitle {
                return selectedCalendarDayTitle
            }
            return TokenMeteringL10n.text(.currentDashboardScope, language: language)
        case let .tool(tool):
            return tool.dashboardLabel(language: language)
        case let .period(period):
            return period.title(language: language)
        case let .workItem(id):
            return snapshot.sessions.first { $0.id == id }?.title
                ?? TokenMeteringL10n.text(.selectedWorkItem, language: language)
        }
    }

    private func moveCalendarMonth(by value: Int) {
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 1
        let now = Date()
        let currentMonth = calendarMonthStart
            ?? TokenUsageDashboardSnapshot.monthStart(for: now, calendar: calendar)
        let proposedMonth = calendar.date(byAdding: .month, value: value, to: currentMonth)
            ?? currentMonth
        calendarMonthStart = TokenUsageDashboardSnapshot.normalizedCalendarMonthStart(
            events: events.filter { $0.aiTool.isDashboardTool },
            now: now,
            proposedMonthStart: proposedMonth,
            calendar: calendar
        )
        rebuildSnapshot()
    }

    func runLocalQueueSelfTest() async {
        guard !isRunningSelfTest else {
            return
        }

        isRunningSelfTest = true
        lastError = nil
        selfTestMessage = nil

        do {
            let event = Self.makeLocalSelfTestEvent(index: snapshot.eventCount)
            try usageStore.enqueueInboxEvent(event)
            usageStore.importQueuedEvents()
            refresh()
            selfTestMessage = TokenUsageSelfTestMessage(
                text: TokenMeteringL10n.text(.queueSelfTestSuccess, language: language),
                isSuccess: true
            )
        } catch {
            lastError = TokenMeteringL10n.text(.queueSelfTestFailed, language: language)
            selfTestMessage = TokenUsageSelfTestMessage(
                text: TokenMeteringL10n.text(.queueSelfTestWriteFailed, language: language),
                isSuccess: false
            )
        }

        isRunningSelfTest = false
    }

    private static func makeLocalSelfTestEvent(index: Int) -> TokenUsageEvent {
        let date = Date()
        let timestamp = ISO8601DateFormatter.tokenUsage.string(from: date)
        let compactTimestamp = timestamp
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "Z", with: "")

        return TokenUsageEvent(
            schemaVersion: 1,
            deviceID: "device_local",
            projectID: "project_global",
            artifactID: "artifact_selftest",
            runID: "run_selftest_\(compactTimestamp)",
            spanID: "span_selftest_\(index + 1)_\(compactTimestamp)",
            aiTool: .codex,
            taskType: .debugging,
            stage: .verify,
            model: "spill-self-test",
            inputTokens: 48,
            outputTokens: 16,
            totalTokens: 64,
            tokenBreakdown: TokenUsageBreakdown(
                system: 4,
                user: 8,
                history: 6,
                repoContext: 18,
                toolOutput: 12,
                generatedOutput: 16,
                unknown: 0
            ),
            latencyMS: 1,
            createdAt: timestamp
        )
    }

    func addLocalTestEvent() {
        do {
            try usageStore.appendEvent(Self.makeLocalTestEvent(index: snapshot.eventCount))
            isOnboardingPreviewEnabled = false
            refresh()
        } catch {
            lastError = TokenMeteringL10n.text(.saveTestFailed, language: language)
        }
    }

    func isLiveUpdated(_ id: String) -> Bool {
        liveUpdateMarker.contains(id)
    }

    private func publishLiveUpdates(
        previousEvents: [TokenUsageEvent],
        nextEvents: [TokenUsageEvent],
        previousSnapshot: TokenUsageDashboardSnapshot,
        nextSnapshot: TokenUsageDashboardSnapshot,
        previousUnfilteredSnapshot: TokenUsageDashboardSnapshot,
        nextUnfilteredSnapshot: TokenUsageDashboardSnapshot
    ) {
        let ids = Self.liveUpdateIDs(
            previousEvents: previousEvents,
            nextEvents: nextEvents,
            previousSnapshot: previousSnapshot,
            nextSnapshot: nextSnapshot,
            previousUnfilteredSnapshot: previousUnfilteredSnapshot,
            nextUnfilteredSnapshot: nextUnfilteredSnapshot,
            selectedTool: selectedTool,
            selectedPeriod: selectedPeriod,
            selectedCalendarDayID: selectedCalendarDayID,
            selectedProjectID: selectedProjectID
        )
        guard !ids.isEmpty else {
            return
        }

        clearLiveUpdateTask?.cancel()
        let nextSequence = liveUpdateMarker.sequence + 1
        liveUpdateMarker = TokenUsageLiveUpdateMarker(ids: ids, sequence: nextSequence)
        clearLiveUpdateTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            await MainActor.run { [weak self] in
                guard let self, self.liveUpdateMarker.sequence == nextSequence else {
                    return
                }
                self.liveUpdateMarker = .empty
            }
        }
    }

    private static func liveUpdateIDs(
        previousEvents: [TokenUsageEvent],
        nextEvents: [TokenUsageEvent],
        previousSnapshot: TokenUsageDashboardSnapshot,
        nextSnapshot: TokenUsageDashboardSnapshot,
        previousUnfilteredSnapshot: TokenUsageDashboardSnapshot,
        nextUnfilteredSnapshot: TokenUsageDashboardSnapshot,
        selectedTool: TokenUsageAITool?,
        selectedPeriod: TokenUsageDashboardPeriod,
        selectedCalendarDayID: String?,
        selectedProjectID: String?
    ) -> Set<String> {
        let previousPeriodEvents = dashboardEvents(
            previousEvents,
            selectedTool: nil,
            selectedPeriod: selectedPeriod,
            selectedCalendarDayID: selectedCalendarDayID
        )
        let nextPeriodEvents = dashboardEvents(
            nextEvents,
            selectedTool: nil,
            selectedPeriod: selectedPeriod,
            selectedCalendarDayID: selectedCalendarDayID
        )
        let previousVisibleEvents = selectedTool.map { tool in
            previousPeriodEvents.filter { $0.aiTool == tool }
        } ?? previousPeriodEvents
        let nextVisibleEvents = selectedTool.map { tool in
            nextPeriodEvents.filter { $0.aiTool == tool }
        } ?? nextPeriodEvents
        let previousProjectEvents = selectedProjectID.map { projectID in
            previousVisibleEvents.filter { $0.projectID == projectID }
        } ?? previousVisibleEvents
        let nextProjectEvents = selectedProjectID.map { projectID in
            nextVisibleEvents.filter { $0.projectID == projectID }
        } ?? nextVisibleEvents

        var ids = Set<String>()

        appendChangedTotals(
            to: &ids,
            previous: tokenTotals(previousPeriodEvents, by: { $0.aiTool.rawValue }),
            next: tokenTotals(nextPeriodEvents, by: { $0.aiTool.rawValue }),
            prefixes: ["tool", "filter:tool"]
        )
        if previousPeriodEvents.reduce(0, { $0 + $1.totalTokens }) != nextPeriodEvents.reduce(0, { $0 + $1.totalTokens }) {
            ids.insert("filter:tool:all")
        }

        appendChangedTotals(
            to: &ids,
            previous: tokenTotals(previousProjectEvents, by: { $0.taskType.rawValue }),
            next: tokenTotals(nextProjectEvents, by: { $0.taskType.rawValue }),
            prefixes: ["task"]
        )
        appendChangedTotals(
            to: &ids,
            previous: tokenTotals(previousProjectEvents, by: { $0.stage.rawValue }),
            next: tokenTotals(nextProjectEvents, by: { $0.stage.rawValue }),
            prefixes: ["stage"]
        )
        appendChangedTotals(
            to: &ids,
            previous: tokenTotals(previousProjectEvents, by: { modelKey($0.model) }),
            next: tokenTotals(nextProjectEvents, by: { modelKey($0.model) }),
            prefixes: ["model"]
        )
        appendChangedTotals(
            to: &ids,
            previous: sourceTotals(previousProjectEvents),
            next: sourceTotals(nextProjectEvents),
            prefixes: ["source"]
        )

        appendChangedRows(to: &ids, previous: previousSnapshot.kpis, next: nextSnapshot.kpis, prefix: "kpi")
        appendChangedRows(to: &ids, previous: previousSnapshot.toolRows, next: nextSnapshot.toolRows, prefix: "tool")
        appendChangedRows(to: &ids, previous: previousSnapshot.modelRows, next: nextSnapshot.modelRows, prefix: "model")
        appendChangedRows(to: &ids, previous: previousSnapshot.workflowUsage.rows, next: nextSnapshot.workflowUsage.rows, prefix: "workflow_usage")
        appendChangedRows(to: &ids, previous: previousSnapshot.taskRows, next: nextSnapshot.taskRows, prefix: "task")
        appendChangedRows(to: &ids, previous: previousSnapshot.stageRows, next: nextSnapshot.stageRows, prefix: "stage")
        appendChangedRows(to: &ids, previous: previousSnapshot.sourceRows, next: nextSnapshot.sourceRows, prefix: "source")
        appendChangedRows(to: &ids, previous: previousSnapshot.sessions, next: nextSnapshot.sessions, prefix: "session")
        appendChangedRows(to: &ids, previous: previousUnfilteredSnapshot.toolRows, next: nextUnfilteredSnapshot.toolRows, prefix: "tool")

        return ids
    }

    private static func appendChangedRows(
        to ids: inout Set<String>,
        previous: [TokenUsageDashboardKPI],
        next: [TokenUsageDashboardKPI],
        prefix: String
    ) {
        let previousByID = Dictionary(uniqueKeysWithValues: previous.map { ($0.id, $0) })
        for row in next where previousByID[row.id] != row {
            ids.insert("\(prefix):\(row.id)")
        }
    }

    private static func appendChangedRows(
        to ids: inout Set<String>,
        previous: [TokenUsageDashboardBarRow],
        next: [TokenUsageDashboardBarRow],
        prefix: String
    ) {
        let previousByID = Dictionary(uniqueKeysWithValues: previous.map { ($0.id, $0) })
        for row in next where previousByID[row.id] != row {
            ids.insert("\(prefix):\(row.id)")
        }
    }

    private static func appendChangedRows(
        to ids: inout Set<String>,
        previous: [TokenUsageDashboardSessionRow],
        next: [TokenUsageDashboardSessionRow],
        prefix: String
    ) {
        let previousByID = Dictionary(uniqueKeysWithValues: previous.map { ($0.id, $0) })
        for row in next where previousByID[row.id] != row {
            ids.insert("\(prefix):\(row.id)")
        }
    }

    private static func appendChangedTotals(
        to ids: inout Set<String>,
        previous: [String: Int],
        next: [String: Int],
        prefixes: [String]
    ) {
        for key in Set(previous.keys).union(next.keys) {
            let previousValue = previous[key, default: 0]
            let nextValue = next[key, default: 0]
            guard nextValue > 0, previousValue != nextValue else {
                continue
            }
            for prefix in prefixes {
                ids.insert("\(prefix):\(key)")
            }
        }
    }

    private static func dashboardEvents(
        _ events: [TokenUsageEvent],
        selectedTool: TokenUsageAITool?,
        selectedPeriod: TokenUsageDashboardPeriod,
        selectedCalendarDayID: String?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [TokenUsageEvent] {
        let filteredEvents = events.filter { event in
            guard event.aiTool.isDashboardTool else {
                return false
            }
            return selectedTool.map { event.aiTool == $0 } ?? true
        }
        return TokenUsageDashboardSnapshot.filterEvents(
            filteredEvents,
            selectedPeriod: selectedPeriod,
            selectedCalendarDayID: selectedCalendarDayID,
            now: now,
            calendar: calendar
        )
    }

    private static func tokenTotals(
        _ events: [TokenUsageEvent],
        by key: (TokenUsageEvent) -> String
    ) -> [String: Int] {
        Dictionary(grouping: events, by: key)
            .mapValues { groupedEvents in
                groupedEvents.reduce(0) { $0 + $1.totalTokens }
            }
    }

    private static func sourceTotals(_ events: [TokenUsageEvent]) -> [String: Int] {
        var totals: [String: Int] = [:]
        for event in events {
            totals["system", default: 0] += event.tokenBreakdown.system
            totals["user", default: 0] += event.tokenBreakdown.user
            totals["history", default: 0] += event.tokenBreakdown.history
            totals["repo_context", default: 0] += event.tokenBreakdown.repoContext
            totals["tool_output", default: 0] += event.tokenBreakdown.toolOutput
            totals["generated_output", default: 0] += event.tokenBreakdown.generatedOutput
            totals["unknown", default: 0] += event.tokenBreakdown.unknown
        }
        return totals
    }

    private static func modelKey(_ model: String) -> String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()
        if trimmed.isEmpty || lowered == "unknown" || lowered == "unknown_model" || lowered == "model_unknown" || lowered == "unavailable" {
            return "model_unavailable"
        }
        return trimmed
    }

    private static func makeLocalTestEvent(index: Int) -> TokenUsageEvent {
        let taskTypes: [TokenUsageTaskType] = [
            .analysis,
            .prdDrafting,
            .codeGeneration,
            .codeReview,
            .testGeneration
        ]
        let tools = TokenUsageAITool.dashboardTools
        let taskType = taskTypes[index % taskTypes.count]
        let aiTool = tools[index % tools.count]
        let inputTokens = 1_000 + index * 90
        let outputTokens = 500 + index * 45
        let totalTokens = inputTokens + outputTokens
        let generatedOutput = outputTokens
        let repoContext = max(0, inputTokens / 3)
        let toolOutput = max(0, inputTokens / 6)
        let history = max(0, inputTokens / 5)
        let system = max(0, inputTokens / 10)
        let user = totalTokens - generatedOutput - repoContext - toolOutput - history - system

        return TokenUsageEvent(
            schemaVersion: 1,
            deviceID: "device_local",
            projectID: "project_local",
            artifactID: "artifact_demo",
            runID: "run_local_\(index + 1)",
            spanID: "span_local_\(index + 1)",
            aiTool: aiTool,
            taskType: taskType,
            stage: .plan,
            model: "local-demo",
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            totalTokens: totalTokens,
            tokenBreakdown: TokenUsageBreakdown(
                system: system,
                user: user,
                history: history,
                repoContext: repoContext,
                toolOutput: toolOutput,
                generatedOutput: generatedOutput
            ),
            latencyMS: 320 + index * 20,
            createdAt: ISO8601DateFormatter.tokenUsage.string(from: Date())
        )
    }
}

private struct TokenUsageDashboardBuildRequest {
    let selectedTool: TokenUsageAITool?
    let selectedPeriod: TokenUsageDashboardPeriod
    let selectedCalendarDayID: String?
    let selectedProjectID: String?
    let selectedSessionID: String?
    let displayMode: TokenUsageDisplayMode
    let language: TokenMeteringLanguage
    let localAliases: [String: String]
    let showAdvancedTools: Bool
    let now: Date
    let proposedCalendarMonthStart: Date?
    let calendar: Calendar
}

struct TokenUsageLiveUpdateMarker: Equatable {
    let ids: Set<String>
    let sequence: Int

    static let empty = TokenUsageLiveUpdateMarker(ids: [], sequence: 0)

    func contains(_ id: String) -> Bool {
        ids.contains(id)
    }
}
