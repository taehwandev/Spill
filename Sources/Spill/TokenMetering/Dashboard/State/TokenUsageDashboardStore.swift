@preconcurrency import Foundation

private enum TokenUsageDashboardPreviewDataSource {
    static let onboardingEvents: [TokenUsageEvent] = []
}

private struct TokenUsageDashboardEventLoadScope {
    let events: [TokenUsageEvent]
    let cacheCoverageDateRange: TokenUsageDashboardSnapshot.DateRange
}

private struct TokenUsageDashboardCalendarMonthSummary {
    let monthStart: Date
    let dayTokenTotals: [String: TokenUsageInputScopeTotals]
}

private struct TokenUsageDashboardContextCacheKey: Equatable {
    let eventCount: Int
    let firstSpanID: String?
    let firstCreatedAt: String?
    let lastSpanID: String?
    let lastCreatedAt: String?
    let totalTokens: Int
    let eventFingerprint: Int
    let showAdvancedTools: Bool
    let visibleAITools: [String]?
    let calendarIdentifier: String
    let calendarTimeZone: String
    let firstWeekday: Int

    init(events: [TokenUsageEvent], request: TokenUsageDashboardBuildRequest) {
        eventCount = events.count
        firstSpanID = events.first?.spanID
        firstCreatedAt = events.first?.createdAt
        lastSpanID = events.last?.spanID
        lastCreatedAt = events.last?.createdAt
        var total = 0
        var hasher = Hasher()
        for event in events {
            total += event.totalTokens
            hasher.combine(event.spanID)
            hasher.combine(event.createdAt)
            hasher.combine(event.aiTool.rawValue)
            hasher.combine(event.totalTokens)
            hasher.combine(event.inputTokens)
            hasher.combine(event.outputTokens)
            hasher.combine(event.tokenAccounting?.uncachedInputTokens)
        }
        totalTokens = total
        eventFingerprint = hasher.finalize()
        showAdvancedTools = request.showAdvancedTools
        visibleAITools = request.visibleAITools?.map(\.rawValue).sorted()
        calendarIdentifier = String(describing: request.calendar.identifier)
        calendarTimeZone = request.calendar.timeZone.identifier
        firstWeekday = request.calendar.firstWeekday
    }
}

private struct TokenUsageDashboardSnapshotBuildOutput {
    let snapshotPair: TokenUsageDashboardSnapshotPair
    let context: TokenUsageDashboardSnapshotBuildContext
    let contextKey: TokenUsageDashboardContextCacheKey
}

private final class TokenUsageDashboardSnapshotBuildGate: @unchecked Sendable {
    private let lock = NSLock()
    private var generation = 0

    @discardableResult
    func next() -> Int {
        lock.withLock {
            generation += 1
            return generation
        }
    }

