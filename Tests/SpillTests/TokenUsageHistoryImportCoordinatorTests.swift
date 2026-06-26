import Foundation
import XCTest
@testable import Spill

final class TokenUsageHistoryImportCoordinatorTests: XCTestCase {
    func testHistoryImportProcessRunnerUsesFiniteHardKillPath() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let source = try String(
            contentsOf: root.appendingPathComponent(
                "Sources/Spill/TokenMetering/HistoryImport/TokenUsageHistoryImportProcessRunner.swift"
            )
        )

        XCTAssertTrue(source.contains("process.terminationHandler"))
        XCTAssertTrue(source.contains("terminateProcess(process, terminationSemaphore: terminationSemaphore)"))
        XCTAssertTrue(source.contains("SIGKILL"))
        XCTAssertFalse(source.contains("process.waitUntilExit()"))
        XCTAssertFalse(source.contains("readDataToEndOfFile()"))
    }

    func testClaudeHistoryStateSyncReplacesExistingLiveStateFile() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let source = try String(
            contentsOf: root.appendingPathComponent(
                "Sources/Spill/TokenMetering/HistoryImport/TokenUsageHistoryImportCoordinator+StateSync.swift"
            )
        )

        XCTAssertTrue(source.contains("replaceItemAt(liveFile, withItemAt: tmpFile)"))
        XCTAssertFalse(source.contains("moveItem(at: tmpFile, to: liveFile)) != nil"))
    }

    func testFirstExplicitImportAttemptsCodexClaudeAndAntigravityWithFullHistory() throws {
        let fixture = try HistoryImportFixture()
        let recorder = HistoryImportRecorder()
        let coordinator = fixture.makeCoordinator(recorder: recorder)

        coordinator.startImport()
        waitForHistoryImport(coordinator)

        let calls = recorder.processCalls
        XCTAssertEqual(calls.count, 2)
        XCTAssertEqual(calls[0].arguments.first, fixture.codexImporterURL.path)
        XCTAssertTrue(calls[0].arguments.contains("--all"))
        XCTAssertTrue(calls[0].arguments.contains("--json"))
        XCTAssertEqual(calls[1].arguments.first, fixture.claudeHookURL.path)
        XCTAssertTrue(calls[1].arguments.contains("--scan-dir"))
        XCTAssertTrue(calls[1].arguments.contains("--all"))
        XCTAssertTrue(calls[1].arguments.contains("--json"))

        let agyDates = recorder.antigravityStartDates
        XCTAssertEqual(agyDates.count, 1)
        XCTAssertLessThan(agyDates[0].timeIntervalSince1970, -1_000_000_000)

        XCTAssertFalse(coordinator.snapshot.isRunning)
        XCTAssertEqual(coordinator.snapshot.tools.map(\.tool), [.codex, .claude, .antigravity])
        XCTAssertEqual(coordinator.snapshot.tools.map(\.state), [.completed, .completed, .completed])
        XCTAssertEqual(coordinator.snapshot.tools.map(\.mode), [.firstImport, .firstImport, .firstImport])
        XCTAssertEqual(coordinator.snapshot.tools.map(\.importedEvents), [2, 2, 3])
    }

    func testLaterExplicitImportReconcilesFullHistoryForAllTools() throws {
        let fixture = try HistoryImportFixture()
        let recorder = HistoryImportRecorder()
        let coordinator = fixture.makeCoordinator(recorder: recorder)

        coordinator.startImport()
        waitForHistoryImport(coordinator)
        recorder.reset()

        coordinator.startImport()
        waitForHistoryImport(coordinator)

        let calls = recorder.processCalls
        XCTAssertEqual(calls.count, 2)
        XCTAssertTrue(calls[0].arguments.contains("--all"))
        XCTAssertFalse(calls[0].arguments.contains("--since-hours"))
        XCTAssertTrue(calls[1].arguments.contains("--all"))
        XCTAssertFalse(calls[1].arguments.contains("--since-hours"))

        let agyDates = recorder.antigravityStartDates
        XCTAssertEqual(agyDates.count, 1)
        XCTAssertLessThan(agyDates[0].timeIntervalSince1970, -1_000_000_000)
        XCTAssertEqual(coordinator.snapshot.tools.map(\.mode), [.firstImport, .firstImport, .firstImport])
    }

    func testExplicitImportPreservesExistingDashboardToolEventsDuringReconciliation() throws {
        let fixture = try HistoryImportFixture()
        let recorder = HistoryImportRecorder()
        let coordinator = fixture.makeCoordinator(recorder: recorder)

        try fixture.store.appendEvent(Self.event(aiTool: .codex, spanID: "span_old_codex"))
        try fixture.store.appendEvent(Self.event(aiTool: .claude, spanID: "span_old_claude"))
        try fixture.store.appendEvent(Self.event(aiTool: .antigravity, spanID: "span_old_agy"))
        try fixture.store.appendEvent(Self.event(aiTool: .openAI, spanID: "span_keep_openai"))

        coordinator.startImport()
        waitForHistoryImport(coordinator)

        XCTAssertEqual(
            fixture.store.loadEvents().map(\.spanID).sorted(),
            ["span_keep_openai", "span_old_agy", "span_old_claude", "span_old_codex"]
        )
    }

    func testExplicitImportResetsHistoryCursorStateBeforeFullReconciliation() throws {
        let fixture = try HistoryImportFixture()
        let recorder = HistoryImportRecorder()
        let coordinator = fixture.makeCoordinator(recorder: recorder)
        let codexState = fixture.historyStateDirectory.appendingPathComponent("codex-session-import-state.json")
        let agyState = fixture.historyStateDirectory.appendingPathComponent("antigravity-active-importer-state.json")
        let claudeStateDirectory = fixture.historyStateDirectory.appendingPathComponent("claude-session-state", isDirectory: true)
        let claudeState = claudeStateDirectory.appendingPathComponent("abcdef.json")
        try FileManager.default.createDirectory(at: claudeStateDirectory, withIntermediateDirectories: true)
        try #"{"sentSpanIDs":["span_old"]}"#.write(to: codexState, atomically: true, encoding: .utf8)
        try #"{"max_generation_index_by_source":{"abcdef123456abcdef123456":42}}"#.write(to: agyState, atomically: true, encoding: .utf8)
        try #"{"fresh":100,"output":10,"byte_offset":999}"#.write(to: claudeState, atomically: true, encoding: .utf8)

        coordinator.startImport()
        waitForHistoryImport(coordinator)

        XCTAssertFalse(FileManager.default.fileExists(atPath: codexState.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: agyState.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: claudeState.path))
    }

    func testPerToolImportOnlyRunsAndPreservesExistingEvents() throws {
        let fixture = try HistoryImportFixture()
        let recorder = HistoryImportRecorder()
        let coordinator = fixture.makeCoordinator(recorder: recorder)

        try fixture.store.appendEvent(Self.event(aiTool: .codex, spanID: "span_keep_codex"))
        try fixture.store.appendEvent(Self.event(aiTool: .claude, spanID: "span_clear_claude"))
        try fixture.store.appendEvent(Self.event(aiTool: .antigravity, spanID: "span_keep_agy"))
        try fixture.store.appendEvent(Self.event(aiTool: .openAI, spanID: "span_keep_openai"))

        coordinator.startImport(for: .claude)
        waitForHistoryImport(coordinator)

        XCTAssertEqual(recorder.processCalls.count, 1)
        XCTAssertEqual(recorder.processCalls.first?.arguments.first, fixture.claudeHookURL.path)
        XCTAssertEqual(recorder.antigravityStartDates.count, 0)
        XCTAssertEqual(
            fixture.store.loadEvents().map(\.spanID).sorted(),
            ["span_clear_claude", "span_keep_agy", "span_keep_codex", "span_keep_openai"]
        )
        XCTAssertEqual(coordinator.snapshot.tools.map(\.state), [.pending, .completed, .pending])
    }

    func testPerToolImportResetsOnlySelectedCursorState() throws {
        let fixture = try HistoryImportFixture()
        let recorder = HistoryImportRecorder()
        let coordinator = fixture.makeCoordinator(recorder: recorder)
        let codexState = fixture.historyStateDirectory.appendingPathComponent("codex-session-import-state.json")
        let agyState = fixture.historyStateDirectory.appendingPathComponent("antigravity-active-importer-state.json")
        let claudeStateDirectory = fixture.historyStateDirectory.appendingPathComponent("claude-session-state", isDirectory: true)
        let claudeState = claudeStateDirectory.appendingPathComponent("abcdef.json")
        try FileManager.default.createDirectory(at: claudeStateDirectory, withIntermediateDirectories: true)
        try #"{"sentSpanIDs":["span_old"]}"#.write(to: codexState, atomically: true, encoding: .utf8)
        try #"{"max_generation_index_by_source":{"abcdef123456abcdef123456":42}}"#.write(to: agyState, atomically: true, encoding: .utf8)
        try #"{"fresh":100,"output":10,"byte_offset":999}"#.write(to: claudeState, atomically: true, encoding: .utf8)

        coordinator.startImport(for: .codex)
        waitForHistoryImport(coordinator)

        XCTAssertFalse(FileManager.default.fileExists(atPath: codexState.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: agyState.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: claudeState.path))
    }

    func testCodexHistoryImportPassesReconcileExistingFlag() throws {
        let fixture = try HistoryImportFixture()
        let recorder = HistoryImportRecorder()
        let coordinator = fixture.makeCoordinator(recorder: recorder)

        coordinator.startImport(for: .codex)
        waitForHistoryImport(coordinator)

        let codexCall = try XCTUnwrap(recorder.processCalls.first)
        XCTAssertEqual(codexCall.arguments.first, fixture.codexImporterURL.path)
        XCTAssertTrue(codexCall.arguments.contains("--reconcile-existing"), codexCall.arguments.joined(separator: " "))
    }

    func testAntigravityHistoryImportAdvancesLiveActiveImporterState() throws {
        let fixture = try HistoryImportFixture()
        let historyState = fixture.historyStateDirectory.appendingPathComponent("antigravity-active-importer-state.json")
        let liveStateDirectory = fixture.rootURL.appendingPathComponent("session-state", isDirectory: true)
        let liveState = liveStateDirectory.appendingPathComponent("antigravity-active-importer-state.json")
        try FileManager.default.createDirectory(at: liveStateDirectory, withIntermediateDirectories: true)
        try #"{"max_generation_index_by_source":{"source_a":2,"source_keep":9}}"#
            .write(to: liveState, atomically: true, encoding: .utf8)

        let coordinator = TokenUsageHistoryImportCoordinator(
            store: fixture.store,
            stateStore: fixture.stateStore,
            codexImporterURLProvider: { fixture.codexImporterURL },
            claudeHookURLProvider: { fixture.claudeHookURL },
            nodeExecutableURLProvider: { URL(fileURLWithPath: "/usr/bin/env") },
            python3ExecutableURLProvider: { URL(fileURLWithPath: "/usr/bin/env") },
            historyStateDirectory: fixture.historyStateDirectory,
            antigravityImportRunner: { _, _, _ in
                try? FileManager.default.createDirectory(
                    at: fixture.historyStateDirectory,
                    withIntermediateDirectories: true
                )
                try? #"{"max_generation_index_by_source":{"source_a":5,"source_b":3,"source_keep":4}}"#
                    .write(to: historyState, atomically: true, encoding: .utf8)
                return TokenUsageAntigravityImportSummary(
                    scannedDatabases: 1,
                    scannedGenerationRows: 3,
                    parsedUsageEvents: 3,
                    importedEvents: 3,
                    skippedDuplicateEvents: 0,
                    unsupportedRecords: 0,
                    splitOutputFallbackEvents: 0,
                    cursorAdvancedDatabases: 3,
                    failedToWriteEvents: false
                )
            },
            processRunner: { _ in
                TokenUsageHistoryImportProcessResult(exitCode: 0, stdout: "{}", stderr: "", timedOut: false, durationSeconds: 0.1)
            }
        )

        coordinator.startImport(for: TokenUsageHistoryImportTool.antigravity)
        waitForHistoryImport(coordinator)

        let liveData = try Data(contentsOf: liveState)
        let liveObject = try XCTUnwrap(JSONSerialization.jsonObject(with: liveData) as? [String: Any])
        let cursors = try XCTUnwrap(liveObject["max_generation_index_by_source"] as? [String: Int])
        XCTAssertEqual(cursors["source_a"], 5)
        XCTAssertEqual(cursors["source_b"], 3)
        XCTAssertEqual(cursors["source_keep"], 9)
    }

    func testHistoryImportCompletionNotifiesUsageStoreEvenWithoutInsertedEvents() throws {
        let fixture = try HistoryImportFixture()
        let notificationExpectation = expectation(description: "history import posts usage-store refresh")
        let observer = NotificationCenter.default.addObserver(
            forName: TokenUsageStore.eventsDidChangeNotification,
            object: fixture.store,
            queue: nil
        ) { _ in
            notificationExpectation.fulfill()
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        let coordinator = TokenUsageHistoryImportCoordinator(
            store: fixture.store,
            stateStore: fixture.stateStore,
            codexImporterURLProvider: { fixture.codexImporterURL },
            claudeHookURLProvider: { fixture.claudeHookURL },
            nodeExecutableURLProvider: { URL(fileURLWithPath: "/usr/bin/env") },
            python3ExecutableURLProvider: { URL(fileURLWithPath: "/usr/bin/env") },
            historyStateDirectory: fixture.historyStateDirectory,
            antigravityImportRunner: { _, _, _ in
                TokenUsageAntigravityImportSummary(
                    scannedDatabases: 1,
                    scannedGenerationRows: 0,
                    parsedUsageEvents: 0,
                    importedEvents: 0,
                    skippedDuplicateEvents: 0,
                    unsupportedRecords: 0,
                    splitOutputFallbackEvents: 0,
                    cursorAdvancedDatabases: 0,
                    failedToWriteEvents: false
                )
            },
            processRunner: { _ in
                TokenUsageHistoryImportProcessResult(exitCode: 0, stdout: "{}", stderr: "", timedOut: false, durationSeconds: 0.1)
            }
        )

        coordinator.startImport(for: TokenUsageHistoryImportTool.antigravity)
        waitForHistoryImport(coordinator)
        wait(for: [notificationExpectation], timeout: 1.0)
    }

    func testLastToolSyncResultPersistsAcrossCoordinatorRecreation() throws {
        let fixture = try HistoryImportFixture()
        let recorder = HistoryImportRecorder()
        let coordinator = fixture.makeCoordinator(recorder: recorder)

        coordinator.startImport(for: .claude)
        waitForHistoryImport(coordinator)

        let claude = try XCTUnwrap(coordinator.snapshot.tools.first { $0.tool == .claude })
        let lastRun = try XCTUnwrap(claude.lastRun)
        XCTAssertEqual(lastRun.state, .completed)
        XCTAssertEqual(lastRun.importedEvents, 2)
        XCTAssertEqual(lastRun.skippedDuplicates, 1)

        let recreated = fixture.makeCoordinator(recorder: HistoryImportRecorder())
        let restoredClaude = try XCTUnwrap(recreated.snapshot.tools.first { $0.tool == .claude })
        XCTAssertEqual(restoredClaude.lastRun, lastRun)
        XCTAssertEqual(restoredClaude.state, .completed)
        XCTAssertEqual(restoredClaude.importedEvents, 2)
        XCTAssertEqual(restoredClaude.skippedDuplicates, 1)
    }

    func testOneImporterFailureDoesNotSkipRemainingTools() throws {
        let fixture = try HistoryImportFixture()
        let recorder = HistoryImportRecorder()
        let failureRecorder = HistoryImportFailureRecorder()
        recorder.codexExitCode = 1
        let coordinator = fixture.makeCoordinator(recorder: recorder, failureReporter: failureRecorder.record(tool:mode:result:))

        coordinator.startImport()
        waitForHistoryImport(coordinator)

        XCTAssertEqual(recorder.processCalls.count, 2)
        XCTAssertEqual(recorder.antigravityStartDates.count, 1)
        XCTAssertEqual(coordinator.snapshot.tools.map(\.tool), [.codex, .claude, .antigravity])
        XCTAssertEqual(coordinator.snapshot.tools.map(\.state), [.failed, .completed, .completed])
        XCTAssertEqual(failureRecorder.reports.map(\.tool), [.codex])
        XCTAssertEqual(failureRecorder.reports.map(\.mode), [.firstImport])
        XCTAssertEqual(failureRecorder.reports.map(\.result.state), [.failed])
        XCTAssertEqual(failureRecorder.reports.first?.result.failureStage, .process)
        XCTAssertEqual(failureRecorder.reports.first?.result.failureReason, .processFailed)
        XCTAssertEqual(failureRecorder.reports.first?.result.exitCode, 1)
        XCTAssertEqual(failureRecorder.reports.first?.result.timedOut, false)
        XCTAssertNotNil(failureRecorder.reports.first?.result.durationSeconds)
    }

    func testEmptySuccessfulProcessOutputIsFailureInsteadOfUnavailable() throws {
        let fixture = try HistoryImportFixture()
        let recorder = HistoryImportRecorder()
        recorder.emptyStdoutForClaude = true
        let coordinator = fixture.makeCoordinator(recorder: recorder)

        coordinator.startImport()
        waitForHistoryImport(coordinator)

        XCTAssertEqual(coordinator.snapshot.tools.map(\.state), [.completed, .failed, .completed])
    }

    func testRepeatedFullImportWithNoHistoryReportsUnavailable() throws {
        let fixture = try HistoryImportFixture()
        let firstImportDate = Date(timeIntervalSince1970: 1_800_000_000)
        TokenUsageHistoryImportTool.allCases.forEach { tool in
            fixture.stateStore.markSuccessfulImport(for: tool, mode: .firstImport, at: firstImportDate)
        }
        let recorder = HistoryImportRecorder()
        recorder.processSummaryStdout = #"{"scanned_files":0,"imported_events":0,"skipped_seen":0,"unsupported_records":0}"#
        recorder.antigravitySummary = TokenUsageAntigravityImportSummary(
            scannedDatabases: 0,
            scannedGenerationRows: 0,
            parsedUsageEvents: 0,
            importedEvents: 0,
            skippedDuplicateEvents: 0,
            unsupportedRecords: 0,
            splitOutputFallbackEvents: 0,
            cursorAdvancedDatabases: 0,
            failedToWriteEvents: false
        )
        let coordinator = fixture.makeCoordinator(recorder: recorder)

        coordinator.startImport()
        waitForHistoryImport(coordinator)

        XCTAssertEqual(coordinator.snapshot.tools.map(\.mode), [.firstImport, .firstImport, .firstImport])
        XCTAssertEqual(coordinator.snapshot.tools.map(\.state), [.unavailable, .unavailable, .unavailable])
        XCTAssertEqual(coordinator.snapshot.tools.compactMap(\.lastSuccessfulImportAt), [firstImportDate, firstImportDate, firstImportDate])
        XCTAssertEqual(coordinator.snapshot.tools.compactMap(\.lastRun).map(\.state), [.unavailable, .unavailable, .unavailable])
    }

    func testAntigravityWriteFailureDoesNotMarkFirstImportSuccessful() throws {
        let fixture = try HistoryImportFixture()
        let recorder = HistoryImportRecorder()
        let failureRecorder = HistoryImportFailureRecorder()
        recorder.antigravitySummary = TokenUsageAntigravityImportSummary(
            scannedDatabases: 1,
            scannedGenerationRows: 200,
            parsedUsageEvents: 200,
            importedEvents: 0,
            skippedDuplicateEvents: 0,
            unsupportedRecords: 0,
            splitOutputFallbackEvents: 0,
            cursorAdvancedDatabases: 0,
            failedToWriteEvents: true
        )
        let coordinator = fixture.makeCoordinator(recorder: recorder, failureReporter: failureRecorder.record(tool:mode:result:))

        coordinator.startImport()
        waitForHistoryImport(coordinator)

        XCTAssertEqual(coordinator.snapshot.tools.map(\.state), [.completed, .completed, .failed])
        XCTAssertFalse(fixture.stateStore.hasCompletedFirstImport(for: .antigravity))
        XCTAssertNil(fixture.stateStore.lastSuccessfulImportAt(for: .antigravity))
        XCTAssertEqual(failureRecorder.reports.map(\.tool), [.antigravity])
        XCTAssertEqual(failureRecorder.reports.first?.result.failureStage, .write)
        XCTAssertEqual(failureRecorder.reports.first?.result.failureReason, .writeFailed)
        XCTAssertEqual(failureRecorder.reports.first?.result.scannedSources, 1)
        XCTAssertEqual(failureRecorder.reports.first?.result.importedEvents, 0)
        XCTAssertEqual(failureRecorder.reports.first?.result.unsupportedRecords, 0)
    }

    func testPrepareFailurePersistsLastRunForSelectedTool() throws {
        let fixture = try HistoryImportFixture()
        let recorder = HistoryImportRecorder()
        let failureRecorder = HistoryImportFailureRecorder()
        try Data("not a directory".utf8).write(to: fixture.historyStateDirectory)
        let coordinator = fixture.makeCoordinator(
            recorder: recorder,
            failureReporter: failureRecorder.record(tool:mode:result:)
        )

        coordinator.startImport(for: .codex)

        let codex = try XCTUnwrap(coordinator.snapshot.tools.first { $0.tool == .codex })
        XCTAssertEqual(codex.state, .failed)
        XCTAssertEqual(codex.message, "Failed to prepare local token history sync.")
        XCTAssertEqual(failureRecorder.reports.map(\.tool), [.codex])
        XCTAssertEqual(failureRecorder.reports.first?.result.failureStage, .prepare)
        XCTAssertEqual(failureRecorder.reports.first?.result.failureReason, .prepareFailed)

        let lastRun = try XCTUnwrap(fixture.stateStore.lastRun(for: .codex))
        XCTAssertEqual(lastRun.state, .failed)
        XCTAssertEqual(lastRun.message, "Failed to prepare local token history sync.")
    }

    func testHistoryImportPrefersBundledAdapterOverInstalledAdapter() throws {
        let fixture = try HistoryImportFixture()
        let bundledURL = fixture.rootURL.appendingPathComponent("bundled-importer")
        let installedURL = fixture.rootURL.appendingPathComponent("installed-importer")
        try "bundled".write(to: bundledURL, atomically: true, encoding: .utf8)
        try "installed".write(to: installedURL, atomically: true, encoding: .utf8)

        XCTAssertEqual(
            TokenUsageHistoryImportCoordinator.preferredHistoryImportScriptURL(
                bundledURL: bundledURL,
                installedURL: installedURL
            ),
            bundledURL
        )

        try FileManager.default.removeItem(at: bundledURL)
        XCTAssertEqual(
            TokenUsageHistoryImportCoordinator.preferredHistoryImportScriptURL(
                bundledURL: bundledURL,
                installedURL: installedURL
            ),
            installedURL
        )
    }

    func testAntigravityUnsupportedRecordsUseExplicitSummaryCount() throws {
        let fixture = try HistoryImportFixture()
        let recorder = HistoryImportRecorder()
        let coordinator = fixture.makeCoordinator(recorder: recorder)

        coordinator.startImport()
        waitForHistoryImport(coordinator)

        let agy = try XCTUnwrap(coordinator.snapshot.tools.first { $0.tool == .antigravity })
        XCTAssertEqual(agy.scannedSources, 1)
        XCTAssertEqual(agy.importedEvents, 3)
        XCTAssertEqual(agy.skippedDuplicates, 1)
        XCTAssertEqual(agy.unsupportedRecords, 1)
    }

    func testDefaultProcessRunnerDrainsLargeStderrWithoutTimingOut() throws {
        let fixture = try HistoryImportFixture()
        let noisyExecutableURL = fixture.rootURL.appendingPathComponent("noisy-importer")
        try """
        #!/bin/sh
        python3 - <<'PY'
        import sys
        sys.stderr.write("x" * 131072)
        print('{"scanned_files":1,"imported_events":1,"skipped_seen":0,"unsupported_records":0}')
        PY
        """.write(to: noisyExecutableURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: noisyExecutableURL.path
        )

        let recorder = HistoryImportRecorder()
        let coordinator = TokenUsageHistoryImportCoordinator(
            store: fixture.store,
            stateStore: fixture.stateStore,
            codexImporterURLProvider: { fixture.codexImporterURL },
            claudeHookURLProvider: { nil },
            nodeExecutableURLProvider: { noisyExecutableURL },
            python3ExecutableURLProvider: { nil },
            antigravityImportRunner: recorder.antigravityResult(store:startDate:shouldCancel:)
        )

        coordinator.startImport()
        waitForHistoryImport(coordinator, timeout: 5)

        let codex = try XCTUnwrap(coordinator.snapshot.tools.first { $0.tool == .codex })
        XCTAssertEqual(codex.state, .completed)
        XCTAssertEqual(codex.importedEvents, 1)
    }

    func testBundledHistoryImportAdaptersExposeAllHistoryJSONMode() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let codexImporter = try String(contentsOf: root.appendingPathComponent("adapters/codex/spill-importer.mjs"))
        let bundledCodexImporter = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Resources/adapters/codex/spill-importer.mjs"))
        let claudeHook = try String(contentsOf: root.appendingPathComponent("adapters/claude-code/spill-hook.py"))
        let bundledClaudeHook = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Resources/adapters/claude-code/spill-hook.py"))

        XCTAssertEqual(codexImporter, bundledCodexImporter)
        XCTAssertEqual(claudeHook, bundledClaudeHook)
        XCTAssertTrue(codexImporter.contains("options.all"))
        XCTAssertTrue(codexImporter.contains("--all                  Scan all supported local session history."))
        XCTAssertTrue(claudeHook.contains("def scan_main(scan_dir: str, since_hours) -> dict:"))
        XCTAssertTrue(claudeHook.contains("if \"--json\" in _args:"))
        XCTAssertTrue(claudeHook.contains("transcript.parent / \"subagents\""))
        XCTAssertFalse(claudeHook.contains("transcript.parent / transcript.stem / \"subagents\""))
    }

    func testCodexImporterAllHistoryEmitsSequentialDeltas() throws {
        try XCTSkipUnless(Self.isNodeAvailable(), "node is unavailable")

        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let importerURL = root.appendingPathComponent("adapters/codex/spill-importer.mjs")
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpillCodexHistoryImport-\(UUID().uuidString)", isDirectory: true)
        let sessionDir = tempURL
            .appendingPathComponent("codex/sessions/2026/06/18", isDirectory: true)
        let inboxURL = tempURL.appendingPathComponent("events-inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: inboxURL, withIntermediateDirectories: true)
        let sessionURL = sessionDir.appendingPathComponent("rollout-test.jsonl")
        try Self.codexTokenCountFixture.write(to: sessionURL, atomically: true, encoding: .utf8)

        let output = try runProcess(
            executable: "/usr/bin/env",
            arguments: [
                "node",
                importerURL.path,
                "--codex-home",
                tempURL.appendingPathComponent("codex", isDirectory: true).path,
                "--all",
                "--json",
                "--transport",
                "file",
                "--inbox",
                inboxURL.path,
                "--events",
                tempURL.appendingPathComponent("events.json").path,
                "--state",
                tempURL.appendingPathComponent("state.json").path,
                "--label-file",
                tempURL.appendingPathComponent("label.json").path,
            ]
        )

        XCTAssertTrue(output.stdout.contains(#""imported_events":3"#), output.stdout)
        let events = try inboxEvents(in: inboxURL)
        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(events.map { $0["input_tokens"] as? Int }, [10, 5, 7])
        XCTAssertEqual(events.map { $0["output_tokens"] as? Int }, [2, 3, 4])
        XCTAssertEqual(try inboxEventFileCount(in: inboxURL), 1)

        let secondOutput = try runProcess(
            executable: "/usr/bin/env",
            arguments: [
                "node",
                importerURL.path,
                "--codex-home",
                tempURL.appendingPathComponent("codex", isDirectory: true).path,
                "--all",
                "--json",
                "--transport",
                "file",
                "--inbox",
                inboxURL.path,
                "--events",
                tempURL.appendingPathComponent("events.json").path,
                "--state",
                tempURL.appendingPathComponent("state.json").path,
                "--label-file",
                tempURL.appendingPathComponent("label.json").path,
            ]
        )
        XCTAssertTrue(secondOutput.stdout.contains(#""imported_events":0"#), secondOutput.stdout)
        XCTAssertEqual(try inboxEvents(in: inboxURL).count, 3)
    }

    func testCodexHistoryUsesTimelineLabelsOnlyInsideCoveredWindow() throws {
        try XCTSkipUnless(Self.isNodeAvailable(), "node is unavailable")

        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let importerURL = root.appendingPathComponent("adapters/codex/spill-importer.mjs")
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpillCodexTimelineLabels-\(UUID().uuidString)", isDirectory: true)
        let sessionDir = tempURL
            .appendingPathComponent("codex/sessions/2026/06/18", isDirectory: true)
        let inboxURL = tempURL.appendingPathComponent("events-inbox", isDirectory: true)
        let labelURL = tempURL.appendingPathComponent("label.json")
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: inboxURL, withIntermediateDirectories: true)
        try """
        {"ai_tool":"codex","task_type":"code_review","stage":"verify","project_id":"project_11111111111151119111111111111111","updated_at":"2026-06-18T00:00:00.000Z","expires_at":"2026-06-18T00:00:30.000Z"}

        """.write(
            to: tempURL.appendingPathComponent("label-timeline.jsonl"),
            atomically: true,
            encoding: .utf8
        )
        try """
        {"timestamp":"2026-06-18T00:00:10.000Z","type":"event_msg","payload":{"type":"token_count","info":{"model":"gpt-5","last_token_usage":{"input_tokens":10,"output_tokens":2,"total_tokens":12},"total_token_usage":{"input_tokens":10,"output_tokens":2,"total_tokens":12}}}}
        {"timestamp":"2026-06-18T00:01:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"model":"gpt-5","last_token_usage":{"input_tokens":5,"output_tokens":3,"total_tokens":8},"total_token_usage":{"input_tokens":15,"output_tokens":5,"total_tokens":20}}}}

        """.write(
            to: sessionDir.appendingPathComponent("rollout-test.jsonl"),
            atomically: true,
            encoding: .utf8
        )

        let output = try runProcess(
            executable: "/usr/bin/env",
            arguments: [
                "node",
                importerURL.path,
                "--codex-home",
                tempURL.appendingPathComponent("codex", isDirectory: true).path,
                "--all",
                "--json",
                "--transport",
                "file",
                "--inbox",
                inboxURL.path,
                "--events",
                tempURL.appendingPathComponent("events.json").path,
                "--state",
                tempURL.appendingPathComponent("state.json").path,
                "--label-file",
                labelURL.path,
            ]
        )

        XCTAssertTrue(output.stdout.contains(#""imported_events":2"#), output.stdout)
        let events = try inboxEvents(in: inboxURL)
        XCTAssertEqual(events.map { $0["created_at"] as? String }, [
            "2026-06-18T00:00:10.000Z",
            "2026-06-18T00:01:00.000Z",
        ])
        XCTAssertEqual(events[0]["task_type"] as? String, "code_review")
        XCTAssertEqual(events[0]["stage"] as? String, "verify")
        XCTAssertEqual(events[0]["project_id"] as? String, "project_11111111111151119111111111111111")
        XCTAssertEqual(events[1]["task_type"] as? String, "uncategorized")
        XCTAssertEqual(events[1]["stage"] as? String, "summarize")
        XCTAssertEqual(events[1]["project_id"] as? String, "project_global")
    }

    func testCodexImporterIncrementalSeedsCursorFromPreWindowTotals() throws {
        try XCTSkipUnless(Self.isNodeAvailable(), "node is unavailable")

        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let importerURL = root.appendingPathComponent("adapters/codex/spill-importer.mjs")
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpillCodexCursorSeed-\(UUID().uuidString)", isDirectory: true)
        let sessionDir = tempURL
            .appendingPathComponent("codex/sessions/2026/06/18", isDirectory: true)
        let inboxURL = tempURL.appendingPathComponent("events-inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: inboxURL, withIntermediateDirectories: true)
        let sessionURL = sessionDir.appendingPathComponent("rollout-test.jsonl")
        let afterDate = Date().addingTimeInterval(-3600)
        try Self.codexCursorSeedFixture(after: afterDate).write(to: sessionURL, atomically: true, encoding: .utf8)

        let output = try runProcess(
            executable: "/usr/bin/env",
            arguments: [
                "node",
                importerURL.path,
                "--codex-home",
                tempURL.appendingPathComponent("codex", isDirectory: true).path,
                "--after",
                Self.iso8601String(afterDate),
                "--json",
                "--transport",
                "file",
                "--inbox",
                inboxURL.path,
                "--events",
                tempURL.appendingPathComponent("events.json").path,
                "--state",
                tempURL.appendingPathComponent("state.json").path,
                "--label-file",
                tempURL.appendingPathComponent("label.json").path,
            ]
        )

        XCTAssertTrue(output.stdout.contains(#""imported_events":1"#), output.stdout)
        XCTAssertTrue(output.stdout.contains(#""unsupported_cumulative_only":1"#), output.stdout)
        let events = try inboxEvents(in: inboxURL)
        XCTAssertEqual(events.map { $0["input_tokens"] as? Int }, [7])
        XCTAssertEqual(events.map { $0["output_tokens"] as? Int }, [4])
    }

    func testCodexImporterPrefersLastUsageWhenCumulativeTotalDiverges() throws {
        try XCTSkipUnless(Self.isNodeAvailable(), "node is unavailable")

        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let importerURL = root.appendingPathComponent("adapters/codex/spill-importer.mjs")
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpillCodexLastUsagePreferred-\(UUID().uuidString)", isDirectory: true)
        let sessionDir = tempURL
            .appendingPathComponent("codex/sessions/2026/06/18", isDirectory: true)
        let inboxURL = tempURL.appendingPathComponent("events-inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: inboxURL, withIntermediateDirectories: true)
        let sessionURL = sessionDir.appendingPathComponent("rollout-test.jsonl")
        let afterDate = Date().addingTimeInterval(-3600)
        let oldTimestamp = Self.iso8601String(afterDate.addingTimeInterval(-10))
        let eventTimestamp = Self.iso8601String(afterDate.addingTimeInterval(10))
        try """
        {"timestamp":"\(oldTimestamp)","type":"event_msg","payload":{"type":"token_count","info":{"model":"gpt-5","total_token_usage":{"input_tokens":1000,"output_tokens":100,"total_tokens":1100}}}}
        {"timestamp":"\(eventTimestamp)","type":"event_msg","payload":{"type":"token_count","info":{"model":"gpt-5","last_token_usage":{"input_tokens":10,"output_tokens":2,"total_tokens":12},"total_token_usage":{"input_tokens":5000,"output_tokens":500,"total_tokens":5500}}}}

        """.write(to: sessionURL, atomically: true, encoding: .utf8)

        let output = try runProcess(
            executable: "/usr/bin/env",
            arguments: [
                "node",
                importerURL.path,
                "--codex-home",
                tempURL.appendingPathComponent("codex", isDirectory: true).path,
                "--after",
                Self.iso8601String(afterDate),
                "--json",
                "--transport",
                "file",
                "--inbox",
                inboxURL.path,
                "--events",
                tempURL.appendingPathComponent("events.json").path,
                "--state",
                tempURL.appendingPathComponent("state.json").path,
                "--label-file",
                tempURL.appendingPathComponent("label.json").path,
            ]
        )

        XCTAssertTrue(output.stdout.contains(#""imported_events":1"#), output.stdout)
        let events = try inboxEvents(in: inboxURL)
        XCTAssertEqual(events.map { $0["input_tokens"] as? Int }, [10])
        XCTAssertEqual(events.map { $0["output_tokens"] as? Int }, [2])
        XCTAssertEqual(events.map { $0["total_tokens"] as? Int }, [12])
    }

    func testCodexImporterSkipsCurrentWindowCumulativeOnlyWithoutCursor() throws {
        try XCTSkipUnless(Self.isNodeAvailable(), "node is unavailable")

        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let importerURL = root.appendingPathComponent("adapters/codex/spill-importer.mjs")
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpillCodexCumulativeOnlyNoCursor-\(UUID().uuidString)", isDirectory: true)
        let sessionDir = tempURL
            .appendingPathComponent("codex/sessions/2026/06/18", isDirectory: true)
        let inboxURL = tempURL.appendingPathComponent("events-inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: inboxURL, withIntermediateDirectories: true)
        let sessionURL = sessionDir.appendingPathComponent("rollout-test.jsonl")
        let afterDate = Date().addingTimeInterval(-3600)
        let eventTimestamp = Self.iso8601String(afterDate.addingTimeInterval(10))
        try """
        {"timestamp":"\(eventTimestamp)","type":"event_msg","payload":{"type":"token_count","info":{"model":"gpt-5","total_token_usage":{"input_tokens":201592959,"output_tokens":1220448,"total_tokens":202813407}}}}

        """.write(to: sessionURL, atomically: true, encoding: .utf8)

        let output = try runProcess(
            executable: "/usr/bin/env",
            arguments: [
                "node",
                importerURL.path,
                "--codex-home",
                tempURL.appendingPathComponent("codex", isDirectory: true).path,
                "--after",
                Self.iso8601String(afterDate),
                "--json",
                "--transport",
                "file",
                "--inbox",
                inboxURL.path,
                "--events",
                tempURL.appendingPathComponent("events.json").path,
                "--state",
                tempURL.appendingPathComponent("state.json").path,
                "--label-file",
                tempURL.appendingPathComponent("label.json").path,
            ]
        )

        XCTAssertTrue(output.stdout.contains(#""imported_events":0"#), output.stdout)
        XCTAssertTrue(output.stdout.contains(#""unsupported_records":1"#), output.stdout)
        XCTAssertTrue(output.stdout.contains(#""unsupported_cumulative_only":1"#), output.stdout)
        XCTAssertEqual(try inboxEvents(in: inboxURL).count, 0)
    }

    func testCodexImporterSkipsCumulativeDeltaWithoutTotalTokenCursor() throws {
        try XCTSkipUnless(Self.isNodeAvailable(), "node is unavailable")

        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let importerURL = root.appendingPathComponent("adapters/codex/spill-importer.mjs")
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpillCodexCumulativeNoTotalCursor-\(UUID().uuidString)", isDirectory: true)
        let sessionDir = tempURL
            .appendingPathComponent("codex/sessions/2026/06/18", isDirectory: true)
        let inboxURL = tempURL.appendingPathComponent("events-inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: inboxURL, withIntermediateDirectories: true)
        let sessionURL = sessionDir.appendingPathComponent("rollout-test.jsonl")
        let afterDate = Date().addingTimeInterval(-3600)
        let oldTimestamp = Self.iso8601String(afterDate.addingTimeInterval(-10))
        let eventTimestamp = Self.iso8601String(afterDate.addingTimeInterval(10))
        try """
        {"timestamp":"\(oldTimestamp)","type":"event_msg","payload":{"type":"token_count","info":{"model":"gpt-5","total_token_usage":{"input_tokens":1000,"output_tokens":100}}}}
        {"timestamp":"\(eventTimestamp)","type":"event_msg","payload":{"type":"token_count","info":{"model":"gpt-5","total_token_usage":{"input_tokens":201592959,"output_tokens":1220448}}}}

        """.write(to: sessionURL, atomically: true, encoding: .utf8)

        let output = try runProcess(
            executable: "/usr/bin/env",
            arguments: [
                "node",
                importerURL.path,
                "--codex-home",
                tempURL.appendingPathComponent("codex", isDirectory: true).path,
                "--after",
                Self.iso8601String(afterDate),
                "--json",
                "--transport",
                "file",
                "--inbox",
                inboxURL.path,
                "--events",
                tempURL.appendingPathComponent("events.json").path,
                "--state",
                tempURL.appendingPathComponent("state.json").path,
                "--label-file",
                tempURL.appendingPathComponent("label.json").path,
            ]
        )

        XCTAssertTrue(output.stdout.contains(#""imported_events":0"#), output.stdout)
        XCTAssertTrue(output.stdout.contains(#""unsupported_records":1"#), output.stdout)
        XCTAssertTrue(output.stdout.contains(#""unsupported_cumulative_only":1"#), output.stdout)
        XCTAssertEqual(try inboxEvents(in: inboxURL).count, 0)
    }

    func testCodexImporterSkipsCumulativeOnlyRecordsInsteadOfEmittingDeltas() throws {
        try XCTSkipUnless(Self.isNodeAvailable(), "node is unavailable")

        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let importerURL = root.appendingPathComponent("adapters/codex/spill-importer.mjs")
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpillCodexCumulativeSpan-\(UUID().uuidString)", isDirectory: true)
        let sessionDir = tempURL
            .appendingPathComponent("codex/sessions/2026/06/18", isDirectory: true)
        let inboxURL = tempURL.appendingPathComponent("events-inbox", isDirectory: true)
        let eventsURL = tempURL.appendingPathComponent("events.json")
        let stateURL = tempURL.appendingPathComponent("state.json")
        let labelURL = tempURL.appendingPathComponent("label.json")
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: inboxURL, withIntermediateDirectories: true)
        let sessionURL = sessionDir.appendingPathComponent("rollout-test.jsonl")
        let afterDate = Date().addingTimeInterval(-3600)
        let oldTimestamp = Self.iso8601String(afterDate.addingTimeInterval(-10))
        let firstTimestamp = Self.iso8601String(afterDate.addingTimeInterval(10))
        let secondTimestamp = Self.iso8601String(afterDate.addingTimeInterval(20))

        func writeFixture(currentTimestamp: String) throws {
            try """
            {"timestamp":"\(oldTimestamp)","type":"event_msg","payload":{"type":"token_count","info":{"model":"gpt-5","total_token_usage":{"input_tokens":80,"output_tokens":20,"total_tokens":100}}}}
            {"timestamp":"\(currentTimestamp)","type":"event_msg","payload":{"type":"token_count","info":{"model":"gpt-5","total_token_usage":{"input_tokens":110,"output_tokens":30,"total_tokens":140}}}}

            """.write(to: sessionURL, atomically: true, encoding: .utf8)
        }

        let commonArguments = [
            "node",
            importerURL.path,
            "--codex-home",
            tempURL.appendingPathComponent("codex", isDirectory: true).path,
            "--after",
            Self.iso8601String(afterDate),
            "--json",
            "--transport",
            "file",
            "--inbox",
            inboxURL.path,
            "--events",
            eventsURL.path,
            "--state",
            stateURL.path,
            "--label-file",
            labelURL.path,
        ]

        try writeFixture(currentTimestamp: firstTimestamp)
        let firstOutput = try runProcess(
            executable: "/usr/bin/env",
            arguments: commonArguments
        )
        XCTAssertTrue(firstOutput.stdout.contains(#""imported_events":0"#), firstOutput.stdout)
        XCTAssertTrue(firstOutput.stdout.contains(#""unsupported_cumulative_only":1"#), firstOutput.stdout)
        XCTAssertTrue(firstOutput.stdout.contains(#""cumulative_delta":0"#), firstOutput.stdout)

        try? FileManager.default.removeItem(at: stateURL)
        try writeFixture(currentTimestamp: secondTimestamp)
        let secondOutput = try runProcess(
            executable: "/usr/bin/env",
            arguments: commonArguments + ["--reconcile-existing"]
        )
        XCTAssertTrue(secondOutput.stdout.contains(#""imported_events":0"#), secondOutput.stdout)
        XCTAssertTrue(secondOutput.stdout.contains(#""unsupported_cumulative_only":1"#), secondOutput.stdout)
        XCTAssertTrue(secondOutput.stdout.contains(#""cumulative_delta":0"#), secondOutput.stdout)

        let events = try inboxEvents(in: inboxURL)
        XCTAssertEqual(events.count, 0)
    }

    func testCodexImporterSkipsCumulativeOutlierAcrossSharedSessionRolloutFiles() throws {
        try XCTSkipUnless(Self.isNodeAvailable(), "node is unavailable")

        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let importerURL = root.appendingPathComponent("adapters/codex/spill-importer.mjs")
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpillCodexSharedSessionOutlier-\(UUID().uuidString)", isDirectory: true)
        let sessionDir = tempURL
            .appendingPathComponent("codex/sessions/2026/06/18", isDirectory: true)
        let inboxURL = tempURL.appendingPathComponent("events-inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: inboxURL, withIntermediateDirectories: true)
        let firstSessionURL = sessionDir.appendingPathComponent("rollout-a.jsonl")
        let secondSessionURL = sessionDir.appendingPathComponent("rollout-b.jsonl")
        let timestamp = Self.iso8601String(Date())
        let sessionMeta = #"{"type":"session_meta","originator":"codex_cli","session_id":"shared-session","model":"gpt-5"}"#
        try """
        \(sessionMeta)
        {"timestamp":"\(timestamp)","type":"event_msg","payload":{"type":"token_count","info":{"model":"gpt-5","total_token_usage":{"input_tokens":4095000,"output_tokens":1000,"total_tokens":4096000}}}}

        """.write(to: firstSessionURL, atomically: true, encoding: .utf8)
        try """
        \(sessionMeta)
        {"timestamp":"\(timestamp)","type":"event_msg","payload":{"type":"token_count","info":{"model":"gpt-5","total_token_usage":{"input_tokens":468990000,"output_tokens":10000,"total_tokens":469000000}}}}

        """.write(to: secondSessionURL, atomically: true, encoding: .utf8)

        let output = try runProcess(
            executable: "/usr/bin/env",
            arguments: [
                "node",
                importerURL.path,
                "--codex-home",
                tempURL.appendingPathComponent("codex", isDirectory: true).path,
                "--all",
                "--json",
                "--transport",
                "file",
                "--inbox",
                inboxURL.path,
                "--events",
                tempURL.appendingPathComponent("events.json").path,
                "--state",
                tempURL.appendingPathComponent("state.json").path,
                "--label-file",
                tempURL.appendingPathComponent("label.json").path,
            ]
        )

        XCTAssertTrue(output.stdout.contains(#""imported_events":0"#), output.stdout)
        XCTAssertTrue(output.stdout.contains(#""unsupported_cumulative_only":2"#), output.stdout)
        XCTAssertTrue(output.stdout.contains(#""cumulative_delta":0"#), output.stdout)
        XCTAssertEqual(try inboxEvents(in: inboxURL).count, 0)
    }

    func testCodexImporterKeepsLastOnlySpanStableAcrossAllAndIncremental() throws {
        try XCTSkipUnless(Self.isNodeAvailable(), "node is unavailable")

        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let importerURL = root.appendingPathComponent("adapters/codex/spill-importer.mjs")
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpillCodexStableSpan-\(UUID().uuidString)", isDirectory: true)
        let sessionDir = tempURL
            .appendingPathComponent("codex/sessions/2026/06/18", isDirectory: true)
        let inboxURL = tempURL.appendingPathComponent("events-inbox", isDirectory: true)
        let eventsURL = tempURL.appendingPathComponent("events.json")
        let stateURL = tempURL.appendingPathComponent("state.json")
        let labelURL = tempURL.appendingPathComponent("label.json")
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        let sessionURL = sessionDir.appendingPathComponent("rollout-test.jsonl")
        let afterDate = Date().addingTimeInterval(-3600)
        try Self.codexCursorSeedFixture(after: afterDate).write(to: sessionURL, atomically: true, encoding: .utf8)

        let commonArguments = [
            "node",
            importerURL.path,
            "--codex-home",
            tempURL.appendingPathComponent("codex", isDirectory: true).path,
            "--json",
            "--transport",
            "file",
            "--inbox",
            inboxURL.path,
            "--events",
            eventsURL.path,
            "--state",
            stateURL.path,
            "--label-file",
            labelURL.path,
        ]

        let allOutput = try runProcess(
            executable: "/usr/bin/env",
            arguments: commonArguments + ["--all"]
        )
        XCTAssertTrue(allOutput.stdout.contains(#""imported_events":1"#), allOutput.stdout)
        XCTAssertTrue(allOutput.stdout.contains(#""unsupported_records":2"#), allOutput.stdout)
        XCTAssertTrue(allOutput.stdout.contains(#""unsupported_cumulative_only":2"#), allOutput.stdout)
        XCTAssertEqual(try inboxEvents(in: inboxURL).count, 1)

        let incrementalOutput = try runProcess(
            executable: "/usr/bin/env",
            arguments: commonArguments + ["--after", Self.iso8601String(afterDate)]
        )
        XCTAssertTrue(incrementalOutput.stdout.contains(#""imported_events":0"#), incrementalOutput.stdout)
        XCTAssertEqual(try inboxEvents(in: inboxURL).count, 1)
    }

    func testCodexImporterReconcileExistingReemitsStoredSpans() throws {
        try XCTSkipUnless(Self.isNodeAvailable(), "node is unavailable")

        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let importerURL = root.appendingPathComponent("adapters/codex/spill-importer.mjs")
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpillCodexReconcileExisting-\(UUID().uuidString)", isDirectory: true)
        let sessionDir = tempURL
            .appendingPathComponent("codex/sessions/2026/06/18", isDirectory: true)
        let inboxURL = tempURL.appendingPathComponent("events-inbox", isDirectory: true)
        let eventsURL = tempURL.appendingPathComponent("events.json")
        let stateURL = tempURL.appendingPathComponent("state.json")
        let labelURL = tempURL.appendingPathComponent("label.json")
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        let sessionURL = sessionDir.appendingPathComponent("rollout-test.jsonl")
        try Self.codexTokenCountFixture.write(to: sessionURL, atomically: true, encoding: .utf8)

        let commonArguments = [
            "node",
            importerURL.path,
            "--codex-home",
            tempURL.appendingPathComponent("codex", isDirectory: true).path,
            "--all",
            "--json",
            "--transport",
            "file",
            "--inbox",
            inboxURL.path,
            "--events",
            eventsURL.path,
            "--state",
            stateURL.path,
            "--label-file",
            labelURL.path,
        ]

        let firstOutput = try runProcess(
            executable: "/usr/bin/env",
            arguments: commonArguments
        )
        XCTAssertTrue(firstOutput.stdout.contains(#""imported_events":3"#), firstOutput.stdout)
        XCTAssertEqual(try inboxEvents(in: inboxURL).count, 3)

        let secondOutput = try runProcess(
            executable: "/usr/bin/env",
            arguments: commonArguments + ["--reconcile-existing"]
        )
        XCTAssertTrue(secondOutput.stdout.contains(#""imported_events":3"#), secondOutput.stdout)
        XCTAssertTrue(secondOutput.stdout.contains(#""skipped_seen":0"#), secondOutput.stdout)
        XCTAssertEqual(try inboxEvents(in: inboxURL).count, 6)
    }

    func testCodexImporterDoesNotAssignMissingTimestampRecordsToImportTime() throws {
        try XCTSkipUnless(Self.isNodeAvailable(), "node is unavailable")

        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let importerURL = root.appendingPathComponent("adapters/codex/spill-importer.mjs")
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpillCodexMissingTimestamp-\(UUID().uuidString)", isDirectory: true)
        let sessionDir = tempURL
            .appendingPathComponent("codex/sessions/2026/06/18", isDirectory: true)
        let inboxURL = tempURL.appendingPathComponent("events-inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: inboxURL, withIntermediateDirectories: true)
        let sessionURL = sessionDir.appendingPathComponent("rollout-test.jsonl")
        try """
        {"type":"event_msg","payload":{"type":"token_count","info":{"model":"gpt-5","last_token_usage":{"input_tokens":10,"output_tokens":2,"total_tokens":12}}}}

        """.write(to: sessionURL, atomically: true, encoding: .utf8)

        let output = try runProcess(
            executable: "/usr/bin/env",
            arguments: [
                "node",
                importerURL.path,
                "--codex-home",
                tempURL.appendingPathComponent("codex", isDirectory: true).path,
                "--all",
                "--json",
                "--transport",
                "file",
                "--inbox",
                inboxURL.path,
                "--events",
                tempURL.appendingPathComponent("events.json").path,
                "--state",
                tempURL.appendingPathComponent("state.json").path,
                "--label-file",
                tempURL.appendingPathComponent("label.json").path,
            ]
        )

        XCTAssertTrue(output.stdout.contains(#""imported_events":0"#), output.stdout)
        XCTAssertTrue(output.stdout.contains(#""unsupported_records":1"#), output.stdout)
        XCTAssertEqual(try inboxEvents(in: inboxURL).count, 0)
    }

    func testClaudeHistoryScanSeparatesUnsupportedTranscriptsFromSkippedSeen() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let hookURL = root.appendingPathComponent("adapters/claude-code/spill-hook.py")
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpillClaudeHistoryScan-\(UUID().uuidString)", isDirectory: true)
        let scanURL = tempURL.appendingPathComponent("claude", isDirectory: true)
        try FileManager.default.createDirectory(at: scanURL, withIntermediateDirectories: true)

        try """
        {"message":{"role":"user","content":"ignored"}}

        """.write(to: scanURL.appendingPathComponent("abcdef.jsonl"), atomically: true, encoding: .utf8)
        try """
        {"message":{"role":"user"}}
        {"timestamp":"2026-06-18T00:00:00.000Z","message":{"role":"assistant","model":"claude-sonnet-4","usage":{"input_tokens":12,"output_tokens":5},"content":[]}}

        """.write(to: scanURL.appendingPathComponent("ghijkl.jsonl"), atomically: true, encoding: .utf8)
        try """
        {"message":{"role":"user"}}
        {"message":{"role":"assistant","model":"claude-sonnet-4","usage":{"input_tokens":7,"output_tokens":2},"content":[]}}

        """.write(to: scanURL.appendingPathComponent("mnopqr.jsonl"), atomically: true, encoding: .utf8)

        let output = try runProcess(
            executable: "/usr/bin/env",
            arguments: [
                "python3",
                hookURL.path,
                "--scan-dir",
                scanURL.path,
                "--all",
                "--json",
            ],
            environment: [
                "SPILL_TOKEN_USAGE_INBOX_DIR": tempURL.appendingPathComponent("inbox", isDirectory: true).path,
                "SPILL_TOKEN_USAGE_SESSION_STATE_DIR": tempURL.appendingPathComponent("state", isDirectory: true).path,
                "SPILL_TOKEN_USAGE_DIAGNOSTICS_DIR": tempURL.appendingPathComponent("diagnostics", isDirectory: true).path,
                "SPILL_TOKEN_USAGE_LABEL_FILE": tempURL.appendingPathComponent("label.json").path,
            ]
        )

        XCTAssertTrue(output.stdout.contains(#""scanned_files":3"#), output.stdout)
        XCTAssertTrue(output.stdout.contains(#""imported_events":1"#), output.stdout)
        XCTAssertTrue(output.stdout.contains(#""skipped_seen":0"#), output.stdout)
        XCTAssertTrue(output.stdout.contains(#""unsupported_records":2"#), output.stdout)
    }

    func testClaudeHistoryUsesTurnTimestampsAndTimelineLabelsOnlyInsideCoveredWindows() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let hookURL = root.appendingPathComponent("adapters/claude-code/spill-hook.py")
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpillClaudeTimelineLabels-\(UUID().uuidString)", isDirectory: true)
        let scanURL = tempURL.appendingPathComponent("claude", isDirectory: true)
        let inboxURL = tempURL.appendingPathComponent("inbox", isDirectory: true)
        let labelURL = tempURL.appendingPathComponent("label.json")
        try FileManager.default.createDirectory(at: scanURL, withIntermediateDirectories: true)
        try """
        {"ai_tool":"claude","task_type":"code_review","stage":"verify","project_id":"project_11111111111151119111111111111111","updated_at":"2026-06-17T23:58:00.000Z","expires_at":"2026-06-18T00:00:30.000Z"}
        {"ai_tool":"claude","task_type":"ui_design","stage":"implement","project_id":"project_2222222222225222a222222222222222","updated_at":"2026-06-18T00:01:30.000Z","expires_at":"2026-06-18T00:03:00.000Z"}

        """.write(
            to: tempURL.appendingPathComponent("label-timeline.jsonl"),
            atomically: true,
            encoding: .utf8
        )
        try """
        {"message":{"role":"user","content":"ignored"}}
        {"timestamp":"2026-06-17T23:58:50.000Z","requestId":"req_111111111111111111111111","message":{"id":"msg_111111111111111111111111","role":"assistant","model":"claude-sonnet-4","usage":{"input_tokens":12,"output_tokens":1},"content":[]}}
        {"timestamp":"2026-06-17T23:59:00.000Z","requestId":"req_111111111111111111111111","message":{"id":"msg_111111111111111111111111","role":"assistant","model":"claude-sonnet-4","usage":{"input_tokens":12,"output_tokens":5},"content":[]}}
        {"message":{"role":"user","content":"ignored"}}
        {"timestamp":"2026-06-18T00:02:00.000Z","requestId":"req_222222222222222222222222","message":{"id":"msg_222222222222222222222222","role":"assistant","model":"claude-sonnet-4","usage":{"input_tokens":7,"output_tokens":2},"content":[]}}
        {"message":{"role":"user","content":"ignored"}}
        {"timestamp":"2026-06-18T00:04:00.000Z","requestId":"req_333333333333333333333333","message":{"id":"msg_333333333333333333333333","role":"assistant","model":"claude-sonnet-4","usage":{"input_tokens":3,"output_tokens":1},"content":[]}}

        """.write(to: scanURL.appendingPathComponent("abcdef.jsonl"), atomically: true, encoding: .utf8)

        let output = try runProcess(
            executable: "/usr/bin/env",
            arguments: [
                "python3",
                hookURL.path,
                "--scan-dir",
                scanURL.path,
                "--all",
                "--json",
            ],
            environment: [
                "SPILL_TOKEN_USAGE_INBOX_DIR": inboxURL.path,
                "SPILL_TOKEN_USAGE_SESSION_STATE_DIR": tempURL.appendingPathComponent("state", isDirectory: true).path,
                "SPILL_TOKEN_USAGE_DIAGNOSTICS_DIR": tempURL.appendingPathComponent("diagnostics", isDirectory: true).path,
                "SPILL_TOKEN_USAGE_LABEL_FILE": labelURL.path,
            ]
        )

        XCTAssertTrue(output.stdout.contains(#""imported_events":3"#), output.stdout)
        let events = try inboxEvents(in: inboxURL)
        XCTAssertEqual(events.map { $0["created_at"] as? String }, [
            "2026-06-17T23:59:00.000Z",
            "2026-06-18T00:02:00.000Z",
            "2026-06-18T00:04:00.000Z",
        ])
        XCTAssertEqual(events.map { $0["output_tokens"] as? Int }, [5, 2, 1])
        XCTAssertEqual(events[0]["task_type"] as? String, "code_review")
        XCTAssertEqual(events[0]["stage"] as? String, "verify")
        XCTAssertEqual(events[0]["project_id"] as? String, "project_11111111111151119111111111111111")
        XCTAssertEqual(events[1]["task_type"] as? String, "ui_design")
        XCTAssertEqual(events[1]["stage"] as? String, "implement")
        XCTAssertEqual(events[1]["project_id"] as? String, "project_2222222222225222a222222222222222")
        XCTAssertEqual(events[2]["task_type"] as? String, "uncategorized")
        XCTAssertEqual(events[2]["stage"] as? String, "summarize")
        XCTAssertEqual(events[2]["project_id"] as? String, "project_global")
    }

    private func waitForHistoryImport(
        _ coordinator: TokenUsageHistoryImportCoordinator,
        timeout: TimeInterval = 3,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if !coordinator.snapshot.isRunning,
               coordinator.snapshot.finishedAt != nil {
                return
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        } while Date() < deadline

        XCTFail("Timed out waiting for history import.", file: file, line: line)
    }

    private static func event(
        aiTool: TokenUsageAITool,
        spanID: String
    ) -> TokenUsageEvent {
        TokenUsageEvent(
            schemaVersion: 1,
            deviceID: "device_local",
            projectID: "project_global",
            artifactID: "artifact_global",
            runID: "run_\(spanID)",
            spanID: spanID,
            aiTool: aiTool,
            taskType: .analysis,
            stage: .summarize,
            model: "test-model",
            inputTokens: 10,
            outputTokens: 5,
            totalTokens: 15,
            tokenBreakdown: TokenUsageBreakdown(
                system: 0,
                user: 0,
                history: 0,
                repoContext: 0,
                toolOutput: 0,
                generatedOutput: 5,
                unknown: 10
            ),
            latencyMS: 0,
            createdAt: "2026-06-18T00:00:00.000Z"
        )
    }

    private static var codexTokenCountFixture: String {
        """
        {"timestamp":"2026-06-18T00:00:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"model":"gpt-5","last_token_usage":{"input_tokens":10,"output_tokens":2,"total_tokens":12},"total_token_usage":{"input_tokens":10,"output_tokens":2,"total_tokens":12}}}}
        {"timestamp":"2026-06-18T00:01:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"model":"gpt-5","last_token_usage":{"input_tokens":5,"output_tokens":3,"total_tokens":8},"total_token_usage":{"input_tokens":15,"output_tokens":5,"total_tokens":20}}}}
        {"timestamp":"2026-06-18T00:02:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"model":"gpt-5","last_token_usage":{"input_tokens":7,"output_tokens":4,"total_tokens":11}}}}

        """
    }

    private static func codexCursorSeedFixture(after: Date) -> String {
        let oldTimestamp = iso8601String(after.addingTimeInterval(-10 * 24 * 3600))
        let totalTimestamp = iso8601String(after.addingTimeInterval(60))
        let lastOnlyTimestamp = iso8601String(after.addingTimeInterval(120))
        return """
        {"timestamp":"\(oldTimestamp)","type":"event_msg","payload":{"type":"token_count","info":{"model":"gpt-5","total_token_usage":{"input_tokens":80,"output_tokens":20,"total_tokens":100}}}}
        {"timestamp":"\(totalTimestamp)","type":"event_msg","payload":{"type":"token_count","info":{"model":"gpt-5","total_token_usage":{"input_tokens":110,"output_tokens":30,"total_tokens":140}}}}
        {"timestamp":"\(lastOnlyTimestamp)","type":"event_msg","payload":{"type":"token_count","info":{"model":"gpt-5","last_token_usage":{"input_tokens":7,"output_tokens":4,"total_tokens":11}}}}

        """
    }

    private static func iso8601String(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    private static func isNodeAvailable() -> Bool {
        (try? runProcess(executable: "/usr/bin/env", arguments: ["node", "--version"])) != nil
    }

    private static func runProcess(
        executable: String,
        arguments: [String],
        environment: [String: String] = [:]
    ) throws -> (stdout: String, stderr: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if !environment.isEmpty {
            var processEnvironment = ProcessInfo.processInfo.environment
            for (key, value) in environment {
                processEnvironment[key] = value
            }
            process.environment = processEnvironment
        }

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let stdout = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "TokenUsageHistoryImportCoordinatorTests",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: stderr]
            )
        }
        return (stdout, stderr)
    }

    private func runProcess(
        executable: String,
        arguments: [String],
        environment: [String: String] = [:]
    ) throws -> (stdout: String, stderr: String) {
        try Self.runProcess(executable: executable, arguments: arguments, environment: environment)
    }

    private func inboxEvents(in inboxURL: URL) throws -> [[String: Any]] {
        let files = try FileManager.default.contentsOfDirectory(
            at: inboxURL,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "json" || $0.pathExtension == "jsonl" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        return try files.flatMap { url -> [[String: Any]] in
            let data = try Data(contentsOf: url)
            if url.pathExtension == "jsonl" {
                let contents = String(data: data, encoding: .utf8) ?? ""
                return try contents
                    .split(whereSeparator: \.isNewline)
                    .map { line in
                        let lineData = Data(String(line).utf8)
                        return try XCTUnwrap(JSONSerialization.jsonObject(with: lineData) as? [String: Any])
                    }
            }
            return [try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])]
        }
        .sorted {
            ($0["created_at"] as? String ?? "") < ($1["created_at"] as? String ?? "")
        }
    }

    private func inboxEventFileCount(in inboxURL: URL) throws -> Int {
        try FileManager.default.contentsOfDirectory(
            at: inboxURL,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "json" || $0.pathExtension == "jsonl" }
        .count
    }
}

private final class HistoryImportRecorder: @unchecked Sendable {
    struct ProcessCall: Equatable {
        let executableURL: URL
        let arguments: [String]
    }

    private let lock = NSLock()
    var codexExitCode: Int32 = 0
    var emptyStdoutForClaude = false
    var codexImporterPath: String?
    var processSummaryStdout = #"{"scanned_files":2,"imported_events":2,"skipped_seen":1,"unsupported_records":0}"#
    var antigravitySummary = TokenUsageAntigravityImportSummary(
        scannedDatabases: 1,
        scannedGenerationRows: 5,
        parsedUsageEvents: 3,
        importedEvents: 3,
        skippedDuplicateEvents: 1,
        unsupportedRecords: 1,
        splitOutputFallbackEvents: 0,
        cursorAdvancedDatabases: 1,
        failedToWriteEvents: false
    )

    private var storedProcessCalls = [ProcessCall]()
    private var storedAntigravityStartDates = [Date]()

    var processCalls: [ProcessCall] {
        lock.withLock { storedProcessCalls }
    }

    var antigravityStartDates: [Date] {
        lock.withLock { storedAntigravityStartDates }
    }

    func reset() {
        lock.withLock {
            storedProcessCalls.removeAll()
            storedAntigravityStartDates.removeAll()
        }
    }

    func processResult(context: TokenUsageHistoryImportProcessContext) -> TokenUsageHistoryImportProcessResult {
        lock.withLock {
            storedProcessCalls.append(
                ProcessCall(executableURL: context.executableURL, arguments: context.arguments)
            )
        }

        let scriptPath = context.arguments.first ?? ""
        let isCodex = scriptPath == codexImporterPath
        let stdout = emptyStdoutForClaude && !isCodex
            ? ""
            : processSummaryStdout
        let exitCode = isCodex ? codexExitCode : 0
        return TokenUsageHistoryImportProcessResult(
            exitCode: exitCode,
            stdout: stdout,
            stderr: "",
            timedOut: false,
            durationSeconds: 0.1
        )
    }

    func antigravityResult(
        store: TokenUsageStore,
        startDate: Date,
        shouldCancel: @escaping () -> Bool
    ) -> TokenUsageAntigravityImportSummary {
        lock.withLock {
            storedAntigravityStartDates.append(startDate)
        }
        return antigravitySummary
    }
}

private final class HistoryImportFailureRecorder: @unchecked Sendable {
    struct Report: Equatable {
        let tool: TokenUsageHistoryImportTool
        let mode: TokenUsageHistoryImportMode
        let result: TokenUsageHistoryToolResult
    }

    private let lock = NSLock()
    private var storedReports = [Report]()

    var reports: [Report] {
        lock.withLock { storedReports }
    }

    func record(
        tool: TokenUsageHistoryImportTool,
        mode: TokenUsageHistoryImportMode,
        result: TokenUsageHistoryToolResult
    ) {
        lock.withLock {
            storedReports.append(Report(tool: tool, mode: mode, result: result))
        }
    }
}

private struct HistoryImportFixture {
    let rootURL: URL
    let codexImporterURL: URL
    let claudeHookURL: URL
    let historyStateDirectory: URL
    let store: TokenUsageStore
    let stateStore: TokenUsageHistoryImportStateStore
    let defaults: UserDefaults

    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpillHistoryImportTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        codexImporterURL = rootURL.appendingPathComponent("codex-importer.mjs")
        claudeHookURL = rootURL.appendingPathComponent("claude-hook.py")
        historyStateDirectory = rootURL.appendingPathComponent("history-import", isDirectory: true)
        FileManager.default.createFile(atPath: codexImporterURL.path, contents: Data())
        FileManager.default.createFile(atPath: claudeHookURL.path, contents: Data())

        let eventsURL = rootURL.appendingPathComponent("events.json")
        let inboxURL = rootURL.appendingPathComponent("events-inbox", isDirectory: true)
        store = TokenUsageStore(fileURL: eventsURL, inboxURL: inboxURL)

        let suiteName = "TokenUsageHistoryImportCoordinatorTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw NSError(domain: "TokenUsageHistoryImportCoordinatorTests", code: 1)
        }
        self.defaults = defaults
        stateStore = TokenUsageHistoryImportStateStore(defaults: defaults, keyPrefix: suiteName)
    }

    func makeCoordinator(
        recorder: HistoryImportRecorder,
        failureReporter: @escaping TokenUsageHistoryImportCoordinator.FailureReporter = { _, _, _ in }
    ) -> TokenUsageHistoryImportCoordinator {
        recorder.codexImporterPath = codexImporterURL.path
        return TokenUsageHistoryImportCoordinator(
            store: store,
            stateStore: stateStore,
            codexImporterURLProvider: { codexImporterURL },
            claudeHookURLProvider: { claudeHookURL },
            nodeExecutableURLProvider: { URL(fileURLWithPath: "/usr/bin/env") },
            python3ExecutableURLProvider: { URL(fileURLWithPath: "/usr/bin/env") },
            historyStateDirectory: historyStateDirectory,
            antigravityImportRunner: recorder.antigravityResult(store:startDate:shouldCancel:),
            processRunner: recorder.processResult(context:),
            failureReporter: failureReporter
        )
    }
}
