import Foundation
import XCTest
@testable import Spill

@MainActor
final class SpillGlanceStoreTests: XCTestCase {
    func testPresentationShowsAllToolsAndWorkTypeInFixedOrder() {
        let summary = TokenUsageDashboardSummary(
            eventCount: 6,
            totalTokens: 1_439_865,
            exactFreshTotalTokens: 43_210,
            toolTotals: [
                "codex": 1_000_000,
                "claude": 400_000,
                "antigravity": 39_865,
            ],
            taskTotals: [
                "testing": 1_000_000,
                "code_generation": 439_865,
            ],
            sourceTotals: ["hook": 1_439_865]
        )
        let panelSummary = TokenUsagePanelSummarySnapshot(summary: summary, language: .english)

        let presentation = SpillGlanceStore.makePresentation(
            enabled: true,
            modules: SpillGlanceModule.defaultOrder,
            panelSummary: panelSummary,
            inputScope: .includeCache
        )

        XCTAssertTrue(presentation.isVisible)
        XCTAssertEqual(presentation.items.map(\.module), SpillGlanceModule.defaultOrder)
        XCTAssertEqual(presentation.items.map(\.title), [
            "All",
            "Codex",
            "Claude",
            "AGY",
            "Work",
        ])
        XCTAssertEqual(presentation.items.map(\.value), [
            "1.44M",
            "1M",
            "400K",
            "39.86K",
            "Testing 1M",
        ])
    }

    func testAllUsesSelectedInputScopeWhileMissingToolUsesCompactNoDataState() {
        let summary = TokenUsageDashboardSummary(
            eventCount: 1,
            totalTokens: 1_000,
            exactFreshTotalTokens: 250,
            toolTotals: ["codex": 1_000],
            taskTotals: [:],
            sourceTotals: [:]
        )
        let panelSummary = TokenUsagePanelSummarySnapshot(summary: summary)

        let presentation = SpillGlanceStore.makePresentation(
            enabled: true,
            modules: [.allToday, .claudeToday, .workType],
            panelSummary: panelSummary,
            inputScope: .freshOnly
        )

        XCTAssertEqual(presentation.items[0].value, "250")
        XCTAssertEqual(presentation.items[1].value, "—")
        XCTAssertEqual(presentation.items[1].tint, .claude)
        XCTAssertEqual(presentation.items[2].value, "—")
        XCTAssertEqual(presentation.items[2].tint, .muted)
    }

    func testDuplicateModulesAreRemovedWithoutChangingCallerOrder() {
        let presentation = SpillGlanceStore.makePresentation(
            enabled: true,
            modules: [.workType, .allToday, .workType, .codexToday],
            panelSummary: .empty,
            inputScope: .includeCache
        )

        XCTAssertEqual(
            presentation.items.map(\.module),
            [.workType, .allToday, .codexToday]
        )
    }

    func testDisabledOrEmptySelectionProducesHiddenPresentation() {
        let disabled = SpillGlanceStore.makePresentation(
            enabled: false,
            modules: SpillGlanceModule.defaultOrder,
            panelSummary: .empty,
            inputScope: .includeCache
        )
        let empty = SpillGlanceStore.makePresentation(
            enabled: true,
            modules: [],
            panelSummary: .empty,
            inputScope: .includeCache
        )

        XCTAssertFalse(disabled.isVisible)
        XCTAssertTrue(disabled.items.isEmpty)
        XCTAssertFalse(empty.isVisible)
        XCTAssertTrue(empty.items.isEmpty)
    }

    func testStoreReactsToPerToolSettingsWithoutOpeningAWindow() throws {
        let suiteName = "SpillGlanceStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = SpillSettings(defaults: defaults)
        settings.glanceEnabled = true
        let usageStore = TokenUsageStore(fileURL: temporaryDatabaseURL())
        let dashboardStore = TokenUsageDashboardStore(
            usageStore: usageStore,
            loadsInitialPanelSummary: false
        )
        let store = SpillGlanceStore(
            settings: settings,
            tokenUsageDashboardStore: dashboardStore
        )

        XCTAssertEqual(store.presentation.items.map(\.module), [.allToday, .workType])

        settings.setGlanceModule(.codexToday, enabled: true)
        settings.setGlanceModule(.antigravityToday, enabled: true)
        XCTAssertEqual(store.presentation.items.map(\.module), [
            .allToday,
            .codexToday,
            .antigravityToday,
            .workType,
        ])

        settings.glanceDisplayStyle = .ticker
        settings.glanceShowInFullScreen = true
        XCTAssertEqual(store.presentation.displayStyle, .ticker)
        XCTAssertTrue(store.presentation.showInFullScreen)

        settings.glanceEnabled = false
        XCTAssertFalse(store.presentation.isVisible)
        XCTAssertTrue(store.presentation.items.isEmpty)
    }

