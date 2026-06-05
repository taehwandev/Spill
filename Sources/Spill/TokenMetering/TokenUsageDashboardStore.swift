@preconcurrency import Foundation

@MainActor
final class TokenUsageDashboardStore: ObservableObject {
    @Published private(set) var snapshot = TokenUsageDashboardSnapshot.empty
    @Published private(set) var unfilteredSnapshot = TokenUsageDashboardSnapshot.empty
    @Published private(set) var liveUpdateMarker = TokenUsageLiveUpdateMarker.empty
    @Published private(set) var selectedTool: TokenUsageAITool?
    @Published private(set) var selectedPeriod: TokenUsageDashboardPeriod = .today
    @Published private(set) var selectedSessionID: String?
    @Published private(set) var displayMode: TokenUsageDisplayMode = .tokens
    @Published private(set) var language: TokenMeteringLanguage = .current()
    @Published private(set) var lastError: String?
    @Published private(set) var isRunningSelfTest = false
    @Published private(set) var selfTestMessage: TokenUsageSelfTestMessage?

    private let usageStore: TokenUsageStore
    private var events: [TokenUsageEvent] = []
    private var eventsDidChangeObserver: NSObjectProtocol?
    private var hasRebuiltSnapshot = false
    private var clearLiveUpdateTask: Task<Void, Never>?

