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
            workRotationEpoch: rotationEpoch
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

    func testWorkRotationIdentityIgnoresTokenOnlyChangesButTracksOrderAndMode() {
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

        let originalIdentity = SpillGlanceStore.workRotationIdentity(
            panelSummary: original,
            rotationEnabled: true
        )
        let tokenOnlyIdentity = SpillGlanceStore.workRotationIdentity(
            panelSummary: tokenOnlyChange,
            rotationEnabled: true
        )
        let reorderedIdentity = SpillGlanceStore.workRotationIdentity(
            panelSummary: orderChange,
            rotationEnabled: true
        )
        let disabledIdentity = SpillGlanceStore.workRotationIdentity(
            panelSummary: original,
            rotationEnabled: false
        )
        let hiddenSurfaceIdentity = SpillGlanceStore.workRotationIdentity(
            panelSummary: original,
            rotationEnabled: true,
            surfaceEnabled: false
        )

        XCTAssertEqual(originalIdentity, tokenOnlyIdentity)
        XCTAssertNotEqual(originalIdentity, reorderedIdentity)
        XCTAssertNotEqual(originalIdentity, disabledIdentity)
        XCTAssertNotEqual(originalIdentity, hiddenSurfaceIdentity)
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
}

private extension SpillGlanceStoreTests {
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