    func testWorkValuesRollInUsageOrderAndUseCompactLabels() {
        let rotationEpoch = Date(timeIntervalSinceReferenceDate: 120)
        let summary = TokenUsageDashboardSummary(
            eventCount: 4,
            totalTokens: 1_000,
            exactFreshTotalTokens: 1_000,
            toolTotals: [:],
            taskTotals: [
                "code_generation": 500,
                "build_verification": 300,
                "debugging": 200,
            ],
            sourceTotals: [:]
        )
        let panelSummary = TokenUsagePanelSummarySnapshot(summary: summary, language: .english)
        let presentation = SpillGlanceStore.makePresentation(
            enabled: true,
            modules: [.allToday, .workType],
            panelSummary: panelSummary,
            inputScope: .includeCache,
            rotationEpoch: rotationEpoch
        )
        let work = presentation.items[1]

        XCTAssertEqual(work.displayValues, ["Code 500", "Build 300", "Debugging 200"])
        XCTAssertEqual(
            work.displayValue(at: rotationEpoch, interval: 3),
            "Code 500"
        )
        XCTAssertEqual(
            work.displayValue(
                at: rotationEpoch.addingTimeInterval(3),
                interval: 3
            ),
            "Build 300"
        )
        XCTAssertEqual(
            work.displayValue(
                at: rotationEpoch.addingTimeInterval(6),
                interval: 3
            ),
            "Debugging 200"
        )
        XCTAssertEqual(
            work.displayValue(
                at: rotationEpoch.addingTimeInterval(9),
                interval: 3
            ),
            "Code 500"
        )
    }

    func testRotationIdentityIgnoresTokenOnlyChangesButTracksQueueOrderAndMode() {
        let original = panelSummary(taskTotals: [
            "code_generation": 600,
            "build_verification": 300,
            "debugging": 100,
        ])
        let tokenOnlyChange = panelSummary(taskTotals: [
            "code_generation": 700,
            "build_verification": 200,
            "debugging": 100,
        ])
        let orderChange = panelSummary(taskTotals: [
            "build_verification": 800,
            "code_generation": 100,
            "debugging": 100,
        ])

        let originalIdentity = SpillGlanceStore.rotationIdentity(
            panelSummary: original,
            modules: [.allToday, .workType],
            workRotationEnabled: true,
            displayStyle: .all
        )
        let tokenOnlyIdentity = SpillGlanceStore.rotationIdentity(
            panelSummary: tokenOnlyChange,
            modules: [.allToday, .workType],
            workRotationEnabled: true,
            displayStyle: .all
        )
        let reorderedIdentity = SpillGlanceStore.rotationIdentity(
            panelSummary: orderChange,
            modules: [.allToday, .workType],
            workRotationEnabled: true,
            displayStyle: .all
        )
        let disabledIdentity = SpillGlanceStore.rotationIdentity(
            panelSummary: original,
            modules: [.allToday, .workType],
            workRotationEnabled: false,
            displayStyle: .all
        )
        let tickerIdentity = SpillGlanceStore.rotationIdentity(
            panelSummary: original,
            modules: [.allToday, .workType],
            workRotationEnabled: true,
            displayStyle: .ticker
        )
        let differentModulesIdentity = SpillGlanceStore.rotationIdentity(
            panelSummary: original,
            modules: [.allToday, .codexToday, .workType],
            workRotationEnabled: true,
            displayStyle: .all
        )
        let hiddenSurfaceIdentity = SpillGlanceStore.rotationIdentity(
            panelSummary: original,
            modules: [.allToday, .workType],
            workRotationEnabled: true,
            displayStyle: .all,
            surfaceEnabled: false
        )

        XCTAssertEqual(originalIdentity, tokenOnlyIdentity)
        XCTAssertNotEqual(originalIdentity, reorderedIdentity)
        XCTAssertNotEqual(originalIdentity, disabledIdentity)
        XCTAssertNotEqual(originalIdentity, tickerIdentity)
        XCTAssertNotEqual(originalIdentity, differentModulesIdentity)
        XCTAssertNotEqual(originalIdentity, hiddenSurfaceIdentity)
    }

