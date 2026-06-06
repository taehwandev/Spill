import Foundation
import Darwin
import SQLite3
import XCTest
@testable import Spill

private let TEST_SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class TokenUsageStoreTests: XCTestCase {
    func testPreferencesModelSeparatesLocalAndCloudOptInModes() {
        let modes = TokenMeteringPreferencesModel.modes

        XCTAssertEqual(modes.map(\.id), ["local_only", "cloud_aggregate", "cloud_detailed"])
        XCTAssertEqual(modes.filter(\.isActive).map(\.id), ["local_only"])
        XCTAssertEqual(modes[0].title, TokenMeteringL10n.text(.modeLocalOnlyTitle))
        XCTAssertEqual(modes[1].state, TokenMeteringL10n.text(.modeCloudAggregateState))
        XCTAssertEqual(modes[2].state, TokenMeteringL10n.text(.modeCloudDetailedState))
        XCTAssertEqual(
            TokenMeteringPreferencesModel.forbiddenContentLabels,
            TokenMeteringL10n.forbiddenContentLabels()
        )
    }

    func testTokenMeteringLocalizationCoversSupportedLanguages() {
        XCTAssertEqual(TokenMeteringLanguage.current(preferredLanguages: ["ko-KR"], appLanguage: .automatic), .korean)
        XCTAssertEqual(TokenMeteringLanguage.current(preferredLanguages: ["ja-JP"], appLanguage: .automatic), .japanese)
        XCTAssertEqual(TokenMeteringLanguage.current(preferredLanguages: ["en-US"], appLanguage: .automatic), .english)
        XCTAssertEqual(TokenMeteringLanguage.current(preferredLanguages: ["fr-FR"], appLanguage: .automatic), .english)
        XCTAssertEqual(TokenMeteringLanguage.current(preferredLanguages: ["en-US"], appLanguage: .korean), .korean)
        XCTAssertEqual(TokenMeteringL10n.text(.dashboardTitle, language: .english), "Local Token Metering")
        XCTAssertEqual(TokenMeteringL10n.text(.dashboardTitle, language: .korean), "로컬 토큰 미터링")
        XCTAssertEqual(TokenMeteringL10n.text(.dashboardTitle, language: .japanese), "ローカルトークン計測")
        XCTAssertEqual(TokenMeteringL10n.text(.displayModeShare, language: .korean), "비중 %")
        XCTAssertEqual(TokenMeteringL10n.text(.agentConnectionStatus, language: .korean), "에이전트 연결 상태")
        XCTAssertEqual(TokenMeteringL10n.text(.setupWorkflowLabelsTitle, language: .english), "Workflow labels are more accurate")
        XCTAssertEqual(TokenMeteringL10n.text(.copyWebSetup, language: .korean), "설치 명령 복사")
        XCTAssertEqual(TokenMeteringL10n.text(.adapterSetupRequired, language: .japanese), "ローカル追跡の設定が必要")
        XCTAssertEqual(TokenMeteringL10n.adapterInstalled("spill-hook.py", language: .english), "Installed: spill-hook.py")
        XCTAssertEqual(TokenMeteringL10n.hookConfigTarget("~/.claude/settings.json", language: .korean), "Hook 설정 -> ~/.claude/settings.json")
        XCTAssertEqual(TokenMeteringL10n.taskLabel("git_commit", language: .korean), "Git 커밋")
        XCTAssertEqual(TokenMeteringL10n.stageLabel("verify", language: .japanese), "検証")
        XCTAssertEqual(TokenMeteringL10n.taskLabel("ux_copy_review", language: .english), "Ux Copy Review")
    }

    func testDashboardSnapshotAggregatesLocalEvents() {
        let snapshot = TokenUsageDashboardSnapshot(events: [Self.safeEvent()])

        XCTAssertEqual(snapshot.eventCount, 1)
        XCTAssertEqual(snapshot.totalTokens, 150)
        XCTAssertEqual(snapshot.kpis.first?.value, "150")
        XCTAssertEqual(snapshot.kpis.map(\.id), ["total", "input", "output"])
        XCTAssertEqual(snapshot.toolRows.map(\.title), ["Codex"])
        XCTAssertEqual(snapshot.modelRows.map(\.title), ["local-manual"])
        XCTAssertEqual(snapshot.taskRows.map(\.title), [TokenMeteringL10n.taskLabel("analysis")])
        XCTAssertTrue(snapshot.sourceRows.contains { $0.title == TokenMeteringL10n.text(.sourceGeneratedOutput) && $0.value == "50" })
        XCTAssertEqual(snapshot.sessions.first?.title, "Analysis - Plan")
        XCTAssertNil(snapshot.selectedSession)
    }

    func testDashboardSnapshotFiltersByAITool() {
        let codex = Self.safeEvent(aiTool: .codex, spanID: "span_codex_01")
        let claude = Self.safeEvent(
            aiTool: .claude,
            spanID: "span_claude_01",
            inputTokens: 20,
            outputTokens: 10
        )
        let allSnapshot = TokenUsageDashboardSnapshot(events: [codex, claude])
        let claudeSnapshot = TokenUsageDashboardSnapshot(events: [codex, claude], selectedTool: .claude)

        XCTAssertEqual(allSnapshot.totalTokens, 180)
        XCTAssertEqual(allSnapshot.toolRows.map(\.title), ["Codex", "Claude"])
        XCTAssertEqual(allSnapshot.toolFilters.first?.title, TokenMeteringL10n.text(.allTools))
        XCTAssertTrue(allSnapshot.toolFilters.first { $0.tool == .claude }?.detail.contains("30") == true)
        XCTAssertEqual(claudeSnapshot.eventCount, 1)
        XCTAssertEqual(claudeSnapshot.totalTokens, 30)
        XCTAssertEqual(claudeSnapshot.toolRows.map(\.title), ["Claude"])
        XCTAssertEqual(claudeSnapshot.sessions.map(\.title), ["Analysis - Plan"])
    }

    func testDashboardSnapshotFiltersTodayUsingLocalCalendar() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Seoul"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let now = try Self.date("2026-06-05T12:00:00.000Z")

        let previousLocalDay = Self.safeEvent(
            spanID: "span_previous_local_day",
            inputTokens: 900,
            outputTokens: 100,
            createdAt: "2026-06-04T14:59:00.000Z"
        )
        let today = Self.safeEvent(
            spanID: "span_today",
            inputTokens: 100,
            outputTokens: 50,
            createdAt: "2026-06-04T15:01:00.000Z"
        )
        let future = Self.safeEvent(
            spanID: "span_future",
            inputTokens: 400,
            outputTokens: 100,
            createdAt: "2026-06-05T12:01:00.000Z"
        )

        let snapshot = TokenUsageDashboardSnapshot(
            events: [previousLocalDay, today, future],
            selectedPeriod: .today,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.eventCount, 1)
        XCTAssertEqual(snapshot.totalTokens, 150)
        XCTAssertEqual(snapshot.sessions.map(\.id), ["work_analysis_plan_2026_06_05"])
        XCTAssertEqual(
            snapshot.periodFilters.first { $0.period == .today }?.detail,
            "150"
        )
    }

    func testDashboardLastUpdatedUsesTimeOnlyForToday() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let now = try Self.date("2026-06-06T20:00:00.000Z")
        let event = Self.safeEvent(
            spanID: "span_today_last_updated",
            createdAt: "2026-06-06T19:45:00.000Z"
        )

        let snapshot = TokenUsageDashboardSnapshot(
            events: [event],
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: timeZone
        )

        let overallLastUpdated = try XCTUnwrap(snapshot.overallLastUpdatedString)
        let codexLastUpdated = try XCTUnwrap(snapshot.codexLastUpdatedString)
        XCTAssertTrue(overallLastUpdated.contains("7:45"))
        XCTAssertTrue(overallLastUpdated.contains("PM"))
        XCTAssertFalse(overallLastUpdated.contains("Jun"))
        XCTAssertFalse(overallLastUpdated.contains("2026"))
        XCTAssertTrue(codexLastUpdated.contains("7:45"))
        XCTAssertTrue(codexLastUpdated.contains("PM"))
        XCTAssertFalse(codexLastUpdated.contains("Jun"))
        XCTAssertFalse(codexLastUpdated.contains("2026"))
    }

    func testDashboardLastUpdatedUsesShortDateForOlderSameYearEvents() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let now = try Self.date("2026-06-06T20:00:00.000Z")
        let event = Self.safeEvent(
            spanID: "span_yesterday_last_updated",
            createdAt: "2026-06-05T19:45:00.000Z"
        )

        let snapshot = TokenUsageDashboardSnapshot(
            events: [event],
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: timeZone
        )

        let lastUpdated = try XCTUnwrap(snapshot.overallLastUpdatedString)
        XCTAssertTrue(lastUpdated.contains("Jun"))
        XCTAssertTrue(lastUpdated.contains("5"))
        XCTAssertTrue(lastUpdated.contains("7:45"))
        XCTAssertTrue(lastUpdated.contains("PM"))
        XCTAssertFalse(lastUpdated.contains("2026"))
    }

    func testDashboardSnapshotShowsOnlySupportedAgentTools() {
        let codex = Self.safeEvent(aiTool: .codex, spanID: "span_codex_01")
        let unknown = Self.safeEvent(
            aiTool: .unknown,
            spanID: "span_unknown_01",
            inputTokens: 900,
            outputTokens: 100
        )
        let openAI = Self.safeEvent(
            aiTool: .openAI,
            spanID: "span_openai_01",
            inputTokens: 400,
            outputTokens: 100
        )

        let snapshot = TokenUsageDashboardSnapshot(events: [codex, unknown, openAI])
        XCTAssertEqual(snapshot.totalTokens, 150)
        XCTAssertEqual(snapshot.eventCount, 1)
        XCTAssertEqual(snapshot.toolRows.map(\.title), ["Codex"])
        XCTAssertEqual(snapshot.toolFilters.compactMap(\.tool), [.codex, .claude, .antigravity])

        let unsupportedSelection = TokenUsageDashboardSnapshot(events: [codex], selectedTool: .unknown)
        XCTAssertEqual(unsupportedSelection.totalTokens, 150)
        XCTAssertTrue(unsupportedSelection.toolFilters.first?.isSelected == true)
    }

    func testDashboardSnapshotAggregatesModelRows() {
        let codex = Self.safeEvent(
            aiTool: .codex,
            spanID: "span_model_codex_01",
            inputTokens: 80,
            outputTokens: 20,
            model: "codex-test-model"
        )
        let claude = Self.safeEvent(
            aiTool: .claude,
            spanID: "span_model_claude_01",
            inputTokens: 30,
            outputTokens: 20,
            model: "claude-test-model"
        )

        let snapshot = TokenUsageDashboardSnapshot(events: [codex, claude])
        XCTAssertEqual(snapshot.modelRows.map(\.title), ["codex-test-model", "claude-test-model"])
        XCTAssertEqual(snapshot.modelRows.map(\.value), ["100", "50"])

        let percentageSnapshot = TokenUsageDashboardSnapshot(events: [codex, claude], displayMode: .percentage)
        XCTAssertEqual(percentageSnapshot.modelRows.first?.title, "codex-test-model")
        XCTAssertEqual(percentageSnapshot.modelRows.first?.value, "66.7%")

        let claudeSnapshot = TokenUsageDashboardSnapshot(events: [codex, claude], selectedTool: .claude)
        XCTAssertEqual(claudeSnapshot.modelRows.map(\.title), ["claude-test-model"])
        XCTAssertEqual(claudeSnapshot.modelRows.map(\.value), ["50"])
    }

    func testDashboardSourceRowsShowUnknownOnlyBreakdownAsRuntimeTotal() {
        let snapshot = TokenUsageDashboardSnapshot(events: [
            Self.safeEvent(inputTokens: 22, outputTokens: 11)
        ])

        XCTAssertEqual(snapshot.totalTokens, 33)
        XCTAssertTrue(snapshot.sourceRows.contains { $0.title == TokenMeteringL10n.text(.sourceUnavailable) && $0.value == "33" })
    }

    func testDashboardSnapshotOmitsLatencyKPIAndMissingLatencyCopy() {
        let snapshot = TokenUsageDashboardSnapshot(events: [
            Self.safeEvent(latencyMS: 0)
        ])

        XCTAssertFalse(snapshot.kpis.contains { $0.id == "latency" })
        XCTAssertFalse(snapshot.sessions.first?.detail.contains(TokenMeteringL10n.text(.latencyUnavailable)) == true)
        XCTAssertTrue(snapshot.sessions.first?.detail.contains("events") == true)
    }

    func testDashboardSourceRowsShowUnknownWhenMixedWithKnownBreakdown() {
        let snapshot = TokenUsageDashboardSnapshot(events: [
            Self.safeEvent(inputTokens: 22, outputTokens: 11, generatedOutput: 11)
        ])

        XCTAssertEqual(snapshot.totalTokens, 33)
        XCTAssertTrue(snapshot.sourceRows.contains { $0.title == TokenMeteringL10n.text(.sourceGeneratedOutput) && $0.value == "11" })
        XCTAssertTrue(snapshot.sourceRows.contains { $0.title == TokenMeteringL10n.text(.sourceUnavailable) && $0.value == "22" })
    }

    func testDashboardViewSimplifiesClearActions() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let dashboardView = try String(contentsOf: root.appendingPathComponent("Sources/Spill/TokenMetering/TokenMeteringDashboardView.swift"))
        let preferencesSection = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Preferences/TokenMeteringPreferencesSection.swift"))

        XCTAssertFalse(dashboardView.contains("dataManagementPanel"))
        XCTAssertFalse(dashboardView.contains("title: t(.clearAllLocalData)"))
        XCTAssertFalse(dashboardView.contains("scope: .currentScope"))
        XCTAssertFalse(dashboardView.contains("requestClear(.all)"))
        XCTAssertFalse(dashboardView.contains("scope: .tool(tool)"))
        XCTAssertFalse(dashboardView.contains("scope: .period(period)"))
        XCTAssertTrue(dashboardView.contains(".contextMenu"))
        XCTAssertTrue(dashboardView.contains("requestClear(.workItem(session.id))"))
        XCTAssertFalse(dashboardView.contains("requestClear(.workItem(detailSession.id))"))
        XCTAssertTrue(dashboardView.contains("settingsAction()"))
        XCTAssertTrue(dashboardView.contains("Label(AppL10n.text(.settings"))
        XCTAssertFalse(dashboardView.contains("TokenMeteringGlobalSetup.prompt("))
        XCTAssertFalse(dashboardView.contains("diagnosticsPanel"))
        XCTAssertFalse(dashboardView.contains("runLocalQueueSelfTest()"))
        XCTAssertFalse(dashboardView.contains("t(.avgLatency)"))
        XCTAssertTrue(preferencesSection.contains("localDataManagementSection"))
        XCTAssertTrue(preferencesSection.contains("Label(t(.clearAllLocalData), systemImage: \"trash\")"))
        XCTAssertTrue(preferencesSection.contains("try tokenUsageStore.clearEvents()"))
    }

    func testPreferencesSetupGuidanceIsAlwaysVisible() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let preferencesSection = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Preferences/TokenMeteringPreferencesSection.swift"))

        XCTAssertTrue(preferencesSection.contains("TokenMeteringSetupGuidanceRow"))
        XCTAssertTrue(preferencesSection.contains("t(.setupGlobalInstructionTitle)"))
        XCTAssertTrue(preferencesSection.contains("t(.setupWorkflowLabelsTitle)"))
        XCTAssertTrue(preferencesSection.contains("t(.setupApplyWhereTitle)"))
        XCTAssertTrue(preferencesSection.contains("localEventQueueSection"))
        XCTAssertTrue(preferencesSection.contains("privacyBoundarySection"))
        XCTAssertFalse(preferencesSection.contains("DisclosureGroup"))
        XCTAssertFalse(preferencesSection.contains("advancedVisible"))
    }

    func testDashboardShowsSelectedWorkItemInPopover() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let dashboardView = try String(contentsOf: root.appendingPathComponent("Sources/Spill/TokenMetering/TokenMeteringDashboardView.swift"))

        XCTAssertTrue(dashboardView.contains("detailPanel(for: selectedSession)"))
        XCTAssertTrue(dashboardView.contains("store.selectSession(session.id)"))
        XCTAssertTrue(dashboardView.contains("store.snapshotForWorkItem(session.id)"))
        XCTAssertTrue(dashboardView.contains("title: t(.aiTool)"))
        XCTAssertTrue(dashboardView.contains("title: t(.modelBreakdown)"))
        XCTAssertTrue(dashboardView.contains("title: t(.workflowBreakdown)"))
        XCTAssertTrue(dashboardView.contains("title: t(.stageBreakdown)"))
        XCTAssertTrue(dashboardView.contains("title: t(.sourceBreakdown)"))
    }

    func testDashboardViewUsesTopToolTabsAndOptionalCalendarPicker() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let dashboardView = try String(contentsOf: root.appendingPathComponent("Sources/Spill/TokenMetering/TokenMeteringDashboardView.swift"))
        let preferencesView = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Preferences/PreferencesView.swift"))
        let dashboardStore = try String(contentsOf: root.appendingPathComponent("Sources/Spill/TokenMetering/TokenUsageDashboardStore.swift"))

        XCTAssertFalse(dashboardView.contains("private var leftRail"))
        XCTAssertFalse(dashboardView.contains("railPanel(title: t(.aiTool))"))
        XCTAssertFalse(dashboardView.contains("railPanel(title: t(.workflowFocus))"))
        XCTAssertTrue(dashboardView.contains("topFilterBar"))
        XCTAssertTrue(dashboardView.contains("topToolTab(filter)"))
        XCTAssertTrue(dashboardView.contains("store.setSelectedTool(filter.tool)"))
        XCTAssertTrue(dashboardView.contains("calendarPickerPanel"))
        XCTAssertTrue(dashboardView.contains(".popover(isPresented: $isCalendarPickerPresented"))
        XCTAssertTrue(dashboardView.contains("store.clearSelectedCalendarDay()"))
        XCTAssertTrue(dashboardView.contains("receiverPanel"))
        XCTAssertTrue(dashboardView.contains(".focusEffectDisabled()"))
        XCTAssertTrue(dashboardView.contains("private struct TokenMeteringInfoButton"))
        XCTAssertTrue(dashboardView.contains(".focusable(false)"))
        XCTAssertTrue(dashboardView.contains(".accessibilityLabel(title)"))
        XCTAssertTrue(preferencesView.contains("private func sidebarItem"))
        XCTAssertTrue(preferencesView.contains(".focusEffectDisabled()"))
        XCTAssertTrue(dashboardStore.contains("@Published private(set) var unfilteredSnapshot"))
        XCTAssertFalse(dashboardStore.contains("var unfilteredSnapshot: TokenUsageDashboardSnapshot {"))
        XCTAssertTrue(dashboardStore.contains("func clearSelectedCalendarDay()"))
        XCTAssertTrue(dashboardView.contains("TokenMeteringLiveUpdateDot"))
        XCTAssertTrue(dashboardView.contains(".contentTransition(.numericText())"))
    }

    func testOpeningTokenDashboardDismissesPanelBeforeShowingWindow() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appDelegate = try String(contentsOf: root.appendingPathComponent("Sources/Spill/App/AppDelegate.swift"))
        let dashboardView = try String(contentsOf: root.appendingPathComponent("Sources/Spill/TokenMetering/TokenMeteringDashboardView.swift"))
        let dashboardProcess = try String(contentsOf: root.appendingPathComponent("Sources/Spill/TokenMetering/TokenMeteringDashboardProcess.swift"))
        let collector = try String(contentsOf: root.appendingPathComponent("Sources/Spill/TokenMetering/TokenUsageCollectorCoordinator.swift"))

        XCTAssertTrue(appDelegate.contains("let wasPanelVisible = spillPanelController.isVisible"))
        XCTAssertTrue(appDelegate.contains("spillPanelController.hide(animated: false)"))
        XCTAssertTrue(appDelegate.contains("Task { @MainActor [weak self] in"))
        XCTAssertTrue(appDelegate.contains("self?.openTokenDashboardProcessOrFallback()"))
        XCTAssertTrue(appDelegate.contains("tokenMeteringDashboardLauncher.open"))
        XCTAssertTrue(appDelegate.contains("self?.presentTokenDashboardWindow()"))
        XCTAssertTrue(appDelegate.contains("tokenMeteringDashboardWindowController.show()"))
        XCTAssertTrue(appDelegate.contains("TokenUsageCollectorCoordinator("))
        XCTAssertTrue(appDelegate.contains("requestTokenUsageCollection(reason: \"panel_open\")"))
        XCTAssertTrue(appDelegate.contains("requestTokenUsageCollection(reason: \"dashboard_refresh\")"))
        XCTAssertTrue(appDelegate.contains("requestTokenUsageCollection(reason: \"manual_refresh\")"))
        XCTAssertTrue(appDelegate.contains("selectedTab: TokenMeteringDashboardProcess.tokenMeteringPreferencesTab"))
        XCTAssertTrue(appDelegate.contains("observeDashboardPreferenceRequests()"))
        XCTAssertTrue(appDelegate.contains("showPreferencesFromDashboardRequest"))
        XCTAssertTrue(dashboardProcess.contains("openPreferencesNotification"))
        XCTAssertTrue(dashboardProcess.contains("postOpenPreferencesRequest"))
        XCTAssertTrue(appDelegate.contains("SPILL_SMOKE_ENABLE_TOKEN_COLLECTORS"))
        XCTAssertTrue(dashboardView.contains("private let refreshAction: () -> Void"))
        XCTAssertTrue(dashboardView.contains("private let settingsAction: () -> Void"))
        XCTAssertTrue(dashboardView.contains("settingsAction: @escaping () -> Void = {}"))
        XCTAssertTrue(dashboardView.contains("refreshAction()"))
        XCTAssertTrue(collector.contains("TokenMeteringAdapterKit.defaultInstallURL(for: TokenMeteringAdapterKit.codex)"))
        XCTAssertTrue(collector.contains("runCodexImporterIfAvailable()"))
        XCTAssertTrue(collector.contains("importQueuedEventsWhileProcessRuns(process)"))
        XCTAssertFalse(collector.contains("TokenMeteringAdapterKit.claudeCode"))
        XCTAssertFalse(collector.contains("TokenMeteringAdapterKit.agy"))
    }

    func testCodexImporterStreamsInboxWhileImporterRuns() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let collector = try String(contentsOf: root.appendingPathComponent("Sources/Spill/TokenMetering/TokenUsageCollectorCoordinator.swift"))

        XCTAssertTrue(collector.contains("private func importQueuedEventsWhileProcessRuns(_ process: Process)"))
        XCTAssertTrue(collector.contains("while process.isRunning"))
        XCTAssertTrue(collector.contains("store.importQueuedEvents()"))
        XCTAssertTrue(collector.contains("Thread.sleep(forTimeInterval: importerDrainInterval)"))
        XCTAssertTrue(collector.contains("process.terminate()"))
        XCTAssertTrue(collector.contains("importerMaximumRuntime"))
        XCTAssertTrue(collector.contains("process.standardOutput = FileHandle.nullDevice"))
        XCTAssertTrue(collector.contains("process.standardError = FileHandle.nullDevice"))
    }

    func testMenuBarAITokenStatusRefreshesFromSharedStoreChanges() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appDelegate = try String(contentsOf: root.appendingPathComponent("Sources/Spill/App/AppDelegate.swift"))
        let usageStore = try String(contentsOf: root.appendingPathComponent("Sources/Spill/TokenMetering/TokenUsageStore.swift"))
        let dashboardStore = try String(contentsOf: root.appendingPathComponent("Sources/Spill/TokenMetering/TokenUsageDashboardStore.swift"))

        XCTAssertTrue(usageStore.contains("distributedEventsDidChangeNotification"))
        XCTAssertTrue(usageStore.contains("DistributedNotificationCenter.default().postNotificationName"))
        XCTAssertTrue(appDelegate.contains("TokenUsageStore.distributedEventsDidChangeNotification"))
        XCTAssertTrue(appDelegate.contains("tokenUsageEventsDidChangeFromDistributedNotification"))
        XCTAssertTrue(appDelegate.contains("private var shouldRefreshMenuBarAITokenTotal"))
        XCTAssertTrue(appDelegate.contains("settings.enabledMenuBarStatusItems.contains(.ai)"))
        XCTAssertTrue(appDelegate.contains("events: tokenUsageStore.importQueuedEvents()"))
        XCTAssertTrue(appDelegate.contains("menuBarTokenCollectionInterval"))
        XCTAssertTrue(appDelegate.contains("requestMenuBarTokenUsageCollectionIfNeeded()"))
        XCTAssertTrue(appDelegate.contains("requestTokenUsageCollection(reason: \"menu_bar_status\")"))
        XCTAssertFalse(appDelegate.contains("guard force || menuBarAITokenDayStart != dayStart else"))
        XCTAssertTrue(dashboardStore.contains("distributedEventsDidChangeObserver"))
        XCTAssertTrue(dashboardStore.contains("TokenUsageStore.distributedEventsDidChangeNotification"))
    }

    func testTokenDashboardHelperProcessContracts() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let main = try String(contentsOf: root.appendingPathComponent("Sources/Spill/App/SpillMain.swift"))
        let appDelegate = try String(contentsOf: root.appendingPathComponent("Sources/Spill/App/AppDelegate.swift"))
        let process = try String(contentsOf: root.appendingPathComponent("Sources/Spill/TokenMetering/TokenMeteringDashboardProcess.swift"))
        let launcher = try String(contentsOf: root.appendingPathComponent("Sources/Spill/TokenMetering/TokenMeteringDashboardLauncher.swift"))
        let helperDelegate = try String(contentsOf: root.appendingPathComponent("Sources/Spill/TokenMetering/TokenMeteringDashboardAppDelegate.swift"))
        let windowController = try String(contentsOf: root.appendingPathComponent("Sources/Spill/TokenMetering/TokenMeteringDashboardWindowController.swift"))
        let buildScript = try String(contentsOf: root.appendingPathComponent("scripts/build-app.sh"))
        let smokeScript = try String(contentsOf: root.appendingPathComponent("scripts/verify-runtime-smoke.sh"))

        XCTAssertTrue(main.contains("TokenMeteringDashboardProcess.isDashboardProcess"))
        XCTAssertTrue(main.contains("TokenMeteringDashboardAppDelegate()"))
        XCTAssertTrue(main.contains("application.setActivationPolicy(.regular)"))
        XCTAssertTrue(main.contains("application.setActivationPolicy(.accessory)"))
        XCTAssertTrue(process.contains(#"static let helperBundleName = "Spill Token Dashboard.app""#))
        XCTAssertTrue(process.contains(#"static let helperBundleIdentifierSuffix = ".TokenDashboard""#))
        XCTAssertTrue(launcher.contains("NSWorkspace.OpenConfiguration"))
        XCTAssertTrue(launcher.contains("workspace.openApplication(at: helperURL"))
        XCTAssertTrue(appDelegate.contains("private lazy var tokenMeteringDashboardLauncher"))
        XCTAssertTrue(appDelegate.contains("tokenMeteringDashboardLauncher.open"))

        XCTAssertTrue(helperDelegate.contains("applicationShouldTerminateAfterLastWindowClosed"))
        XCTAssertTrue(helperDelegate.contains("SPILL_TOKEN_DASHBOARD_SMOKE_READY"))
        XCTAssertTrue(helperDelegate.contains("SPILL_TOKEN_DASHBOARD_SMOKE_EXIT"))
        XCTAssertTrue(helperDelegate.contains("openMainAppTokenMeteringSettings"))
        XCTAssertTrue(helperDelegate.contains("TokenMeteringDashboardProcess.postOpenPreferencesRequest()"))
        XCTAssertFalse(helperDelegate.contains("StatusItemController("))
        XCTAssertFalse(helperDelegate.contains("AXMenuBarItemScanner("))
        XCTAssertFalse(helperDelegate.contains("HotKeyController("))
        XCTAssertFalse(helperDelegate.contains("TokenUsageBridgeServer("))
        XCTAssertFalse(helperDelegate.contains("SpillPanelController("))
        XCTAssertTrue(windowController.contains("closeAction"))
        XCTAssertTrue(windowController.contains("settingsAction"))
        XCTAssertTrue(windowController.contains("window.delegate = self"))
        XCTAssertTrue(windowController.contains("windowWillClose"))

        XCTAssertTrue(buildScript.contains(#"HELPER_APP_NAME="Spill Token Dashboard.app""#))
        XCTAssertTrue(buildScript.contains(#"HELPER_BUNDLE_ID="${BUNDLE_ID}.TokenDashboard""#))
        XCTAssertTrue(buildScript.contains(#"sign_app_bundle "$HELPER_APP_DIR" "$HELPER_BUNDLE_ID""#))
        XCTAssertTrue(smokeScript.contains("SPILL_TOKEN_DASHBOARD_STANDALONE=1"))
        XCTAssertTrue(smokeScript.contains("SPILL_TOKEN_DASHBOARD_SMOKE_READY"))
        XCTAssertTrue(smokeScript.contains("SPILL_TOKEN_DASHBOARD_SMOKE_EXIT"))
    }

    func testTokenDashboardHelperURLResolution() {
        let mainBundleURL = URL(fileURLWithPath: "/tmp/Spill.app")
        let expectedPath = "/tmp/Spill.app/Contents/Applications/Spill Token Dashboard.app"
        let resolved = TokenMeteringDashboardProcess.helperAppURL(
            mainBundleURL: mainBundleURL,
            fileExists: { $0 == expectedPath }
        )

        XCTAssertEqual(resolved?.path, expectedPath)
        XCTAssertEqual(
            TokenMeteringDashboardProcess.mainAppURLForDashboardHelper(
                helperBundleURL: URL(fileURLWithPath: expectedPath),
                fileExists: { $0 == mainBundleURL.path }
            )?.path,
            mainBundleURL.path
        )
        XCTAssertNil(TokenMeteringDashboardProcess.helperAppURL(
            mainBundleURL: mainBundleURL,
            fileExists: { _ in false }
        ))
        XCTAssertNil(TokenMeteringDashboardProcess.mainAppURLForDashboardHelper(
            helperBundleURL: mainBundleURL,
            fileExists: { _ in true }
        ))
        XCTAssertTrue(TokenMeteringDashboardProcess.isDashboardBundleIdentifier("dev.spill.Spill.TokenDashboard"))
        XCTAssertFalse(TokenMeteringDashboardProcess.isDashboardBundleIdentifier("dev.spill.Spill"))
    }

    func testTokenUsageCollectorResolvesNodeWithoutRelyingOnGUIPath() {
        let explicit = TokenUsageCollectorCoordinator.nodeExecutableURL(
            environment: [
                "SPILL_TOKEN_USAGE_NODE": "/custom/bin/node",
                "NODE_BINARY": "/ignored/node",
            ],
            isExecutableFile: { $0 == "/custom/bin/node" }
        )
        XCTAssertEqual(explicit?.path, "/custom/bin/node")

        let nodeBinary = TokenUsageCollectorCoordinator.nodeExecutableURL(
            environment: ["NODE_BINARY": "/configured/node"],
            isExecutableFile: { $0 == "/configured/node" }
        )
        XCTAssertEqual(nodeBinary?.path, "/configured/node")

        let homebrew = TokenUsageCollectorCoordinator.nodeExecutableURL(
            environment: [:],
            isExecutableFile: { $0 == "/opt/homebrew/bin/node" }
        )
        XCTAssertEqual(homebrew?.path, "/opt/homebrew/bin/node")

        let missing = TokenUsageCollectorCoordinator.nodeExecutableURL(
            environment: [:],
            isExecutableFile: { _ in false }
        )
        XCTAssertNil(missing)
    }

    @MainActor
    func testDashboardStoreAddsAndClearsLocalTestEvents() {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        let dashboardStore = dashboardStore(usageStore: usageStore)

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 0)

        dashboardStore.addLocalTestEvent()
        XCTAssertEqual(dashboardStore.snapshot.eventCount, 1)
        XCTAssertEqual(usageStore.loadEvents().count, 1)

        dashboardStore.clearLocalEvents()
        XCTAssertEqual(dashboardStore.snapshot.eventCount, 0)
        XCTAssertEqual(usageStore.loadEvents(), [])
    }

    @MainActor
    func testDashboardStoreClearsSelectedWorkItemOnly() throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        let dashboardStore = dashboardStore(usageStore: usageStore)
        let selectedEvent = Self.safeEvent(
            spanID: "span_delete_selected",
            taskType: .codeReview,
            stage: .verify
        )
        let remainingEvent = Self.safeEvent(
            spanID: "span_delete_remaining",
            taskType: .testing,
            stage: .verify
        )

        try usageStore.replaceEvents([selectedEvent, remainingEvent])
        dashboardStore.refresh()
        let selectedID = try XCTUnwrap(dashboardStore.snapshot.sessions.first { $0.title == "Testing - Verify" }?.id)
        dashboardStore.selectSession(selectedID)
        let preview = dashboardStore.clearPreview(for: .workItem(selectedID))

        XCTAssertEqual(preview.eventCount, 1)
        XCTAssertEqual(preview.totalTokens, 150)

        dashboardStore.clearEvents(in: .workItem(selectedID))

        XCTAssertEqual(usageStore.loadEvents().map(\.spanID), ["span_delete_selected"])
        XCTAssertNil(dashboardStore.selectedSessionID)
    }

    @MainActor
    func testDashboardStoreClearsToolAndCurrentScope() throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        let dashboardStore = dashboardStore(usageStore: usageStore)
        let codex = Self.safeEvent(aiTool: .codex, spanID: "span_scope_codex")
        let claude = Self.safeEvent(aiTool: .claude, spanID: "span_scope_claude")
        let agy = Self.safeEvent(aiTool: .antigravity, spanID: "span_scope_agy")

        try usageStore.replaceEvents([codex, claude, agy])
        dashboardStore.refresh()
        XCTAssertEqual(dashboardStore.clearPreview(for: .tool(.claude)).eventCount, 1)

        dashboardStore.clearEvents(in: .tool(.claude))

        XCTAssertEqual(Set(usageStore.loadEvents().map(\.spanID)), ["span_scope_codex", "span_scope_agy"])

        dashboardStore.setSelectedTool(.antigravity)
        XCTAssertEqual(dashboardStore.clearPreview(for: .currentScope).eventCount, 1)
        dashboardStore.clearEvents(in: .currentScope)

        XCTAssertEqual(usageStore.loadEvents().map(\.spanID), ["span_scope_codex"])
    }

    @MainActor
    func testDashboardStoreUnfilteredSnapshotBypassesSelectedToolFilter() throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        let dashboardStore = dashboardStore(usageStore: usageStore)

        try usageStore.appendEvent(Self.safeEvent(aiTool: .codex, spanID: "span_codex"))
        try usageStore.appendEvent(Self.safeEvent(aiTool: .claude, spanID: "span_claude"))
        dashboardStore.refresh()

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 2)
        XCTAssertEqual(dashboardStore.unfilteredSnapshot.eventCount, 2)

        dashboardStore.setSelectedTool(.claude)
        XCTAssertEqual(dashboardStore.snapshot.eventCount, 1)
        XCTAssertEqual(dashboardStore.unfilteredSnapshot.eventCount, 2)
    }

    @MainActor
    func testDashboardRefreshDoesNotDrainInbox() throws {
        let inboxURL = temporaryInboxURL()
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL(), inboxURL: inboxURL)
        let dashboardStore = dashboardStore(usageStore: usageStore)
        let event = Self.safeEvent(aiTool: .claude, spanID: "span_dashboard_inbox")
        let queuedURL = inboxURL.appendingPathComponent("001.json")

        try FileManager.default.createDirectory(
            at: inboxURL,
            withIntermediateDirectories: true
        )
        try TokenUsageSanitizer.eventData(event).write(to: queuedURL)

        dashboardStore.refresh()

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: queuedURL.path))

        usageStore.importQueuedEvents()
        dashboardStore.refresh()

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: queuedURL.path))
    }

    @MainActor
    func testDashboardStoreBuildsWorkItemSnapshotWithoutFocusingDashboard() throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        let dashboardStore = dashboardStore(usageStore: usageStore)
        let first = Self.safeEvent(
            spanID: "span_popover_first",
            taskType: .analysis,
            stage: .plan
        )
        let second = Self.safeEvent(
            spanID: "span_popover_second",
            inputTokens: 40,
            outputTokens: 20,
            taskType: .testing,
            stage: .verify,
            model: "popover-model"
        )

        try usageStore.replaceEvents([first, second])
        dashboardStore.refresh()
        let workItemID = try XCTUnwrap(dashboardStore.snapshot.sessions.first { $0.title == "Testing - Verify" }?.id)
        let itemSnapshot = dashboardStore.snapshotForWorkItem(workItemID)

        XCTAssertNil(dashboardStore.selectedSessionID)
        XCTAssertNil(dashboardStore.snapshot.selectedSession)
        XCTAssertEqual(dashboardStore.snapshot.eventCount, 2)
        XCTAssertEqual(itemSnapshot.selectedSession?.id, workItemID)
        XCTAssertEqual(itemSnapshot.eventCount, 1)
        XCTAssertEqual(itemSnapshot.modelRows.map(\.title), ["popover-model"])
    }

    @MainActor
    func testDashboardStoreMarksLiveUpdatesOnlyWhenEventDataChanges() throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        let dashboardStore = dashboardStore(usageStore: usageStore)
        let createdAt = ISO8601DateFormatter.tokenUsage.string(from: Date())

        XCTAssertEqual(dashboardStore.liveUpdateMarker, .empty)

        try usageStore.appendEvent(Self.safeEvent(
            spanID: "span_live_codex",
            inputTokens: 20,
            outputTokens: 10,
            generatedOutput: 10,
            taskType: .codeGeneration,
            stage: .implement,
            model: "gpt-live",
            latencyMS: 44,
            createdAt: createdAt
        ))
        dashboardStore.refresh()

        let sequence = dashboardStore.liveUpdateMarker.sequence
        XCTAssertGreaterThan(sequence, 0)
        XCTAssertTrue(dashboardStore.isLiveUpdated("kpi:total"))
        XCTAssertTrue(dashboardStore.isLiveUpdated("kpi:input"))
        XCTAssertTrue(dashboardStore.isLiveUpdated("kpi:output"))
        XCTAssertFalse(dashboardStore.isLiveUpdated("kpi:latency"))
        XCTAssertTrue(dashboardStore.isLiveUpdated("tool:codex"))
        XCTAssertTrue(dashboardStore.isLiveUpdated("filter:tool:codex"))
        XCTAssertTrue(dashboardStore.isLiveUpdated("filter:tool:all"))
        XCTAssertTrue(dashboardStore.isLiveUpdated("task:code_generation"))
        XCTAssertTrue(dashboardStore.isLiveUpdated("stage:implement"))
        XCTAssertTrue(dashboardStore.isLiveUpdated("model:gpt-live"))
        XCTAssertTrue(dashboardStore.isLiveUpdated("source:generated_output"))
        XCTAssertTrue(dashboardStore.isLiveUpdated("source:unknown"))

        let sessionID = try XCTUnwrap(dashboardStore.snapshot.sessions.first?.id)
        XCTAssertTrue(dashboardStore.isLiveUpdated("session:\(sessionID)"))

        dashboardStore.setDisplayMode(.percentage)
        XCTAssertEqual(dashboardStore.liveUpdateMarker.sequence, sequence)

        dashboardStore.refresh()
        XCTAssertEqual(dashboardStore.liveUpdateMarker.sequence, sequence)
    }

    @MainActor

    func testDashboardStoreRefreshesWhenUsageStoreChangesExternally() async throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        let dashboardStore = dashboardStore(usageStore: usageStore)

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 0)

        try usageStore.appendEvent(Self.safeEvent())
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 1)
        XCTAssertEqual(dashboardStore.snapshot.totalTokens, 150)
    }

    @MainActor
    func testDashboardStoreRunsLocalQueueSelfTest() async throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL(), inboxURL: temporaryInboxURL())
        let dashboardStore = dashboardStore(usageStore: usageStore)

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 0)

        await dashboardStore.runLocalQueueSelfTest()

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 1)
        XCTAssertEqual(dashboardStore.snapshot.totalTokens, 64)
        XCTAssertEqual(dashboardStore.selfTestMessage?.isSuccess, true)
        XCTAssertNil(dashboardStore.lastError)

        let event = try XCTUnwrap(usageStore.loadEvents().first)
        XCTAssertEqual(event.projectID, "project_global")
        XCTAssertEqual(event.artifactID, "artifact_selftest")
        XCTAssertEqual(event.aiTool, .codex)
        XCTAssertEqual(event.taskType, .debugging)
        XCTAssertEqual(event.stage, .verify)
        XCTAssertEqual(event.model, "spill-self-test")
        XCTAssertEqual(event.syncMode, .localOnly)
        XCTAssertEqual(event.tokenBreakdown.generatedOutput, 16)
        XCTAssertEqual(event.tokenBreakdown.repoContext, 18)
        XCTAssertEqual(event.tokenBreakdown.toolOutput, 12)
        XCTAssertEqual(event.tokenBreakdown.unknown, 0)
    }

    @MainActor
    func testDashboardStoreReportsLocalQueueSelfTestFailure() async {
        let blockedInboxURL = temporaryInboxURL()
            .deletingLastPathComponent()
            .appendingPathComponent("not-a-directory")
        try? FileManager.default.createDirectory(
            at: blockedInboxURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? Data("blocked".utf8).write(to: blockedInboxURL)
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL(), inboxURL: blockedInboxURL)
        let dashboardStore = dashboardStore(usageStore: usageStore)

        await dashboardStore.runLocalQueueSelfTest()

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 0)
        XCTAssertEqual(dashboardStore.selfTestMessage?.isSuccess, false)
        XCTAssertEqual(dashboardStore.lastError, TokenMeteringL10n.text(.queueSelfTestFailed))
    }

    func testSafeEventEncodesWithWebCompatibleKeys() throws {
        let event = Self.safeEvent()
        let data = try TokenUsageSanitizer.eventData(event)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(object?["schema_version"] as? Int, 1)
        XCTAssertEqual(object?["ai_tool"] as? String, "codex")
        XCTAssertEqual(object?["task_type"] as? String, "analysis")
        XCTAssertEqual(object?["input_tokens"] as? Int, 100)
        XCTAssertEqual(object?["output_tokens"] as? Int, 50)
        XCTAssertNil(object?["prompt"])
        XCTAssertNil(object?["command"])
    }

    func testSanitizerRejectsForbiddenTopLevelField() throws {
        let data = try jsonData([
            "schema_version": 1,
            "device_id": "device_local",
            "project_id": "project_local",
            "artifact_id": "artifact_one",
            "run_id": "run_local_01",
            "span_id": "span_local_01",
            "ai_tool": "codex",
            "task_type": "analysis",
            "stage": "plan",
            "model": "local-manual",
            "input_tokens": 100,
            "output_tokens": 50,
            "total_tokens": 150,
            "token_breakdown": Self.safeBreakdown(),
            "latency_ms": 20,
            "created_at": "2026-06-04T00:00:00.000Z",
            "sync_mode": "local_only",
            "prompt": "must not be accepted"
        ])

        XCTAssertThrowsError(try TokenUsageSanitizer.sanitizeEventJSONData(data)) { error in
            XCTAssertEqual(
                error as? TokenUsageValidationError,
                .forbiddenFieldPresent(["prompt"])
            )
        }
    }

    func testSanitizerRejectsUnknownField() throws {
        let event = Self.safeEvent()
        var object = try decodedJSONObject(from: TokenUsageSanitizer.eventData(event))
        object["display_name"] = "not allowed"

        XCTAssertThrowsError(try TokenUsageSanitizer.sanitizeEventJSONData(try jsonData(object))) { error in
            XCTAssertEqual(
                error as? TokenUsageValidationError,
                .unknownFieldPresent(["display_name"])
            )
        }
    }

    func testLegacySafeEventWithoutAIToolDecodesAsUnknown() throws {
        var object = try decodedJSONObject(from: TokenUsageSanitizer.eventData(Self.safeEvent()))
        object.removeValue(forKey: "ai_tool")

        let event = try TokenUsageSanitizer.sanitizeEventJSONData(try jsonData(object))

        XCTAssertEqual(event.aiTool, .unknown)
    }

    func testSanitizerRejectsUnknownAITool() throws {
        var object = try decodedJSONObject(from: TokenUsageSanitizer.eventData(Self.safeEvent()))
        object["ai_tool"] = "private_tool_name"

        XCTAssertThrowsError(try TokenUsageSanitizer.sanitizeEventJSONData(try jsonData(object)))
    }

    func testLegacyOllamaAIToolDecodesAsUnknown() throws {
        var object = try decodedJSONObject(from: TokenUsageSanitizer.eventData(Self.safeEvent()))
        object["ai_tool"] = "ollama"

        let event = try TokenUsageSanitizer.sanitizeEventJSONData(try jsonData(object))

        XCTAssertEqual(event.aiTool, .unknown)
    }

    func testAgyAIToolAliasDecodesAsAntigravity() throws {
        var object = try decodedJSONObject(from: TokenUsageSanitizer.eventData(Self.safeEvent()))
        object["ai_tool"] = "agy"

        let event = try TokenUsageSanitizer.sanitizeEventJSONData(try jsonData(object))

        XCTAssertEqual(event.aiTool, .antigravity)
    }

    func testSanitizerAcceptsCustomWorkflowLabels() throws {
        var object = try decodedJSONObject(from: TokenUsageSanitizer.eventData(Self.safeEvent()))
        object["task_type"] = "ux_copy_review"
        object["stage"] = "handoff_review"

        let event = try TokenUsageSanitizer.sanitizeEventJSONData(try jsonData(object))

        XCTAssertEqual(event.taskType.rawValue, "ux_copy_review")
        XCTAssertEqual(event.stage.rawValue, "handoff_review")

        let snapshot = TokenUsageDashboardSnapshot(events: [event])
        XCTAssertEqual(snapshot.taskRows.first?.title, TokenMeteringL10n.taskLabel("ux_copy_review"))
        XCTAssertEqual(snapshot.stageRows.first?.title, TokenMeteringL10n.stageLabel("handoff_review"))
    }

    func testDashboardUsesDetailedWorkflowLabels() {
        let events = [
            Self.safeEvent(
                aiTool: .codex,
                spanID: "span_review_01",
                taskType: .codeReview,
                stage: .verify
            ),
            Self.safeEvent(
                aiTool: .claude,
                spanID: "span_commit_01",
                taskType: .gitCommit,
                stage: .summarize
            ),
            Self.safeEvent(
                aiTool: .antigravity,
                spanID: "span_response_01",
                taskType: .reviewResponse,
                stage: .revise
            )
        ]

        let snapshot = TokenUsageDashboardSnapshot(events: events)
        let taskTitles = Set(snapshot.taskRows.map(\.title))

        XCTAssertTrue(taskTitles.contains(TokenMeteringL10n.taskLabel("code_review")))
        XCTAssertTrue(taskTitles.contains(TokenMeteringL10n.taskLabel("git_commit")))
        XCTAssertTrue(taskTitles.contains(TokenMeteringL10n.taskLabel("review_response")))
    }

    func testSanitizerRejectsUnsafeWorkflowLabels() throws {
        var object = try decodedJSONObject(from: TokenUsageSanitizer.eventData(Self.safeEvent()))
        object["task_type"] = "feature/login"

        XCTAssertThrowsError(try TokenUsageSanitizer.sanitizeEventJSONData(try jsonData(object)))
    }

    func testStoreHandlesAppendLoadCorruptionAndClear() throws {
        let url = temporaryEventsURL()
        let store = TokenUsageStore(fileURL: url)
        let event = Self.safeEvent()

        XCTAssertEqual(store.loadEvents(), [])
        XCTAssertEqual(try store.appendEvent(event), [event])
        XCTAssertEqual(try store.appendEvent(event), [event])
        XCTAssertEqual(store.loadEvents(), [event])

        try Data("{not-json".utf8).write(to: url)
        XCTAssertEqual(store.loadEvents(), [event])

        XCTAssertEqual(try store.replaceEvents([event]), [event])
        try store.clearEvents()
        XCTAssertEqual(store.loadEvents(), [])
    }

    func testStoreMigratesLegacyJSONEventsIntoSQLite() throws {
        let eventsURL = temporaryEventsURL()
        let store = TokenUsageStore(fileURL: eventsURL)
        let event = Self.safeEvent()
        let duplicate = Self.safeEvent()
        let secondEvent = Self.safeEvent(
            aiTool: .claude,
            spanID: "span_legacy_second",
            inputTokens: 20,
            outputTokens: 10
        )

        try FileManager.default.createDirectory(
            at: eventsURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try TokenUsageSanitizer.jsonEncoder.encode([event, duplicate, secondEvent])
        try data.write(to: eventsURL)

        XCTAssertEqual(store.loadEvents(), [])
        XCTAssertTrue(FileManager.default.fileExists(atPath: eventsURL.path))

        let events = store.importQueuedEvents()

        XCTAssertEqual(events.map(\.spanID), ["span_local_01", "span_legacy_second"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.eventsDatabaseURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: eventsURL.path))
    }

    func testStoreWritesDashboardBreakdownColumnsAndIndexes() throws {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let event = Self.safeEvent(
            aiTool: .claude,
            runID: "run_indexed",
            spanID: "span_indexed",
            inputTokens: 200,
            outputTokens: 50,
            taskType: .codeReview,
            stage: .verify,
            model: "claude-indexed"
        )

        try store.appendEvent(event)

        let rows = try sqliteRows(
            databaseURL: store.eventsDatabaseURL,
            sql: """
            SELECT run_id, task_type, stage, model, ai_tool, total_tokens
            FROM token_usage_events
            WHERE span_id = 'span_indexed'
            """,
            columnCount: 6
        )
        XCTAssertEqual(rows, [[
            "run_indexed",
            "code_review",
            "verify",
            "claude-indexed",
            "claude",
            "250"
        ]])

        let indexNames = Set(try sqliteRows(
            databaseURL: store.eventsDatabaseURL,
            sql: "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'token_usage_events'",
            columnCount: 1
        ).flatMap { $0 })
        XCTAssertTrue(indexNames.contains("idx_token_usage_events_task_type_created_at"))
        XCTAssertTrue(indexNames.contains("idx_token_usage_events_stage_created_at"))
        XCTAssertTrue(indexNames.contains("idx_token_usage_events_model_created_at"))
        XCTAssertTrue(indexNames.contains("idx_token_usage_events_run_id"))
    }

    func testStoreBackfillsDashboardBreakdownColumnsForExistingSQLiteRows() throws {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let databaseURL = store.eventsDatabaseURL
        let event = Self.safeEvent(
            aiTool: .antigravity,
            runID: "run_legacy_sqlite",
            spanID: "span_legacy_sqlite",
            inputTokens: 300,
            outputTokens: 70,
            taskType: .debugging,
            stage: .implement,
            model: "gemini-legacy"
        )

        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let database = try openSQLiteDatabase(databaseURL)
        defer { sqlite3_close(database) }
        try executeSQLite(
            """
            CREATE TABLE token_usage_events (
                span_id TEXT PRIMARY KEY NOT NULL,
                created_at TEXT NOT NULL,
                ai_tool TEXT NOT NULL,
                total_tokens INTEGER NOT NULL,
                payload_json BLOB NOT NULL
            )
            """,
            database: database
        )
        try insertLegacySQLiteEvent(event, database: database)

        XCTAssertEqual(store.loadEvents().map(\.spanID), ["span_legacy_sqlite"])

        let rows = try sqliteRows(
            databaseURL: databaseURL,
            sql: """
            SELECT run_id, task_type, stage, model
            FROM token_usage_events
            WHERE span_id = 'span_legacy_sqlite'
            """,
            columnCount: 4
        )
        XCTAssertEqual(rows, [[
            "run_legacy_sqlite",
            "debugging",
            "implement",
            "gemini-legacy"
        ]])
    }

    func testStoreDrainsQueuedInboxEventsAndDeduplicates() throws {
        let eventsURL = temporaryEventsURL()
        let inboxURL = temporaryInboxURL()
        let store = TokenUsageStore(fileURL: eventsURL, inboxURL: inboxURL)
        let storedEvent = Self.safeEvent()
        let inboxEvent = Self.safeEvent(
            aiTool: .claude,
            spanID: "span_inbox_01",
            inputTokens: 20,
            outputTokens: 10
        )

        try store.replaceEvents([storedEvent])
        try FileManager.default.createDirectory(
            at: inboxURL,
            withIntermediateDirectories: true
        )
        let duplicateURL = inboxURL.appendingPathComponent("001.json")
        let inboxEventURL = inboxURL.appendingPathComponent("002.json")
        let invalidURL = inboxURL.appendingPathComponent("003.json")
        try TokenUsageSanitizer.eventData(storedEvent).write(to: duplicateURL)
        try TokenUsageSanitizer.eventData(inboxEvent).write(to: inboxEventURL)
        try Data("{not-json".utf8).write(to: invalidURL)

        XCTAssertEqual(store.loadEvents().map(\.spanID), ["span_local_01"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: duplicateURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: inboxEventURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: invalidURL.path))

        let events = store.importQueuedEvents()

        XCTAssertEqual(events.map(\.spanID), ["span_local_01", "span_inbox_01"])
        XCTAssertEqual(events.map(\.aiTool), [.codex, .claude])
        XCTAssertEqual(store.loadEvents(), events)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.eventsDatabaseURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: eventsURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: duplicateURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: inboxEventURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: invalidURL.path))

        try store.clearEvents()
        XCTAssertEqual(store.loadEvents(), [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: eventsURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: inboxURL.path))
    }

    func testStoreCanEnqueueInboxEventAtomically() throws {
        let eventsURL = temporaryEventsURL()
        let inboxURL = temporaryInboxURL()
        let store = TokenUsageStore(fileURL: eventsURL, inboxURL: inboxURL)
        let event = Self.safeEvent(aiTool: .claude, spanID: "span_queue_01")

        try store.enqueueInboxEvent(event)

        let queuedFiles = try FileManager.default.contentsOfDirectory(
            at: inboxURL,
            includingPropertiesForKeys: nil
        )
        XCTAssertEqual(queuedFiles.filter { $0.pathExtension == "json" }.count, 1)
        XCTAssertEqual(queuedFiles.filter { $0.pathExtension == "tmp" }.count, 0)

        XCTAssertEqual(store.loadEvents(), [])
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(
                at: inboxURL,
                includingPropertiesForKeys: nil
            )
            .filter { $0.pathExtension == "json" }
            .count,
            1
        )

        XCTAssertEqual(store.importQueuedEvents(), [event])
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(
                at: inboxURL,
                includingPropertiesForKeys: nil
            )
            .filter { $0.pathExtension == "json" }
            .count,
            0
        )
    }

    func testStoreMigratesLegacyJSONLInboxOnce() throws {
        let eventsURL = temporaryEventsURL()
        let inboxURL = temporaryInboxURL()
        let store = TokenUsageStore(fileURL: eventsURL, inboxURL: inboxURL)
        let legacyURL = inboxURL
            .deletingLastPathComponent()
            .appendingPathComponent("events-inbox.jsonl")
        let event = Self.safeEvent(aiTool: .claude, spanID: "span_legacy_01")
        let line = try XCTUnwrap(String(data: TokenUsageSanitizer.eventData(event), encoding: .utf8))

        try FileManager.default.createDirectory(
            at: legacyURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("\(line)\n{not-json\n".utf8).write(to: legacyURL)

        XCTAssertEqual(store.loadEvents(), [])
        XCTAssertEqual(store.importQueuedEvents(), [event])
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyURL.path))
        XCTAssertEqual(store.loadEvents(), [event])
    }

    @MainActor
    func testTokenUsageBridgeSettingDefaultsOffAndPersists() throws {
        let suiteName = "TokenUsageBridgeSetting.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let settings = SpillSettings(defaults: defaults)
        XCTAssertFalse(settings.tokenUsageBridgeEnabled)

        settings.tokenUsageBridgeEnabled = true
        let reloadedSettings = SpillSettings(defaults: defaults)
        XCTAssertTrue(reloadedSettings.tokenUsageBridgeEnabled)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testBridgeResponsesReadAppendRejectAndClearEvents() throws {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let server = TokenUsageBridgeServer(store: store)
        let event = Self.safeEvent()
        let postResponse = server.response(for: httpRequest(
            method: "POST",
            path: "/v1/usage/events",
            body: try TokenUsageSanitizer.eventData(event)
        ))

        XCTAssertTrue(httpStatusLine(postResponse).contains("201 Created"))
        XCTAssertEqual(store.loadEvents(), [event])

        let getResponse = server.response(for: httpRequest(method: "GET", path: "/v1/usage/events"))
        XCTAssertTrue(httpStatusLine(getResponse).contains("200 OK"))
        XCTAssertTrue(String(data: getResponse, encoding: .utf8)?.contains("spill_local_app") == true)

        var unsafeObject = try decodedJSONObject(from: TokenUsageSanitizer.eventData(event))
        unsafeObject["command"] = "must not be accepted"
        let rejectedResponse = server.response(for: httpRequest(
            method: "POST",
            path: "/v1/usage/events",
            body: try jsonData(unsafeObject)
        ))
        XCTAssertTrue(httpStatusLine(rejectedResponse).contains("400 Bad Request"))
        XCTAssertEqual(store.loadEvents(), [event])

        let clearResponse = server.response(for: httpRequest(method: "DELETE", path: "/v1/usage/events"))
        XCTAssertTrue(httpStatusLine(clearResponse).contains("200 OK"))
        XCTAssertEqual(store.loadEvents(), [])
    }

    func testBridgeStartBindsLoopbackHTTPPort() async throws {
        let port = try Self.availableLoopbackPort()
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let server = TokenUsageBridgeServer(store: store, port: port)
        try server.start()
        defer {
            server.stop()
        }

        let url = try XCTUnwrap(URL(string: "http://127.0.0.1:\(port)/v1/usage/health"))
        let (data, response) = try await URLSession.shared.data(from: url)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)

        XCTAssertEqual(httpResponse.statusCode, 200)
        XCTAssertEqual(
            String(data: data, encoding: .utf8),
            #"{"status":"ok","source":"spill_local_app"}"#
        )
    }

    func testBridgeClientPostsSafeEventToLoopbackServer() async throws {
        let port = try Self.availableLoopbackPort()
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let server = TokenUsageBridgeServer(store: store, port: port)
        try server.start()
        defer {
            server.stop()
        }

        let event = Self.safeEvent()
        let client = TokenUsageBridgeClient.loopback(port: port)
        try await client.postEvent(event)

        XCTAssertEqual(store.loadEvents(), [event])
    }

    func testGlobalSetupPromptBootstrapsPublicInstaller() {
        let prompt = TokenMeteringGlobalSetup.globalPrompt

        XCTAssertTrue(prompt.contains("MANDATORY ACTION: install or repair Spill token metering now"))
        XCTAssertTrue(prompt.contains("not just a global instruction to remember later"))
        XCTAssertTrue(prompt.contains("Use the current public setup request as the source of truth"))
        XCTAssertTrue(prompt.contains(TokenMeteringGlobalSetup.setupPromptURL))
        XCTAssertTrue(prompt.contains(TokenMeteringGlobalSetup.runtimeInstructionURL))
        XCTAssertTrue(prompt.contains("You MUST run the public setup installer before doing anything else"))
        XCTAssertTrue(prompt.contains("If shell, filesystem, sandbox, or user-level config permission is required"))
        XCTAssertTrue(prompt.contains("ask for that permission and then run the installer"))
        XCTAssertTrue(prompt.contains("downloads the latest open-source Spill adapter files from spill.thdev.app"))
        XCTAssertTrue(prompt.contains("SPILL_AI_TOOL=claude"))
        XCTAssertTrue(prompt.contains("SPILL_AI_TOOL=antigravity"))
        XCTAssertTrue(prompt.contains("Spill label handoff commands"))
        XCTAssertTrue(prompt.contains("Workflow runner permissions are separate"))
        XCTAssertTrue(prompt.contains("runtime-specific exact-count input shapes"))
        XCTAssertTrue(prompt.contains("nested runtime envelopes"))
        XCTAssertTrue(prompt.contains("empty tokens objects"))
        XCTAssertTrue(prompt.contains("zero-valued token fields"))
        XCTAssertTrue(prompt.contains("structured lifecycle/tool/model-adjacent payloads"))
        XCTAssertTrue(prompt.contains("even when they include model or session hints"))
        XCTAssertTrue(prompt.contains("antigravity-last-empty.json"))
        XCTAssertTrue(prompt.contains("antigravity-last-mismatch.json"))
        XCTAssertTrue(prompt.contains("antigravity-last-success.json"))
        XCTAssertTrue(prompt.contains("Claude Code uses a different Stop-hook contract"))
        XCTAssertTrue(prompt.contains("claude-last-empty.json"))
        XCTAssertTrue(prompt.contains("claude-last-mismatch.json"))
        XCTAssertTrue(prompt.contains("claude-last-success.json"))
        XCTAssertTrue(prompt.contains("observed_safe_shape booleans only"))
        XCTAssertTrue(prompt.contains("Diagnostics must never store transcript paths"))
        XCTAssertFalse(prompt.contains("agent-preflight.py"))
        XCTAssertFalse(prompt.contains("agent-finish-check.py"))
        XCTAssertTrue(prompt.contains("~/.codex/rules/default.rules"))
        XCTAssertTrue(prompt.contains("managed prefix_rule entries"))
        XCTAssertTrue(prompt.contains("Do not use broad python3, node, or shell-wide allow rules"))
        XCTAssertTrue(prompt.contains("Workflow integration is only for better labels"))
        XCTAssertTrue(prompt.contains("per-turn fallback labels must use --if-absent"))
        XCTAssertTrue(prompt.contains("two-layer design, not a choice between modes"))
        XCTAssertTrue(prompt.contains("preserve existing UserPromptSubmit or workflow label hooks"))
        XCTAssertTrue(prompt.contains("never remove a workflow label hook"))
        XCTAssertTrue(prompt.contains("always attempt the per-turn fallback label with --if-absent"))
        XCTAssertTrue(prompt.contains("Do not configure agents or workflows to send conversation titles"))
        XCTAssertTrue(prompt.contains("Spill generates default work item names locally"))
        XCTAssertFalse(prompt.contains("Optional Local Display Names Enabled"))
        XCTAssertTrue(prompt.contains("code_review/verify"))
        XCTAssertTrue(prompt.contains("review_response/implement"))
        XCTAssertTrue(prompt.contains("uncategorized/summarize"))
        XCTAssertTrue(prompt.contains("Do you want Spill token usage to follow your workflow steps?"))
        XCTAssertTrue(prompt.contains("per-turn labels must still come from the runtime instruction"))
        XCTAssertTrue(prompt.contains("Do not add --if-absent to workflow step labels"))
        XCTAssertTrue(prompt.contains("script-based workflow entry points first"))
        XCTAssertTrue(prompt.contains("wire labels in the script first"))
        XCTAssertTrue(prompt.contains("Merge new Spill integration with the existing workflow instead of replacing it"))
        XCTAssertTrue(prompt.contains("receiver-only"))
        XCTAssertTrue(prompt.contains("write-code/edit/implement/patch -> code_generation/implement"))
        XCTAssertTrue(prompt.contains("work item titles"))
        XCTAssertTrue(prompt.contains("--label <current-tool>"))
        XCTAssertTrue(prompt.contains("Never let Claude Code or Antigravity/AGY workflow routing fall back to codex"))
        XCTAssertTrue(prompt.contains("Do not save only the runtime instruction and call the task done"))
        XCTAssertTrue(prompt.contains("Do not give manual per-adapter setup steps as the primary answer"))
        XCTAssertTrue(prompt.contains("Do not claim Spill token metering is installed until these conditions are satisfied"))
        XCTAssertTrue(prompt.contains("If workflow labels were requested, script-based workflows were checked first"))
        XCTAssertTrue(prompt.contains(#"/bin/bash -c "$(curl -fsSL https://spill.thdev.app/token-metering/install.sh)""#))
        XCTAssertTrue(prompt.contains(#""spill-metering" JSONHookSpec containing PostInvocation[]"#))
        XCTAssertTrue(prompt.contains("~/.gemini/spill-hook.py"))
        XCTAssertTrue(prompt.contains("compatibility symlink or fresh copy"))
        XCTAssertTrue(prompt.contains("matches, the canonical installed hook"))
        XCTAssertTrue(prompt.contains("Do not use a root-level PostInvocation array"))
        XCTAssertFalse(prompt.contains("workflow-setup-prompt.md"))
        XCTAssertFalse(prompt.contains("Do not nest AGY hooks under \"spill-metering\""))
        XCTAssertFalse(prompt.contains("root-level PostInvocation[] with matcher"))
    }

    func testGlobalSetupPromptCanOptIntoLocalDisplayNames() {
        let strictPrompt = TokenMeteringGlobalSetup.prompt(allowsLocalDisplayNames: false)
        let optInPrompt = TokenMeteringGlobalSetup.prompt(allowsLocalDisplayNames: true)

        XCTAssertEqual(strictPrompt, TokenMeteringGlobalSetup.globalPrompt)
        XCTAssertFalse(strictPrompt.contains("Optional Local Display Names Enabled"))
        XCTAssertTrue(optInPrompt.contains("Optional Local Display Names Enabled"))
        XCTAssertTrue(optInPrompt.contains("not active until the user reapplies this copied prompt"))
        XCTAssertTrue(optInPrompt.contains("separate from token usage data sync"))
        XCTAssertTrue(optInPrompt.contains("settings sync for this selected setting"))
        XCTAssertTrue(optInPrompt.contains("Do not send full commands or command text"))
        XCTAssertTrue(optInPrompt.contains("Do not add display aliases to the usage event JSON body"))
        XCTAssertTrue(optInPrompt.contains("Usage events must remain token-only"))
    }

    func testHostedTokenMeteringSetupDocsDefineRuntimeContract() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let setup = try String(contentsOf: root.appendingPathComponent("docs/token-metering/setup-prompt.md"))
        let runtime = try String(contentsOf: root.appendingPathComponent("docs/token-metering/runtime-instruction.md"))
        let installer = try String(contentsOf: root.appendingPathComponent("docs/token-metering/install.sh"))
        let helper = try String(contentsOf: root.appendingPathComponent("adapters/setup/spill-token-metering-setup.mjs"))
        let codexImporter = try String(contentsOf: root.appendingPathComponent("adapters/codex/spill-importer.mjs"))
        let agyHook = try String(contentsOf: root.appendingPathComponent("adapters/antigravity/spill-hook.py"))
        let bundledAgyHook = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Resources/adapters/antigravity/spill-hook.py"))
        let claudeHook = try String(contentsOf: root.appendingPathComponent("adapters/claude-code/spill-hook.py"))
        let bundledClaudeHook = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Resources/adapters/claude-code/spill-hook.py"))
        let preferencesSection = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Preferences/TokenMeteringPreferencesSection.swift"))

        XCTAssertTrue(setup.contains("MANDATORY ACTION: install or repair Spill token metering now"))
        XCTAssertTrue(setup.contains("https://spill.thdev.app/token-metering/install.sh"))
        XCTAssertTrue(setup.contains("install and repair Codex, Claude Code, and Antigravity/AGY together"))
        XCTAssertTrue(setup.contains("Codex is the OpenAI-backed agent runtime hook"))
        XCTAssertTrue(setup.contains("SPILL_AI_TOOL=claude"))
        XCTAssertTrue(setup.contains("SPILL_AI_TOOL=antigravity"))
        XCTAssertTrue(setup.contains("Spill label handoff commands"))
        XCTAssertTrue(setup.contains("Workflow runner permissions are separate"))
        XCTAssertTrue(setup.contains("common safe path spellings"))
        XCTAssertTrue(setup.contains("quoted `$HOME/...`"))
        XCTAssertTrue(setup.contains("escaped\n`Application\\ Support`"))
        XCTAssertFalse(setup.contains("agent-preflight.py"))
        XCTAssertFalse(setup.contains("agent-finish-check.py"))
        XCTAssertTrue(setup.contains("~/.codex/rules/default.rules"))
        XCTAssertTrue(setup.contains("managed `prefix_rule` entries"))
        XCTAssertTrue(setup.contains("Do not use broad `python3`, `node`,\nor shell-wide allow rules"))
        XCTAssertTrue(setup.contains("Workflow integration is\nonly for better labels"))
        XCTAssertTrue(setup.contains("per-turn fallback labels must use\n`--if-absent`"))
        XCTAssertTrue(setup.contains("two-layer design, not a choice between modes"))
        XCTAssertTrue(setup.contains("preserve existing UserPromptSubmit or workflow\nlabel hooks"))
        XCTAssertTrue(setup.contains("never remove a workflow label hook"))
        XCTAssertTrue(setup.contains("Agents should always attempt the per-turn fallback label with `--if-absent`"))
        XCTAssertTrue(setup.contains("Do not configure agents or workflows to send conversation titles"))
        XCTAssertTrue(setup.contains("Spill generates default work item names locally"))
        XCTAssertTrue(setup.contains("code_review/verify"))
        XCTAssertTrue(setup.contains("review_response/implement"))
        XCTAssertTrue(setup.contains("uncategorized/summarize"))
        XCTAssertTrue(setup.contains("Do you want Spill token usage to follow your workflow steps?"))
        XCTAssertTrue(setup.contains("per-turn labels must still\ncome from the runtime instruction"))
        XCTAssertTrue(setup.contains("Do not add `--if-absent` to workflow step labels"))
        XCTAssertTrue(setup.contains("input alias for\nthe canonical `antigravity` event label"))
        XCTAssertTrue(setup.contains("script-based workflow entry points first"))
        XCTAssertTrue(setup.contains("wire labels in the script"))
        XCTAssertTrue(setup.contains("Preserve unrelated hooks and existing workflow label hooks"))
        XCTAssertTrue(setup.contains("receiver-only integration"))
        XCTAssertTrue(setup.contains("write-code, edit, implement, patch"))
        XCTAssertTrue(setup.contains("code_generation"))
        XCTAssertTrue(setup.contains("git_commit"))
        XCTAssertTrue(setup.contains("commit_message"))
        XCTAssertTrue(setup.contains("canonical installed hook lives at `~/Library/Application Support/Spill/adapters/antigravity/spill-hook.py`"))
        XCTAssertTrue(setup.contains("`python3 '~/.gemini/spill-hook.py'`"))
        XCTAssertTrue(setup.contains("compatibility file resolves to, or matches, the canonical installed hook"))
        XCTAssertTrue(setup.contains("--label <current-tool>"))
        XCTAssertTrue(setup.contains("Never let Claude"))
        XCTAssertTrue(setup.contains("Never encode project names"))
        XCTAssertTrue(setup.contains("Never encode conversation titles"))
        XCTAssertFalse(setup.contains("workflow-setup-prompt.md"))
        XCTAssertTrue(setup.contains(#"`~/.gemini/config/hooks.json` contains a `"spill-metering"` JSONHookSpec"#))
        XCTAssertTrue(setup.contains("Do not write `PostInvocation` as a root-level array"))
        XCTAssertTrue(setup.contains("force one strict Spill output event schema"))
        XCTAssertTrue(setup.contains("shared runtime hook input schema"))
        XCTAssertTrue(setup.contains("hook payload exposes exact token usage fields"))
        XCTAssertTrue(setup.contains("normalized `spill_token_usage` object"))
        XCTAssertTrue(setup.contains("AGY may wrap those exact token fields in runtime-specific envelopes"))
        XCTAssertTrue(setup.contains("empty `tokens` object"))
        XCTAssertTrue(setup.contains("local-only safe diagnostics under Spill's token-metering diagnostics directory"))
        XCTAssertTrue(setup.contains("model-adjacent"))
        XCTAssertTrue(setup.contains("even when the payload contains model or session hints"))
        XCTAssertTrue(setup.contains("no_token_usage_payload"))
        XCTAssertTrue(setup.contains("antigravity-last-empty.json"))
        XCTAssertTrue(setup.contains("antigravity-last-mismatch.json"))
        XCTAssertTrue(setup.contains("antigravity-last-success.json"))
        XCTAssertTrue(setup.contains("claude-last-empty.json"))
        XCTAssertTrue(setup.contains("claude-last-mismatch.json"))
        XCTAssertTrue(setup.contains("claude-last-success.json"))
        XCTAssertTrue(setup.contains("observed_safe_shape"))
        XCTAssertTrue(setup.contains("Empty/no-usage diagnostics must never overwrite"))
        XCTAssertTrue(setup.contains("Claude Code diagnostic files must use the same local-only separation"))
        XCTAssertFalse(setup.contains("root-level `PostInvocation[]`"))
        XCTAssertFalse(setup.contains("Do not nest this under `\"spill-metering\"`"))

        XCTAssertTrue(runtime.contains("silent background metering instruction"))
        XCTAssertTrue(runtime.contains("Do not add Spill metering status lines to normal replies"))
        XCTAssertTrue(runtime.contains("Runtime input normalization"))
        XCTAssertTrue(runtime.contains("strict contract is the Spill output event schema"))
        XCTAssertTrue(runtime.contains("Runtime hook input formats are allowed to differ by tool"))
        XCTAssertTrue(runtime.contains("Antigravity/AGY may wrap exact usage data in nested runtime envelopes"))
        XCTAssertTrue(runtime.contains("empty `tokens` object"))
        XCTAssertTrue(runtime.contains("Antigravity/AGY `PostInvocation` hooks can execute"))
        XCTAssertTrue(runtime.contains("write a local-only diagnostic"))
        XCTAssertTrue(runtime.contains("AGY empty stdin is a normal no-event hook call"))
        XCTAssertTrue(runtime.contains("Any structured AGY payload without exact token"))
        XCTAssertTrue(runtime.contains("invalid\n  JSON or non-object payloads"))
        XCTAssertTrue(runtime.contains("antigravity-last-success.json"))
        XCTAssertTrue(runtime.contains("Claude Code uses a different Stop-hook contract"))
        XCTAssertTrue(runtime.contains("claude-last-mismatch.json"))
        XCTAssertTrue(runtime.contains("short-lived safe label context"))
        XCTAssertTrue(runtime.contains("Workflow integration is an enhancement, not a prerequisite"))
        XCTAssertTrue(runtime.contains("Workflow-provided labels win"))
        XCTAssertTrue(runtime.contains("two active layers, not as a\n  choice between modes"))
        XCTAssertTrue(runtime.contains("Do not remove, disable, or overwrite existing workflow-provided label hooks"))
        XCTAssertTrue(runtime.contains("--if-absent"))
        XCTAssertTrue(runtime.contains("Always attempt the per-turn fallback label with `--if-absent`"))
        XCTAssertTrue(runtime.contains("omit `--if-absent`"))
        XCTAssertTrue(runtime.contains("uncategorized/summarize"))
        XCTAssertTrue(runtime.contains("Never skip usage event creation only because"))
        XCTAssertTrue(runtime.contains("Use `code_review` for review-only work"))
        XCTAssertTrue(runtime.contains("Use `review_response`"))
        XCTAssertTrue(runtime.contains("Use `git_commit`"))
        XCTAssertTrue(runtime.contains("SPILL_AI_TOOL"))
        XCTAssertTrue(runtime.contains("SPILL_TOKEN_USAGE_AI_TOOL"))
        XCTAssertTrue(runtime.contains("normalized to the canonical `antigravity` event label"))
        XCTAssertTrue(runtime.contains("Never let Claude Code or Antigravity/AGY workflow routing fall back to"))
        XCTAssertTrue(runtime.contains("Workflow runner permissions are separate"))
        XCTAssertFalse(runtime.contains("agent-preflight.py"))
        XCTAssertFalse(runtime.contains("agent-finish-check.py"))
        XCTAssertTrue(runtime.contains("equivalent exact helper\npath spellings"))
        XCTAssertTrue(runtime.contains("$HOME/..."))
        XCTAssertTrue(runtime.contains(#"${HOME}/..."#))
        XCTAssertTrue(runtime.contains("quoted `$HOME/...`"))
        XCTAssertTrue(runtime.contains("task_type` is a safe lowercase workflow slug"))
        XCTAssertTrue(runtime.contains("git_commit"))
        XCTAssertTrue(runtime.contains("workflow_setup"))
        XCTAssertTrue(runtime.contains("stage` is a safe lowercase workflow slug"))
        XCTAssertTrue(runtime.contains("Do not let a short verification step overwrite an implementation-heavy task"))
        XCTAssertTrue(runtime.contains("use the stage that consumed the dominant work"))
        XCTAssertTrue(runtime.contains("generate a fresh opaque `span_id`"))
        XCTAssertTrue(runtime.contains("Do not collapse two distinct real turns"))
        XCTAssertTrue(runtime.contains("events-inbox"))
        XCTAssertTrue(runtime.contains("Never send, derive, or store conversation titles"))
        XCTAssertTrue(runtime.contains("Spill generates default work item display names locally"))
        XCTAssertTrue(runtime.contains("unknown` equal to `total_tokens`"))
        XCTAssertFalse(runtime.contains("ollama"))

        XCTAssertTrue(installer.contains("BASE_URL"))
        XCTAssertTrue(installer.contains("adapters/setup/spill-token-metering-setup.mjs"))
        XCTAssertTrue(installer.contains("adapters/codex/spill-importer.mjs"))
        XCTAssertTrue(installer.contains("adapters/claude-code/spill-hook.py"))
        XCTAssertTrue(installer.contains("adapters/antigravity/spill-hook.py"))
        XCTAssertTrue(installer.contains("--include codex,claude,antigravity"))
        XCTAssertTrue(installer.contains("--source-root \"$TMP_DIR/adapters\""))

        XCTAssertTrue(helper.contains("configureRuntimeLabelDefaults"))
        XCTAssertFalse(helper.contains("removeClaudeBaselineLabelHook"))
        XCTAssertFalse(helper.contains("cleaned_baseline_label"))
        XCTAssertFalse(helper.contains("would_cleanup_baseline_label"))
        XCTAssertFalse(helper.contains("configureAgentPlaybookRuntimeDefaults"))
        XCTAssertTrue(helper.contains("configureCodexRuntimeRules"))
        XCTAssertTrue(helper.contains(#".codex", "rules", "default.rules"#))
        XCTAssertTrue(helper.contains("prefix_rule("))
        XCTAssertTrue(helper.contains("spill-token-metering:begin"))
        XCTAssertTrue(helper.contains("SPILL_AI_TOOL"))
        XCTAssertTrue(helper.contains("SPILL_TOKEN_USAGE_AI_TOOL"))
        XCTAssertTrue(helper.contains(#""claude""#))
        XCTAssertTrue(helper.contains(#""antigravity""#))
        XCTAssertTrue(helper.contains(#".claude", "settings.json"#))
        XCTAssertTrue(helper.contains(#".gemini", "spill-hook.py"#))
        XCTAssertTrue(helper.contains(#".gemini", "antigravity-cli", "settings.json"#))
        XCTAssertFalse(helper.contains("Allow trusted AgentPlaybook"))
        XCTAssertTrue(helper.contains("permissionPathVariants"))
        XCTAssertTrue(helper.contains("homeEnvironmentPathVariants"))
        XCTAssertTrue(helper.contains("doubleQuote(path)"))
        XCTAssertTrue(preferencesSection.contains(#"compatibilityURLs: [homeURL(".gemini/spill-hook.py")]"#))
        XCTAssertTrue(preferencesSection.contains("resolvingSymlinksInPath()"))
        XCTAssertTrue(preferencesSection.contains("contentsEqual("))
        XCTAssertTrue(helper.contains("$HOME/${suffix}"))
        XCTAssertTrue(helper.contains(#"\${HOME}/${suffix}"#))
        XCTAssertTrue(helper.contains(#"normalized === "agy""#))
        XCTAssertTrue(helper.contains(#"return "antigravity""#))
        XCTAssertTrue(helper.contains("isStaleAgentRuntimePermissionEntry"))
        XCTAssertTrue(helper.contains("shellQuote(path)"))
        XCTAssertTrue(helper.contains("node ${path} --label ${tool}"))
        XCTAssertTrue(helper.contains(#"pattern: ["node", path, "--label", "codex"]"#))
        XCTAssertFalse(helper.contains("python3 scripts/${script}"))
        XCTAssertFalse(helper.contains("--agent-playbook-home"))
        XCTAssertTrue(helper.contains("--if-absent"))
        XCTAssertTrue(helper.contains("readActiveRuntimeLabel"))
        XCTAssertTrue(helper.contains(#""label_exists""#))
        XCTAssertFalse(helper.contains("dominantStageForTask"))
        XCTAssertFalse(helper.contains("implementationDominantTaskTypes"))

        XCTAssertTrue(codexImporter.contains("labelForTimestamp(runtimeLabel, latest.timestamp)"))
        XCTAssertTrue(codexImporter.contains("timestamp < label.updatedAt"))
        XCTAssertTrue(codexImporter.contains("timestamp > label.expiresAt"))
        XCTAssertTrue(codexImporter.contains("usedRuntimeLabel"))
        XCTAssertTrue(codexImporter.contains("taskType: taskTypeOverride ?? eventLabel.taskType ?? fallbackLabel.taskType"))

        XCTAssertTrue(agyHook.contains("model_name"))
        XCTAssertTrue(agyHook.contains("modelId"))
        XCTAssertTrue(agyHook.contains("modelVersion"))
        XCTAssertTrue(agyHook.contains(#""antigravity", "agy""#))
        XCTAssertTrue(agyHook.contains("usageMetadata"))
        XCTAssertTrue(agyHook.contains("totalTokenCount"))
        XCTAssertTrue(agyHook.contains("SPILL_TOKEN_USAGE_DIAGNOSTICS_DIR"))
        XCTAssertTrue(agyHook.contains("runtime_payload_mismatch"))
        XCTAssertTrue(agyHook.contains("no_usage_hook_call"))
        XCTAssertTrue(agyHook.contains("spill_token_usage"))
        XCTAssertTrue(agyHook.contains("EMPTY_DIAGNOSTIC_FILE_NAME"))
        XCTAssertTrue(agyHook.contains("MISMATCH_DIAGNOSTIC_FILE_NAME"))
        XCTAssertTrue(agyHook.contains("SUCCESS_DIAGNOSTIC_FILE_NAME"))
        XCTAssertTrue(agyHook.contains("empty_stdin_hook_call"))
        XCTAssertTrue(agyHook.contains(#""input""#))
        XCTAssertTrue(agyHook.contains(#""output""#))
        XCTAssertFalse(agyHook.contains("def _usage_metadata_total"))
        XCTAssertFalse(agyHook.contains("agentcat"))
        XCTAssertFalse(agyHook.contains("telemetry.log"))
        XCTAssertFalse(agyHook.contains("/tmp/spill-hook-debug.log"))
        XCTAssertFalse(agyHook.contains("Raw stdin"))
        XCTAssertTrue(agyHook.contains("No payload values"))
        XCTAssertEqual(agyHook, bundledAgyHook)
        XCTAssertTrue(claudeHook.contains("DIAGNOSTICS_DIR"))
        XCTAssertTrue(claudeHook.contains("claude-last-empty.json"))
        XCTAssertTrue(claudeHook.contains("claude-last-mismatch.json"))
        XCTAssertTrue(claudeHook.contains("claude-last-success.json"))
        XCTAssertTrue(claudeHook.contains("transcript_path"))
        XCTAssertTrue(claudeHook.contains("No payload values"))
        XCTAssertFalse(claudeHook.contains("traceback.print_exc"))
        XCTAssertEqual(claudeHook, bundledClaudeHook)
    }

    func testAntigravityHookAcceptsTokensInputOutputPayload() throws {
        let inboxURL = temporaryInboxURL()
        let diagnosticsURL = temporaryDiagnosticsURL()

        try runAntigravityHook(
            payload: [
                "session_id": "agySession01",
                "model": "gemini-2.5-pro",
                "tokens": [
                    "input": 100,
                    "output": 50
                ],
                "task_type": "code_generation",
                "stage": "implement"
            ],
            inboxURL: inboxURL,
            diagnosticsURL: diagnosticsURL
        )

        let events = try antigravityEventObjects(in: inboxURL)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?["input_tokens"] as? Int, 100)
        XCTAssertEqual(events.first?["output_tokens"] as? Int, 50)
        XCTAssertEqual(events.first?["total_tokens"] as? Int, 150)
        XCTAssertEqual(events.first?["ai_tool"] as? String, "antigravity")
        let success = try decodedJSONObject(
            from: Data(contentsOf: diagnosticsURL.appendingPathComponent("antigravity-last-success.json"))
        )
        XCTAssertEqual(success["kind"] as? String, "success")
        XCTAssertEqual(success["total_tokens"] as? Int, 150)
        XCTAssertNil(success["run_id"])
        XCTAssertNil(success["span_id"])
    }

    func testAntigravityHookExtractsNestedTokenPayloads() throws {
        let inboxURL = temporaryInboxURL()
        let diagnosticsURL = temporaryDiagnosticsURL()

        try runAntigravityHook(
            payload: [
                "hook_event": "PostInvocation",
                "data": [
                    "conversationId": "agyNested01",
                    "response": [
                        "modelVersion": "gemini-3.5-flash-medium",
                        "usageMetadata": [
                            "promptTokenCount": 120,
                            "candidatesTokenCount": 30
                        ]
                    ]
                ],
                "workflow": [
                    "tokens": [
                        "input": 1,
                        "output": 1
                    ]
                ],
                "task_type": "debugging",
                "stage": "implement"
            ],
            inboxURL: inboxURL,
            diagnosticsURL: diagnosticsURL
        )

        let events = try antigravityEventObjects(in: inboxURL)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?["input_tokens"] as? Int, 120)
        XCTAssertEqual(events.first?["output_tokens"] as? Int, 30)
        XCTAssertEqual(events.first?["total_tokens"] as? Int, 150)
        XCTAssertEqual(events.first?["run_id"] as? String, "agyNested01")
        XCTAssertEqual(events.first?["model"] as? String, "gemini-3.5-flash-medium")
        XCTAssertEqual(events.first?["task_type"] as? String, "debugging")
        XCTAssertEqual(events.first?["stage"] as? String, "implement")
    }

    func testAntigravityHookTreatsEmptyTokenContainersAsNoUsage() throws {
        let inboxURL = temporaryInboxURL()
        let diagnosticsURL = temporaryDiagnosticsURL()
        let emptyURL = diagnosticsURL.appendingPathComponent("antigravity-last-empty.json")

        try runAntigravityHook(
            payload: [
                "data": [
                    "conversationId": "agyEmptyTokens01",
                    "response": [
                        "modelVersion": "gemini-3.5-flash-medium",
                        "tokens": [:]
                    ]
                ]
            ],
            inboxURL: inboxURL,
            diagnosticsURL: diagnosticsURL
        )

        XCTAssertEqual(try antigravityEventObjects(in: inboxURL).count, 0)
        let empty = try decodedJSONObject(from: Data(contentsOf: emptyURL))
        XCTAssertEqual(empty["kind"] as? String, "no_usage_hook_call")
        XCTAssertEqual(empty["reason"] as? String, "no_token_usage_payload")
        let shape = try XCTUnwrap(empty["observed_safe_shape"] as? [String: Any])
        XCTAssertEqual(shape["payload_object"] as? Bool, true)
        XCTAssertEqual(shape["has_exact_input_output"] as? Bool, false)
        XCTAssertEqual(shape["has_model_hint"] as? Bool, true)
        XCTAssertEqual(shape["has_opaque_run_hint"] as? Bool, true)
    }

    func testAntigravityHookSeparatesEmptyMismatchAndSuccessDiagnostics() throws {
        let inboxURL = temporaryInboxURL()
        let diagnosticsURL = temporaryDiagnosticsURL()
        let emptyURL = diagnosticsURL.appendingPathComponent("antigravity-last-empty.json")
        let mismatchURL = diagnosticsURL.appendingPathComponent("antigravity-last-mismatch.json")
        let successURL = diagnosticsURL.appendingPathComponent("antigravity-last-success.json")

        try runAntigravityHook(rawInput: "\n", inboxURL: inboxURL, diagnosticsURL: diagnosticsURL)

        var empty = try decodedJSONObject(from: Data(contentsOf: emptyURL))
        XCTAssertEqual(empty["kind"] as? String, "empty_stdin_hook_call")
        XCTAssertEqual(empty["reason"] as? String, "empty_stdin")
        XCTAssertFalse(FileManager.default.fileExists(atPath: mismatchURL.path))

        try runAntigravityHook(
            payload: [
                "session_id": "agySession02",
                "model": "gemini-2.5-pro",
                "usage": [
                    "requests": 1
                ]
            ],
            inboxURL: inboxURL,
            diagnosticsURL: diagnosticsURL
        )

        empty = try decodedJSONObject(from: Data(contentsOf: emptyURL))
        XCTAssertEqual(empty["kind"] as? String, "no_usage_hook_call")
        XCTAssertEqual(empty["reason"] as? String, "no_token_usage_payload")
        let shape = try XCTUnwrap(empty["observed_safe_shape"] as? [String: Any])
        XCTAssertEqual(shape["payload_object"] as? Bool, true)
        XCTAssertEqual(shape["has_exact_input_output"] as? Bool, false)
        XCTAssertEqual(shape["has_model_hint"] as? Bool, true)
        XCTAssertEqual(shape["has_opaque_run_hint"] as? Bool, true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: mismatchURL.path))

        try runAntigravityHook(rawInput: "not-json", inboxURL: inboxURL, diagnosticsURL: diagnosticsURL)

        let mismatch = try decodedJSONObject(from: Data(contentsOf: mismatchURL))
        XCTAssertEqual(mismatch["kind"] as? String, "runtime_payload_mismatch")
        XCTAssertEqual(mismatch["reason"] as? String, "invalid_json")

        try runAntigravityHook(rawInput: "\n", inboxURL: inboxURL, diagnosticsURL: diagnosticsURL)

        empty = try decodedJSONObject(from: Data(contentsOf: emptyURL))
        XCTAssertEqual(empty["reason"] as? String, "empty_stdin")
        XCTAssertTrue(FileManager.default.fileExists(atPath: mismatchURL.path))

        try runAntigravityHook(
            payload: [
                "hook_event": "post_invocation",
                "phase": "tool"
            ],
            inboxURL: inboxURL,
            diagnosticsURL: diagnosticsURL
        )

        empty = try decodedJSONObject(from: Data(contentsOf: emptyURL))
        XCTAssertEqual(empty["kind"] as? String, "no_usage_hook_call")
        XCTAssertEqual(empty["reason"] as? String, "no_token_usage_payload")
        let lifecycleShape = try XCTUnwrap(empty["observed_safe_shape"] as? [String: Any])
        XCTAssertEqual(lifecycleShape["payload_object"] as? Bool, true)
        XCTAssertEqual(lifecycleShape["has_model_hint"] as? Bool, false)
        XCTAssertEqual(lifecycleShape["has_opaque_run_hint"] as? Bool, false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: mismatchURL.path))

        try runAntigravityHook(
            payload: [
                "session_id": "agySession02",
                "model": "gemini-2.5-pro",
                "usage": [
                    "input_tokens": 10,
                    "output_tokens": 5
                ]
            ],
            inboxURL: inboxURL,
            diagnosticsURL: diagnosticsURL
        )

        let success = try decodedJSONObject(from: Data(contentsOf: successURL))
        XCTAssertEqual(success["kind"] as? String, "success")
        XCTAssertEqual(success["total_tokens"] as? Int, 15)
        XCTAssertFalse(FileManager.default.fileExists(atPath: mismatchURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: diagnosticsURL.appendingPathComponent("antigravity-latest.json").path))
    }

    func testAntigravityTotalOnlyPayloadsDoNotCollideOnSameTokenCount() throws {
        let inboxURL = temporaryInboxURL()
        let diagnosticsURL = temporaryDiagnosticsURL()
        let payload: [String: Any] = [
            "session_id": "agySession03",
            "model": "gemini-2.5-pro",
            "usageMetadata": [
                "totalTokenCount": 500
            ]
        ]

        try runAntigravityHook(payload: payload, inboxURL: inboxURL, diagnosticsURL: diagnosticsURL)
        try runAntigravityHook(payload: payload, inboxURL: inboxURL, diagnosticsURL: diagnosticsURL)

        let events = try antigravityEventObjects(in: inboxURL)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(Set(events.compactMap { $0["span_id"] as? String }).count, 2)
        XCTAssertEqual(events.map { $0["input_tokens"] as? Int }, [500, 500])
        XCTAssertEqual(events.map { $0["output_tokens"] as? Int }, [0, 0])
    }

    func testClaudeHookSeparatesEmptyMismatchAndSuccessDiagnostics() throws {
        let inboxURL = temporaryInboxURL()
        let diagnosticsURL = temporaryDiagnosticsURL()
        let sessionStateURL = temporaryDiagnosticsURL().deletingLastPathComponent().appendingPathComponent("claude-session-state")
        let emptyURL = diagnosticsURL.appendingPathComponent("claude-last-empty.json")
        let mismatchURL = diagnosticsURL.appendingPathComponent("claude-last-mismatch.json")
        let successURL = diagnosticsURL.appendingPathComponent("claude-last-success.json")

        try runClaudeHook(
            rawInput: "\n",
            inboxURL: inboxURL,
            diagnosticsURL: diagnosticsURL,
            sessionStateURL: sessionStateURL
        )

        var empty = try decodedJSONObject(from: Data(contentsOf: emptyURL))
        XCTAssertEqual(empty["kind"] as? String, "empty_stdin_hook_call")
        XCTAssertEqual(empty["reason"] as? String, "empty_stdin")

        try runClaudeHook(
            rawInput: #"{"session_id":"claudeDiag01"}"#,
            inboxURL: inboxURL,
            diagnosticsURL: diagnosticsURL,
            sessionStateURL: sessionStateURL
        )

        let mismatch = try decodedJSONObject(from: Data(contentsOf: mismatchURL))
        XCTAssertEqual(mismatch["kind"] as? String, "runtime_payload_mismatch")
        XCTAssertEqual(mismatch["reason"] as? String, "missing_transcript_path")
        let shape = try XCTUnwrap(mismatch["observed_safe_shape"] as? [String: Any])
        XCTAssertEqual(shape["payload_object"] as? Bool, true)
        XCTAssertEqual(shape["has_session_id"] as? Bool, true)

        let transcriptURL = diagnosticsURL
            .deletingLastPathComponent()
            .appendingPathComponent("claude-transcript.jsonl")
        let transcript = [
            #"{"message":{"role":"user"}}"#,
            #"{"message":{"role":"assistant","model":"claude-sonnet-4","usage":{"input_tokens":20,"cache_creation_input_tokens":5,"cache_read_input_tokens":100,"output_tokens":7},"content":[{"type":"tool_use","name":"Read"}]}}"#,
        ].joined(separator: "\n")
        try "\(transcript)\n".write(to: transcriptURL, atomically: true, encoding: .utf8)
        let payload = #"{"session_id":"claudeDiag01","transcript_path":"\#(transcriptURL.path)"}"#

        try runClaudeHook(
            rawInput: payload,
            inboxURL: inboxURL,
            diagnosticsURL: diagnosticsURL,
            sessionStateURL: sessionStateURL
        )

        let success = try decodedJSONObject(from: Data(contentsOf: successURL))
        XCTAssertEqual(success["kind"] as? String, "success")
        XCTAssertEqual(success["total_tokens"] as? Int, 32)
        XCTAssertNil(success["run_id"])
        XCTAssertNil(success["span_id"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: mismatchURL.path))

        let events = try antigravityEventObjects(in: inboxURL)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?["ai_tool"] as? String, "claude")

        try runClaudeHook(
            rawInput: payload,
            inboxURL: inboxURL,
            diagnosticsURL: diagnosticsURL,
            sessionStateURL: sessionStateURL
        )

        empty = try decodedJSONObject(from: Data(contentsOf: emptyURL))
        XCTAssertEqual(empty["kind"] as? String, "no_usage_hook_call")
        XCTAssertEqual(empty["reason"] as? String, "no_new_token_delta")

        let updatedTranscript = [
            transcript,
            #"{"message":{"role":"user"}}"#,
            #"{"message":{"role":"assistant","model":"claude-sonnet-4","usage":{"input_tokens":3,"cache_creation_input_tokens":4,"output_tokens":2},"content":[{"type":"tool_use","name":"Edit"}]}}"#,
        ].joined(separator: "\n")
        try "\(updatedTranscript)\n".write(to: transcriptURL, atomically: true, encoding: .utf8)

        try runClaudeHook(
            rawInput: payload,
            inboxURL: inboxURL,
            diagnosticsURL: diagnosticsURL,
            sessionStateURL: sessionStateURL
        )

        let refreshedEvents = try antigravityEventObjects(in: inboxURL)
        XCTAssertEqual(refreshedEvents.count, 2)
        XCTAssertEqual(refreshedEvents.compactMap { $0["total_tokens"] as? Int }.sorted(), [9, 32])
        XCTAssertFalse(FileManager.default.fileExists(atPath: emptyURL.path))
    }

    func testAdapterHookConfigsUseExactRuntimeHookShapes() throws {
        let claudePath = URL(fileURLWithPath: "/tmp/Spill Support/adapters/claude-code/spill-hook.py")
        let codexPath = URL(fileURLWithPath: "/tmp/Spill Support/adapters/codex/spill-importer.mjs")
        let agyPath = URL(fileURLWithPath: "/tmp/Spill Support/adapters/antigravity/spill-hook.py")

        let claudeConfig = try XCTUnwrap(TokenMeteringAdapterKit.claudeCode.hookConfig(installedAt: claudePath))
        XCTAssertTrue(claudeConfig.contains(#""matcher": """#))
        XCTAssertTrue(claudeConfig.contains("python3 '/tmp/Spill Support/adapters/claude-code/spill-hook.py'"))
        XCTAssertTrue(claudeConfig.contains(#""timeout": 5"#))

        let codexConfig = try XCTUnwrap(TokenMeteringAdapterKit.codex.hookConfig(installedAt: codexPath))
        XCTAssertTrue(codexConfig.contains(#""hooks": {"#))
        XCTAssertTrue(codexConfig.contains(#""Stop": ["#))
        XCTAssertTrue(codexConfig.contains(#""matcher": """#))
        XCTAssertTrue(codexConfig.contains("node '/tmp/Spill Support/adapters/codex/spill-importer.mjs' --since-hours 6"))
        XCTAssertTrue(codexConfig.contains(#""timeout": 30"#))

        let agyConfig = try XCTUnwrap(TokenMeteringAdapterKit.agy.hookConfig(installedAt: agyPath))
        XCTAssertTrue(agyConfig.contains(#"named "spill-metering" hook spec"#))
        XCTAssertTrue(agyConfig.contains(#""spill-metering": {"#))
        XCTAssertTrue(agyConfig.contains(#""PostInvocation": ["#))
        XCTAssertTrue(agyConfig.contains(#""matcher": """#))
        XCTAssertTrue(agyConfig.contains("python3 '/tmp/Spill Support/adapters/antigravity/spill-hook.py'"))
        XCTAssertTrue(agyConfig.contains("root-level PostInvocation arrays are rejected"))
        XCTAssertTrue(agyConfig.contains("~/.gemini/spill-hook.py"))
        XCTAssertTrue(agyConfig.contains("compatibility symlink or fresh copy"))
        XCTAssertFalse(agyConfig.contains("Do not nest this under \"spill-metering\""))
    }

    func testAdapterInstallPathsUseHookRuntimeDirectories() {
        XCTAssertEqual(
            TokenMeteringAdapterKit.hookAdapters.map(\.aiTool),
            [.claude, .codex, .antigravity]
        )
        XCTAssertTrue(
            TokenMeteringAdapterKit.defaultInstallURL(for: TokenMeteringAdapterKit.claudeCode)
                .path
                .contains("/adapters/claude-code/spill-hook.py")
        )
        XCTAssertTrue(
            TokenMeteringAdapterKit.defaultInstallURL(for: TokenMeteringAdapterKit.codex)
                .path
                .contains("/adapters/codex/spill-importer.mjs")
        )
        XCTAssertTrue(
            TokenMeteringAdapterKit.defaultInstallURL(for: TokenMeteringAdapterKit.agy)
                .path
                .contains("/adapters/antigravity/spill-hook.py")
        )
        XCTAssertEqual(
            TokenMeteringSetupInstaller.setupCommand(),
            #"/bin/bash -c "$(curl -fsSL https://spill.thdev.app/token-metering/install.sh)""#
        )
    }

    func testDashboardSnapshotDisplayModes() {
        let event = Self.safeEvent(
            aiTool: .claude,
            spanID: "span_cost_01",
            inputTokens: 100_000,
            outputTokens: 50_000,
            taskType: .codeReview,
            stage: .verify
        )
        let events = [event]

        // 1. Tokens Mode
        let tokensSnapshot = TokenUsageDashboardSnapshot(events: events, displayMode: .tokens)
        XCTAssertEqual(tokensSnapshot.displayMode, .tokens)
        XCTAssertEqual(tokensSnapshot.totalTokens, 150_000)
        XCTAssertEqual(tokensSnapshot.kpis.first(where: { $0.id == "total" })?.value, "150K")
        XCTAssertEqual(tokensSnapshot.toolRows.first?.value, "150K")
        XCTAssertEqual(tokensSnapshot.sessions.first?.value, "150K")

        // 3. Percentage Mode
        let percentageSnapshot = TokenUsageDashboardSnapshot(events: events, displayMode: .percentage)
        XCTAssertEqual(percentageSnapshot.displayMode, .percentage)
        XCTAssertEqual(percentageSnapshot.kpis.first(where: { $0.id == "total" })?.value, "100.0%")
        XCTAssertEqual(percentageSnapshot.toolRows.first?.value, "100.0%")
        XCTAssertEqual(percentageSnapshot.sessions.first?.value, "100.0%")

        let emptyPercentageSnapshot = TokenUsageDashboardSnapshot(events: [], displayMode: .percentage)
        XCTAssertEqual(emptyPercentageSnapshot.kpis.first(where: { $0.id == "total" })?.value, "0.0%")
    }

    func testDashboardTokenFormattingCompactsLargeValuesAndKeepsSmallValues() {
        XCTAssertEqual(TokenUsageDashboardSnapshot.formatTokens(9_999), "9,999")
        XCTAssertEqual(TokenUsageDashboardSnapshot.formatTokens(10_000), "10K")
        XCTAssertEqual(TokenUsageDashboardSnapshot.formatTokens(1_439_865), "1.44M")
        XCTAssertEqual(TokenUsageDashboardSnapshot.formatTokens(282_196_651), "282.2M")
        XCTAssertEqual(TokenUsageDashboardSnapshot.formatPercentage(0), "0.0%")
        XCTAssertEqual(TokenUsageDashboardSnapshot.formatPercentage(0.04), "<0.1%")
        XCTAssertEqual(TokenUsageDashboardSnapshot.formatPercentage(1.234), "1.2%")
    }

    func testDashboardSessionRowsSortByLatestThenTokensNotLocalizedDetail() {
        let olderLarge = Self.safeEvent(
            runID: "run_older_large",
            spanID: "span_older_large",
            inputTokens: 900,
            outputTokens: 100,
            taskType: .analysis,
            stage: .plan,
            model: "model-older",
            createdAt: "2026-06-05T00:00:00.000Z"
        )
        let newerSmall = Self.safeEvent(
            runID: "run_newer_small",
            spanID: "span_newer_small",
            inputTokens: 9,
            outputTokens: 1,
            taskType: .codeReview,
            stage: .verify,
            model: "model-review",
            createdAt: "2026-06-05T00:01:00.000Z"
        )
        let sameLatestMoreTokens = Self.safeEvent(
            runID: "run_same_latest_more_tokens",
            spanID: "span_same_latest_more_tokens",
            inputTokens: 90,
            outputTokens: 10,
            taskType: .codeGeneration,
            stage: .implement,
            model: "model-codegen",
            createdAt: "2026-06-05T00:01:00.000Z"
        )

        let snapshot = TokenUsageDashboardSnapshot(events: [olderLarge, newerSmall, sameLatestMoreTokens])

        XCTAssertEqual(
            snapshot.sessions.map(\.title),
            [
                "Code generation - Implement",
                "Code review - Verify",
                "Analysis - Plan"
            ]
        )
        XCTAssertFalse(snapshot.sessions.map(\.runID).contains("run_same_latest_more_tokens"))
    }

    func testDashboardSnapshotSelectsWorkItemBySafeID() {
        let first = Self.safeEvent(
            spanID: "span_first",
            taskType: .analysis,
            stage: .plan,
            model: "model-first",
            createdAt: "2026-06-05T00:00:00.000Z"
        )
        let second = Self.safeEvent(
            spanID: "span_second",
            taskType: .codeGeneration,
            stage: .implement,
            model: "model-second",
            createdAt: "2026-06-05T00:01:00.000Z"
        )
        let initial = TokenUsageDashboardSnapshot(events: [first, second])
        XCTAssertNil(initial.selectedSession)
        let selectedID = try! XCTUnwrap(initial.sessions.first { $0.title == "Analysis - Plan" }?.id)
        let selected = TokenUsageDashboardSnapshot(events: [first, second], selectedSessionID: selectedID)

        XCTAssertEqual(selected.selectedSession?.id, selectedID)
        XCTAssertEqual(selected.selectedSession?.title, "Analysis - Plan")
        XCTAssertEqual(selected.eventCount, 1)
        XCTAssertEqual(selected.totalTokens, 150)
        XCTAssertEqual(selected.modelRows.map(\.title), ["model-first"])
    }

    func testDashboardSnapshotGroupsWorkItemsAcrossAgentTools() {
        let codex = Self.safeEvent(
            aiTool: .codex,
            spanID: "span_group_codex",
            inputTokens: 80,
            outputTokens: 20,
            taskType: .codeGeneration,
            stage: .implement,
            model: "codex-model",
            createdAt: "2026-06-05T00:00:00.000Z"
        )
        let claude = Self.safeEvent(
            aiTool: .claude,
            spanID: "span_group_claude",
            inputTokens: 30,
            outputTokens: 20,
            taskType: .codeGeneration,
            stage: .implement,
            model: "claude-model",
            createdAt: "2026-06-05T00:01:00.000Z"
        )
        let initial = TokenUsageDashboardSnapshot(events: [codex, claude])
        let session = try! XCTUnwrap(initial.sessions.first)

        XCTAssertEqual(initial.sessions.count, 1)
        XCTAssertEqual(session.title, "Code generation - Implement")
        XCTAssertEqual(session.eventCount, 2)

        let selected = TokenUsageDashboardSnapshot(events: [codex, claude], selectedSessionID: session.id)
        XCTAssertEqual(selected.eventCount, 2)
        XCTAssertEqual(selected.totalTokens, 150)
        XCTAssertEqual(selected.toolRows.map(\.title), ["Codex", "Claude"])
        XCTAssertEqual(selected.modelRows.map(\.title), ["codex-model", "claude-model"])
    }

    func testDashboardSnapshotUsesLocalLocaleAndTimeZoneForEventTimes() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Seoul"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let event = Self.safeEvent(
            createdAt: "2026-06-04T23:30:00.000Z"
        )
        let snapshot = TokenUsageDashboardSnapshot(
            events: [event],
            language: .korean,
            now: try Self.date("2026-06-05T01:00:00.000Z"),
            calendar: calendar,
            locale: Locale(identifier: "ko_KR"),
            timeZone: timeZone
        )

        let session = try XCTUnwrap(snapshot.sessions.first)
        XCTAssertTrue(session.id.contains("2026_06_05"))
        XCTAssertFalse(session.detail.contains("2026-06-04T23:30"))
        XCTAssertFalse(session.detail.contains("2026"))
        XCTAssertTrue(session.detail.contains("8:30"))
    }

    func testDashboardSnapshotBuildsCurrentMonthCalendarFromSunday() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Seoul"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = 1
        let snapshot = TokenUsageDashboardSnapshot(
            events: [
                Self.safeEvent(createdAt: "2026-05-31T15:05:00.000Z"),
                Self.safeEvent(spanID: "span_current_month", createdAt: "2026-06-04T15:05:00.000Z")
            ],
            now: try Self.date("2026-06-05T01:00:00.000Z"),
            calendar: calendar,
            locale: Locale(identifier: "ko_KR"),
            timeZone: timeZone
        )

        XCTAssertEqual(snapshot.calendarWeekdayTitles.prefix(2), ["일", "월"])
        XCTAssertEqual(snapshot.calendarMonthTitle, "2026년 6월")
        XCTAssertEqual(snapshot.todayCalendarDayID, "2026-06-05")
        XCTAssertFalse(snapshot.todayCalendarDayTitle.isEmpty)
        XCTAssertFalse(snapshot.canNavigateNextCalendarMonth)
        XCTAssertFalse(snapshot.canNavigatePreviousCalendarMonth)
        XCTAssertEqual(snapshot.calendarDays.first?.isPlaceholder, true)
        XCTAssertEqual(snapshot.calendarDays.first { !$0.isPlaceholder }?.id, "2026-06-01")
        XCTAssertTrue(snapshot.calendarDays.contains { $0.id == "2026-06-01" && $0.hasEvents })
        XCTAssertTrue(snapshot.calendarDays.contains { $0.id == "2026-06-05" && $0.hasEvents && $0.isToday })
        XCTAssertFalse(snapshot.calendarDays.contains { $0.id.hasPrefix("2026-05") && !$0.isPlaceholder })
    }

    func testDashboardSnapshotFiltersSelectedCalendarDay() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Seoul"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = 1
        let snapshot = TokenUsageDashboardSnapshot(
            events: [
                Self.safeEvent(spanID: "span_june_fifth", inputTokens: 100, outputTokens: 50, createdAt: "2026-06-04T15:05:00.000Z"),
                Self.safeEvent(spanID: "span_june_sixth", inputTokens: 400, outputTokens: 100, createdAt: "2026-06-05T15:05:00.000Z")
            ],
            selectedCalendarDayID: "2026-06-05",
            now: try Self.date("2026-06-20T01:00:00.000Z"),
            calendar: calendar,
            locale: Locale(identifier: "en_US"),
            timeZone: timeZone
        )

        XCTAssertEqual(snapshot.selectedCalendarDayID, "2026-06-05")
        XCTAssertEqual(snapshot.eventCount, 1)
        XCTAssertEqual(snapshot.totalTokens, 150)
        XCTAssertFalse(snapshot.periodFilters.contains { $0.isSelected })
        XCTAssertTrue(snapshot.calendarDays.contains { $0.id == "2026-06-05" && $0.isSelected })
        XCTAssertTrue(snapshot.calendarDays.contains { $0.id == "2026-06-06" && !$0.isSelected })
        XCTAssertNil(snapshot.comparisonTotalTokens)
    }

    func testDashboardSnapshotClampsCalendarToFirstDataMonth() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Seoul"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = 1
        let snapshot = TokenUsageDashboardSnapshot(
            events: [
                Self.safeEvent(createdAt: "2026-06-04T15:05:00.000Z")
            ],
            now: try Self.date("2026-06-20T01:00:00.000Z"),
            calendarMonthStart: try Self.date("2026-04-01T00:00:00.000Z"),
            calendar: calendar,
            locale: Locale(identifier: "en_US"),
            timeZone: timeZone
        )

        XCTAssertEqual(snapshot.calendarMonthTitle, "June 2026")
        XCTAssertFalse(snapshot.canNavigatePreviousCalendarMonth)
        XCTAssertFalse(snapshot.canNavigateNextCalendarMonth)
        XCTAssertTrue(snapshot.calendarDays.contains { $0.id == "2026-06-05" && $0.hasEvents })
    }

    private static func safeEvent(
        aiTool: TokenUsageAITool = .codex,
        runID: String = "run_local_01",
        spanID: String = "span_local_01",
        inputTokens: Int = 100,
        outputTokens: Int = 50,
        generatedOutput: Int? = nil,
        taskType: TokenUsageTaskType = .analysis,
        stage: TokenUsageStage = .plan,
        model: String = "local-manual",
        latencyMS: Int = 20,
        createdAt: String? = nil
    ) -> TokenUsageEvent {
        let resolvedCreatedAt = createdAt ?? ISO8601DateFormatter.tokenUsage.string(from: Date())
        let totalTokens = inputTokens + outputTokens
        let tokenBreakdown: TokenUsageBreakdown
        if let generatedOutput {
            tokenBreakdown = TokenUsageBreakdown(
                system: 0,
                user: 0,
                history: 0,
                repoContext: 0,
                toolOutput: 0,
                generatedOutput: generatedOutput,
                unknown: max(0, totalTokens - generatedOutput)
            )
        } else if inputTokens == 100 && outputTokens == 50 {
            tokenBreakdown = TokenUsageBreakdown(
                system: 10,
                user: 20,
                history: 20,
                repoContext: 30,
                toolOutput: 20,
                generatedOutput: 50
            )
        } else {
            tokenBreakdown = TokenUsageBreakdown(
                system: 0,
                user: 0,
                history: 0,
                repoContext: 0,
                toolOutput: 0,
                generatedOutput: 0,
                unknown: totalTokens
            )
        }
        return TokenUsageEvent(
            schemaVersion: 1,
            deviceID: "device_local",
            projectID: "project_local",
            artifactID: "artifact_one",
            runID: runID,
            spanID: spanID,
            aiTool: aiTool,
            taskType: taskType,
            stage: stage,
            model: model,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            totalTokens: totalTokens,
            tokenBreakdown: tokenBreakdown,
            latencyMS: latencyMS,
            createdAt: resolvedCreatedAt,
            syncMode: .localOnly
        )
    }

    private static func date(_ value: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter.tokenUsage.date(from: value))
    }

    private static func safeBreakdown() -> [String: Any] {
        [
            "system": 10,
            "user": 20,
            "history": 20,
            "repo_context": 30,
            "tool_output": 20,
            "generated_output": 50
        ]
    }

    private static func availableLoopbackPort() throws -> UInt16 {
        let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard socket >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        defer {
            Darwin.close(socket)
        }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Darwin.bind(
                    socket,
                    sockaddrPointer,
                    socklen_t(MemoryLayout<sockaddr_in>.size)
                )
            }
        }
        guard bindResult == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }

        var boundAddress = sockaddr_in()
        var boundAddressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &boundAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Darwin.getsockname(socket, sockaddrPointer, &boundAddressLength)
            }
        }
        guard nameResult == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }

        return UInt16(bigEndian: boundAddress.sin_port)
    }

    private func openSQLiteDatabase(_ databaseURL: URL) throws -> OpaquePointer {
        var database: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &database) == SQLITE_OK,
              let database
        else {
            defer { sqlite3_close(database) }
            throw sqliteError(database)
        }
        return database
    }

    private func executeSQLite(_ sql: String, database: OpaquePointer) throws {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw sqliteError(database)
        }
    }

    private func sqliteRows(databaseURL: URL, sql: String, columnCount: Int) throws -> [[String]] {
        let database = try openSQLiteDatabase(databaseURL)
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            throw sqliteError(database)
        }
        defer { sqlite3_finalize(statement) }

        var rows = [[String]]()
        while sqlite3_step(statement) == SQLITE_ROW {
            var row = [String]()
            for index in 0..<columnCount {
                if let text = sqlite3_column_text(statement, Int32(index)) {
                    row.append(String(cString: text))
                } else {
                    row.append("")
                }
            }
            rows.append(row)
        }
        return rows
    }

    private func insertLegacySQLiteEvent(_ event: TokenUsageEvent, database: OpaquePointer) throws {
        let sql = """
        INSERT INTO token_usage_events (
            span_id,
            created_at,
            ai_tool,
            total_tokens,
            payload_json
        ) VALUES (?, ?, ?, ?, ?)
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            throw sqliteError(database)
        }
        defer { sqlite3_finalize(statement) }

        let payload = try TokenUsageSanitizer.eventData(event)
        sqlite3_bind_text(statement, 1, event.spanID, -1, TEST_SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, event.createdAt, -1, TEST_SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 3, event.aiTool.rawValue, -1, TEST_SQLITE_TRANSIENT)
        sqlite3_bind_int64(statement, 4, sqlite3_int64(event.totalTokens))
        let result = payload.withUnsafeBytes { buffer -> Int32 in
            sqlite3_bind_blob(statement, 5, buffer.baseAddress, Int32(buffer.count), TEST_SQLITE_TRANSIENT)
            return sqlite3_step(statement)
        }

        guard result == SQLITE_DONE else {
            throw sqliteError(database)
        }
    }

    private func sqliteError(_ database: OpaquePointer?) -> NSError {
        let code = database.map { Int(sqlite3_errcode($0)) } ?? -1
        let message = database
            .flatMap { sqlite3_errmsg($0) }
            .map { String(cString: $0) }
            ?? "Unknown SQLite error"
        return NSError(
            domain: "SpillTests.SQLite",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    private func temporaryEventsURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("events.json")
    }

    @MainActor
    private func dashboardStore(usageStore: TokenUsageStore) -> TokenUsageDashboardStore {
        TokenUsageDashboardStore(usageStore: usageStore)
    }

    private func temporaryInboxURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("events-inbox", isDirectory: true)
    }

    private func temporaryDiagnosticsURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("diagnostics", isDirectory: true)
    }

    private func runAntigravityHook(
        payload: [String: Any],
        inboxURL: URL,
        diagnosticsURL: URL
    ) throws {
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let input = try XCTUnwrap(String(data: data, encoding: .utf8))
        try runAntigravityHook(rawInput: input, inboxURL: inboxURL, diagnosticsURL: diagnosticsURL)
    }

    private func runAntigravityHook(
        rawInput: String,
        inboxURL: URL,
        diagnosticsURL: URL
    ) throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let hookURL = root.appendingPathComponent("adapters/antigravity/spill-hook.py")
        let labelURL = diagnosticsURL
            .deletingLastPathComponent()
            .appendingPathComponent("label-context", isDirectory: true)
            .appendingPathComponent("antigravity.json")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", hookURL.path]
        var environment = ProcessInfo.processInfo.environment
        for key in environment.keys {
            if key.hasPrefix("ANTIGRAVITY_") || key.hasPrefix("CLAUDE_") || key.hasPrefix("SPILL_") {
                environment.removeValue(forKey: key)
            }
        }
        environment["SPILL_TOKEN_USAGE_INBOX_DIR"] = inboxURL.path
        environment["SPILL_TOKEN_USAGE_DIAGNOSTICS_DIR"] = diagnosticsURL.path
        environment["SPILL_TOKEN_USAGE_LABEL_FILE"] = labelURL.path
        environment["PYTHONPYCACHEPREFIX"] = "/tmp/spill-pycache"
        process.environment = environment

        let inputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardInput = inputPipe
        process.standardError = errorPipe

        try process.run()
        inputPipe.fileHandleForWriting.write(Data(rawInput.utf8))
        try inputPipe.fileHandleForWriting.close()
        process.waitUntilExit()

        let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        XCTAssertEqual(process.terminationStatus, 0, stderr)
    }

    private func runClaudeHook(
        rawInput: String,
        inboxURL: URL,
        diagnosticsURL: URL,
        sessionStateURL: URL
    ) throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let hookURL = root.appendingPathComponent("adapters/claude-code/spill-hook.py")
        let labelURL = diagnosticsURL
            .deletingLastPathComponent()
            .appendingPathComponent("label-context", isDirectory: true)
            .appendingPathComponent("claude.json")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", hookURL.path]
        var environment = ProcessInfo.processInfo.environment
        for key in environment.keys {
            if key.hasPrefix("ANTIGRAVITY_") || key.hasPrefix("CLAUDE_") || key.hasPrefix("SPILL_") {
                environment.removeValue(forKey: key)
            }
        }
        environment["SPILL_TOKEN_USAGE_INBOX_DIR"] = inboxURL.path
        environment["SPILL_TOKEN_USAGE_DIAGNOSTICS_DIR"] = diagnosticsURL.path
        environment["SPILL_TOKEN_USAGE_LABEL_FILE"] = labelURL.path
        environment["SPILL_TOKEN_USAGE_SESSION_STATE_DIR"] = sessionStateURL.path
        environment["PYTHONPYCACHEPREFIX"] = "/tmp/spill-pycache"
        process.environment = environment

        let inputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardInput = inputPipe
        process.standardError = errorPipe

        try process.run()
        inputPipe.fileHandleForWriting.write(Data(rawInput.utf8))
        try inputPipe.fileHandleForWriting.close()
        process.waitUntilExit()

        let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        XCTAssertEqual(process.terminationStatus, 0, stderr)
    }

    private func antigravityEventObjects(in inboxURL: URL) throws -> [[String: Any]] {
        guard FileManager.default.fileExists(atPath: inboxURL.path) else {
            return []
        }
        let files = try FileManager.default.contentsOfDirectory(
            at: inboxURL,
            includingPropertiesForKeys: nil
        )
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        return try files.map { try decodedJSONObject(from: Data(contentsOf: $0)) }
    }

    private func jsonData(_ object: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private func decodedJSONObject(from data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func httpRequest(method: String, path: String, body: Data = Data()) -> Data {
        let header = """
        \(method) \(path) HTTP/1.1\r
        Host: 127.0.0.1\r
        Content-Type: application/json\r
        Content-Length: \(body.count)\r
        \r

        """
        var request = Data(header.utf8)
        request.append(body)
        return request
    }

    private func httpStatusLine(_ response: Data) -> String {
        String(data: response, encoding: .utf8)?
            .components(separatedBy: "\r\n")
            .first ?? ""
    }
}
