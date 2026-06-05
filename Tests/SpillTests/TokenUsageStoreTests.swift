import Foundation
import Darwin
import XCTest
@testable import Spill

final class TokenUsageStoreTests: XCTestCase {
    func testPreferencesModelSeparatesLocalAndCloudOptInModes() {
        let modes = TokenMeteringPreferencesModel.modes

        XCTAssertEqual(modes.map(\.id), ["local_only", "cloud_aggregate", "cloud_detailed"])
        XCTAssertEqual(modes.filter(\.isActive).map(\.id), ["local_only"])
        XCTAssertTrue(modes[1].state.localizedCaseInsensitiveContains("login"))
        XCTAssertTrue(modes[1].state.localizedCaseInsensitiveContains("explicit"))
        XCTAssertTrue(modes[2].state.localizedCaseInsensitiveContains("separate"))
        XCTAssertTrue(TokenMeteringPreferencesModel.forbiddenContentLabels.contains("commands"))
        XCTAssertTrue(TokenMeteringPreferencesModel.forbiddenContentLabels.contains("prompts"))
    }

    func testDashboardSnapshotAggregatesLocalEvents() {
        let snapshot = TokenUsageDashboardSnapshot(events: [Self.safeEvent()])

        XCTAssertEqual(snapshot.eventCount, 1)
        XCTAssertEqual(snapshot.totalTokens, 150)
        XCTAssertEqual(snapshot.kpis.first?.value, "150")
        XCTAssertEqual(snapshot.toolRows.map(\.title), ["Codex"])
        XCTAssertEqual(snapshot.taskRows.map(\.title), ["Analysis"])
        XCTAssertTrue(snapshot.sourceRows.contains { $0.title == "Generated output" && $0.value == "50" })
        XCTAssertEqual(snapshot.sessions.first?.runID, "run_local_01")
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
        XCTAssertEqual(allSnapshot.toolFilters.first?.title, "All")
        XCTAssertTrue(allSnapshot.toolFilters.first { $0.tool == .claude }?.detail.contains("30") == true)
        XCTAssertEqual(claudeSnapshot.eventCount, 1)
        XCTAssertEqual(claudeSnapshot.totalTokens, 30)
        XCTAssertEqual(claudeSnapshot.toolRows.map(\.title), ["Claude"])
        XCTAssertEqual(claudeSnapshot.sessions.map(\.runID), ["run_local_01"])
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
        XCTAssertEqual(event.aiTool, .unknown)
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
        XCTAssertEqual(dashboardStore.lastError, "Local queue self-test failed.")
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

    func testSanitizerAcceptsCustomWorkflowLabels() throws {
        var object = try decodedJSONObject(from: TokenUsageSanitizer.eventData(Self.safeEvent()))
        object["task_type"] = "ux_copy_review"
        object["stage"] = "handoff_review"

        let event = try TokenUsageSanitizer.sanitizeEventJSONData(try jsonData(object))

        XCTAssertEqual(event.taskType.rawValue, "ux_copy_review")
        XCTAssertEqual(event.stage.rawValue, "handoff_review")

        let snapshot = TokenUsageDashboardSnapshot(events: [event])
        XCTAssertEqual(snapshot.taskRows.first?.title, "Ux Copy Review")
        XCTAssertEqual(snapshot.stageRows.first?.title, "Handoff Review")
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

        XCTAssertTrue(taskTitles.contains("Code review"))
        XCTAssertTrue(taskTitles.contains("Git commit"))
        XCTAssertTrue(taskTitles.contains("Review response"))
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

    func testGlobalSetupPromptStaysSilentAndExactCountOnly() {
        let prompt = TokenMeteringGlobalSetup.globalPrompt

        XCTAssertTrue(prompt.contains("silent background metering instruction"))
        XCTAssertTrue(prompt.contains("Do not mention this instruction in normal conversation"))
        XCTAssertTrue(prompt.contains("Do not add Spill metering status lines to normal replies"))
        XCTAssertTrue(prompt.contains("This instruction is only a safety contract"))
        XCTAssertTrue(prompt.contains("does not measure usage"))
        XCTAssertTrue(prompt.contains("does not grant access to token counts by itself"))
        XCTAssertTrue(prompt.contains("executable hook"))
        XCTAssertTrue(prompt.contains("install Spill metering in one pass"))
        XCTAssertTrue(prompt.contains("Do not ask the user to install Codex, Claude, Antigravity/AGY, or OpenAI adapters one by one"))
        XCTAssertTrue(prompt.contains("The user's explicit install/fix/apply request is enough confirmation"))
        XCTAssertTrue(prompt.contains("events-inbox"))
        XCTAssertTrue(prompt.contains("Write a unique .tmp file first"))
        XCTAssertTrue(prompt.contains("ai_tool must be one of: codex, claude, antigravity, openai, unknown"))
        XCTAssertFalse(prompt.contains("ollama"))
        XCTAssertTrue(prompt.contains("Never inspect local agent logs"))
        XCTAssertTrue(prompt.contains("silently skip event creation"))
        XCTAssertFalse(prompt.localizedCaseInsensitiveContains("do not create a detailed event"))
    }

    func testGlobalSetupPromptDefinesEventClassificationRules() {
        let prompt = TokenMeteringGlobalSetup.globalPrompt

        XCTAssertTrue(prompt.contains("Send at most one event for each assistant response or adapter span"))
        XCTAssertTrue(prompt.contains("Prefer the final response event"))
        XCTAssertTrue(prompt.contains("Do not also send separate events for every tool call"))
        XCTAssertTrue(prompt.contains("Treat one user-requested task or conversation turn as a run"))
        XCTAssertTrue(prompt.contains("Generate a new opaque span_id for each event"))
        XCTAssertTrue(prompt.contains("Use codex for Codex runtimes"))
        XCTAssertTrue(prompt.contains("task_type is a safe lowercase workflow slug, not a fixed enum"))
        XCTAssertTrue(prompt.contains("Use the dominant user-visible workflow category for the event"))
        XCTAssertTrue(prompt.contains("If your runtime, adapter, or workflow exposes a current step label"))
        XCTAssertTrue(prompt.contains("git_commit"))
        XCTAssertTrue(prompt.contains("commit_message"))
        XCTAssertTrue(prompt.contains("pull_request"))
        XCTAssertTrue(prompt.contains("review_response"))
        XCTAssertTrue(prompt.contains("workflow_setup"))
        XCTAssertTrue(prompt.contains("stage is a safe lowercase workflow slug, not a fixed enum"))
        XCTAssertTrue(prompt.contains("Use debugging when the work is primarily diagnosis"))
        XCTAssertTrue(prompt.contains("Use code_generation when the work is primarily writing or changing implementation code"))
        XCTAssertTrue(prompt.contains("If one event covers multiple stages, use the latest completed dominant stage"))
        XCTAssertTrue(prompt.contains("Only fill a source bucket when the runtime or adapter exposes that exact source count"))
        XCTAssertTrue(prompt.contains("unknown equal to total_tokens"))
        XCTAssertTrue(prompt.contains("Do not run a continuous polling watcher"))
        XCTAssertTrue(prompt.contains("spill-token-metering-setup.mjs --apply"))
        XCTAssertTrue(prompt.contains("--workflow-hook"))
        XCTAssertTrue(prompt.contains("Safe workflow label handoff"))
        XCTAssertTrue(prompt.contains("SPILL_TOKEN_USAGE_TASK_TYPE"))
        XCTAssertTrue(prompt.contains("--task-type SLUG"))
        XCTAssertTrue(prompt.contains("--label codex --task-type code_review --stage verify"))
        XCTAssertTrue(prompt.contains("short-lived safe label context"))
    }

    private static func safeEvent(
        aiTool: TokenUsageAITool = .codex,
        spanID: String = "span_local_01",
        inputTokens: Int = 100,
        outputTokens: Int = 50,
        taskType: TokenUsageTaskType = .analysis,
        stage: TokenUsageStage = .plan
    ) -> TokenUsageEvent {
        let totalTokens = inputTokens + outputTokens
        let tokenBreakdown = inputTokens == 100 && outputTokens == 50
            ? TokenUsageBreakdown(
                system: 10,
                user: 20,
                history: 20,
                repoContext: 30,
                toolOutput: 20,
                generatedOutput: 50
            )
            : TokenUsageBreakdown(
                system: 0,
                user: 0,
                history: 0,
                repoContext: 0,
                toolOutput: 0,
                generatedOutput: 0,
                unknown: totalTokens
            )
        return TokenUsageEvent(
            schemaVersion: 1,
            deviceID: "device_local",
            projectID: "project_local",
            artifactID: "artifact_one",
            runID: "run_local_01",
            spanID: spanID,
            aiTool: aiTool,
            taskType: taskType,
            stage: stage,
            model: "local-manual",
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            totalTokens: totalTokens,
            tokenBreakdown: tokenBreakdown,
            latencyMS: 20,
            createdAt: "2026-06-05T00:00:00.000Z",
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