    func testTickerGivesWorkOneSlotAndAdvancesItsValueOnTheNextGlobalCycle() {
        let rotationEpoch = Date(timeIntervalSinceReferenceDate: 120)
        let summary = TokenUsageDashboardSummary(
            eventCount: 3,
            totalTokens: 1_000,
            exactFreshTotalTokens: 1_000,
            toolTotals: ["codex": 600],
            taskTotals: [
                "code_generation": 700,
                "build_verification": 300,
            ],
            sourceTotals: [:]
        )
        let presentation = SpillGlanceStore.makePresentation(
            enabled: true,
            modules: [.allToday, .codexToday, .workType],
            panelSummary: TokenUsagePanelSummarySnapshot(summary: summary, language: .english),
            inputScope: .includeCache,
            displayStyle: .ticker,
            rotationEpoch: rotationEpoch
        )

        let queue = stride(from: 0.0, through: 25.0, by: 5.0).compactMap { offset in
            presentation.visibleItems(
                at: rotationEpoch.addingTimeInterval(offset)
            ).first.map { ($0.module, $0.value) }
        }

        XCTAssertEqual(queue.map(\.0), [
            .allToday,
            .codexToday,
            .workType,
            .allToday,
            .codexToday,
            .workType,
        ])
        XCTAssertEqual(queue.map(\.1), [
            "1,000",
            "600",
            "Code 700",
            "1,000",
            "600",
            "Build 300",
        ])
        XCTAssertTrue(presentation.requiresRotation)
    }

    func testAllStyleKeepsEveryModuleVisibleWhileWorkUsesItsOwnValueRotation() {
        let rotationEpoch = Date(timeIntervalSinceReferenceDate: 240)
        let presentation = SpillGlanceStore.makePresentation(
            enabled: true,
            modules: [.allToday, .workType],
            panelSummary: panelSummary(taskTotals: [
                "code_generation": 700,
                "build_verification": 300,
            ]),
            inputScope: .includeCache,
            displayStyle: .all,
            rotationEpoch: rotationEpoch
        )

        XCTAssertEqual(
            presentation.visibleItems(at: rotationEpoch).map(\.module),
            [.allToday, .workType]
        )
        XCTAssertEqual(
            presentation.visibleItems(at: rotationEpoch.addingTimeInterval(5))[1]
                .displayValue(at: rotationEpoch.addingTimeInterval(5)),
            "Build 300"
        )
        XCTAssertTrue(presentation.requiresRotation)
    }

    func testTickerLayoutSignatureDoesNotChangeWhenSelectedQueueChanges() {
        let compact = SpillGlanceStore.makePresentation(
            enabled: true,
            modules: [.allToday, .workType],
            panelSummary: .empty,
            inputScope: .includeCache,
            displayStyle: .ticker
        )
        let expanded = SpillGlanceStore.makePresentation(
            enabled: true,
            modules: SpillGlanceModule.defaultOrder,
            panelSummary: .empty,
            inputScope: .includeCache,
            displayStyle: .ticker
        )

        XCTAssertEqual(compact.layoutSignature, expanded.layoutSignature)
    }

    func testDisabledWorkRotationKeepsHighestUsageWorkAndTokenValueVisible() {
        let summary = TokenUsageDashboardSummary(
            eventCount: 4,
            totalTokens: 1_000,
            exactFreshTotalTokens: 1_000,
            toolTotals: [:],
            taskTotals: [
                "code_generation": 500,
                "build_verification": 300,
                "debugging": 200,
            ],
            sourceTotals: [:]
        )
        let panelSummary = TokenUsagePanelSummarySnapshot(summary: summary, language: .english)
        let presentation = SpillGlanceStore.makePresentation(
            enabled: true,
            modules: [.allToday, .workType],
            panelSummary: panelSummary,
            inputScope: .includeCache,
            workRotationEnabled: false
        )

        XCTAssertEqual(presentation.items[1].displayValues, ["Code 500"])
        XCTAssertEqual(
            presentation.items[1].displayValue(
                at: Date(timeIntervalSinceReferenceDate: 3),
                interval: 3
            ),
            "Code 500"
        )
    }