    init(usageStore: TokenUsageStore) {
        self.usageStore = usageStore
        eventsDidChangeObserver = NotificationCenter.default.addObserver(
            forName: TokenUsageStore.eventsDidChangeNotification,
            object: usageStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        refresh()
    }

    deinit {
        if let eventsDidChangeObserver {
            NotificationCenter.default.removeObserver(eventsDidChangeObserver)
        }
        clearLiveUpdateTask?.cancel()
    }

    func refresh(trackLiveUpdates: Bool = true) {
        let previousEvents = events
        events = usageStore.loadEvents()
        rebuildSnapshot(
            trackLiveUpdates: trackLiveUpdates && hasRebuiltSnapshot,
            previousEvents: previousEvents
        )
    }

    func rebuildSnapshot(
        trackLiveUpdates: Bool = false,
        previousEvents: [TokenUsageEvent]? = nil
    ) {
        let previousSnapshot = snapshot
        let previousUnfilteredSnapshot = unfilteredSnapshot
        let filteredSnapshot = TokenUsageDashboardSnapshot(
            events: events,
            selectedTool: selectedTool,
            selectedPeriod: selectedPeriod,
            selectedSessionID: selectedSessionID,
            displayMode: displayMode,
            language: language
        )
        selectedSessionID = filteredSnapshot.selectedSession?.id
        snapshot = filteredSnapshot
        unfilteredSnapshot = TokenUsageDashboardSnapshot(
            events: events,
            selectedTool: nil,
            selectedPeriod: selectedPeriod,
            selectedSessionID: selectedSessionID,
            displayMode: displayMode,
            language: language
        )
        lastError = nil
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

    func setSelectedTool(_ tool: TokenUsageAITool?) {
        selectedTool = tool?.isDashboardTool == true ? tool : nil
        rebuildSnapshot()
    }

    func setSelectedPeriod(_ period: TokenUsageDashboardPeriod) {
        selectedPeriod = period
        rebuildSnapshot()
    }

    func selectSession(_ sessionID: String) {
        selectedSessionID = sessionID
        rebuildSnapshot()
    }

    func setDisplayMode(_ mode: TokenUsageDisplayMode) {
        displayMode = mode
        rebuildSnapshot()
    }

    func setLanguage(_ language: TokenMeteringLanguage) {
        guard self.language != language else {
            return
        }
        self.language = language
        rebuildSnapshot()
    }

    func clearLocalEvents() {
        do {
            try usageStore.clearEvents()
            selfTestMessage = nil
            liveUpdateMarker = .empty
            refresh(trackLiveUpdates: false)
        } catch {
            lastError = TokenMeteringL10n.text(.clearFailed, language: language)
        }
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
            createdAt: timestamp,
            syncMode: .localOnly
        )
    }

    func addLocalTestEvent() {
        do {
            try usageStore.appendEvent(Self.makeLocalTestEvent(index: snapshot.eventCount))
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
            selectedPeriod: selectedPeriod
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
        selectedPeriod: TokenUsageDashboardPeriod
    ) -> Set<String> {
        let previousPeriodEvents = dashboardEvents(
            previousEvents,
            selectedTool: nil,
            selectedPeriod: selectedPeriod
        )
        let nextPeriodEvents = dashboardEvents(
            nextEvents,
            selectedTool: nil,
            selectedPeriod: selectedPeriod
        )
        let previousVisibleEvents = selectedTool.map { tool in
            previousPeriodEvents.filter { $0.aiTool == tool }
        } ?? previousPeriodEvents
        let nextVisibleEvents = selectedTool.map { tool in
            nextPeriodEvents.filter { $0.aiTool == tool }
        } ?? nextPeriodEvents

        var ids = Set<String>()

        let previousVisibleTotal = previousVisibleEvents.reduce(0) { $0 + $1.totalTokens }
        let nextVisibleTotal = nextVisibleEvents.reduce(0) { $0 + $1.totalTokens }
        if nextVisibleTotal != previousVisibleTotal {
            ids.formUnion(["kpi:total", "kpi:input", "kpi:output"])
        }
        if averageLatency(previousVisibleEvents) != averageLatency(nextVisibleEvents) {
            ids.insert("kpi:latency")
        }

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
            previous: tokenTotals(previousVisibleEvents, by: { $0.taskType.rawValue }),
            next: tokenTotals(nextVisibleEvents, by: { $0.taskType.rawValue }),
            prefixes: ["task"]
        )
        appendChangedTotals(
            to: &ids,
            previous: tokenTotals(previousVisibleEvents, by: { $0.stage.rawValue }),
            next: tokenTotals(nextVisibleEvents, by: { $0.stage.rawValue }),
            prefixes: ["stage"]
        )
        appendChangedTotals(
            to: &ids,
            previous: tokenTotals(previousVisibleEvents, by: { modelKey($0.model) }),
            next: tokenTotals(nextVisibleEvents, by: { modelKey($0.model) }),
            prefixes: ["model"]
        )
        appendChangedTotals(
            to: &ids,
            previous: sourceTotals(previousVisibleEvents),
            next: sourceTotals(nextVisibleEvents),
            prefixes: ["source"]
        )

        appendChangedRows(to: &ids, previous: previousSnapshot.kpis, next: nextSnapshot.kpis, prefix: "kpi")
        appendChangedRows(to: &ids, previous: previousSnapshot.toolRows, next: nextSnapshot.toolRows, prefix: "tool")
        appendChangedRows(to: &ids, previous: previousSnapshot.modelRows, next: nextSnapshot.modelRows, prefix: "model")
        appendChangedRows(to: &ids, previous: previousSnapshot.taskRows, next: nextSnapshot.taskRows, prefix: "task")
        appendChangedRows(to: &ids, previous: previousSnapshot.stageRows, next: nextSnapshot.stageRows, prefix: "stage")
        appendChangedRows(to: &ids, previous: previousSnapshot.sourceRows, next: nextSnapshot.sourceRows, prefix: "source")
        appendChangedRows(to: &ids, previous: previousSnapshot.sessions, next: nextSnapshot.sessions, prefix: "session")
        appendChangedRows(to: &ids, previous: previousUnfilteredSnapshot.toolRows, next: nextUnfilteredSnapshot.toolRows, prefix: "tool")

        return ids
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
            createdAt: ISO8601DateFormatter.tokenUsage.string(from: Date()),
            syncMode: .localOnly
        )
    }
}
