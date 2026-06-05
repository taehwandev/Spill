import Foundation
import Darwin
import XCTest
@testable import Spill

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
        XCTAssertEqual(snapshot.toolRows.map(\.title), ["Codex"])
        XCTAssertEqual(snapshot.modelRows.map(\.title), ["local-manual"])
        XCTAssertEqual(snapshot.taskRows.map(\.title), [TokenMeteringL10n.taskLabel("analysis")])
        XCTAssertTrue(snapshot.sourceRows.contains { $0.title == TokenMeteringL10n.text(.sourceGeneratedOutput) && $0.value == "50" })
        XCTAssertEqual(snapshot.sessions.first?.title, "Codex - Analysis - Plan")
        XCTAssertEqual(snapshot.selectedSession?.title, "Codex - Analysis - Plan")
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
        XCTAssertEqual(claudeSnapshot.sessions.map(\.title), ["Claude - Analysis - Plan"])
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

    func testDashboardSnapshotMarksMissingLatencyAsUnavailable() {
        let snapshot = TokenUsageDashboardSnapshot(events: [
            Self.safeEvent(latencyMS: 0)
        ])

        XCTAssertEqual(snapshot.kpis.first(where: { $0.id == "latency" })?.value, TokenMeteringL10n.text(.latencyUnavailable))
        XCTAssertEqual(snapshot.kpis.first(where: { $0.id == "latency" })?.detail, TokenMeteringL10n.text(.runtimeTimingUnavailable))
        XCTAssertTrue(snapshot.sessions.first?.detail.contains(TokenMeteringL10n.text(.latencyUnavailable)) == true)
    }

    func testDashboardSourceRowsShowUnknownWhenMixedWithKnownBreakdown() {
        let snapshot = TokenUsageDashboardSnapshot(events: [
            Self.safeEvent(inputTokens: 22, outputTokens: 11, generatedOutput: 11)
        ])

        XCTAssertEqual(snapshot.totalTokens, 33)
        XCTAssertTrue(snapshot.sourceRows.contains { $0.title == TokenMeteringL10n.text(.sourceGeneratedOutput) && $0.value == "11" })
        XCTAssertTrue(snapshot.sourceRows.contains { $0.title == TokenMeteringL10n.text(.sourceUnavailable) && $0.value == "22" })
    }

    @MainActor
    func testDashboardClearActionIsVisible() {
        XCTAssertTrue(TokenMeteringDashboardView.showsClearAction)
    }

    func testDashboardViewKeepsAgentFilterRailAndSuppressesDefaultFocusBoxes() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let dashboardView = try String(contentsOf: root.appendingPathComponent("Sources/Spill/TokenMetering/TokenMeteringDashboardView.swift"))
        let preferencesView = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Preferences/PreferencesView.swift"))
        let dashboardStore = try String(contentsOf: root.appendingPathComponent("Sources/Spill/TokenMetering/TokenUsageDashboardStore.swift"))

        XCTAssertTrue(dashboardView.contains("railPanel(title: t(.aiTool))"))
        XCTAssertTrue(dashboardView.contains("store.setSelectedTool(filter.tool)"))
        XCTAssertTrue(dashboardView.contains(".focusEffectDisabled()"))
        XCTAssertTrue(preferencesView.contains("private func sidebarItem"))
        XCTAssertTrue(preferencesView.contains(".focusEffectDisabled()"))
        XCTAssertTrue(dashboardStore.contains("@Published private(set) var unfilteredSnapshot"))
        XCTAssertFalse(dashboardStore.contains("var unfilteredSnapshot: TokenUsageDashboardSnapshot {"))
        XCTAssertTrue(dashboardView.contains("TokenMeteringLiveUpdateDot"))
        XCTAssertTrue(dashboardView.contains(".contentTransition(.numericText())"))
    }

    @MainActor
    func testDashboardStoreAddsAndClearsLocalTestEvents() {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        let dashboardStore = TokenUsageDashboardStore(usageStore: usageStore)

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 0)

        dashboardStore.addLocalTestEvent()
        XCTAssertEqual(dashboardStore.snapshot.eventCount, 1)
        XCTAssertEqual(usageStore.loadEvents().count, 1)

        dashboardStore.clearLocalEvents()
        XCTAssertEqual(dashboardStore.snapshot.eventCount, 0)
        XCTAssertEqual(usageStore.loadEvents(), [])
    }

    @MainActor
    func testDashboardStoreUnfilteredSnapshotBypassesSelectedToolFilter() throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        let dashboardStore = TokenUsageDashboardStore(usageStore: usageStore)

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
    func testDashboardStoreMarksLiveUpdatesOnlyWhenEventDataChanges() throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        let dashboardStore = TokenUsageDashboardStore(usageStore: usageStore)
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
        XCTAssertTrue(dashboardStore.isLiveUpdated("kpi:latency"))
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
        let dashboardStore = TokenUsageDashboardStore(usageStore: usageStore)

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 0)

        try usageStore.appendEvent(Self.safeEvent())
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 1)
        XCTAssertEqual(dashboardStore.snapshot.totalTokens, 150)
    }

    @MainActor
    func testDashboardStoreRunsLocalQueueSelfTest() async throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL(), inboxURL: temporaryInboxURL())
        let dashboardStore = TokenUsageDashboardStore(usageStore: usageStore)

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
        let dashboardStore = TokenUsageDashboardStore(usageStore: usageStore)

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
        XCTAssertEqual(store.loadEvents(), [event])

        try Data("{not-json".utf8).write(to: url)
        XCTAssertEqual(store.loadEvents(), [])

        XCTAssertEqual(try store.replaceEvents([event]), [event])
        try store.clearEvents()
        XCTAssertEqual(store.loadEvents(), [])
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

        let events = store.loadEvents()

        XCTAssertEqual(events.map(\.spanID), ["span_local_01", "span_inbox_01"])
        XCTAssertEqual(events.map(\.aiTool), [.codex, .claude])
        XCTAssertEqual(store.loadEvents(), events)
        XCTAssertTrue(FileManager.default.fileExists(atPath: eventsURL.path))
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

        XCTAssertEqual(store.loadEvents(), [event])
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

        XCTAssertEqual(store.loadEvents(), [event])
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
        XCTAssertFalse(prompt.contains("agent-preflight.py"))
        XCTAssertFalse(prompt.contains("agent-finish-check.py"))
        XCTAssertTrue(prompt.contains("~/.codex/rules/default.rules"))
        XCTAssertTrue(prompt.contains("managed prefix_rule entries"))
        XCTAssertTrue(prompt.contains("Do not use broad python3, node, or shell-wide allow rules"))
        XCTAssertTrue(prompt.contains("Workflow integration is only for better labels"))
        XCTAssertTrue(prompt.contains("per-turn fallback labels must use --if-absent"))
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
        let agyHook = try String(contentsOf: root.appendingPathComponent("adapters/antigravity/spill-hook.py"))
        let bundledAgyHook = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Resources/adapters/antigravity/spill-hook.py"))

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
        XCTAssertTrue(setup.contains("receiver-only integration"))
        XCTAssertTrue(setup.contains("write-code, edit, implement, patch"))
        XCTAssertTrue(setup.contains("code_generation"))
        XCTAssertTrue(setup.contains("git_commit"))
        XCTAssertTrue(setup.contains("commit_message"))
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
        XCTAssertTrue(setup.contains("local-only safe diagnostic"))
        XCTAssertTrue(setup.contains("antigravity-latest.json"))
        XCTAssertTrue(setup.contains("observed_safe_shape"))
        XCTAssertTrue(setup.contains("Low-information diagnostics such as `empty_stdin` must not overwrite"))
        XCTAssertFalse(setup.contains("root-level `PostInvocation[]`"))
        XCTAssertFalse(setup.contains("Do not nest this under `\"spill-metering\"`"))

        XCTAssertTrue(runtime.contains("silent background metering instruction"))
        XCTAssertTrue(runtime.contains("Do not add Spill metering status lines to normal replies"))
        XCTAssertTrue(runtime.contains("Runtime input normalization"))
        XCTAssertTrue(runtime.contains("strict contract is the Spill output event schema"))
        XCTAssertTrue(runtime.contains("Runtime hook input formats are allowed to differ by tool"))
        XCTAssertTrue(runtime.contains("Antigravity/AGY `PostInvocation` hooks can execute"))
        XCTAssertTrue(runtime.contains("write a local-only diagnostic"))
        XCTAssertTrue(runtime.contains("short-lived safe label context"))
        XCTAssertTrue(runtime.contains("Workflow integration is an enhancement, not a prerequisite"))
        XCTAssertTrue(runtime.contains("Workflow-provided labels win"))
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
        XCTAssertTrue(helper.contains(#".gemini", "antigravity-cli", "settings.json"#))
        XCTAssertFalse(helper.contains("Allow trusted AgentPlaybook"))
        XCTAssertTrue(helper.contains("permissionPathVariants"))
        XCTAssertTrue(helper.contains("homeEnvironmentPathVariants"))
        XCTAssertTrue(helper.contains("doubleQuote(path)"))
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

        XCTAssertTrue(agyHook.contains("model_name"))
        XCTAssertTrue(agyHook.contains("modelId"))
        XCTAssertTrue(agyHook.contains("modelVersion"))
        XCTAssertTrue(agyHook.contains(#""antigravity", "agy""#))
        XCTAssertTrue(agyHook.contains("usageMetadata"))
        XCTAssertTrue(agyHook.contains("totalTokenCount"))
        XCTAssertTrue(agyHook.contains("SPILL_TOKEN_USAGE_DIAGNOSTICS_DIR"))
        XCTAssertTrue(agyHook.contains("runtime_payload_mismatch"))
        XCTAssertTrue(agyHook.contains("missing_exact_token_usage"))
        XCTAssertTrue(agyHook.contains("spill_token_usage"))
        XCTAssertTrue(agyHook.contains("DIAGNOSTIC_FILE_NAME"))
        XCTAssertTrue(agyHook.contains(#""input""#))
        XCTAssertTrue(agyHook.contains(#""output""#))
        XCTAssertFalse(agyHook.contains("def _usage_metadata_total"))
        XCTAssertTrue(agyHook.contains("No payload values"))
        XCTAssertEqual(agyHook, bundledAgyHook)
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
        XCTAssertFalse(FileManager.default.fileExists(atPath: diagnosticsURL.appendingPathComponent("antigravity-latest.json").path))
    }

    func testAntigravityHookPreservesMissingUsageDiagnosticOverEmptyStdin() throws {
        let inboxURL = temporaryInboxURL()
        let diagnosticsURL = temporaryDiagnosticsURL()
        let diagnosticURL = diagnosticsURL.appendingPathComponent("antigravity-latest.json")

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

        var diagnostic = try decodedJSONObject(from: Data(contentsOf: diagnosticURL))
        XCTAssertEqual(diagnostic["reason"] as? String, "missing_exact_token_usage")
        let shape = try XCTUnwrap(diagnostic["observed_safe_shape"] as? [String: Any])
        XCTAssertEqual(shape["payload_object"] as? Bool, true)
        XCTAssertEqual(shape["has_exact_input_output"] as? Bool, false)

        try runAntigravityHook(rawInput: "\n", inboxURL: inboxURL, diagnosticsURL: diagnosticsURL)

        diagnostic = try decodedJSONObject(from: Data(contentsOf: diagnosticURL))
        XCTAssertEqual(diagnostic["reason"] as? String, "missing_exact_token_usage")
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
        XCTAssertEqual(tokensSnapshot.kpis.first(where: { $0.id == "total" })?.value, "150,000")
        XCTAssertEqual(tokensSnapshot.toolRows.first?.value, "150,000")
        XCTAssertEqual(tokensSnapshot.sessions.first?.value, "150,000")

        // 3. Percentage Mode
        let percentageSnapshot = TokenUsageDashboardSnapshot(events: events, displayMode: .percentage)
        XCTAssertEqual(percentageSnapshot.displayMode, .percentage)
        XCTAssertEqual(percentageSnapshot.kpis.first(where: { $0.id == "total" })?.value, "100.0%")
        XCTAssertEqual(percentageSnapshot.toolRows.first?.value, "100.0%")
        XCTAssertEqual(percentageSnapshot.sessions.first?.value, "100.0%")

        let emptyPercentageSnapshot = TokenUsageDashboardSnapshot(events: [], displayMode: .percentage)
        XCTAssertEqual(emptyPercentageSnapshot.kpis.first(where: { $0.id == "total" })?.value, "0.0%")
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
                "Codex - Code generation - Implement",
                "Codex - Code review - Verify",
                "Codex - Analysis - Plan"
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
        let selectedID = try! XCTUnwrap(initial.sessions.first { $0.title == "Codex - Analysis - Plan" }?.id)
        let selected = TokenUsageDashboardSnapshot(events: [first, second], selectedSessionID: selectedID)

        XCTAssertEqual(selected.selectedSession?.id, selectedID)
        XCTAssertEqual(selected.selectedSession?.title, "Codex - Analysis - Plan")
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
        createdAt: String = "2026-06-05T00:00:00.000Z"
    ) -> TokenUsageEvent {
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
            createdAt: createdAt,
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

    private func temporaryEventsURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("events.json")
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