    func testLongCustomWorkLabelUsesInitialsInsteadOfEllipsis() {
        let title = SpillGlanceStore.compactTaskTitle(
            id: "custom_workflow_category",
            title: "Custom Workflow Category"
        )

        XCTAssertEqual(title, "CWC")
        XCTAssertFalse(title.contains("…"))
    }

    func testReactiveTickerRollsOnlyChangedModulesThenSettlesOnTodayTotal() {
        let start = Date(timeIntervalSinceReferenceDate: 600)
        var reactive = ReactiveSurface(
            displayStyle: .ticker,
            modules: [.allToday, .codexToday, .claudeToday, .workType],
            summary: toolSummary(codex: 100, claude: 100, taskTotals: ["testing": 200]),
            at: start
        )

        // Only Codex moved, so only Codex and the recomputed total may roll.
        reactive.advance(
            to: toolSummary(codex: 900, claude: 100, taskTotals: ["testing": 200]),
            at: start
        )

        XCTAssertEqual(
            reactive.rolledModules(from: start, count: 3),
            [.allToday, .codexToday, .allToday],
            "Claude did not change, so it must never take a ticker slot."
        )
        XCTAssertEqual(
            reactive.value(at: start.addingTimeInterval(11)),
            TokenUsageDashboardSnapshot.formatTokens(1_000),
            "A quiet queue rests on today's total."
        )
    }

    func testReactiveRotationThrottlesABurstIntoOneSlotPerModule() {
        let start = Date(timeIntervalSinceReferenceDate: 900)
        var reactive = ReactiveSurface(
            displayStyle: .ticker,
            modules: [.allToday, .codexToday, .workType],
            summary: toolSummary(codex: 100, claude: 0, taskTotals: ["testing": 100]),
            at: start
        )

        var openingCodexValue: String?
        for step in 1...6 {
            reactive.advance(
                to: toolSummary(
                    codex: 100 + (step * 1_000),
                    claude: 0,
                    taskTotals: ["testing": 100]
                ),
                at: start.addingTimeInterval(Double(step))
            )
            openingCodexValue = openingCodexValue ?? reactive.moduleValue(.codexToday)
        }

        XCTAssertEqual(
            reactive.queue.entries.count,
            2,
            "Six bursts must coalesce into at most one pending slot per module."
        )
        let lastEnqueue = start.addingTimeInterval(6)
        XCTAssertLessThanOrEqual(
            reactive.queue.entries.last?.end.timeIntervalSince(lastEnqueue) ?? .infinity,
            Double(reactive.queue.entries.count) * SpillGlanceChangeQueue.dwell,
            "The queue must never run further ahead than one dwell per pending module."
        )
        XCTAssertEqual(
            reactive.value(at: lastEnqueue),
            reactive.moduleValue(.codexToday),
            "A coalesced slot shows the newest value, not the one that opened it."
        )
        XCTAssertNotEqual(reactive.moduleValue(.codexToday), openingCodexValue)
    }

    func testReactiveAllStyleSurfacesTheChangedWorkTypeThenRestsOnTopUsage() {
        let start = Date(timeIntervalSinceReferenceDate: 1_200)
        var reactive = ReactiveSurface(
            displayStyle: .all,
            modules: [.allToday, .workType],
            summary: panelSummary(taskTotals: ["code_generation": 900, "debugging": 100]),
            at: start
        )

        reactive.advance(
            to: panelSummary(taskTotals: ["code_generation": 900, "debugging": 400]),
            at: start
        )

        XCTAssertEqual(reactive.presentation.visibleItems(at: start).count, 2)
        XCTAssertEqual(
            reactive.workValue(at: start),
            "Debugging 400",
            "The all layout must surface the work type that just moved."
        )
        XCTAssertEqual(
            reactive.workValue(at: start.addingTimeInterval(SpillGlanceChangeQueue.dwell)),
            "Code 900",
            "Once the change elapses, Work rests on the highest-usage type."
        )
    }