    func isCurrent(_ candidate: Int) -> Bool {
        lock.withLock {
            generation == candidate
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
    @Published private(set) var periodOffset = 0
    @Published private(set) var usageInputScope: TokenUsageInputScope = .includeCache
    @Published private(set) var snapshotInputScope: TokenUsageInputScope = .includeCache
    @Published private(set) var language: TokenMeteringLanguage = .current()
    @Published private(set) var lastError: String?
    @Published private(set) var isRunningSelfTest = false
    @Published private(set) var selfTestMessage: TokenUsageSelfTestMessage?
    @Published private(set) var isRefreshing = false

    private let usageStore: TokenUsageStore
    private var events: [TokenUsageEvent] = []
    private var loadedEventsDateRange: TokenUsageDashboardSnapshot.DateRange?
    private var periodFilterTotals: [TokenUsageDashboardPeriod: TokenUsageInputScopeTotals] = [:]
    private var availableDateBounds = TokenUsageDashboardDateBounds.empty
    private var cachedSnapshotContext: TokenUsageDashboardSnapshotBuildContext?
    private var cachedSnapshotContextKey: TokenUsageDashboardContextCacheKey?
    private var visibleAITools: Set<TokenUsageAITool>?
    private var eventsDidChangeObserver: NSObjectProtocol?
    private var distributedEventsDidChangeObserver: NSObjectProtocol?
    private var collectionDidFinishObserver: NSObjectProtocol?
    private var hasRebuiltSnapshot = false
    private var clearLiveUpdateTask: Task<Void, Never>?
    private var scheduledRefreshTask: Task<Void, Never>?
    private let snapshotBuildQueue = DispatchQueue(label: "app.spill.token-dashboard.snapshot-build", qos: .userInitiated)
    private let snapshotBuildGate = TokenUsageDashboardSnapshotBuildGate()
    private let panelSummaryRefreshGate = TokenUsageDashboardSnapshotBuildGate()

    init(
        usageStore: TokenUsageStore,
        collectionCoordinator: AnyObject? = nil,
        loadsInitialPanelSummary: Bool = true
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
        if loadsInitialPanelSummary {
            refreshPanelSummary()
        }
    }

    var hasDashboardEvents: Bool {
        let showAdvancedTools = SpillSettings.shared.tokenUsageShowAdvancedTools
        let dashboardFilterTools = TokenUsageDashboardToolVisibility.dashboardFilterTools(
            visibleTools: visibleAITools,
            showAdvancedTools: showAdvancedTools
        )
        let hasLoadedDashboardEvents = displayEvents(for: events).contains { event in
            (showAdvancedTools || event.aiTool.isDashboardTool)
                && (dashboardFilterTools?.contains(event.aiTool) ?? true)
        }
        if isOnboardingPreviewEnabled {
            return hasLoadedDashboardEvents
        }
        let hasKnownDashboardHistory = availableDateBounds.earliest != nil
            || periodFilterTotals.values.contains { $0.includeCache > 0 }
        return panelSummary.eventCount > 0 || hasLoadedDashboardEvents || hasKnownDashboardHistory
    }

    var isDashboardRefreshInProgress: Bool {
        loadState == .loading || isRefreshing
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
}

extension TokenUsageDashboardStore {
    func refresh(trackLiveUpdates: Bool = true, refreshesPanelSummary: Bool = true) {
        scheduledRefreshTask?.cancel()
        scheduledRefreshTask = nil
        snapshotBuildGate.next()
        if refreshesPanelSummary {
            panelSummaryRefreshGate.next()
        }
        let previousEvents = events
        let shouldTrackLiveUpdates = trackLiveUpdates && (
            hasRebuiltSnapshot || (previousEvents.isEmpty && panelSummary.eventCount == 0)
        )
        let request = snapshotBuildRequest()
        let loadedEventScope = loadEvents(for: request)
        events = loadedEventScope.events
        loadedEventsDateRange = loadedEventScope.cacheCoverageDateRange
        let nextPeriodFilterTotals = loadPeriodFilterTotals(for: request)
        let panelSummary = refreshesPanelSummary ? loadPanelSummary(for: request) : nil
        rebuildSnapshot(
            trackLiveUpdates: shouldTrackLiveUpdates,
            previousEvents: previousEvents,
            periodFilterTotals: nextPeriodFilterTotals,
            panelSummary: panelSummary
        )
    }
}

extension TokenUsageDashboardStore {
    func refreshAsync(
        trackLiveUpdates: Bool = true,
        refreshesPanelSummary: Bool = true,
        reusesLoadedEvents: Bool = false,
        reusesPeriodFilterTotals: Bool = false
    ) {
        scheduledRefreshTask?.cancel()
        scheduledRefreshTask = nil
        let generation = snapshotBuildGate.next()
        let panelSummaryGeneration = refreshesPanelSummary ? panelSummaryRefreshGate.next() : nil
        let previousEvents = events
        let previousSnapshot = snapshot
        let previousUnfilteredSnapshot = unfilteredSnapshot
        let cachedEvents = reusesLoadedEvents ? events : []
        let cachedEventsDateRange = reusesLoadedEvents ? loadedEventsDateRange : nil
        let cachedPeriodFilterTotals = reusesPeriodFilterTotals ? periodFilterTotals : [:]
        let cachedContext = cachedSnapshotContext
        let cachedContextKey = cachedSnapshotContextKey
        let shouldTrackLiveUpdates = trackLiveUpdates && !isOnboardingPreviewEnabled && (
            hasRebuiltSnapshot || (previousEvents.isEmpty && panelSummary.eventCount == 0)
        )
        let request = snapshotBuildRequest()
        let usesPreviewDataSource = isOnboardingPreviewEnabled
        let usageStore = usageStore
        let snapshotBuildGate = snapshotBuildGate
        let isAlreadyLoaded = loadState == .loaded
        if !isAlreadyLoaded {
            loadState = usesPreviewDataSource ? .previewingEmpty : .loading
        }
        isRefreshing = true

        snapshotBuildQueue.async {
            guard snapshotBuildGate.isCurrent(generation) else {
                return
            }

            let loadedEventScope = Self.loadEvents(
                from: usageStore,
                for: request,
                cachedEvents: cachedEvents,
                cachedDateRange: cachedEventsDateRange
            )
            guard snapshotBuildGate.isCurrent(generation) else {
                return
            }

            let loadedEvents = loadedEventScope.events
            let periodFilterTotals = cachedPeriodFilterTotals.isEmpty
                ? Self.loadPeriodFilterTotals(from: usageStore, for: request)
                : cachedPeriodFilterTotals
            guard snapshotBuildGate.isCurrent(generation) else {
                return
            }

            let panelSummary = refreshesPanelSummary ? Self.loadPanelSummary(from: usageStore, for: request) : nil
            let dateBounds = Self.loadDateBounds(from: usageStore, for: request)
            let buildRequest = request.replacingAvailableDateBounds(dateBounds)
            let calendarMonthSummary = Self.loadCalendarMonthSummary(from: usageStore, for: buildRequest)
            guard snapshotBuildGate.isCurrent(generation) else {
                return
            }

            let displayEvents = usesPreviewDataSource ? TokenUsageDashboardPreviewDataSource.onboardingEvents : loadedEvents
            let snapshotOutput = Self.buildSnapshotOutput(
                events: displayEvents,
                request: buildRequest,
                periodFilterTotals: periodFilterTotals,
                calendarDayTotals: calendarMonthSummary.dayTokenTotals,
                cachedContext: cachedContext,
                cachedContextKey: cachedContextKey
            )

            DispatchQueue.main.async { [weak self] in
                guard let self, self.snapshotBuildGate.isCurrent(generation) else {
                    return
                }

                let appliedPanelSummary: TokenUsagePanelSummarySnapshot?
                if let panelSummaryGeneration,
                   !self.panelSummaryRefreshGate.isCurrent(panelSummaryGeneration) {
                    appliedPanelSummary = nil
                } else {
                    appliedPanelSummary = panelSummary
                }

                self.applySnapshotPair(
                    snapshotOutput.snapshotPair,
                    loadedEvents: loadedEvents,
                    inputScope: buildRequest.inputScope,
                    trackLiveUpdates: shouldTrackLiveUpdates,
                    previousEvents: previousEvents,
                    previousSnapshot: previousSnapshot,
                    previousUnfilteredSnapshot: previousUnfilteredSnapshot,
                    loadedEventsDateRange: loadedEventScope.cacheCoverageDateRange,
                    periodFilterTotals: periodFilterTotals,
                    panelSummary: appliedPanelSummary,
                    availableDateBounds: dateBounds,
                    snapshotContext: snapshotOutput.context,
                    snapshotContextKey: snapshotOutput.contextKey
                )
            }
        }
    }
}

extension TokenUsageDashboardStore {
    func refreshAsyncIfIdle(trackLiveUpdates: Bool = true, refreshesPanelSummary: Bool = true) {
        guard loadState == .idle, !isRefreshing else {
            return
        }
        refreshAsync(trackLiveUpdates: trackLiveUpdates, refreshesPanelSummary: refreshesPanelSummary)
    }

    func refreshPanelSummary() {
        let generation = panelSummaryRefreshGate.next()
        let request = snapshotBuildRequest()
        let usageStore = usageStore

        snapshotBuildQueue.async {
            let panelSummary = Self.loadPanelSummary(from: usageStore, for: request)

            DispatchQueue.main.async { [weak self] in
                guard let self, self.panelSummaryRefreshGate.isCurrent(generation) else {
                    return
                }

                self.panelSummary = panelSummary
                self.lastError = nil
            }
        }
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
}

extension TokenUsageDashboardStore {
    func rebuildSnapshot(
        trackLiveUpdates: Bool = false,
        previousEvents: [TokenUsageEvent]? = nil,
        periodFilterTotals nextPeriodFilterTotals: [TokenUsageDashboardPeriod: TokenUsageInputScopeTotals]? = nil,
        panelSummary: TokenUsagePanelSummarySnapshot? = nil
    ) {
        snapshotBuildGate.next()
        if let nextPeriodFilterTotals {
            periodFilterTotals = nextPeriodFilterTotals
        }
        let previousSnapshot = snapshot
        let previousUnfilteredSnapshot = unfilteredSnapshot
        let displayEvents = displayEvents(for: events)
        let initialRequest = snapshotBuildRequest()
        let nextDateBounds = usageStore.dashboardDateBounds(
            selectedTool: selectedTool,
            dashboardToolsOnly: !initialRequest.showAdvancedTools,
            visibleTools: initialRequest.visibleAITools
        )
        let request = initialRequest.replacingAvailableDateBounds(nextDateBounds)
        let calendarMonthSummary = Self.loadCalendarMonthSummary(from: usageStore, for: request)
        let snapshotOutput = Self.buildSnapshotOutput(
            events: displayEvents,
            request: request,
            periodFilterTotals: periodFilterTotals,
            calendarDayTotals: calendarMonthSummary.dayTokenTotals,
            cachedContext: cachedSnapshotContext,
            cachedContextKey: cachedSnapshotContextKey
        )
        applySnapshotPair(
            snapshotOutput.snapshotPair,
            loadedEvents: events,
            inputScope: request.inputScope,
            trackLiveUpdates: trackLiveUpdates && !isOnboardingPreviewEnabled,
            previousEvents: previousEvents,
            previousSnapshot: previousSnapshot,
            previousUnfilteredSnapshot: previousUnfilteredSnapshot,
            loadedEventsDateRange: nil,
            periodFilterTotals: periodFilterTotals,
            panelSummary: panelSummary,
            availableDateBounds: nextDateBounds,
            snapshotContext: snapshotOutput.context,
            snapshotContextKey: snapshotOutput.contextKey
        )
    }
}

extension TokenUsageDashboardStore {
    private func rebuildSnapshotFromCurrentEventsAsync(
        trackLiveUpdates: Bool = false,
        previousEvents: [TokenUsageEvent]? = nil
    ) {
        let generation = snapshotBuildGate.next()
        let currentEvents = events
        let displayEvents = displayEvents(for: currentEvents)
        let request = snapshotBuildRequest()
        let previousSnapshot = snapshot
        let previousUnfilteredSnapshot = unfilteredSnapshot
        let currentPeriodFilterTotals = periodFilterTotals
        let cachedContext = cachedSnapshotContext
        let cachedContextKey = cachedSnapshotContextKey
        let usageStore = usageStore
        let snapshotBuildGate = snapshotBuildGate

        isRefreshing = true

        snapshotBuildQueue.async {
            guard snapshotBuildGate.isCurrent(generation) else {
                return
            }

            let dateBounds = Self.loadDateBounds(from: usageStore, for: request)
            let buildRequest = request.replacingAvailableDateBounds(dateBounds)
            let calendarMonthSummary = Self.loadCalendarMonthSummary(from: usageStore, for: buildRequest)
            guard snapshotBuildGate.isCurrent(generation) else {
                return
            }

            let snapshotOutput = Self.buildSnapshotOutput(
                events: displayEvents,
                request: buildRequest,
                periodFilterTotals: currentPeriodFilterTotals,
                calendarDayTotals: calendarMonthSummary.dayTokenTotals,
                cachedContext: cachedContext,
                cachedContextKey: cachedContextKey
            )

            DispatchQueue.main.async { [weak self] in
                guard let self, self.snapshotBuildGate.isCurrent(generation) else {
                    return
                }

                self.applySnapshotPair(
                    snapshotOutput.snapshotPair,
                    loadedEvents: currentEvents,
                    inputScope: buildRequest.inputScope,
                    trackLiveUpdates: trackLiveUpdates && !self.isOnboardingPreviewEnabled,
                    previousEvents: previousEvents,
                    previousSnapshot: previousSnapshot,
                    previousUnfilteredSnapshot: previousUnfilteredSnapshot,
                    loadedEventsDateRange: nil,
                    periodFilterTotals: nil,
                    panelSummary: nil,
                    availableDateBounds: dateBounds,
                    snapshotContext: snapshotOutput.context,
                    snapshotContextKey: snapshotOutput.contextKey
                )
            }
        }
    }
}

extension TokenUsageDashboardStore {
    private func applySnapshotPair(
        _ snapshotPair: TokenUsageDashboardSnapshotPair,
        loadedEvents: [TokenUsageEvent],
        inputScope: TokenUsageInputScope,
        trackLiveUpdates: Bool,
        previousEvents: [TokenUsageEvent]?,
        previousSnapshot: TokenUsageDashboardSnapshot,
        previousUnfilteredSnapshot: TokenUsageDashboardSnapshot,
        loadedEventsDateRange nextLoadedEventsDateRange: TokenUsageDashboardSnapshot.DateRange?,
        periodFilterTotals nextPeriodFilterTotals: [TokenUsageDashboardPeriod: TokenUsageInputScopeTotals]?,
        panelSummary: TokenUsagePanelSummarySnapshot?,
        availableDateBounds nextAvailableDateBounds: TokenUsageDashboardDateBounds? = nil,
        snapshotContext nextSnapshotContext: TokenUsageDashboardSnapshotBuildContext? = nil,
        snapshotContextKey nextSnapshotContextKey: TokenUsageDashboardContextCacheKey? = nil
    ) {
        events = loadedEvents
        if let nextLoadedEventsDateRange {
            loadedEventsDateRange = nextLoadedEventsDateRange
        }
        if let nextPeriodFilterTotals {
            periodFilterTotals = nextPeriodFilterTotals
        }
        if let nextAvailableDateBounds {
            availableDateBounds = nextAvailableDateBounds
        }
        if let nextSnapshotContext, let nextSnapshotContextKey {
            cachedSnapshotContext = nextSnapshotContext
            cachedSnapshotContextKey = nextSnapshotContextKey
        }
        calendarMonthStart = snapshotPair.calendarMonthStart
        let filteredSnapshot = snapshotPair.filtered
        selectedProjectID = filteredSnapshot.selectedProjectID
        selectedSessionID = filteredSnapshot.selectedSession?.id
        snapshotInputScope = inputScope
        snapshot = filteredSnapshot
        unfilteredSnapshot = snapshotPair.unfiltered
        if let panelSummary {
            self.panelSummary = panelSummary
        }
        lastError = nil
        loadState = isOnboardingPreviewEnabled ? .previewingEmpty : .loaded
        isRefreshing = false
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
}

extension TokenUsageDashboardStore {
    private func displayEvents(for loadedEvents: [TokenUsageEvent]) -> [TokenUsageEvent] {
        isOnboardingPreviewEnabled ? TokenUsageDashboardPreviewDataSource.onboardingEvents : loadedEvents
    }

    private func snapshotBuildRequest() -> TokenUsageDashboardBuildRequest {
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 1
        let showAdvancedTools = SpillSettings.shared.tokenUsageShowAdvancedTools
        return TokenUsageDashboardBuildRequest(
            selectedTool: selectedTool,
            selectedPeriod: selectedPeriod,
            selectedCalendarDayID: selectedCalendarDayID,
            selectedProjectID: selectedProjectID,
            selectedSessionID: selectedSessionID,
            language: language,
            localAliases: SpillSettings.shared.tokenUsageLocalAliases,
            showAdvancedTools: showAdvancedTools,
            visibleAITools: TokenUsageDashboardToolVisibility.dashboardFilterTools(
                visibleTools: visibleAITools,
                showAdvancedTools: showAdvancedTools
            ),
            now: Date(),
            proposedCalendarMonthStart: calendarMonthStart,
            calendar: calendar,
            periodOffset: periodOffset,
            inputScope: usageInputScope,
            availableDateBounds: availableDateBounds
        )
    }

    nonisolated private static func buildSnapshotOutput(
        events: [TokenUsageEvent],
        request: TokenUsageDashboardBuildRequest,
        periodFilterTotals: [TokenUsageDashboardPeriod: TokenUsageInputScopeTotals],
        calendarDayTotals: [String: TokenUsageInputScopeTotals],
        cachedContext: TokenUsageDashboardSnapshotBuildContext?,
        cachedContextKey: TokenUsageDashboardContextCacheKey?
    ) -> TokenUsageDashboardSnapshotBuildOutput {
        let resolvedPeriodFilterTotals = periodFilterTotals.isEmpty ? nil : periodFilterTotals
        let contextKey = TokenUsageDashboardContextCacheKey(events: events, request: request)
        let context: TokenUsageDashboardSnapshotBuildContext
        if contextKey == cachedContextKey, let cachedContext {
            context = cachedContext
        } else {
            context = TokenUsageDashboardSnapshotBuildContext(
                events: events,
                showAdvancedTools: request.showAdvancedTools,
                calendar: request.calendar
            )
        }

        let snapshotPair = TokenUsageDashboardSnapshot.buildPair(
            context: context,
            selectedTool: request.selectedTool,
            selectedPeriod: request.selectedPeriod,
            selectedCalendarDayID: request.selectedCalendarDayID,
            selectedProjectID: request.selectedProjectID,
            selectedSessionID: request.selectedSessionID,
            language: request.language,
            localAliases: request.localAliases,
            showAdvancedTools: request.showAdvancedTools,
            visibleTools: request.visibleAITools,
            now: request.now,
            proposedCalendarMonthStart: request.proposedCalendarMonthStart,
            calendar: request.calendar,
            periodFilterTotals: resolvedPeriodFilterTotals,
            availableDateBounds: request.availableDateBounds,
            calendarDayTotals: calendarDayTotals,
            periodOffset: request.periodOffset,
            inputScope: request.inputScope
        )
        return TokenUsageDashboardSnapshotBuildOutput(
            snapshotPair: snapshotPair,
            context: context,
            contextKey: contextKey
        )
    }

    nonisolated private static func buildSnapshotPair(
        events: [TokenUsageEvent],
        request: TokenUsageDashboardBuildRequest,
        periodFilterTotals: [TokenUsageDashboardPeriod: TokenUsageInputScopeTotals]
    ) -> TokenUsageDashboardSnapshotPair {
        buildSnapshotOutput(
            events: events,
            request: request,
            periodFilterTotals: periodFilterTotals,
            calendarDayTotals: [:],
            cachedContext: nil,
            cachedContextKey: nil
        )
        .snapshotPair
    }
}

extension TokenUsageDashboardStore {
    private func loadEvents(for request: TokenUsageDashboardBuildRequest) -> TokenUsageDashboardEventLoadScope {
        Self.loadEvents(from: usageStore, for: request)
    }

    nonisolated private static func loadEvents(
        from usageStore: TokenUsageStore,
        for request: TokenUsageDashboardBuildRequest
    ) -> TokenUsageDashboardEventLoadScope {
        loadEvents(from: usageStore, for: request, cachedEvents: [], cachedDateRange: nil)
    }

    nonisolated private static func loadEvents(
        from usageStore: TokenUsageStore,
        for request: TokenUsageDashboardBuildRequest,
        cachedEvents: [TokenUsageEvent],
        cachedDateRange: TokenUsageDashboardSnapshot.DateRange?
    ) -> TokenUsageDashboardEventLoadScope {
        let requestedRange = eventLoadDateRange(for: request)
        let cacheCoverageRange = cacheCoverageDateRange(for: request, eventLoadRange: requestedRange)
        if let cachedDateRange,
           !cachedEvents.isEmpty,
           dateRange(cachedDateRange, contains: requestedRange) {
            return TokenUsageDashboardEventLoadScope(
                events: cachedEvents,
                cacheCoverageDateRange: cachedDateRange
            )
        }

        let events = usageStore.loadEvents(startingAt: requestedRange.start, endingBefore: requestedRange.end)
        return TokenUsageDashboardEventLoadScope(
            events: events,
            cacheCoverageDateRange: cacheCoverageRange
        )
    }

    private func loadEvents(
        for request: TokenUsageDashboardBuildRequest,
        includingCalendarMonth monthStart: Date
    ) -> [TokenUsageEvent] {
        Self.loadEvents(
            from: usageStore,
            ranges: [
                Self.eventLoadDateRange(for: request),
                Self.calendarMonthDateRange(startingAt: monthStart, calendar: request.calendar)
            ]
        )
    }

    nonisolated private static func loadEvents(
        from usageStore: TokenUsageStore,
        ranges: [TokenUsageDashboardSnapshot.DateRange]
    ) -> [TokenUsageEvent] {
        var eventsBySpanID = [String: TokenUsageEvent]()
        for range in ranges {
            let events = usageStore.loadEvents(startingAt: range.start, endingBefore: range.end)
            for event in events {
                eventsBySpanID[event.spanID] = event
            }
        }
        return eventsBySpanID.values.sorted {
            if $0.createdAt == $1.createdAt {
                return $0.spanID < $1.spanID
            }
            return $0.createdAt < $1.createdAt
        }
    }
}

extension TokenUsageDashboardStore {
    private func loadPanelSummary(for request: TokenUsageDashboardBuildRequest) -> TokenUsagePanelSummarySnapshot {
        Self.loadPanelSummary(from: usageStore, for: request)
    }

    private func loadPeriodFilterTotals(
        for request: TokenUsageDashboardBuildRequest
    ) -> [TokenUsageDashboardPeriod: TokenUsageInputScopeTotals] {
        Self.loadPeriodFilterTotals(from: usageStore, for: request)
    }

    nonisolated private static func loadDateBounds(
        from usageStore: TokenUsageStore,
        for request: TokenUsageDashboardBuildRequest
    ) -> TokenUsageDashboardDateBounds {
        usageStore.dashboardDateBounds(
            selectedTool: request.selectedTool,
            dashboardToolsOnly: !request.showAdvancedTools,
            visibleTools: request.visibleAITools
        )
    }

    nonisolated private static func loadCalendarMonthSummary(
        from usageStore: TokenUsageStore,
        for request: TokenUsageDashboardBuildRequest
    ) -> TokenUsageDashboardCalendarMonthSummary {
        let monthStart = calendarMonthStart(for: request)
        let monthRange = calendarMonthDateRange(startingAt: monthStart, calendar: request.calendar)
        let endDate = monthRange.end
            ?? request.calendar.date(byAdding: .month, value: 1, to: monthStart)
            ?? monthStart
        let dayTokenTotals = usageStore.dashboardDayInputScopeTotals(
            startingAt: monthStart,
            endingBefore: endDate,
            calendar: request.calendar,
            dashboardToolsOnly: !request.showAdvancedTools,
            visibleTools: request.visibleAITools
        )
        return TokenUsageDashboardCalendarMonthSummary(
            monthStart: monthStart,
            dayTokenTotals: dayTokenTotals
        )
    }

    nonisolated private static func loadPeriodFilterTotals(
        from usageStore: TokenUsageStore,
        for request: TokenUsageDashboardBuildRequest
    ) -> [TokenUsageDashboardPeriod: TokenUsageInputScopeTotals] {
        usageStore.allPeriodInputScopeTotals(
            now: request.now,
            calendar: request.calendar,
            dashboardToolsOnly: !request.showAdvancedTools,
            visibleTools: request.visibleAITools
        )
    }

    nonisolated private static func loadPanelSummary(
        from usageStore: TokenUsageStore,
        for request: TokenUsageDashboardBuildRequest
    ) -> TokenUsagePanelSummarySnapshot {
        let dayStart = request.calendar.startOfDay(for: request.now)
        let dayEnd = request.calendar.date(byAdding: .day, value: 1, to: dayStart) ?? request.now
        let summary = usageStore.dashboardSummary(
            startingAt: dayStart,
            endingBefore: dayEnd,
            dashboardToolsOnly: !request.showAdvancedTools,
            visibleTools: request.visibleAITools
        )
        return TokenUsagePanelSummarySnapshot(
            summary: summary,
            language: request.language
        )
    }
}

extension TokenUsageDashboardStore {
    nonisolated private static func eventLoadDateRange(
        for request: TokenUsageDashboardBuildRequest
    ) -> TokenUsageDashboardSnapshot.DateRange {
        if let selectedCalendarDayID = request.selectedCalendarDayID,
           let selectedDay = TokenUsageDashboardSnapshot.date(
            forDayID: selectedCalendarDayID,
            calendar: request.calendar
           ) {
            let start = request.calendar.startOfDay(for: selectedDay)
            let end = request.calendar.date(byAdding: .day, value: 1, to: start)
            return TokenUsageDashboardSnapshot.DateRange(start: start, end: end)
        }

        return TokenUsageDashboardSnapshot.cutoffDateRange(
            for: request.selectedPeriod,
            periodOffset: request.periodOffset,
            now: request.now,
            calendar: request.calendar
        )
    }

    nonisolated private static func calendarMonthDateRange(
        startingAt monthStart: Date,
        calendar: Calendar
    ) -> TokenUsageDashboardSnapshot.DateRange {
        TokenUsageDashboardSnapshot.DateRange(
            start: monthStart,
            end: calendar.date(byAdding: .month, value: 1, to: monthStart)
        )
    }

    nonisolated private static func cacheCoverageDateRange(
        for request: TokenUsageDashboardBuildRequest,
        eventLoadRange: TokenUsageDashboardSnapshot.DateRange
    ) -> TokenUsageDashboardSnapshot.DateRange {
        guard request.selectedCalendarDayID == nil, request.periodOffset == 0 else {
            return eventLoadRange
        }
        return TokenUsageDashboardSnapshot.DateRange(start: eventLoadRange.start, end: nil)
    }

    nonisolated private static func calendarMonthStart(
        for request: TokenUsageDashboardBuildRequest
    ) -> Date {
        let selectedDayMonth = request.selectedCalendarDayID
            .flatMap { TokenUsageDashboardSnapshot.date(forDayID: $0, calendar: request.calendar) }
            .map { TokenUsageDashboardSnapshot.monthStart(for: $0, calendar: request.calendar) }
        return TokenUsageDashboardSnapshot.normalizedCalendarMonthStart(
            availableDateBounds: request.availableDateBounds,
            now: request.now,
            proposedMonthStart: request.proposedCalendarMonthStart ?? selectedDayMonth,
            calendar: request.calendar
        )
    }

    nonisolated private static func dateRange(
        _ candidate: TokenUsageDashboardSnapshot.DateRange,
        contains target: TokenUsageDashboardSnapshot.DateRange
    ) -> Bool {
        if let candidateStart = candidate.start {
            guard let targetStart = target.start, targetStart >= candidateStart else {
                return false
            }
        }
        if let candidateEnd = candidate.end {
            guard let targetEnd = target.end, targetEnd <= candidateEnd else {
                return false
            }
        }
        return true
    }
}

extension TokenUsageDashboardStore {
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
        let nextTool = tool.flatMap { candidate in
            candidate.isDashboardTool && (visibleAITools?.contains(candidate) ?? true) ? candidate : nil
        }
        guard selectedTool != nextTool else {
            return
        }

        selectedTool = nextTool
        selectedProjectID = nil
        selectedSessionID = nil
        refreshAsync(
            trackLiveUpdates: false,
            refreshesPanelSummary: false,
            reusesPeriodFilterTotals: true
        )
    }

    func setVisibleAITools(_ tools: Set<TokenUsageAITool>?) {
        let nextTools = tools.map { Set($0.filter(\.isDashboardTool)) }
        guard visibleAITools != nextTools else {
            return
        }

        visibleAITools = nextTools
        if let nextTools, let selectedTool, !nextTools.contains(selectedTool) {
            self.selectedTool = nil
            selectedProjectID = nil
            selectedSessionID = nil
        }
        if hasRebuiltSnapshot || isRefreshing {
            refreshAsync(
                trackLiveUpdates: false,
                reusesLoadedEvents: hasRebuiltSnapshot && !isRefreshing,
                reusesPeriodFilterTotals: false
            )
        } else {
            refreshPanelSummary()
        }
    }
}

extension TokenUsageDashboardStore {
    func setSelectedProjectID(_ projectID: String?) {
        selectedProjectID = projectID
        selectedSessionID = nil
        rebuildSnapshotFromCurrentEventsAsync()
    }

    func setSelectedPeriod(_ period: TokenUsageDashboardPeriod) {
        guard selectedPeriod != period || selectedCalendarDayID != nil || periodOffset != 0 else {
            return
        }
        selectedPeriod = period
        selectedCalendarDayID = nil
        selectedSessionID = nil
        periodOffset = 0
        refreshAsync(
            trackLiveUpdates: false,
            refreshesPanelSummary: false,
            reusesLoadedEvents: false,
            reusesPeriodFilterTotals: true
        )
    }

    func selectCalendarDay(_ dayID: String) {
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 1
        guard TokenUsageDashboardSnapshot.date(forDayID: dayID, calendar: calendar) != nil else {
            return
        }

        selectedCalendarDayID = dayID
        selectedSessionID = nil
        periodOffset = 0
        if let date = TokenUsageDashboardSnapshot.date(forDayID: dayID, calendar: calendar) {
            calendarMonthStart = TokenUsageDashboardSnapshot.monthStart(for: date, calendar: calendar)
        }
        refreshAsync(
            trackLiveUpdates: false,
            refreshesPanelSummary: false,
            reusesLoadedEvents: false,
            reusesPeriodFilterTotals: true
        )
    }

    func selectTodayCalendarDay() {
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 1
        let now = Date()
        selectedCalendarDayID = TokenUsageDashboardSnapshot.dayID(for: now, calendar: calendar)
        selectedSessionID = nil
        periodOffset = 0
        calendarMonthStart = TokenUsageDashboardSnapshot.monthStart(for: now, calendar: calendar)
        refreshAsync(
            trackLiveUpdates: false,
            refreshesPanelSummary: false,
            reusesLoadedEvents: false,
            reusesPeriodFilterTotals: true
        )
    }

    func clearSelectedCalendarDay() {
        selectedCalendarDayID = nil
        selectedSessionID = nil
        periodOffset = 0
        refreshAsync(
            trackLiveUpdates: false,
            refreshesPanelSummary: false,
            reusesLoadedEvents: false,
            reusesPeriodFilterTotals: true
        )
    }
}

extension TokenUsageDashboardStore {
    func selectSession(_ sessionID: String) {
        selectedSessionID = sessionID
        rebuildSnapshotFromCurrentEventsAsync()
    }

    func clearWorkItemSelection() {
        selectedSessionID = nil
        rebuildSnapshotFromCurrentEventsAsync()
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
            refreshAsync(trackLiveUpdates: false, refreshesPanelSummary: false, reusesLoadedEvents: true)
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
            language: language,
            localAliases: SpillSettings.shared.tokenUsageLocalAliases,
            showAdvancedTools: SpillSettings.shared.tokenUsageShowAdvancedTools,
            now: now,
            calendarMonthStart: displayCalendarMonth,
            periodOffset: periodOffset,
            inputScope: usageInputScope,
            calendar: calendar
        )
    }
}

extension TokenUsageDashboardStore {
    func showPreviousCalendarMonth() {
        moveCalendarMonth(by: -1)
    }

    func showNextCalendarMonth() {
        moveCalendarMonth(by: 1)
    }

    func showPreviousPeriod() {
        periodOffset -= 1
        refreshAsync(
            trackLiveUpdates: false,
            refreshesPanelSummary: false,
            reusesLoadedEvents: false,
            reusesPeriodFilterTotals: true
        )
    }

    func showNextPeriod() {
        guard periodOffset < 0 else { return }
        periodOffset += 1
        refreshAsync(
            trackLiveUpdates: false,
            refreshesPanelSummary: false,
            reusesLoadedEvents: false,
            reusesPeriodFilterTotals: true
        )
    }

    func setLanguage(_ language: TokenMeteringLanguage) {
        guard self.language != language else {
            return
        }
        self.language = language
        if hasRebuiltSnapshot {
            refreshAsync(reusesLoadedEvents: true, reusesPeriodFilterTotals: true)
        } else {
            refreshPanelSummary()
        }
    }

    func setUsageInputScope(_ scope: TokenUsageInputScope) {
        guard usageInputScope != scope else {
            return
        }
        usageInputScope = scope
        if hasRebuiltSnapshot {
            rebuildSnapshotFromCurrentEventsAsync()
            return
        }
        if isRefreshing {
            refreshAsync(
                trackLiveUpdates: false,
                refreshesPanelSummary: false
            )
        }
    }
}

extension TokenUsageDashboardStore {
    func clearLocalEvents() {
        guard SpillBuildOptions.developerOptionsEnabled else {
            return
        }
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
        guard SpillBuildOptions.developerOptionsEnabled else {
            return
        }
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
}

extension TokenUsageDashboardStore {
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
                calendar: calendar,
                periodOffset: periodOffset
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
}

extension TokenUsageDashboardStore {
    private func moveCalendarMonth(by value: Int) {
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 1
        let now = Date()
        let currentMonth = calendarMonthStart
            ?? TokenUsageDashboardSnapshot.monthStart(for: now, calendar: calendar)
        let proposedMonth = calendar.date(byAdding: .month, value: value, to: currentMonth)
            ?? currentMonth
        calendarMonthStart = proposedMonth
        let request = snapshotBuildRequest()
        let generation = snapshotBuildGate.next()
        let previousSnapshot = snapshot
        let previousUnfilteredSnapshot = unfilteredSnapshot
        let usageStore = usageStore
        let currentEvents = events
        let currentLoadedEventsDateRange = loadedEventsDateRange
        let cachedContext = cachedSnapshotContext
        let cachedContextKey = cachedSnapshotContextKey
        let currentPeriodFilterTotals = periodFilterTotals

        isRefreshing = true

        snapshotBuildQueue.async {
            let loadedEventScope = Self.loadEvents(
                from: usageStore,
                for: request,
                cachedEvents: currentEvents,
                cachedDateRange: currentLoadedEventsDateRange
            )
            let loadedEvents = loadedEventScope.events
            let dateBounds = Self.loadDateBounds(from: usageStore, for: request)
            let buildRequest = request.replacingAvailableDateBounds(dateBounds)
            let calendarMonthSummary = Self.loadCalendarMonthSummary(from: usageStore, for: buildRequest)
            let snapshotOutput = Self.buildSnapshotOutput(
                events: loadedEvents,
                request: buildRequest,
                periodFilterTotals: currentPeriodFilterTotals,
                calendarDayTotals: calendarMonthSummary.dayTokenTotals,
                cachedContext: cachedContext,
                cachedContextKey: cachedContextKey
            )

            DispatchQueue.main.async { [weak self] in
                guard let self, self.snapshotBuildGate.isCurrent(generation) else {
                    return
                }

                self.applySnapshotPair(
                    snapshotOutput.snapshotPair,
                    loadedEvents: loadedEvents,
                    inputScope: buildRequest.inputScope,
                    trackLiveUpdates: false,
                    previousEvents: nil,
                    previousSnapshot: previousSnapshot,
                    previousUnfilteredSnapshot: previousUnfilteredSnapshot,
                    loadedEventsDateRange: loadedEventScope.cacheCoverageDateRange,
                    periodFilterTotals: nil,
                    panelSummary: nil,
                    availableDateBounds: dateBounds,
                    snapshotContext: snapshotOutput.context,
                    snapshotContextKey: snapshotOutput.contextKey
                )
            }
        }
    }
}

extension TokenUsageDashboardStore {
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
            _ = usageStore.importQueuedEvents()
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
}

extension TokenUsageDashboardStore {
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
}

extension TokenUsageDashboardStore {
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
        appendChangedRows(to: &ids, previous: previousSnapshot.inputAccounting.rows, next: nextSnapshot.inputAccounting.rows, prefix: "input_accounting")
        appendChangedRows(to: &ids, previous: previousSnapshot.taskRows, next: nextSnapshot.taskRows, prefix: "task")
        appendChangedRows(to: &ids, previous: previousSnapshot.stageRows, next: nextSnapshot.stageRows, prefix: "stage")
        appendChangedRows(to: &ids, previous: previousSnapshot.sourceRows, next: nextSnapshot.sourceRows, prefix: "source")
        appendChangedRows(to: &ids, previous: previousSnapshot.sessions, next: nextSnapshot.sessions, prefix: "session")
        appendChangedRows(to: &ids, previous: previousUnfilteredSnapshot.toolRows, next: nextUnfilteredSnapshot.toolRows, prefix: "tool")

        return ids
    }
}

extension TokenUsageDashboardStore {
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
}

extension TokenUsageDashboardStore {
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
}

extension TokenUsageDashboardStore {
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
    let language: TokenMeteringLanguage
    let localAliases: [String: String]
    let showAdvancedTools: Bool
    let visibleAITools: Set<TokenUsageAITool>?
    let now: Date
    let proposedCalendarMonthStart: Date?
    let calendar: Calendar
    let periodOffset: Int
    let inputScope: TokenUsageInputScope
    let availableDateBounds: TokenUsageDashboardDateBounds
}

private extension TokenUsageDashboardBuildRequest {
    func replacingAvailableDateBounds(
        _ bounds: TokenUsageDashboardDateBounds
    ) -> TokenUsageDashboardBuildRequest {
        TokenUsageDashboardBuildRequest(
            selectedTool: selectedTool,
            selectedPeriod: selectedPeriod,
            selectedCalendarDayID: selectedCalendarDayID,
            selectedProjectID: selectedProjectID,
            selectedSessionID: selectedSessionID,
            language: language,
            localAliases: localAliases,
            showAdvancedTools: showAdvancedTools,
            visibleAITools: visibleAITools,
            now: now,
            proposedCalendarMonthStart: proposedCalendarMonthStart,
            calendar: calendar,
            periodOffset: periodOffset,
            inputScope: inputScope,
            availableDateBounds: bounds
        )
    }
}