    func testReconfiguringTheSurfaceIsNotTreatedAsAUsageChange() {
        let start = Date(timeIntervalSinceReferenceDate: 1_500)
        var reactive = ReactiveSurface(
            displayStyle: .ticker,
            modules: [.allToday, .workType],
            summary: panelSummary(taskTotals: ["testing": 100]),
            at: start
        )
        reactive.advance(
            to: panelSummary(taskTotals: ["testing": 900]),
            at: start
        )
        XCTAssertFalse(reactive.queue.entries.isEmpty)

        reactive.modules = [.allToday, .codexToday, .workType]
        reactive.advance(
            to: panelSummary(taskTotals: ["testing": 900]),
            at: start,
            didReconfigure: true
        )

        XCTAssertTrue(
            reactive.queue.entries.isEmpty,
            "Adding a module changes visible values without any usage having moved."
        )
        XCTAssertEqual(reactive.presentation.rotationSchedule, .none)
    }

    func testDisabledWorkRotationKeepsWorkOutOfTheReactiveQueue() {
        let start = Date(timeIntervalSinceReferenceDate: 1_800)
        var reactive = ReactiveSurface(
            displayStyle: .all,
            modules: [.allToday, .workType],
            summary: panelSummary(taskTotals: ["code_generation": 900, "debugging": 100]),
            at: start,
            workRotationEnabled: false
        )

        reactive.advance(
            to: panelSummary(taskTotals: ["code_generation": 900, "debugging": 400]),
            at: start
        )

        XCTAssertTrue(reactive.queue.entries.isEmpty)
        XCTAssertEqual(reactive.workValue(at: start), "Code 900")
    }

    func testRollingRotationStillDrivesAPeriodicScheduleWhenReactiveIsOff() {
        let rotationEpoch = Date(timeIntervalSinceReferenceDate: 2_100)
        let presentation = SpillGlanceStore.makePresentation(
            enabled: true,
            modules: [.allToday, .workType],
            panelSummary: panelSummary(taskTotals: [
                "code_generation": 700,
                "build_verification": 300,
            ]),
            inputScope: .includeCache,
            displayStyle: .ticker,
            reactiveRotationEnabled: false,
            rotationEpoch: rotationEpoch
        )

        XCTAssertEqual(
            presentation.rotationSchedule,
            .periodic(from: rotationEpoch, interval: SpillGlanceItem.rotationInterval)
        )
        XCTAssertEqual(
            presentation.visibleItems(at: rotationEpoch).map(\.module),
            [.allToday]
        )
        XCTAssertEqual(
            presentation.visibleItems(
                at: rotationEpoch.addingTimeInterval(SpillGlanceItem.rotationInterval)
            ).map(\.module),
            [.workType]
        )
    }

    func testChangeQueueBoundariesDriveTheExplicitSchedule() {
        let start = Date(timeIntervalSinceReferenceDate: 2_400)
        var queue = SpillGlanceChangeQueue()

        queue.enqueue(
            [
                SpillGlanceChangeQueue.Change(module: .allToday, value: "1K"),
                SpillGlanceChangeQueue.Change(module: .codexToday, value: "1K"),
            ],
            at: start,
            dwell: 5
        )

        XCTAssertEqual(
            queue.boundaries.map { $0.timeIntervalSince(start) },
            [0, 5, 10]
        )
        XCTAssertEqual(queue.entry(at: start)?.module, .allToday)
        XCTAssertEqual(queue.entry(at: start.addingTimeInterval(5))?.module, .codexToday)
        XCTAssertNil(queue.entry(at: start.addingTimeInterval(10)))
        XCTAssertNil(queue.entry(for: .codexToday, at: start))
    }
}

/// Replays the store's reactive step over a sequence of snapshots using the same
/// production functions the Combine pipeline calls, so the change policy is
/// verified without standing up a database-backed dashboard store.
@MainActor
private struct ReactiveSurface {
    var displayStyle: SpillGlanceDisplayStyle
    var modules: [SpillGlanceModule]
    var workRotationEnabled: Bool

    private(set) var queue = SpillGlanceChangeQueue()
    private(set) var presentation: SpillGlancePresentation
    private var baseline: SpillGlanceStore.ChangeBaseline
    private let rotationEpoch: Date

    init(
        displayStyle: SpillGlanceDisplayStyle,
        modules: [SpillGlanceModule],
        summary: TokenUsagePanelSummarySnapshot,
        at date: Date,
        workRotationEnabled: Bool = true
    ) {
        self.displayStyle = displayStyle
        self.modules = modules
        self.workRotationEnabled = workRotationEnabled
        rotationEpoch = date
        presentation = Self.makePresentation(
            displayStyle: displayStyle,
            modules: modules,
            workRotationEnabled: workRotationEnabled,
            summary: summary,
            rotationEpoch: date,
            queue: SpillGlanceChangeQueue()
        )
        baseline = SpillGlanceStore.changeBaseline(
            items: presentation.items,
            panelSummary: summary
        )
    }

    mutating func advance(
        to summary: TokenUsagePanelSummarySnapshot,
        at date: Date,
        didReconfigure: Bool = false
    ) {
        let base = Self.makePresentation(
            displayStyle: displayStyle,
            modules: modules,
            workRotationEnabled: workRotationEnabled,
            summary: summary,
            rotationEpoch: rotationEpoch,
            queue: queue
        )
        let next = SpillGlanceStore.changeBaseline(
            items: base.items,
            panelSummary: summary
        )
        queue = SpillGlanceStore.advancedQueue(
            queue,
            reactiveRotationEnabled: true,
            didReconfigure: didReconfigure,
            displayStyle: displayStyle,
            workRotationEnabled: workRotationEnabled,
            items: base.items,
            previous: baseline,
            next: next,
            at: date
        )
        baseline = next
        presentation = Self.makePresentation(
            displayStyle: displayStyle,
            modules: modules,
            workRotationEnabled: workRotationEnabled,
            summary: summary,
            rotationEpoch: rotationEpoch,
            queue: queue
        )
    }

    func rolledModules(from date: Date, count: Int) -> [SpillGlanceModule] {
        (0 ..< count).compactMap { step in
            presentation.visibleItems(
                at: date.addingTimeInterval(Double(step) * SpillGlanceChangeQueue.dwell)
            ).first?.module
        }
    }

    func value(at date: Date) -> String? {
        presentation.visibleItems(at: date).first?.value
    }

    func workValue(at date: Date) -> String? {
        presentation.visibleItems(at: date)
            .first { $0.module == .workType }?
            .value
    }

    func moduleValue(_ module: SpillGlanceModule) -> String? {
        presentation.items.first { $0.module == module }?.value
    }

    private static func makePresentation(
        displayStyle: SpillGlanceDisplayStyle,
        modules: [SpillGlanceModule],
        workRotationEnabled: Bool,
        summary: TokenUsagePanelSummarySnapshot,
        rotationEpoch: Date,
        queue: SpillGlanceChangeQueue
    ) -> SpillGlancePresentation {
        SpillGlanceStore.makePresentation(
            enabled: true,
            modules: modules,
            panelSummary: summary,
            inputScope: .includeCache,
            displayStyle: displayStyle,
            reactiveRotationEnabled: true,
            workRotationEnabled: workRotationEnabled,
            rotationEpoch: rotationEpoch,
            changeQueue: queue
        )
    }
}

private extension SpillGlanceStoreTests {
    func toolSummary(
        codex: Int,
        claude: Int,
        taskTotals: [String: Int]
    ) -> TokenUsagePanelSummarySnapshot {
        var toolTotals: [String: Int] = [:]
        if codex > 0 {
            toolTotals["codex"] = codex
        }
        if claude > 0 {
            toolTotals["claude"] = claude
        }
        let totalTokens = codex + claude
        return TokenUsagePanelSummarySnapshot(
            summary: TokenUsageDashboardSummary(
                eventCount: toolTotals.count,
                totalTokens: totalTokens,
                exactFreshTotalTokens: totalTokens,
                toolTotals: toolTotals,
                taskTotals: taskTotals,
                sourceTotals: [:]
            ),
            language: .english
        )
    }

    func panelSummary(taskTotals: [String: Int]) -> TokenUsagePanelSummarySnapshot {
        let totalTokens = taskTotals.values.reduce(0, +)
        return TokenUsagePanelSummarySnapshot(
            summary: TokenUsageDashboardSummary(
                eventCount: taskTotals.count,
                totalTokens: totalTokens,
                exactFreshTotalTokens: totalTokens,
                toolTotals: [:],
                taskTotals: taskTotals,
                sourceTotals: [:]
            ),
            language: .english
        )
    }

    func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("spill-glance-\(UUID().uuidString)")
            .appendingPathExtension("sqlite")
    }
}
