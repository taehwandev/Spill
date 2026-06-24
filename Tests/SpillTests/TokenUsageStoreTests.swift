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
        XCTAssertEqual(TokenMeteringL10n.text(.agentConnectionStatus, language: .korean), "에이전트 연결 상태")
        XCTAssertEqual(TokenMeteringL10n.text(.agentStatusDetected, language: .english), "Detected")
        XCTAssertTrue(TokenMeteringL10n.text(.agentStatusInfoDetail, language: .korean).contains("프롬프트"))
        XCTAssertEqual(TokenMeteringL10n.text(.noAgentStatusData, language: .japanese), "ローカルエージェントは検出されていません")
        XCTAssertEqual(TokenMeteringL10n.text(.setupWorkflowLabelsTitle, language: .english), "2. Work labels are optional")
        XCTAssertEqual(TokenMeteringL10n.text(.copyWebSetup, language: .korean), "설치 명령 복사")
        XCTAssertEqual(TokenMeteringL10n.text(.adapterSetupRequired, language: .japanese), "ローカル追跡の設定が必要")
        XCTAssertEqual(TokenMeteringL10n.adapterInstalled("spill-hook.py", language: .english), "Installed: spill-hook.py")
        XCTAssertEqual(TokenMeteringL10n.hookConfigTarget("~/.claude/settings.json", language: .korean), "연결 설정 -> ~/.claude/settings.json")
        XCTAssertEqual(TokenMeteringL10n.text(.sourceBreakdown, language: .english), "Runtime Detail")
        XCTAssertEqual(TokenMeteringL10n.text(.sourceBreakdown, language: .korean), "런타임 세부")
        XCTAssertEqual(TokenMeteringL10n.text(.folderFilterHeader, language: .korean), "폴더 필터")
        XCTAssertEqual(TokenMeteringL10n.folderTitle("abcd1234", language: .english), "Folder abcd1234")
        XCTAssertEqual(TokenMeteringL10n.text(.sourceUnavailable, language: .korean), "세부 미분류")
        XCTAssertEqual(TokenMeteringL10n.text(.cumulativeOnlyBadge, language: .japanese), "合計のみ")
        XCTAssertEqual(TokenMeteringL10n.text(.clearAlias, language: .korean), "삭제")
        XCTAssertEqual(TokenMeteringL10n.text(.relativePreviousWeek, language: .english), "prev week")
        XCTAssertEqual(TokenMeteringL10n.text(.runs, language: .korean), "작업 단위")
        XCTAssertEqual(TokenMeteringL10n.text(.previewBadge, language: .english), "ALPHA")
        XCTAssertEqual(TokenMeteringL10n.text(.privateUsageUploadTitle, language: .korean), "비공개 사용량 업로드")
        XCTAssertEqual(TokenMeteringL10n.text(.privateUsageUploadSyncNow, language: .japanese), "今すぐ同期")
        XCTAssertEqual(TokenMeteringL10n.text(.localDataDeleteOptions, language: .korean), "로컬 데이터 삭제")
        XCTAssertEqual(TokenMeteringL10n.text(.reviewLocalDataDelete, language: .korean), "삭제 전 확인")
        XCTAssertTrue(TokenMeteringL10n.text(.localDataManagementDetail, language: .korean).contains("연결 해제"))
        XCTAssertEqual(TokenMeteringL10n.text(.workflowUsage, language: .korean), "워크플로우 사용")
        XCTAssertEqual(TokenMeteringL10n.text(.workflowAssistedWork, language: .english), "Assisted work")
        XCTAssertTrue(TokenMeteringL10n.text(.workflowUsageInfoDetail, language: .korean).contains("측정 품질"))
        XCTAssertEqual(
            TokenMeteringL10n.deleteTokenDataMessage(
                scope: "All",
                eventCount: 12,
                tokens: "1,234",
                language: .english
            ),
            "This permanently deletes 12 local records in All (1,234 tokens). This cannot be undone."
        )
        XCTAssertEqual(
            TokenMeteringL10n.deleteTokenDataMessage(
                scope: "전체",
                eventCount: 12,
                tokens: "1,234",
                language: .korean
            ),
            "전체 범위의 로컬 기록 12개(1,234 토큰)를 영구 삭제합니다. 이 작업은 되돌릴 수 없습니다."
        )
        XCTAssertEqual(TokenMeteringL10n.taskLabel("git_commit", language: .korean), "Git 커밋")
        XCTAssertEqual(TokenMeteringL10n.stageLabel("verify", language: .japanese), "検証")
        XCTAssertEqual(TokenMeteringL10n.taskLabel("ux_copy_review", language: .english), "Ux Copy Review")
    }

    func testTokenMeteringDashboardCopyAvoidsInternalTerminology() {
        let dashboardKeys: [TokenMeteringTextKey] = [
            .dashboardTitle,
            .dashboardSubtitle,
            .aiToolDistribution,
            .aiToolDistributionSubtitle,
            .agentConnectionStatus,
            .agentStatusSubtitle,
            .agentStatusInfoTitle,
            .agentStatusInfoDetail,
            .agentStatusDetected,
            .noAgentStatusData,
            .noAgentStatusDetail,
            .modelBreakdown,
            .modelInfoTitle,
            .modelInfoDetail,
            .workflowUsage,
            .workflowUsageInfoTitle,
            .workflowUsageInfoDetail,
            .workflowAssistedWork,
            .workflowAssistedTokens,
            .noWorkflowUsageData,
            .workflowBreakdown,
            .workflowBreakdownSubtitle,
            .stageBreakdown,
            .stageBreakdownSubtitle,
            .sourceBreakdown,
            .sourceBreakdownSubtitle,
            .noSourceBreakdown,
            .workflowInfoTitle,
            .workflowInfoDetail,
            .stageInfoTitle,
            .stageInfoDetail,
            .sourceInfoTitle,
            .sourceInfoDetail,
            .aiToolInfoTitle,
            .aiToolInfoDetail,
            .privacyBoundary,
            .privacyBoundaryDetail,
            .runs,
            .runsSubtitle,
            .runsInfoTitle,
            .runsInfoDetail,
            .noLocalTokenEvents,
            .noLocalTokenEventsDetail,
            .dashboardEmptyGuideTitle,
            .dashboardEmptyGuideDetail,
            .dashboardEmptyOpenSettings,
            .dashboardEmptyAutomaticTitle,
            .dashboardEmptyAutomaticDetail,
            .dashboardEmptySetupTitle,
            .dashboardEmptySetupDetail,
            .dashboardEmptyPrivacyTitle,
            .dashboardEmptyPrivacyDetail,
            .dashboardEmptyPreview,
            .dashboardEmptyPreviewDetail,
            .cumulativeOnlyBadge,
            .cumulativeOnlyInfoTitle,
            .cumulativeOnlyInfoDetail,
            .folderFilterHeader,
            .allFolders,
            .folderUnassigned,
            .sourceSystem,
            .sourceUser,
            .sourceHistory,
            .sourceRepoContext,
            .sourceToolOutput,
            .sourceGeneratedOutput,
            .sourceUnavailable,
            .localAlias,
            .localAliasPlaceholder,
            .applyAlias,
            .clearAlias,
            .localAliasDetail,
            .aiToolHeader,
            .selectedWorkItemHeader,
            .previewBadge
        ]
        let blockedTerms: [(term: String, wholeWord: Bool)] = [
            ("Source Breakdown", false),
            ("Source buckets", false),
            ("Numeric buckets", false),
            ("Runtime Total", false),
            ("runtime total", false),
            ("token_breakdown", true),
            ("task_type", true),
            ("span_id", true),
            ("run_id", true),
            ("slug", true),
            ("fallback", true),
            ("hook", true),
            ("raw token", false),
            ("소스 분류", false),
            ("소스 버킷", false),
            ("숫자 버킷", false),
            ("런타임 합계", false),
            ("슬러그", false),
            ("폴백", false),
            ("훅", false),
            ("ソース分類", false),
            ("ソースバケット", false),
            ("数値バケット", false),
            ("ランタイム合計", false)
        ]

        for language in TokenMeteringLanguage.allCases {
            for key in dashboardKeys {
                let copy = TokenMeteringL10n.text(key, language: language)
                for term in blockedTerms {
                    XCTAssertFalse(
                        Self.copy(copy, containsBlockedTerm: term.term, wholeWord: term.wholeWord),
                        "\(key.rawValue) for \(language.rawValue) contains internal term: \(term.term)"
                    )
                }
            }
        }
    }

    func testTokenMeteringLocalizationUsesStringCatalog() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let localizationSource = try String(
            contentsOf: root.appendingPathComponent("Sources/Spill/TokenMetering/TokenMeteringLocalization.swift")
        )
        let packageSource = try String(contentsOf: root.appendingPathComponent("Package.swift"))
        let catalogURL = root.appendingPathComponent("Sources/Spill/Resources/Localization/TokenMetering.xcstrings")
        let catalogData = try Data(contentsOf: catalogURL)
        let catalog = try XCTUnwrap(JSONSerialization.jsonObject(with: catalogData) as? [String: Any])
        let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])

        XCTAssertFalse(localizationSource.contains("private static let table: [TokenMeteringLanguage"))
        XCTAssertFalse(localizationSource.contains("private static let taskLabels"))
        XCTAssertTrue(localizationSource.contains("#if DEBUG"))
        XCTAssertTrue(localizationSource.contains("return .module"))
        XCTAssertTrue(localizationSource.contains("packagedResourceBundle"))
        XCTAssertTrue(localizationSource.contains("Bundle.main.resourceURL"))
        XCTAssertTrue(localizationSource.contains("Contents\", isDirectory: true"))
        XCTAssertTrue(localizationSource.contains("Resources\", isDirectory: true"))
        XCTAssertTrue(packageSource.contains("defaultLocalization: \"en\""))
        XCTAssertTrue(packageSource.contains(".process(\"Resources/Localization\")"))
        XCTAssertNotNil(strings["token_metering.sourceBreakdown"])
        XCTAssertNotNil(strings["token_metering.format.delete_token_data_message"])
        XCTAssertNotNil(strings["token_metering.task.git_commit"])
        XCTAssertNotNil(strings["token_metering.forbidden.code_content"])
        XCTAssertNotNil(strings["token_metering.privateUsageUploadTitle"])
        XCTAssertTrue(localizationSource.contains("let stringUnit: StringCatalogStringUnit?"))
        XCTAssertTrue(localizationSource.contains("variations: [String: [String: StringCatalogVariation]]?"))
    }

    func testTokenMeteringStringCatalogFallbackAcceptsVariationsEntries() throws {
        let catalogJSON = """
        {
          "sourceLanguage": "en",
          "strings": {
            "token_metering.variation_test": {
              "localizations": {
                "en": {
                  "variations": {
                    "plural": {
                      "one": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "One item"
                        }
                      },
                      "other": {
                        "stringUnit": {
                          "state": "translated",
                          "value": "%lld items"
                        }
                      }
                    }
                  }
                }
              }
            },
            "token_metering.normal_test": {
              "localizations": {
                "en": {
                  "stringUnit": {
                    "state": "translated",
                    "value": "Normal"
                  }
                }
              }
            }
          },
          "version": "1.0"
        }
        """

        let data = Data(catalogJSON.utf8)

        XCTAssertEqual(
            try TokenMeteringL10n.testingStringCatalogValue(
                from: data,
                key: "token_metering.normal_test",
                language: .english
            ),
            "Normal"
        )
        XCTAssertEqual(
            try TokenMeteringL10n.testingStringCatalogValue(
                from: data,
                key: "token_metering.variation_test",
                language: .english
            ),
            "One item"
        )
    }

    func testBuildAppCopiesSwiftPMResourceBundle() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let script = try String(contentsOf: root.appendingPathComponent("scripts/build-app.sh"))

        XCTAssertTrue(script.contains("Spill_Spill.bundle"))
        XCTAssertTrue(script.contains("ditto \"$RESOURCE_BUNDLE\" \"$RESOURCES_DIR/Spill_Spill.bundle\""))
        XCTAssertTrue(script.contains("ditto \"$RESOURCES_DIR/Spill_Spill.bundle\" \"$HELPER_RESOURCES_DIR/Spill_Spill.bundle\""))
        XCTAssertFalse(script.contains("ditto \"$RESOURCE_BUNDLE\" \"$APP_DIR/Spill_Spill.bundle\""))
        XCTAssertFalse(script.contains("ditto \"$RESOURCES_DIR/Spill_Spill.bundle\" \"$HELPER_APP_DIR/Spill_Spill.bundle\""))
    }

    private static func copy(_ copy: String, containsBlockedTerm term: String, wholeWord: Bool) -> Bool {
        if !wholeWord {
            return copy.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }

        let escapedTerm = NSRegularExpression.escapedPattern(for: term)
        let pattern = #"(?<![A-Za-z0-9_])\#(escapedTerm)(?![A-Za-z0-9_])"#
        let range = NSRange(copy.startIndex..<copy.endIndex, in: copy)
        return (try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]))
            .flatMap { $0.firstMatch(in: copy, range: range) } != nil
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
        XCTAssertTrue(snapshot.sourceRows.contains { $0.title == TokenMeteringL10n.text(.sourceGeneratedOutput) && $0.value == "50 (33.3%)" })
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
        XCTAssertNil(allSnapshot.toolFilters.first?.shareLabel)
        XCTAssertEqual(allSnapshot.toolFilters.first { $0.tool == .codex }?.shareLabel, "83.3%")
        XCTAssertEqual(allSnapshot.toolFilters.first { $0.tool == .claude }?.shareLabel, "16.7%")
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
        let laterSameLocalDay = Self.safeEvent(
            spanID: "span_later_same_local_day",
            inputTokens: 400,
            outputTokens: 100,
            createdAt: "2026-06-05T12:01:00.000Z"
        )

        let snapshot = TokenUsageDashboardSnapshot(
            events: [previousLocalDay, today, laterSameLocalDay],
            selectedPeriod: .today,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.eventCount, 2)
        XCTAssertEqual(snapshot.totalTokens, 650)
        XCTAssertEqual(snapshot.sessions.map(\.id), ["work_project_local_analysis_plan_2026_06_05"])
        XCTAssertEqual(
            snapshot.periodFilters.first { $0.period == .today }?.detail,
            "650"
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
        XCTAssertEqual(snapshot.modelRows.map(\.value), ["100 (66.7%)", "50 (33.3%)"])

        let claudeSnapshot = TokenUsageDashboardSnapshot(events: [codex, claude], selectedTool: .claude)
        XCTAssertEqual(claudeSnapshot.modelRows.map(\.title), ["claude-test-model"])
        XCTAssertEqual(claudeSnapshot.modelRows.map(\.value), ["50 (100.0%)"])
    }

    func testDashboardSourceRowsShowUnknownOnlyBreakdownAsRuntimeTotal() {
        let snapshot = TokenUsageDashboardSnapshot(events: [
            Self.safeEvent(inputTokens: 22, outputTokens: 11)
        ])

        XCTAssertEqual(snapshot.totalTokens, 33)
        XCTAssertTrue(snapshot.sourceRows.contains { $0.title == TokenMeteringL10n.text(.sourceUnavailable) && $0.value == "33 (100.0%)" })
        XCTAssertEqual(snapshot.sourceRows.map(\.id), ["unknown"])
    }

    func testDashboardSnapshotOmitsLatencyKPIAndMissingLatencyCopy() {
        let snapshot = TokenUsageDashboardSnapshot(events: [
            Self.safeEvent(latencyMS: 0)
        ], language: .english)

        XCTAssertFalse(snapshot.kpis.contains { $0.id == "latency" })
        XCTAssertFalse(snapshot.sessions.first?.detail.contains(TokenMeteringL10n.text(.latencyUnavailable)) == true)
        XCTAssertTrue(snapshot.sessions.first?.detail.contains("records") == true)
    }

    func testDashboardSourceRowsShowUnknownWhenMixedWithKnownBreakdown() {
        let snapshot = TokenUsageDashboardSnapshot(events: [
            Self.safeEvent(inputTokens: 22, outputTokens: 11, generatedOutput: 11)
        ])

        XCTAssertEqual(snapshot.totalTokens, 33)
        XCTAssertTrue(snapshot.sourceRows.contains { $0.title == TokenMeteringL10n.text(.sourceGeneratedOutput) && $0.value == "11 (33.3%)" })
        XCTAssertTrue(snapshot.sourceRows.contains { $0.title == TokenMeteringL10n.text(.sourceUnavailable) && $0.value == "22 (66.7%)" })
        XCTAssertEqual(snapshot.sourceRows.map(\.id), ["unknown", "generated_output"])
        XCTAssertEqual(snapshot.sourceRows.map(\.value), ["22 (66.7%)", "11 (33.3%)"])
    }

    func testDashboardSnapshotClampsChartRatiosWhenBreakdownExceedsTotal() {
        let event = Self.safeEvent(
            aiTool: .antigravity,
            spanID: "span_agy_oversized_breakdown",
            inputTokens: 5,
            outputTokens: 5,
            tokenBreakdown: TokenUsageBreakdown(
                system: 60,
                user: 20,
                history: 0,
                repoContext: 0,
                toolOutput: 0,
                generatedOutput: 0,
                unknown: 0
            )
        )

        let snapshot = TokenUsageDashboardSnapshot(events: [event])
        let systemRow = snapshot.sourceRows.first { $0.id == "system" }

        XCTAssertEqual(snapshot.totalTokens, 10)
        XCTAssertEqual(systemRow?.value, "60 (100.0%)")
        XCTAssertEqual(systemRow?.ratio, 1.0)
        XCTAssertTrue(snapshot.sourceRows.allSatisfy { row in
            row.ratio.isFinite && row.ratio >= 0.0 && row.ratio <= 1.0
        })
    }

    func testDashboardViewSimplifiesClearActions() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let dashboardView = try Self.source(named: "TokenMeteringDashboardView.swift")
        let analyticsGrid = try Self.source(named: "TokenMeteringDashboardAnalyticsGrid.swift")
        let sessionsTable = try Self.source(named: "TokenMeteringDashboardSessionsTable.swift")
        let trendChart = try Self.source(named: "TokenMeteringDashboardTrendChart.swift")
        let trendBucketBuilder = try Self.source(named: "TokenUsageDashboardTrendBucketBuilder.swift")
        let preferencesSection = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Preferences/TokenMeteringPreferencesSection.swift"))
        let localDataSection = try Self.source(named: "TokenMeteringLocalDataManagementSection.swift")
        let developerOptionsSection = try Self.source(named: "DeveloperOptionsPreferencesSection.swift")
        let preferencesView = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Preferences/PreferencesView.swift"))

        XCTAssertFalse(dashboardView.contains("dataManagementPanel"))
        XCTAssertFalse(dashboardView.contains("title: t(.clearAllLocalData)"))
        XCTAssertFalse(dashboardView.contains("scope: .currentScope"))
        XCTAssertFalse(dashboardView.contains("requestClear(.all)"))
        XCTAssertFalse(dashboardView.contains("scope: .tool(tool)"))
        XCTAssertFalse(dashboardView.contains("scope: .period(period)"))
        XCTAssertTrue(sessionsTable.contains(".contextMenu"))
        XCTAssertTrue(sessionsTable.contains("if SpillBuildOptions.developerOptionsEnabled"))
        XCTAssertTrue(sessionsTable.contains("requestClear(.workItem(session.id))"))
        XCTAssertFalse(dashboardView.contains("requestClear(.workItem(detailSession.id))"))
        XCTAssertTrue(dashboardView.contains("settingsAction()"))
        XCTAssertTrue(dashboardView.contains("Label(AppL10n.text(.settings"))
        XCTAssertFalse(dashboardView.contains("TokenMeteringGlobalSetup.prompt("))
        XCTAssertFalse(dashboardView.contains("diagnosticsPanel"))
        XCTAssertFalse(dashboardView.contains("runLocalQueueSelfTest()"))
        XCTAssertFalse(dashboardView.contains("t(.avgLatency)"))
        XCTAssertFalse(dashboardView.contains("import Charts"))
        XCTAssertFalse(dashboardView.contains("BarMark("))
        XCTAssertFalse(dashboardView.contains("SectorMark("))
        XCTAssertTrue(analyticsGrid.contains("private var shouldShowTrendChart: Bool"))
        XCTAssertTrue(analyticsGrid.contains("guard store.snapshot.selectedCalendarDayID == nil else"))
        XCTAssertTrue(analyticsGrid.contains("case .sevenDays, .thirtyDays, .all:"))
        XCTAssertTrue(analyticsGrid.contains("if shouldShowTrendChart"))
        XCTAssertTrue(analyticsGrid.contains("store.snapshot.trendBuckets"))
        XCTAssertTrue(analyticsGrid.contains("TokenMeteringDashboardTrendChart("))
        XCTAssertTrue(analyticsGrid.contains("selectedBucketID: $selectedTrendBucketID"))
        XCTAssertTrue(analyticsGrid.contains("TokenMeteringDashboardTrendBucketSummary"))
        XCTAssertFalse(dashboardView.contains("private func trendBars"))
        XCTAssertTrue(trendChart.contains("struct TokenMeteringDashboardTrendChart: View"))
        XCTAssertTrue(trendBucketBuilder.contains("enum TokenUsageDashboardTrendBucketBuilder"))
        XCTAssertTrue(trendBucketBuilder.contains("static func buckets("))
        XCTAssertTrue(trendBucketBuilder.contains("private static func dailyBuckets("))
        XCTAssertTrue(trendBucketBuilder.contains("private static func monthlyBuckets("))
        XCTAssertFalse(preferencesSection.contains("localDataManagementSection"))
        XCTAssertTrue(localDataSection.contains("struct TokenMeteringLocalDataManagementSection"))
        XCTAssertTrue(preferencesView.contains("DeveloperOptionsPreferencesSection("))
        XCTAssertTrue(developerOptionsSection.contains("TokenMeteringLocalDataManagementSection("))
        XCTAssertTrue(localDataSection.contains("Text(t(.localDataManagementDetail))"))
        XCTAssertTrue(localDataSection.contains("DisclosureGroup(isExpanded: $showsDeleteControls)"))
        XCTAssertTrue(localDataSection.contains("Label(t(.localDataDeleteOptions), systemImage: \"trash\")"))
        XCTAssertTrue(localDataSection.contains("Label(t(.reviewLocalDataDelete), systemImage: \"trash\")"))
        XCTAssertFalse(localDataSection.contains("Label(t(.clearAllLocalData), systemImage: \"trash\")"))
        XCTAssertTrue(localDataSection.contains("try tokenUsageStore.clearEvents()"))
        XCTAssertTrue(dashboardView.contains("guard SpillBuildOptions.developerOptionsEnabled else"))
    }

    func testPreferencesSetupGuidanceIsAlwaysVisible() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let preferencesSection = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Preferences/TokenMeteringPreferencesSection.swift"))
        let setupSection = try Self.source(named: "TokenMeteringSetupSection.swift")
        let promptCard = try Self.source(named: "TokenMeteringPromptInstructionCard.swift")
        let localSyncSection = try Self.source(named: "TokenMeteringLocalSyncSettingsSection.swift")
        let privacyBoundarySection = try Self.source(named: "TokenMeteringPrivacyBoundarySection.swift")

        XCTAssertTrue(preferencesSection.contains("TokenMeteringSetupSection("))
        XCTAssertTrue(setupSection.contains("t(.step1Title)"))
        XCTAssertTrue(setupSection.contains("TokenMeteringPromptInstructionCard("))
        XCTAssertTrue(promptCard.contains("t(.copyInstallPrompt)"))
        XCTAssertTrue(promptCard.contains("TokenMeteringGlobalSetup.globalPrompt"))
        XCTAssertFalse(preferencesSection.contains("TokenMeteringGlobalSetup.prompt("))
        XCTAssertFalse(preferencesSection.contains("Text(TokenMeteringSetupInstaller.setupCommand())"))
        XCTAssertTrue(localSyncSection.contains("t(.menuBarTokenDisplayModeTitle)"))
        XCTAssertTrue(localSyncSection.contains("t(.menuBarTokenDisplayModeDetail)"))
        XCTAssertTrue(preferencesSection.contains("localSyncAndDisplaySettingsSection"))
        XCTAssertTrue(preferencesSection.contains("TokenMeteringLocalSyncSettingsSection("))
        XCTAssertTrue(preferencesSection.contains("privacyBoundarySection"))
        XCTAssertTrue(privacyBoundarySection.contains("TokenMeteringPreferencesModel.forbiddenContentLabels"))
        XCTAssertFalse(preferencesSection.contains("showsPrivateUsageManualConnection"))
        XCTAssertFalse(preferencesSection.contains("privateUsageGrantCode"))
        XCTAssertFalse(preferencesSection.contains("privateUsageUploadManualConnection"))
        XCTAssertFalse(preferencesSection.contains("privateUsageUploadManualCodeFallback"))
        XCTAssertFalse(preferencesSection.contains("privateUsageUploadConnectionCode"))
        XCTAssertFalse(preferencesSection.contains("connect(grantCode:"))
        XCTAssertFalse(preferencesSection.contains("advancedVisible"))
    }

    func testDashboardShowsSelectedWorkItemInPopover() throws {
        let dashboardView = try Self.source(named: "TokenMeteringDashboardView.swift")
        let analyticsGrid = try Self.source(named: "TokenMeteringDashboardAnalyticsGrid.swift")
        let detailPanel = try Self.source(named: "TokenMeteringDashboardDetailPanel.swift")
        let sessionsTable = try Self.source(named: "TokenMeteringDashboardSessionsTable.swift")

        XCTAssertTrue(dashboardView.contains("TokenMeteringDashboardDetailPanel("))
        XCTAssertTrue(sessionsTable.contains("store.selectSession(session.id)"))
        XCTAssertFalse(dashboardView.contains("store.snapshotForWorkItem(session.id)"))
        XCTAssertTrue(detailPanel.contains("title: t(.aiTool)"))
        XCTAssertTrue(detailPanel.contains("title: t(.modelBreakdown)"))
        XCTAssertTrue(dashboardView.contains("title: t(.workflowUsage)"))
        XCTAssertTrue(analyticsGrid.contains("title: t(.workflowBreakdown)"))
        XCTAssertTrue(analyticsGrid.contains("title: t(.stageBreakdown)"))
        XCTAssertTrue(analyticsGrid.contains("title: t(.sourceBreakdown)"))
        XCTAssertTrue(sessionsTable.contains("projectFilterBar"))
        XCTAssertTrue(sessionsTable.contains("projectFilterPill(filter)"))
        XCTAssertTrue(sessionsTable.contains("store.setSelectedProjectID(filter.projectID)"))
        XCTAssertTrue(sessionsTable.contains("Text(session.projectTitle)"))
        XCTAssertTrue(detailPanel.contains("Text(detailSession.projectTitle)"))
        XCTAssertFalse(dashboardView.contains("detailQualityContent("))
        XCTAssertFalse(dashboardView.contains("Text(t(.runtimeCategories))"))
        XCTAssertFalse(dashboardView.contains("barRows(store.snapshot.sourceRows"))
        XCTAssertTrue(detailPanel.contains(".frame(maxHeight: .infinity, alignment: .topLeading)"))
        XCTAssertFalse(dashboardView.contains(".frame(maxHeight: .infinity, alignment: .center)"))
    }

    func testDashboardViewUsesTopToolTabsAndOptionalCalendarPicker() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let dashboardView = try Self.source(named: "TokenMeteringDashboardView.swift")
        let dashboardWindowController = try Self.source(named: "TokenMeteringDashboardWindowController.swift")
        let dashboardAppDelegate = try Self.source(named: "TokenMeteringDashboardAppDelegate.swift")
        let dashboardProcess = try Self.source(named: "TokenMeteringDashboardProcess.swift")
        let preferencesSidebar = try Self.source(named: "PreferencesSidebarView.swift")
        let analyticsGrid = try Self.source(named: "TokenMeteringDashboardAnalyticsGrid.swift")
        let filterBar = try Self.source(named: "TokenMeteringDashboardFilterBar.swift")
        let calendarControl = try Self.source(named: "TokenMeteringDashboardCalendarControl.swift")
        let toolTab = try Self.source(named: "TokenMeteringDashboardToolTab.swift")
        let toolColor = try Self.source(named: "TokenMeteringDashboardToolColor.swift")
        let infoButton = try Self.source(named: "TokenMeteringInfoButton.swift")
        let onboardingGuide = try Self.source(named: "TokenMeteringDashboardOnboardingGuide.swift")
        let sessionsTable = try Self.source(named: "TokenMeteringDashboardSessionsTable.swift")
        let appDelegate = try String(contentsOf: root.appendingPathComponent("Sources/Spill/App/AppDelegate.swift"))
        let preferencesView = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Preferences/PreferencesView.swift"))
        let tokenMeteringPreferencesSection = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Preferences/TokenMeteringPreferencesSection.swift"))
        let historyImportSection = try Self.source(named: "TokenUsageHistoryImportSection.swift")
        let localDataSection = try Self.source(named: "TokenMeteringLocalDataManagementSection.swift")
        let developerOptionsSection = try Self.source(named: "DeveloperOptionsPreferencesSection.swift")
        let dashboardStore = try Self.source(named: "TokenUsageDashboardStore.swift")

        XCTAssertFalse(dashboardView.contains("private var leftRail"))
        XCTAssertFalse(dashboardView.contains("railPanel(title: t(.aiTool))"))
        XCTAssertFalse(dashboardView.contains("railPanel(title: t(.workflowFocus))"))
        XCTAssertTrue(dashboardView.contains("topFilterBar"))
        XCTAssertTrue(dashboardView.contains("TokenMeteringDashboardFilterBar("))
        XCTAssertTrue(filterBar.contains("TokenMeteringDashboardToolTab("))
        XCTAssertTrue(filterBar.contains("TokenMeteringDashboardCalendarControl("))
        XCTAssertFalse(filterBar.contains("TokenUsageDisplayMode"))
        XCTAssertFalse(filterBar.contains("store.setDisplayMode"))
        XCTAssertFalse(filterBar.contains(".pickerStyle(.segmented)"))
        XCTAssertTrue(toolTab.contains("store.setSelectedTool(filter.tool)"))
        XCTAssertTrue(toolTab.contains("let isSelected = store.selectedTool == filter.tool"))
        XCTAssertTrue(toolTab.contains("filter.shareLabel"))
        XCTAssertTrue(toolTab.contains("toolShareBadge("))
        XCTAssertFalse(toolTab.contains("tokenUsageDetail"))
        XCTAssertFalse(toolTab.contains(#"\(filter.detail) (\(shareLabel))"#))
        XCTAssertTrue(toolTab.contains("filter.tool?.dashboardTint"))
        XCTAssertTrue(toolTab.contains("tabAccent.opacity(0.86)"))
        XCTAssertTrue(toolTab.contains("tabAccent.opacity(0.68)"))
        let tabDetailRange = try XCTUnwrap(toolTab.range(of: "Text(detail)"))
        let tabBadgeRange = try XCTUnwrap(toolTab.range(of: "toolShareBadge("))
        let tabLiveDotRange = try XCTUnwrap(toolTab.range(of: "TokenMeteringLiveUpdateDot"))
        XCTAssertLessThan(tabDetailRange.lowerBound, tabBadgeRange.lowerBound)
        XCTAssertLessThan(tabBadgeRange.lowerBound, tabLiveDotRange.lowerBound)
        XCTAssertTrue(analyticsGrid.contains("rowTint: aiToolTint"))
        XCTAssertTrue(analyticsGrid.contains("metricValueBadge("))
        XCTAssertTrue(analyticsGrid.contains(".padding(.top, 10)"))
        XCTAssertTrue(analyticsGrid.contains(".frame(minHeight: 210, alignment: .topLeading)"))
        XCTAssertTrue(analyticsGrid.contains("TokenUsageAITool(rawValue: row.id.lowercased())?.dashboardTint ?? .secondary"))
        XCTAssertTrue(toolColor.contains("extension TokenUsageAITool"))
        XCTAssertTrue(toolColor.contains("enum TokenMeteringDashboardToolPalette"))
        XCTAssertTrue(toolColor.contains("static let codex = Color(red: 0.04, green: 0.76, blue: 0.79)"))
        XCTAssertTrue(toolColor.contains("static let claude = Color(red: 0.86, green: 0.45, blue: 0.28)"))
        XCTAssertTrue(toolColor.contains("static let antigravity = Color(red: 0.12, green: 0.55, blue: 0.96)"))
        XCTAssertTrue(toolColor.contains("case .codex:"))
        XCTAssertTrue(toolColor.contains("case .claude:"))
        XCTAssertTrue(toolColor.contains("case .antigravity:"))
        XCTAssertTrue(dashboardStore.contains("rebuildSnapshotFromCurrentEventsAsync()"))
        XCTAssertTrue(dashboardView.contains("store.refreshAsync()"))
        XCTAssertTrue(dashboardView.contains("store.refreshAsyncIfIdle()"))
        XCTAssertTrue(dashboardWindowController.contains("store.refreshAsyncIfIdle()"))
        XCTAssertFalse(dashboardWindowController.contains("store.refreshAsync()"))
        XCTAssertTrue(dashboardWindowController.contains("deferredRefreshDelayNanoseconds"))
        XCTAssertTrue(dashboardWindowController.contains("aiStatusRefreshIntervalNanoseconds: UInt64 = 8_000_000_000"))
        XCTAssertTrue(dashboardWindowController.contains("startAIStatusRefreshLoop()"))
        XCTAssertTrue(dashboardWindowController.contains("self.window?.isVisible == true"))
        XCTAssertTrue(dashboardWindowController.contains("!self.store.isDashboardRefreshInProgress"))
        XCTAssertTrue(dashboardAppDelegate.contains("loadsInitialPanelSummary: false"))
        XCTAssertFalse(dashboardAppDelegate.contains("tokenUsageInboxMonitor.start()"))
        XCTAssertFalse(dashboardAppDelegate.contains("TokenUsageInboxMonitor(store: tokenUsageStore)"))
        XCTAssertFalse(dashboardAppDelegate.contains("TokenUsageCollectorCoordinator("))
        XCTAssertTrue(dashboardAppDelegate.contains("postTokenUsageCollectionRequest(reason: reason)"))
        XCTAssertTrue(dashboardProcess.contains("collectionRequestNotification"))
        XCTAssertTrue(appDelegate.contains("tokenUsageCollectionRequestFromDashboard"))
        XCTAssertTrue(dashboardView.contains("syncOnboardingPreviewFromSettings()"))
        XCTAssertTrue(dashboardView.contains("settings.tokenUsageDashboardOnboardingPreviewEnabled"))
        XCTAssertTrue(dashboardView.contains("SpillBuildOptions.developerOptionsEnabled"))
        XCTAssertTrue(onboardingGuide.contains("developerOptionsAction()"))
        XCTAssertTrue(dashboardView.contains("private var dashboardBody"))
        XCTAssertTrue(dashboardView.contains("private var agentStatusPanel"))
        XCTAssertTrue(dashboardView.contains("TokenMeteringDashboardAgentStatusPanel("))
        XCTAssertFalse(analyticsGrid.contains("TokenMeteringDashboardAgentStatusPanel("))
        XCTAssertTrue(dashboardView.contains("showsEmptyDashboardOverlay"))
        XCTAssertTrue(dashboardView.contains("showsDashboardPlaceholder"))
        XCTAssertTrue(dashboardView.contains(".disabled(showsEmptyDashboardOverlay)"))
        XCTAssertTrue(onboardingGuide.contains("Label(t(.dashboardEmptyOpenSettings), systemImage: \"gearshape.fill\")"))
        XCTAssertTrue(onboardingGuide.contains("settingsAction()"))
        XCTAssertFalse(dashboardView.contains("store.setOnboardingPreviewEnabled(!store.isOnboardingPreviewEnabled)"))
        XCTAssertFalse(tokenMeteringPreferencesSection.contains("debugDeveloperOptionsSection"))
        XCTAssertFalse(tokenMeteringPreferencesSection.contains("$settings.tokenUsageDashboardOnboardingPreviewEnabled"))
        XCTAssertTrue(preferencesView.contains("DeveloperOptionsPreferencesSection("))
        XCTAssertTrue(preferencesSidebar.contains("if SpillBuildOptions.developerOptionsEnabled"))
        XCTAssertTrue(preferencesSidebar.contains("sidebarItem(title: t(.developerOptions)"))
        XCTAssertTrue(developerOptionsSection.contains("$settings.panelOnboardingPreviewEnabled"))
        XCTAssertTrue(developerOptionsSection.contains("$settings.tokenUsageDashboardOnboardingPreviewEnabled"))
        XCTAssertTrue(developerOptionsSection.contains("t(.aiDashboardOnboardingPreview)"))
        XCTAssertTrue(dashboardStore.contains("func refreshAsync("))
        XCTAssertTrue(dashboardStore.contains("reusesLoadedEvents: Bool = false"))
        XCTAssertTrue(dashboardStore.contains("reusesPeriodFilterTotals: Bool = false"))
        XCTAssertTrue(dashboardStore.contains("func refreshAsyncIfIdle(trackLiveUpdates: Bool = true, refreshesPanelSummary: Bool = true)"))
        XCTAssertTrue(dashboardStore.contains("loadsInitialPanelSummary: Bool = true"))
        XCTAssertTrue(dashboardStore.contains("@Published private(set) var loadState"))
        XCTAssertTrue(dashboardStore.contains("@Published private(set) var isOnboardingPreviewEnabled"))
        XCTAssertTrue(dashboardStore.contains("TokenUsageDashboardPreviewDataSource.onboardingEvents"))
        XCTAssertTrue(dashboardStore.contains("snapshotBuildQueue = DispatchQueue(label: \"app.spill.token-dashboard.snapshot-build\""))
        XCTAssertTrue(dashboardStore.contains("snapshotBuildGate.isCurrent(generation)"))
        XCTAssertFalse(dashboardStore.contains("DispatchQueue.global(qos: .userInitiated).async"))
        XCTAssertTrue(analyticsGrid.contains("loadingAnalyticsGrid"))
        XCTAssertTrue(sessionsTable.contains("TokenMeteringDashboardLoadingSessionRows"))
        XCTAssertTrue(dashboardView.contains("store.loadState == .loading"))
        XCTAssertTrue(calendarControl.contains("calendarPickerPanel"))
        XCTAssertTrue(calendarControl.contains(".popover(isPresented: $isPresented"))
        XCTAssertTrue(calendarControl.contains("store.clearSelectedCalendarDay()"))
        XCTAssertTrue(dashboardView.contains("receiverPanel"))
        XCTAssertTrue(dashboardView.contains(".focusEffectDisabled()"))
        XCTAssertTrue(infoButton.contains("struct TokenMeteringInfoButton"))
        XCTAssertTrue(infoButton.contains(".focusable(false)"))
        XCTAssertTrue(infoButton.contains(".accessibilityLabel(title)"))
        XCTAssertTrue(preferencesSidebar.contains("private func sidebarItem"))
        XCTAssertTrue(preferencesSidebar.contains(".focusEffectDisabled()"))
        XCTAssertTrue(dashboardStore.contains("@Published private(set) var unfilteredSnapshot"))
        XCTAssertFalse(dashboardStore.contains("var unfilteredSnapshot: TokenUsageDashboardSnapshot {"))
        XCTAssertTrue(dashboardStore.contains("func clearSelectedCalendarDay()"))
        XCTAssertTrue(dashboardView.contains("TokenMeteringLiveUpdateDot"))
        XCTAssertTrue(dashboardView.contains(".contentTransition(.numericText())"))
        XCTAssertTrue(localDataSection.contains("tokenUsageStore.dashboardSummary(dashboardToolsOnly: false)"))
        XCTAssertTrue(historyImportSection.contains("t(.historyImportAllStart)"))
        XCTAssertFalse(tokenMeteringPreferencesSection.contains("if SpillBuildOptions.developerOptionsEnabled"))
        XCTAssertTrue(developerOptionsSection.contains("TokenMeteringLocalDataManagementSection("))
        XCTAssertTrue(tokenMeteringPreferencesSection.contains("tokenHistoryImportCoordinator.startImport(for: tool)"))
        XCTAssertTrue(historyImportSection.contains("startToolAction(toolSnapshot.tool)"))
        XCTAssertTrue(historyImportSection.contains("TokenUsageHistoryImportLastRunText.text("))
        XCTAssertFalse(tokenMeteringPreferencesSection.contains("let events = tokenUsageStore.loadEvents()"))
    }

    func testOpeningTokenDashboardDismissesPanelBeforeShowingWindow() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appDelegate = try String(contentsOf: root.appendingPathComponent("Sources/Spill/App/AppDelegate.swift"))
        let dashboardView = try Self.source(named: "TokenMeteringDashboardView.swift")
        let dashboardProcess = try Self.source(named: "TokenMeteringDashboardProcess.swift")
        let tokenMeteringCoordinator = try Self.source(named: "TokenMeteringCoordinator.swift")
        let collector = try Self.source(named: "TokenUsageCollectorCoordinator.swift")

        XCTAssertTrue(appDelegate.contains("let wasPanelVisible = spillPanelController.isVisible"))
        XCTAssertTrue(appDelegate.contains("spillPanelController.hide(animated: false)"))
        XCTAssertTrue(appDelegate.contains("tokenMeteringCoordinator.openDashboard"))
        XCTAssertTrue(tokenMeteringCoordinator.contains("Task { @MainActor in"))
        XCTAssertTrue(tokenMeteringCoordinator.contains("dashboardLauncher.open"))
        XCTAssertTrue(tokenMeteringCoordinator.contains("isDashboardLaunchInProgress"))
        XCTAssertTrue(tokenMeteringCoordinator.contains("scheduleDashboardLaunchReset"))
        XCTAssertTrue(tokenMeteringCoordinator.contains("self?.presentDashboardWindow"))
        XCTAssertTrue(tokenMeteringCoordinator.contains("dashboardWindowController(showPreferences: showPreferences).show()"))
        XCTAssertTrue(tokenMeteringCoordinator.contains("TokenUsageCollectorCoordinator(store: usageStore)"))
        XCTAssertTrue(appDelegate.contains("tokenMeteringCoordinator.requestCollection(reason: \"panel_open\")"))
        XCTAssertTrue(tokenMeteringCoordinator.contains("self?.requestCollection(reason: \"dashboard_refresh\")"))
        XCTAssertTrue(appDelegate.contains("tokenMeteringCoordinator.requestCollection(reason: \"manual_refresh\")"))
        XCTAssertTrue(tokenMeteringCoordinator.contains("TokenMeteringDashboardProcess.tokenMeteringPreferencesTab"))
        XCTAssertTrue(appDelegate.contains("observeDashboardPreferenceRequests()"))
        XCTAssertTrue(appDelegate.contains("showPreferencesFromDashboardRequest"))
        XCTAssertTrue(dashboardProcess.contains("openPreferencesNotification"))
        XCTAssertTrue(dashboardProcess.contains("postOpenPreferencesRequest"))
        XCTAssertTrue(tokenMeteringCoordinator.contains("SPILL_SMOKE_ENABLE_TOKEN_COLLECTORS"))
        XCTAssertTrue(dashboardView.contains("private let refreshAction: () -> Void"))
        XCTAssertTrue(dashboardView.contains("private let settingsAction: () -> Void"))
        XCTAssertTrue(dashboardView.contains("settingsAction: @escaping () -> Void = {}"))
        XCTAssertTrue(dashboardView.contains("refreshAction()"))
        XCTAssertTrue(collector.contains("drainQueuedInbox()"))
        XCTAssertTrue(collector.contains("Local runtime"))
        XCTAssertTrue(collector.contains("runAntigravityActiveImporter()"))
        XCTAssertTrue(collector.contains("AGY is different: it has no runtime hook"))
        XCTAssertFalse(collector.contains("runLocalImportersIfAvailable()"))
        XCTAssertFalse(collector.contains("runCodexImporterIfAvailable()"))
        XCTAssertFalse(collector.contains("runClaudeTranscriptScanIfAvailable()"))
        XCTAssertFalse(collector.contains("Process()"))
        XCTAssertFalse(collector.contains("--scan-dir"))
    }

    func testDashboardLocalRefreshIsSeparatedFromServerStatusRefresh() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let dashboardView = try Self.source(named: "TokenMeteringDashboardView.swift")
        let panelController = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Panel/SpillPanelController.swift"))
        let spillBarView = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Panel/SpillBarView.swift"))
        let spillBarAISection = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Panel/SpillBarAISection.swift"))
        let spillBarAITokenSummary = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Panel/SpillBarAITokenSummary.swift"))
        let spillBarAIToolCard = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Panel/SpillBarAIToolCard.swift"))
        let panelSizer = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Panel/SpillPanelContentSizer.swift"))
        let appDelegate = try String(contentsOf: root.appendingPathComponent("Sources/Spill/App/AppDelegate.swift"))
        let cloudStatusView = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Panel/CloudServiceStatusDashboardView.swift"))

        XCTAssertTrue(dashboardView.contains("private func refreshLocalTokenData()"))
        XCTAssertTrue(dashboardView.contains("private func refreshServerStatus(force: Bool = false)"))
        XCTAssertTrue(dashboardView.contains("openServiceStatusDetails()"))
        XCTAssertTrue(dashboardView.contains("refreshLocalTokenData()"))
        XCTAssertFalse(dashboardView.contains("cloudServiceStatusStore.refreshIfNeeded(force: true)"))
        XCTAssertFalse(panelController.contains("cloudServiceStatusStore.refreshIfNeeded()"))
        XCTAssertTrue(spillBarAISection.contains("cloudServiceStatusStore.refreshIfNeeded()"))
        XCTAssertTrue(cloudStatusView.contains("store.refreshIfNeeded(force: true)"))
        XCTAssertTrue(spillBarView.contains("panelState.onboardingPreviewEnabled"))
        XCTAssertTrue(spillBarView.contains("SpillBarAISection("))
        XCTAssertTrue(spillBarAISection.contains("SpillBarAITokenSummary("))
        XCTAssertTrue(spillBarAISection.contains("SpillBarAIToolCard("))
        XCTAssertTrue(spillBarAISection.contains("aiStatusDetailTint(for: status)"))
        XCTAssertTrue(spillBarAISection.contains("status.kind.dashboardTint"))
        XCTAssertTrue(spillBarAITokenSummary.contains("TokenUsageAITool(rawValue: toolID.lowercased())?.dashboardTint"))
        XCTAssertFalse(spillBarAITokenSummary.contains("case \"antigravity\":"))
        XCTAssertTrue(spillBarAIToolCard.contains("status.kind.dashboardTint"))
        XCTAssertFalse(spillBarAIToolCard.contains("status.hasRunningProcesses ? .teal"))
        XCTAssertTrue(spillBarAITokenSummary.contains("setupPreview"))
        XCTAssertTrue(spillBarAITokenSummary.contains("tokenMeteringSettingsAction()"))
        XCTAssertFalse(spillBarView.contains("onboardingPreviewBanner"))
        XCTAssertFalse(spillBarView.contains("private var aiProcessSummary"))
        XCTAssertTrue(spillBarAIToolCard.contains("aiProcessStateChip"))
        XCTAssertTrue(panelController.contains("tokenMeteringSettingsAction"))
        XCTAssertTrue(appDelegate.contains("showTokenMeteringPreferencesFromPanel()"))
        XCTAssertTrue(appDelegate.contains("TokenMeteringDashboardProcess.tokenMeteringPreferencesTab"))
        XCTAssertFalse(panelSizer.contains("aiProcessSummaryHeight"))
        XCTAssertFalse(panelSizer.contains("onboardingPreviewHeight"))
    }

    func testMenuBarScannerPublishesItemsBeforeLoadingIcons() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let scanner = try String(contentsOf: root.appendingPathComponent("Sources/Spill/MenuBar/AXMenuBarItemScanner.swift"))

        XCTAssertTrue(scanner.contains("refreshMissingIcons(for: enrichedItems, generation: iconGeneration)"))
        XCTAssertTrue(scanner.contains("Task.detached(priority: .utility)"))
        XCTAssertTrue(scanner.contains("cachedImageDataIfAvailable(for: snapshot)"))
        XCTAssertFalse(scanner.contains("cachedImageData(for: snapshot)"))
    }

    func testTokenUsageCollectorDoesNotAutoRunHistoryImporters() throws {
        let collector = try Self.source(named: "TokenUsageCollectorCoordinator.swift")

        XCTAssertTrue(collector.contains("drainQueuedInbox()"))
        XCTAssertTrue(collector.contains("runAntigravityActiveImporter()"))
        XCTAssertTrue(collector.contains("TokenUsageAntigravityImporter().importRecentEvents"))
        XCTAssertFalse(collector.contains("private func importQueuedEventsWhileProcessRuns(_ process: Process)"))
        XCTAssertFalse(collector.contains("while process.isRunning"))
        XCTAssertFalse(collector.contains("Thread.sleep(forTimeInterval: importerDrainInterval)"))
        XCTAssertFalse(collector.contains("process.terminate()"))
        XCTAssertFalse(collector.contains("process.standardOutput = FileHandle.nullDevice"))
        XCTAssertFalse(collector.contains("process.standardError = FileHandle.nullDevice"))
        XCTAssertFalse(collector.contains("\"--since-hours\""))
        XCTAssertFalse(collector.contains("\"--scan-dir\""))
    }

    func testTokenUsageCollectorRunsAntigravityActiveImporter() {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let lock = NSLock()
        var capturedStartDate: Date?
        let collector = TokenUsageCollectorCoordinator(
            store: store,
            antigravityImportRunner: { _, startDate in
                lock.withLock {
                    capturedStartDate = startDate
                }
                return TokenUsageAntigravityImportSummary(
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
            },
            antigravityLookbackInterval: 3600
        )
        let beforeRequest = Date()
        let notification = expectation(description: "collection finished notification")
        let observer = NotificationCenter.default.addObserver(
            forName: TokenUsageCollectorCoordinator.collectionDidFinishNotification,
            object: collector,
            queue: .main
        ) { _ in
            notification.fulfill()
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        collector.requestCollection(reason: "test")
        wait(for: [notification], timeout: 1)

        let startDate = lock.withLock { capturedStartDate }
        XCTAssertNotNil(startDate)
        XCTAssertEqual(startDate?.timeIntervalSince(beforeRequest.addingTimeInterval(-3600)) ?? 0, 0, accuracy: 2)
    }

    func testTokenUsageCollectorPostsCollectionFinishedNotification() {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let collector = TokenUsageCollectorCoordinator(
            store: store,
            antigravityImportRunner: { _, _ in
                TokenUsageAntigravityImportSummary(
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
            }
        )
        let notification = expectation(description: "collection finished notification")
        let observer = NotificationCenter.default.addObserver(
            forName: TokenUsageCollectorCoordinator.collectionDidFinishNotification,
            object: collector,
            queue: .main
        ) { _ in
            notification.fulfill()
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        collector.requestCollection(reason: "test")

        wait(for: [notification], timeout: 1)
    }

    func testAntigravityActiveImporterReadsExactUsageFromConversationDatabase() throws {
        let rootURL = temporaryDirectoryURL()
        let conversationsURL = rootURL.appendingPathComponent("conversations", isDirectory: true)
        let databaseURL = conversationsURL.appendingPathComponent("opaque-conversation.db")
        let labelURL = rootURL
            .appendingPathComponent("label-context", isDirectory: true)
            .appendingPathComponent("antigravity.json")
        let diagnosticsURL = rootURL
            .appendingPathComponent("diagnostics", isDirectory: true)
            .appendingPathComponent("antigravity-active-importer-last.json")
        let stateURL = rootURL
            .appendingPathComponent("state", isDirectory: true)
            .appendingPathComponent("antigravity-active-importer-state.json")

        try writeAntigravityConversationDatabase(
            at: databaseURL,
            rows: [
                (
                    7,
                    antigravityGenerationMetadataBlob(
                        inputTokens: 120,
                        outputTokens: 34,
                        cachedInputTokens: 56,
                        model: "gemini-3.5-flash-low"
                    )
                )
            ]
        )
        try FileManager.default.createDirectory(
            at: labelURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(
            """
            {"ai_tool":"antigravity","task_type":"debugging","stage":"implement","project_id":"project_2222222222225222a222222222222222","updated_at":"1970-01-01T00:00:00.000Z","expires_at":"2999-01-01T00:00:00.000Z"}
            """.utf8
        ).write(to: labelURL)

        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let importer = TokenUsageAntigravityImporter(
            conversationsDirectory: conversationsURL,
            labelTimelineURL: labelURL,
            diagnosticsURL: diagnosticsURL,
            stateURL: stateURL
        )

        let summary = importer.importRecentEvents(into: store, since: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(summary.scannedDatabases, 1)
        XCTAssertEqual(summary.scannedGenerationRows, 1)
        XCTAssertEqual(summary.parsedUsageEvents, 1)
        XCTAssertEqual(summary.importedEvents, 1)

        let event = try XCTUnwrap(store.loadEvents().first)
        XCTAssertEqual(event.aiTool, .antigravity)
        XCTAssertEqual(event.createdAt, "2026-06-18T00:00:00.000Z")
        XCTAssertEqual(event.projectID, "project_2222222222225222a222222222222222")
        XCTAssertEqual(event.taskType, .debugging)
        XCTAssertEqual(event.stage, .implement)
        XCTAssertEqual(event.model, "gemini-3.5-flash-low")
        XCTAssertEqual(event.inputTokens, 176)
        XCTAssertEqual(event.outputTokens, 34)
        XCTAssertEqual(event.totalTokens, 210)
        XCTAssertEqual(event.tokenBreakdown.unknown, 176)
        XCTAssertEqual(event.tokenBreakdown.generatedOutput, 34)

        let duplicateSummary = importer.importRecentEvents(into: store, since: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(duplicateSummary.scannedGenerationRows, 0)
        XCTAssertEqual(duplicateSummary.importedEvents, 0)
        XCTAssertEqual(duplicateSummary.skippedDuplicateEvents, 0)
        XCTAssertEqual(store.loadEvents().count, 1)

        let diagnostic = try String(contentsOf: diagnosticsURL)
        XCTAssertTrue(diagnostic.contains(#""kind":"active_importer_scan""#))
        XCTAssertTrue(diagnostic.contains(#""imported_events":0"#))
        XCTAssertFalse(diagnostic.contains(databaseURL.path))
    }

    func testMenuBarAITokenStatusRefreshesFromSharedStoreChanges() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appDelegate = try String(contentsOf: root.appendingPathComponent("Sources/Spill/App/AppDelegate.swift"))
        let tokenMeteringCoordinator = try Self.source(named: "TokenMeteringCoordinator.swift")
        let usageStore = try Self.source(named: "TokenUsageStore.swift")
        let usageStoreNotifications = try Self.source(named: "TokenUsageStore+ClearAndNotify.swift")
        let dashboardStore = try Self.source(named: "TokenUsageDashboardStore.swift")

        XCTAssertTrue(usageStore.contains("distributedEventsDidChangeNotification"))
        XCTAssertTrue(usageStoreNotifications.contains("DistributedNotificationCenter.default().postNotificationName"))
        XCTAssertTrue(tokenMeteringCoordinator.contains("TokenUsageStore.distributedEventsDidChangeNotification"))
        XCTAssertTrue(tokenMeteringCoordinator.contains("tokenUsageEventsDidChangeFromDistributedNotification"))
        XCTAssertTrue(tokenMeteringCoordinator.contains("private var shouldRefreshMenuBarTokenTotal"))
        XCTAssertTrue(tokenMeteringCoordinator.contains("settings.enabledMenuBarStatusItems.contains(.ai)"))
        XCTAssertTrue(tokenMeteringCoordinator.contains("usageStore.totalTokens("))
        XCTAssertTrue(tokenMeteringCoordinator.contains("startingAt: dayStart"))
        XCTAssertTrue(tokenMeteringCoordinator.contains("menuBarTokenCollectionInterval"))
        XCTAssertTrue(appDelegate.contains("requestMenuBarTokenUsageCollectionIfNeeded()"))
        XCTAssertTrue(tokenMeteringCoordinator.contains("requestCollection(reason: \"menu_bar_status\")"))
        XCTAssertTrue(tokenMeteringCoordinator.contains("guard force || shouldRefreshMenuBarTokenTotal else"))
        XCTAssertTrue(tokenMeteringCoordinator.contains("guard force || menuBarTokenDayStart != dayStart else"))
        XCTAssertTrue(dashboardStore.contains("distributedEventsDidChangeObserver"))
        XCTAssertTrue(dashboardStore.contains("TokenUsageStore.distributedEventsDidChangeNotification"))
        XCTAssertTrue(dashboardStore.contains("private var scheduledRefreshTask"))
        XCTAssertTrue(dashboardStore.contains("private func scheduleRefresh"))
    }

    func testTokenDashboardHelperProcessContracts() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let main = try String(contentsOf: root.appendingPathComponent("Sources/Spill/App/SpillMain.swift"))
        let appDelegate = try String(contentsOf: root.appendingPathComponent("Sources/Spill/App/AppDelegate.swift"))
        let process = try Self.source(named: "TokenMeteringDashboardProcess.swift")
        let launcher = try Self.source(named: "TokenMeteringDashboardLauncher.swift")
        let tokenMeteringCoordinator = try Self.source(named: "TokenMeteringCoordinator.swift")
        let helperDelegate = try Self.source(named: "TokenMeteringDashboardAppDelegate.swift")
        let windowController = try Self.source(named: "TokenMeteringDashboardWindowController.swift")
        let buildScript = try String(contentsOf: root.appendingPathComponent("scripts/build-app.sh"))
        let smokeScript = try String(contentsOf: root.appendingPathComponent("scripts/verify-runtime-smoke.sh"))

        XCTAssertTrue(main.contains("TokenMeteringDashboardProcess.isDashboardProcess"))
        XCTAssertTrue(main.contains("TokenMeteringDashboardAppDelegate()"))
        XCTAssertTrue(main.contains("application.setActivationPolicy(.regular)"))
        XCTAssertTrue(main.contains("application.setActivationPolicy(.accessory)"))
        XCTAssertTrue(process.contains(#"static let helperBundleName = "Spill Token Dashboard.app""#))
        XCTAssertTrue(process.contains(#"static let helperBundleIdentifierSuffix = ".TokenDashboard""#))
        XCTAssertTrue(process.contains("mainBundleIdentifierForDashboardHelper"))
        XCTAssertTrue(process.contains("settingsDidChangeNotification"))
        XCTAssertTrue(process.contains("postAppLanguageDidChange"))
        XCTAssertTrue(process.contains("postTokenUsageDashboardOnboardingPreviewDidChange"))
        XCTAssertTrue(process.contains(#"static let developerOptionsPreferencesTab = "developer""#))
        XCTAssertTrue(launcher.contains("NSWorkspace.OpenConfiguration"))
        XCTAssertTrue(launcher.contains("workspace.openApplication(at: helperURL"))
        XCTAssertTrue(launcher.contains("runningApplicationsProvider"))
        XCTAssertTrue(launcher.contains("activateRunningHelper(at: helperURL)"))
        XCTAssertTrue(launcher.contains("targetHelperURL"))
        XCTAssertTrue(launcher.contains("$0.bundleURL?.standardizedFileURL.resolvingSymlinksInPath()"))
        XCTAssertTrue(launcher.contains("runningApplication.activate(options: [.activateAllWindows])"))
        XCTAssertTrue(launcher.contains("TokenMeteringWorkspaceOpenCompletion.handleOpenResult"))
        XCTAssertTrue(launcher.contains("nonisolated static func handleOpenResult"))
        XCTAssertTrue(launcher.contains("if error != nil, runningApplication == nil"))
        XCTAssertTrue(launcher.contains("Task { @MainActor in"))
        XCTAssertTrue(launcher.contains("mergeSmokeTestEnvironment"))
        XCTAssertTrue(launcher.contains("\"SPILL_TOKEN_USAGE_EVENTS_FILE\""))
        XCTAssertTrue(launcher.contains("mainBundleIdentifierEnvironmentKey"))
        XCTAssertTrue(tokenMeteringCoordinator.contains("private lazy var dashboardLauncher"))
        XCTAssertTrue(tokenMeteringCoordinator.contains("dashboardLauncher.open"))
        XCTAssertTrue(appDelegate.contains("SPILL_SMOKE_OPEN_TOKEN_DASHBOARD"))
        XCTAssertTrue(appDelegate.contains("SPILL_TOKEN_DASHBOARD_LAUNCH_SMOKE_REQUESTED"))
        XCTAssertTrue(tokenMeteringCoordinator.contains("SPILL_TOKEN_DASHBOARD_LAUNCH_SMOKE_DUPLICATE_IGNORED"))
        XCTAssertTrue(appDelegate.contains("DispatchQueue.main.async { [weak self] in"))
        XCTAssertTrue(appDelegate.contains("TokenMeteringDashboardProcess.postAppLanguageDidChange()"))
        XCTAssertTrue(appDelegate.contains("TokenMeteringDashboardProcess.postTokenUsageDashboardOnboardingPreviewDidChange()"))

        XCTAssertTrue(helperDelegate.contains("applicationShouldTerminateAfterLastWindowClosed"))
        XCTAssertTrue(helperDelegate.contains("SPILL_TOKEN_DASHBOARD_SMOKE_READY"))
        XCTAssertTrue(helperDelegate.contains("SPILL_TOKEN_DASHBOARD_SMOKE_EXIT"))
        XCTAssertTrue(helperDelegate.contains("shouldHideWindowInSmokeTest"))
        XCTAssertTrue(helperDelegate.contains("SPILL_TOKEN_DASHBOARD_SMOKE_NO_WINDOW"))
        XCTAssertTrue(helperDelegate.contains("openMainAppTokenMeteringSettings"))
        XCTAssertTrue(helperDelegate.contains("launchMainAppIfNeeded()"))
        XCTAssertTrue(helperDelegate.contains("NSWorkspace.shared.runningApplications"))
        XCTAssertTrue(helperDelegate.contains("openMainAppDeveloperOptions"))
        XCTAssertTrue(helperDelegate.contains("TokenMeteringDashboardProcess.postOpenPreferencesRequest(tab: tab)"))
        XCTAssertTrue(helperDelegate.contains("TokenMeteringWorkspaceOpenCompletion.postOpenPreferencesRequest(tab: tab)"))
        XCTAssertTrue(helperDelegate.contains("observeSettingsChanges()"))
        XCTAssertTrue(helperDelegate.contains("settingsDidChangeFromMainApp"))
        XCTAssertTrue(helperDelegate.contains("settings.reloadAppLanguageFromDefaults()"))
        XCTAssertTrue(helperDelegate.contains("settings.reloadTokenUsageDashboardOnboardingPreviewFromDefaults()"))
        XCTAssertTrue(helperDelegate.contains("tokenUsageDashboardStore.setOnboardingPreviewEnabled"))
        XCTAssertFalse(helperDelegate.contains("StatusItemController("))
        XCTAssertFalse(helperDelegate.contains("AXMenuBarItemScanner("))
        XCTAssertFalse(helperDelegate.contains("HotKeyController("))
        XCTAssertFalse(helperDelegate.contains("TokenUsageBridgeServer("))
        XCTAssertFalse(helperDelegate.contains("SpillPanelController("))
        XCTAssertFalse(helperDelegate.contains("requestTokenUsageCollection(reason: \"dashboard_launch\")"))
        XCTAssertTrue(windowController.contains("closeAction"))
        XCTAssertTrue(windowController.contains("settingsAction"))
        XCTAssertTrue(windowController.contains("developerOptionsAction"))
        XCTAssertTrue(windowController.contains("window.delegate = self"))
        XCTAssertTrue(windowController.contains("windowWillClose"))
        XCTAssertTrue(windowController.contains("scheduleDeferredRefreshAction()"))
        XCTAssertTrue(windowController.contains("deferredRefreshDelayNanoseconds: UInt64 = 1_500_000_000"))
        XCTAssertTrue(windowController.contains("Task.sleep(nanoseconds: delay)"))
        XCTAssertTrue(windowController.contains("!self.store.isDashboardRefreshInProgress"))

        XCTAssertTrue(buildScript.contains(#"HELPER_APP_NAME="Spill Token Dashboard.app""#))
        XCTAssertTrue(buildScript.contains(#"HELPER_BUNDLE_ID="${BUNDLE_ID}.TokenDashboard""#))
        XCTAssertTrue(buildScript.contains("SPILL_DEVELOPER_OPTIONS_ENABLED"))
        XCTAssertTrue(buildScript.contains("<key>SPILLDeveloperOptionsEnabled</key>"))
        XCTAssertFalse(buildScript.contains(#"ditto "$RESOURCE_BUNDLE" "$APP_DIR/Spill_Spill.bundle""#))
        XCTAssertFalse(buildScript.contains(#"ditto "$RESOURCES_DIR/Spill_Spill.bundle" "$HELPER_APP_DIR/Spill_Spill.bundle""#))
        XCTAssertTrue(buildScript.contains(#"sign_app_bundle "$HELPER_APP_DIR" "$HELPER_BUNDLE_ID""#))
        XCTAssertTrue(smokeScript.contains("APP_RESOURCE_BUNDLE"))
        XCTAssertTrue(smokeScript.contains("HELPER_RESOURCE_BUNDLE"))
        XCTAssertTrue(smokeScript.contains("SPILL_TOKEN_DASHBOARD_STANDALONE=1"))
        XCTAssertTrue(smokeScript.contains("SPILL_TOKEN_DASHBOARD_SMOKE_NO_WINDOW=1"))
        XCTAssertTrue(smokeScript.contains("SPILL_SMOKE_OPEN_TOKEN_DASHBOARD=1"))
        XCTAssertTrue(smokeScript.contains("SPILL_TOKEN_DASHBOARD_LAUNCH_SMOKE_REQUESTED"))
        XCTAssertTrue(smokeScript.contains("SPILL_TOKEN_DASHBOARD_LAUNCH_SMOKE_DUPLICATE_IGNORED"))
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
        XCTAssertEqual(
            TokenMeteringDashboardProcess.mainBundleIdentifierForDashboardHelper(
                helperBundleIdentifier: "dev.spill.Spill.TokenDashboard",
                environment: [:]
            ),
            "dev.spill.Spill"
        )
        XCTAssertEqual(
            TokenMeteringDashboardProcess.mainBundleIdentifierForDashboardHelper(
                helperBundleIdentifier: nil,
                environment: [TokenMeteringDashboardProcess.mainBundleIdentifierEnvironmentKey: "dev.custom.Spill"]
            ),
            "dev.custom.Spill"
        )
        XCTAssertNil(TokenMeteringDashboardProcess.mainBundleIdentifierForDashboardHelper(
            helperBundleIdentifier: "dev.spill.Spill",
            environment: [:]
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
            isExecutableFile: { $0 == "/custom/bin/node" },
            isRegularFile: { $0 == "/custom/bin/node" }
        )
        XCTAssertEqual(explicit?.path, "/custom/bin/node")

        let nodeBinary = TokenUsageCollectorCoordinator.nodeExecutableURL(
            environment: ["NODE_BINARY": "/configured/node"],
            isExecutableFile: { $0 == "/configured/node" },
            isRegularFile: { $0 == "/configured/node" }
        )
        XCTAssertEqual(nodeBinary?.path, "/configured/node")

        let homebrew = TokenUsageCollectorCoordinator.nodeExecutableURL(
            environment: [:],
            isExecutableFile: { $0 == "/opt/homebrew/bin/node" },
            isRegularFile: { $0 == "/opt/homebrew/bin/node" }
        )
        XCTAssertEqual(homebrew?.path, "/opt/homebrew/bin/node")

        let missing = TokenUsageCollectorCoordinator.nodeExecutableURL(
            environment: [:],
            isExecutableFile: { _ in false },
            isRegularFile: { _ in false }
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

    func testAppendEventsWithoutLoadingPreservesExistingLabelMetadataForDuplicateSpan() throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        let existing = Self.safeEvent(
            spanID: "span_reconciled_history",
            inputTokens: 10,
            outputTokens: 2,
            projectID: "project_existing",
            taskType: .codeReview,
            stage: .verify
        )
        let incoming = Self.safeEvent(
            spanID: "span_reconciled_history",
            inputTokens: 20,
            outputTokens: 4,
            projectID: "project_new",
            taskType: .uiDesign,
            stage: .implement
        )

        try usageStore.appendEvent(existing)
        let insertedCount = try usageStore.appendEventsWithoutLoading([incoming])
        let event = try XCTUnwrap(usageStore.loadEvents().first)

        XCTAssertEqual(insertedCount, 0)
        XCTAssertEqual(event.projectID, "project_existing")
        XCTAssertEqual(event.taskType, .codeReview)
        XCTAssertEqual(event.stage, .verify)
        XCTAssertEqual(event.inputTokens, 10)
        XCTAssertEqual(event.outputTokens, 2)
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
    func testDashboardStoreUnfilteredSnapshotBypassesSelectedToolAndProjectFilters() async throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        let dashboardStore = dashboardStore(usageStore: usageStore)

        try usageStore.appendEvent(Self.safeEvent(
            aiTool: .codex,
            spanID: "span_codex",
            projectID: "project_aaaaaaaaaaaa5aaaaaaa9aaaaaaaaaaa"
        ))
        try usageStore.appendEvent(Self.safeEvent(
            aiTool: .claude,
            spanID: "span_claude",
            projectID: "project_bbbbbbbbbbbb5bbbbbbb9bbbbbbbbbbb"
        ))
        dashboardStore.refresh()

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 2)
        XCTAssertEqual(dashboardStore.unfilteredSnapshot.eventCount, 2)

        dashboardStore.setSelectedProjectID("project_aaaaaaaaaaaa5aaaaaaa9aaaaaaaaaaa")
        try await waitForDashboardStoreRefresh(dashboardStore)
        XCTAssertEqual(dashboardStore.snapshot.eventCount, 1)
        XCTAssertEqual(dashboardStore.unfilteredSnapshot.eventCount, 2)

        dashboardStore.setSelectedTool(.claude)
        XCTAssertNil(dashboardStore.selectedProjectID)
        try await waitForDashboardStoreRefresh(dashboardStore)
        XCTAssertEqual(dashboardStore.snapshot.eventCount, 1)
        XCTAssertEqual(dashboardStore.unfilteredSnapshot.eventCount, 2)
    }

    @MainActor
    func testDashboardStoreInitializesPanelSummaryWithoutFullSnapshot() throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        try usageStore.appendEvent(Self.safeEvent(aiTool: .codex, spanID: "span_panel_summary"))

        let dashboardStore = dashboardStore(usageStore: usageStore)

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 0)
        XCTAssertEqual(dashboardStore.unfilteredSnapshot.eventCount, 0)
        XCTAssertEqual(dashboardStore.panelSummary.eventCount, 1)
        XCTAssertEqual(dashboardStore.panelSummary.totalTokens, 150)

        dashboardStore.refresh()

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 1)
        XCTAssertEqual(dashboardStore.unfilteredSnapshot.eventCount, 1)
        XCTAssertEqual(dashboardStore.panelSummary.eventCount, 1)
    }

    @MainActor
    func testDashboardStoreMovesCalendarMonthWithAsyncSnapshotRefresh() async throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        let dashboardStore = dashboardStore(usageStore: usageStore)
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 1
        let now = Date()
        let currentMonth = TokenUsageDashboardSnapshot.monthStart(for: now, calendar: calendar)
        let previousMonth = try XCTUnwrap(calendar.date(byAdding: .month, value: -1, to: currentMonth))
        let previousDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: previousMonth))
        let currentDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: currentMonth))
        let previousDayID = TokenUsageDashboardSnapshot.dayID(for: previousDay, calendar: calendar)

        try usageStore.replaceEvents([
            Self.safeEvent(
                spanID: "span_previous_month",
                createdAt: ISO8601DateFormatter.tokenUsage.string(from: previousDay)
            ),
            Self.safeEvent(
                spanID: "span_current_month",
                createdAt: ISO8601DateFormatter.tokenUsage.string(from: currentDay)
            )
        ])
        dashboardStore.refresh()

        let sessionsBeforeMove = dashboardStore.snapshot.sessions
        let eventCountBeforeMove = dashboardStore.snapshot.eventCount
        dashboardStore.showPreviousCalendarMonth()
        try await waitForDashboardStoreRefresh(dashboardStore)

        XCTAssertEqual(dashboardStore.snapshot.eventCount, eventCountBeforeMove)
        XCTAssertEqual(dashboardStore.snapshot.sessions, sessionsBeforeMove)
        XCTAssertTrue(calendar.isDate(dashboardStore.calendarMonthStart ?? now, equalTo: previousMonth, toGranularity: .month))
        XCTAssertTrue(dashboardStore.snapshot.calendarDays.contains { day in
            day.id == previousDayID && day.hasEvents
        })
    }

    @MainActor
    func testDashboardStoreDateSelectionLoadsSelectedDayWithoutRefreshingPanelSummary() async throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 1
        let todayStart = calendar.startOfDay(for: Date())
        let yesterdayStart = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: todayStart))
        let today = try XCTUnwrap(calendar.date(byAdding: .hour, value: 1, to: todayStart))
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .hour, value: 1, to: yesterdayStart))
        let yesterdayDayID = TokenUsageDashboardSnapshot.dayID(for: yesterday, calendar: calendar)
        try usageStore.replaceEvents([
            Self.safeEvent(
                aiTool: .codex,
                spanID: "span_date_select_today",
                inputTokens: 80,
                outputTokens: 20,
                createdAt: ISO8601DateFormatter.tokenUsage.string(from: today)
            ),
            Self.safeEvent(
                aiTool: .claude,
                spanID: "span_date_select_yesterday",
                inputTokens: 160,
                outputTokens: 40,
                createdAt: ISO8601DateFormatter.tokenUsage.string(from: yesterday)
            )
        ])
        let dashboardStore = TokenUsageDashboardStore(
            usageStore: usageStore,
            loadsInitialPanelSummary: false
        )

        dashboardStore.refreshAsyncIfIdle()
        try await waitForDashboardStoreRefresh(dashboardStore)
        XCTAssertEqual(dashboardStore.snapshot.eventCount, 1)
        XCTAssertEqual(dashboardStore.snapshot.totalTokens, 100)
        XCTAssertTrue(dashboardStore.snapshot.calendarDays.contains { day in
            day.id == yesterdayDayID && day.hasEvents
        })
        XCTAssertEqual(dashboardStore.panelSummary.eventCount, 2)

        dashboardStore.selectCalendarDay(yesterdayDayID)
        try await waitForDashboardStoreRefresh(dashboardStore)

        XCTAssertEqual(dashboardStore.selectedCalendarDayID, yesterdayDayID)
        XCTAssertEqual(dashboardStore.snapshot.eventCount, 1)
        XCTAssertEqual(dashboardStore.snapshot.totalTokens, 200)
        XCTAssertEqual(dashboardStore.snapshot.toolRows.map(\.id), ["claude"])
        XCTAssertEqual(dashboardStore.panelSummary.eventCount, 2)
    }

    func testDashboardStoreScopeChangesSkipPanelSummaryRefresh() throws {
        let dashboardStore = try Self.source(named: "TokenUsageDashboardStore.swift")

        XCTAssertTrue(dashboardStore.contains("refreshesPanelSummary ? loadPanelSummary"))
        XCTAssertTrue(dashboardStore.contains("refreshesPanelSummary ? Self.loadPanelSummary"))
        XCTAssertEqual(
            dashboardStore.components(
                separatedBy: "reusesPeriodFilterTotals: true"
            ).count - 1,
            7
        )
        XCTAssertTrue(dashboardStore.contains("let cachedPeriodFilterTotals = reusesPeriodFilterTotals ? periodFilterTotals : [:]"))
        XCTAssertTrue(dashboardStore.contains("dateRange(cachedDateRange, contains: requestedRange)"))

        let moveCalendarStart = try XCTUnwrap(dashboardStore.range(of: "private func moveCalendarMonth"))
        let runSelfTestStart = try XCTUnwrap(dashboardStore.range(of: "func runLocalQueueSelfTest"))
        let moveCalendarSource = String(dashboardStore[moveCalendarStart.lowerBound..<runSelfTestStart.lowerBound])
        XCTAssertFalse(moveCalendarSource.contains("loadPanelSummary"))
        XCTAssertTrue(moveCalendarSource.contains("snapshotBuildQueue.async"))
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

    func testDrainQueuedEventsSchedulesFollowUpAfterConsumingNonImportedFiles() throws {
        let inboxURL = temporaryInboxURL()
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL(), inboxURL: inboxURL)
        try FileManager.default.createDirectory(at: inboxURL, withIntermediateDirectories: true)
        let duplicateEvent = Self.safeEvent(spanID: "span_duplicate_drain")
        try usageStore.appendEvent(duplicateEvent)

        for index in 0..<5 {
            let queuedURL = inboxURL.appendingPathComponent(String(format: "%03d.json", index))
            try TokenUsageSanitizer.eventData(duplicateEvent).write(to: queuedURL)
        }

        var didScheduleFollowUp = false
        let didImport = usageStore.drainQueuedEventsWithoutLoading(
            maximumInboxEventCount: 1,
            maximumBatchCount: 4
        ) {
            didScheduleFollowUp = true
        }

        XCTAssertFalse(didImport)
        XCTAssertTrue(didScheduleFollowUp)
        XCTAssertEqual(usageStore.loadEvents().map(\.spanID), ["span_duplicate_drain"])
        let remainingURLs = try FileManager.default.contentsOfDirectory(
            at: inboxURL,
            includingPropertiesForKeys: nil
        )
        XCTAssertEqual(remainingURLs.count, 1)
    }

    func testDrainQueuedEventsChunksLargeJSONLInboxFile() throws {
        let inboxURL = temporaryInboxURL()
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL(), inboxURL: inboxURL)
        try FileManager.default.createDirectory(at: inboxURL, withIntermediateDirectories: true)

        let events = [
            Self.safeEvent(spanID: "span_jsonl_chunk_1"),
            Self.safeEvent(spanID: "span_jsonl_chunk_2"),
            Self.safeEvent(spanID: "span_jsonl_chunk_3")
        ]
        let jsonl = try events
            .map { event -> String in
                let data = try TokenUsageSanitizer.eventData(event)
                return try XCTUnwrap(String(data: data, encoding: .utf8))
            }
            .joined(separator: "\n")
        try (jsonl + "\n").write(
            to: inboxURL.appendingPathComponent("001.jsonl"),
            atomically: true,
            encoding: .utf8
        )

        var didScheduleFollowUp = false
        XCTAssertTrue(usageStore.drainQueuedEventsWithoutLoading(
            maximumInboxEventCount: 2,
            maximumBatchCount: 1
        ) {
            didScheduleFollowUp = true
        })
        XCTAssertTrue(didScheduleFollowUp)
        XCTAssertEqual(usageStore.loadEvents().map(\.spanID), ["span_jsonl_chunk_1", "span_jsonl_chunk_2"])

        XCTAssertTrue(usageStore.drainQueuedEventsWithoutLoading(maximumInboxEventCount: 2))
        XCTAssertEqual(
            usageStore.loadEvents().map(\.spanID),
            ["span_jsonl_chunk_1", "span_jsonl_chunk_2", "span_jsonl_chunk_3"]
        )
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
    func testDashboardStoreMarksLiveUpdatesOnlyWhenEventDataChanges() async throws {
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

        dashboardStore.refresh()
        XCTAssertEqual(dashboardStore.liveUpdateMarker.sequence, sequence)
    }

    @MainActor

    func testDashboardStoreRefreshesWhenUsageStoreChangesExternally() async throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        let dashboardStore = dashboardStore(usageStore: usageStore)

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 0)

        try usageStore.appendEvent(Self.safeEvent())
        try await Task.sleep(nanoseconds: 350_000_000)

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 1)
        XCTAssertEqual(dashboardStore.snapshot.totalTokens, 150)
    }

    @MainActor
    func testDashboardStoreRefreshesWhenLocalCollectionFinishes() async throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        try usageStore.appendEvent(Self.safeEvent(spanID: "span_collection_finish"))
        let dashboardStore = dashboardStore(usageStore: usageStore)

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 0)
        XCTAssertEqual(dashboardStore.panelSummary.eventCount, 1)

        NotificationCenter.default.post(
            name: TokenUsageCollectorCoordinator.collectionDidFinishNotification,
            object: nil
        )
        try await Task.sleep(nanoseconds: 350_000_000)

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 1)
        XCTAssertEqual(dashboardStore.snapshot.totalTokens, 150)
    }

    @MainActor
    func testDashboardStoreRefreshesOnlyForObservedCollector() async throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        try usageStore.appendEvent(Self.safeEvent(spanID: "span_collection_finish_filtered"))
        let observedCollector = TokenUsageCollectorCoordinator(store: usageStore)
        let otherCollector = TokenUsageCollectorCoordinator(store: usageStore)
        let dashboardStore = TokenUsageDashboardStore(
            usageStore: usageStore,
            collectionCoordinator: observedCollector
        )

        NotificationCenter.default.post(
            name: TokenUsageCollectorCoordinator.collectionDidFinishNotification,
            object: otherCollector
        )
        try await Task.sleep(nanoseconds: 350_000_000)
        XCTAssertEqual(dashboardStore.snapshot.eventCount, 0)

        NotificationCenter.default.post(
            name: TokenUsageCollectorCoordinator.collectionDidFinishNotification,
            object: observedCollector
        )
        try await Task.sleep(nanoseconds: 350_000_000)
        XCTAssertEqual(dashboardStore.snapshot.eventCount, 1)
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
        XCTAssertEqual(event.tokenBreakdown.generatedOutput, 16)
        XCTAssertEqual(event.tokenBreakdown.repoContext, 18)
        XCTAssertEqual(event.tokenBreakdown.toolOutput, 12)
        XCTAssertEqual(event.tokenBreakdown.unknown, 0)
    }

    @MainActor
    func testDashboardStoreOnboardingPreviewDoesNotDeleteEvents() async throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        let dashboardStore = dashboardStore(usageStore: usageStore)
        try usageStore.appendEvent(Self.safeEvent(spanID: "span_onboarding_preview"))

        dashboardStore.refresh()
        XCTAssertEqual(dashboardStore.snapshot.eventCount, 1)
        XCTAssertEqual(usageStore.loadEvents().count, 1)

        dashboardStore.setOnboardingPreviewEnabled(true)

        XCTAssertTrue(dashboardStore.isOnboardingPreviewEnabled)
        XCTAssertEqual(dashboardStore.loadState, .previewingEmpty)
        XCTAssertEqual(dashboardStore.snapshot.eventCount, 0)
        XCTAssertFalse(dashboardStore.hasDashboardEvents)
        XCTAssertEqual(usageStore.loadEvents().count, 1)

        dashboardStore.setOnboardingPreviewEnabled(false)
        try await Task.sleep(nanoseconds: 350_000_000)

        XCTAssertFalse(dashboardStore.isOnboardingPreviewEnabled)
        XCTAssertEqual(dashboardStore.loadState, .loaded)
        XCTAssertEqual(dashboardStore.snapshot.eventCount, 1)
        XCTAssertEqual(usageStore.loadEvents().count, 1)
    }

    @MainActor
    func testDashboardStoreAsyncRefreshKeepsExistingLayoutWhileLoading() async throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        let dashboardStore = dashboardStore(usageStore: usageStore)
        try usageStore.appendEvent(Self.safeEvent(spanID: "span_async_dashboard_refresh"))

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 0)
        dashboardStore.refreshAsync()

        XCTAssertEqual(dashboardStore.loadState, .loading)
        XCTAssertEqual(dashboardStore.snapshot.eventCount, 0)

        try await Task.sleep(nanoseconds: 350_000_000)

        XCTAssertEqual(dashboardStore.loadState, .loaded)
        XCTAssertEqual(dashboardStore.snapshot.eventCount, 1)
    }

    @MainActor
    func testDashboardStoreCanSkipInitialPanelSummaryForHelperFirstLoad() async throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        try usageStore.appendEvent(Self.safeEvent(spanID: "span_helper_initial_dashboard_load"))
        let dashboardStore = TokenUsageDashboardStore(
            usageStore: usageStore,
            loadsInitialPanelSummary: false
        )

        XCTAssertEqual(dashboardStore.panelSummary.eventCount, 0)
        dashboardStore.refreshAsyncIfIdle()
        XCTAssertEqual(dashboardStore.loadState, .loading)

        try await Task.sleep(nanoseconds: 350_000_000)

        XCTAssertEqual(dashboardStore.loadState, .loaded)
        XCTAssertEqual(dashboardStore.snapshot.eventCount, 1)
        XCTAssertEqual(dashboardStore.panelSummary.eventCount, 1)
    }

    @MainActor
    func testDashboardStoreInitialAsyncRefreshLoadsTodayScopeFirst() async throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let todayStart = calendar.startOfDay(for: Date())
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: todayStart))
        let today = try XCTUnwrap(calendar.date(byAdding: .hour, value: 1, to: todayStart))
        try usageStore.replaceEvents([
            Self.safeEvent(
                aiTool: .codex,
                spanID: "span_initial_yesterday",
                inputTokens: 900,
                outputTokens: 100,
                createdAt: ISO8601DateFormatter.tokenUsage.string(from: yesterday)
            ),
            Self.safeEvent(
                aiTool: .claude,
                spanID: "span_initial_today",
                inputTokens: 90,
                outputTokens: 10,
                createdAt: ISO8601DateFormatter.tokenUsage.string(from: today)
            )
        ])
        let dashboardStore = TokenUsageDashboardStore(
            usageStore: usageStore,
            loadsInitialPanelSummary: false
        )

        dashboardStore.refreshAsyncIfIdle()
        try await waitForDashboardStoreRefresh(dashboardStore)

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 1)
        XCTAssertEqual(dashboardStore.snapshot.totalTokens, 100)
        XCTAssertEqual(dashboardStore.snapshot.toolRows.map(\.id), ["claude"])
        XCTAssertEqual(dashboardStore.panelSummary.eventCount, 2)
        XCTAssertEqual(dashboardStore.panelSummary.totalTokens, 1_100)

        dashboardStore.setSelectedPeriod(.sevenDays)
        try await waitForDashboardStoreRefresh(dashboardStore)

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 2)
        XCTAssertEqual(dashboardStore.snapshot.totalTokens, 1_100)
    }

    @MainActor
    func testDashboardStoreIgnoresActivePeriodReselect() async throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        try usageStore.replaceEvents([
            Self.safeEvent(spanID: "span_active_period_today")
        ])
        let dashboardStore = TokenUsageDashboardStore(
            usageStore: usageStore,
            loadsInitialPanelSummary: false
        )

        dashboardStore.refreshAsyncIfIdle()
        try await waitForDashboardStoreRefresh(dashboardStore)

        XCTAssertEqual(dashboardStore.selectedPeriod, .today)
        XCTAssertFalse(dashboardStore.isDashboardRefreshInProgress)

        dashboardStore.setSelectedPeriod(.today)

        XCTAssertFalse(dashboardStore.isDashboardRefreshInProgress)
        XCTAssertEqual(dashboardStore.snapshot.eventCount, 1)
    }

    @MainActor
    func testDashboardStorePeriodFilterTotalsStayAnchoredToFullStore() async throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let todayStart = calendar.startOfDay(for: Date())
        let today = try XCTUnwrap(calendar.date(byAdding: .hour, value: 1, to: todayStart))
        let sixDaysAgo = try XCTUnwrap(calendar.date(byAdding: .day, value: -6, to: todayStart))
        let twentyDaysAgo = try XCTUnwrap(calendar.date(byAdding: .day, value: -20, to: todayStart))
        let fortyDaysAgo = try XCTUnwrap(calendar.date(byAdding: .day, value: -40, to: todayStart))
        try usageStore.replaceEvents([
            Self.safeEvent(spanID: "span_period_today", inputTokens: 8, outputTokens: 2, createdAt: ISO8601DateFormatter.tokenUsage.string(from: today)),
            Self.safeEvent(spanID: "span_period_six", inputTokens: 16, outputTokens: 4, createdAt: ISO8601DateFormatter.tokenUsage.string(from: sixDaysAgo)),
            Self.safeEvent(spanID: "span_period_twenty", inputTokens: 24, outputTokens: 6, createdAt: ISO8601DateFormatter.tokenUsage.string(from: twentyDaysAgo)),
            Self.safeEvent(spanID: "span_period_forty", inputTokens: 32, outputTokens: 8, createdAt: ISO8601DateFormatter.tokenUsage.string(from: fortyDaysAgo))
        ])
        let dashboardStore = TokenUsageDashboardStore(
            usageStore: usageStore,
            loadsInitialPanelSummary: false
        )

        dashboardStore.refreshAsyncIfIdle()
        try await waitForDashboardStoreRefresh(dashboardStore)

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 1)
        XCTAssertEqual(dashboardStore.snapshot.periodFilters.map(\.detail), ["10", "30", "60", "100"])

        dashboardStore.setSelectedPeriod(.sevenDays)
        try await waitForDashboardStoreRefresh(dashboardStore)

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 2)
        XCTAssertEqual(dashboardStore.snapshot.periodFilters.map(\.detail), ["10", "30", "60", "100"])
    }

    @MainActor
    func testDashboardStorePreviousPeriodUsesDatabaseBoundsOutsideLoadedScope() async throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let todayStart = calendar.startOfDay(for: Date())
        let today = try XCTUnwrap(calendar.date(byAdding: .hour, value: 1, to: todayStart))
        let previousWindowDay = try XCTUnwrap(calendar.date(byAdding: .day, value: -8, to: todayStart))
        try usageStore.replaceEvents([
            Self.safeEvent(
                spanID: "span_current_window",
                inputTokens: 80,
                outputTokens: 20,
                createdAt: ISO8601DateFormatter.tokenUsage.string(from: today)
            ),
            Self.safeEvent(
                spanID: "span_previous_window",
                inputTokens: 160,
                outputTokens: 40,
                createdAt: ISO8601DateFormatter.tokenUsage.string(from: previousWindowDay)
            )
        ])
        let dashboardStore = TokenUsageDashboardStore(
            usageStore: usageStore,
            loadsInitialPanelSummary: false
        )

        dashboardStore.refreshAsyncIfIdle()
        try await waitForDashboardStoreRefresh(dashboardStore)
        dashboardStore.setSelectedPeriod(.sevenDays)
        try await waitForDashboardStoreRefresh(dashboardStore)

        XCTAssertEqual(dashboardStore.snapshot.totalTokens, 100)
        XCTAssertTrue(dashboardStore.snapshot.canNavigatePreviousPeriod)

        dashboardStore.showPreviousPeriod()
        try await waitForDashboardStoreRefresh(dashboardStore)

        XCTAssertEqual(dashboardStore.snapshot.totalTokens, 200)
        XCTAssertEqual(dashboardStore.periodOffset, -1)
    }

    @MainActor
    func testDashboardStoreToolTabFiltersLoadedScopeWithoutReloadingAllHistory() async throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let todayStart = calendar.startOfDay(for: Date())
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: todayStart))
        let today = try XCTUnwrap(calendar.date(byAdding: .hour, value: 1, to: todayStart))
        try usageStore.replaceEvents([
            Self.safeEvent(
                aiTool: .codex,
                spanID: "span_tool_today_codex",
                inputTokens: 80,
                outputTokens: 20,
                createdAt: ISO8601DateFormatter.tokenUsage.string(from: today)
            ),
            Self.safeEvent(
                aiTool: .claude,
                spanID: "span_tool_today_claude",
                inputTokens: 160,
                outputTokens: 40,
                createdAt: ISO8601DateFormatter.tokenUsage.string(from: today)
            ),
            Self.safeEvent(
                aiTool: .antigravity,
                spanID: "span_tool_yesterday_agy",
                inputTokens: 240,
                outputTokens: 60,
                createdAt: ISO8601DateFormatter.tokenUsage.string(from: yesterday)
            )
        ])
        let dashboardStore = TokenUsageDashboardStore(
            usageStore: usageStore,
            loadsInitialPanelSummary: false
        )

        dashboardStore.refreshAsyncIfIdle()
        try await waitForDashboardStoreRefresh(dashboardStore)
        XCTAssertEqual(dashboardStore.snapshot.eventCount, 2)

        dashboardStore.setSelectedTool(.claude)
        try await waitForDashboardStoreRefresh(dashboardStore)

        XCTAssertEqual(dashboardStore.selectedTool, .claude)
        XCTAssertEqual(dashboardStore.snapshot.eventCount, 1)
        XCTAssertEqual(dashboardStore.snapshot.totalTokens, 200)
        XCTAssertEqual(dashboardStore.snapshot.toolRows.map(\.id), ["claude"])
        XCTAssertEqual(dashboardStore.unfilteredSnapshot.eventCount, 2)
        XCTAssertEqual(dashboardStore.panelSummary.eventCount, 3)
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
        XCTAssertNil(object?["sync_mode"])
        XCTAssertNil(object?["prompt"])
        XCTAssertNil(object?["command"])
    }

    func testSanitizerRejectsSyncModeField() throws {
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
            "sync_mode": "local_only"
        ])

        XCTAssertThrowsError(try TokenUsageSanitizer.sanitizeEventJSONData(data)) { error in
            XCTAssertEqual(
                error as? TokenUsageValidationError,
                .unknownFieldPresent(["sync_mode"])
            )
        }
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

    func testSanitizerRejectsUserFacingChangesField() throws {
        let event = Self.safeEvent()
        var object = try decodedJSONObject(from: TokenUsageSanitizer.eventData(event))
        object["changes"] = "must not be accepted"

        XCTAssertThrowsError(try TokenUsageSanitizer.sanitizeEventJSONData(try jsonData(object))) { error in
            XCTAssertEqual(
                error as? TokenUsageValidationError,
                .forbiddenFieldPresent(["changes"])
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

    func testClearCodexEventsResetsHistoryAndLiveImporterStateBesideStore() throws {
        let rootURL = temporaryDirectoryURL()
        let eventsURL = rootURL.appendingPathComponent("events.json")
        let store = TokenUsageStore(fileURL: eventsURL)
        let historyStateURL = rootURL
            .appendingPathComponent("history-import", isDirectory: true)
            .appendingPathComponent("codex-session-import-state.json")
        let liveStateURL = rootURL.appendingPathComponent("codex-session-import-state.json")
        try FileManager.default.createDirectory(
            at: historyStateURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(#"{"cursor":1}"#.utf8).write(to: historyStateURL)
        try Data(#"{"cursor":2}"#.utf8).write(to: liveStateURL)

        try store.clearEvents(forAITool: TokenUsageAITool.codex.rawValue)

        XCTAssertFalse(FileManager.default.fileExists(atPath: historyStateURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: liveStateURL.path))
    }

    func testClearClaudeEventsKeepsLiveStateAndResetsHistoryStateBesideStore() throws {
        let rootURL = temporaryDirectoryURL()
        let eventsURL = rootURL.appendingPathComponent("events.json")
        let store = TokenUsageStore(fileURL: eventsURL)
        let liveStateURL = rootURL
            .appendingPathComponent("session-state", isDirectory: true)
            .appendingPathComponent("session-a.json")
        let historyStateURL = rootURL
            .appendingPathComponent("history-import", isDirectory: true)
            .appendingPathComponent("claude-session-state", isDirectory: true)
            .appendingPathComponent("session-a.json")
        try FileManager.default.createDirectory(
            at: liveStateURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: historyStateURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(#"{"fresh":100}"#.utf8).write(to: liveStateURL)
        try Data(#"{"fresh":200}"#.utf8).write(to: historyStateURL)

        try store.clearEvents(forAITool: TokenUsageAITool.claude.rawValue)

        XCTAssertTrue(FileManager.default.fileExists(atPath: liveStateURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: historyStateURL.path))
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
            taskType: .codeReview,
            stage: .verify,
            model: "claude-indexed"
        )

        try store.appendEvent(event)

        let rows = try sqliteRows(
            databaseURL: store.eventsDatabaseURL,
            sql: """
            SELECT
                device_id,
                project_id,
                artifact_id,
                run_id,
                task_type,
                stage,
                model,
                ai_tool,
                input_tokens,
                output_tokens,
                latency_ms,
                total_tokens,
                source_system,
                source_user,
                source_history,
                source_repo_context,
                source_tool_output,
                source_generated_output,
                source_unknown
            FROM token_usage_events
            WHERE span_id = 'span_indexed'
            """,
            columnCount: 19
        )
        XCTAssertEqual(rows, [[
            "device_local",
            "project_local",
            "artifact_one",
            "run_indexed",
            "code_review",
            "verify",
            "claude-indexed",
            "claude",
            "100",
            "50",
            "20",
            "150",
            "10",
            "20",
            "20",
            "30",
            "20",
            "50",
            "0"
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
        XCTAssertTrue(indexNames.contains("idx_token_usage_events_project_created_at"))
    }

    func testStoreReadsPeriodTotalWithoutLoadingEvents() throws {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let start = try Self.date("2026-06-05T15:00:00.000Z")
        let end = try Self.date("2026-06-06T15:00:00.000Z")
        try store.appendEvent(Self.safeEvent(
            spanID: "span_before_period",
            inputTokens: 9_000,
            outputTokens: 1_000,
            createdAt: "2026-06-05T14:59:59.000Z"
        ))
        try store.appendEvent(Self.safeEvent(
            aiTool: .codex,
            spanID: "span_today_codex",
            inputTokens: 100,
            outputTokens: 50,
            createdAt: "2026-06-05T15:00:00.000Z"
        ))
        try store.appendEvent(Self.safeEvent(
            aiTool: .claude,
            spanID: "span_today_claude",
            inputTokens: 200,
            outputTokens: 80,
            createdAt: "2026-06-06T14:59:59.000Z"
        ))
        try store.appendEvent(Self.safeEvent(
            aiTool: .openAI,
            spanID: "span_today_openai",
            inputTokens: 700,
            outputTokens: 200,
            createdAt: "2026-06-06T01:00:00.000Z"
        ))

        XCTAssertEqual(
            store.totalTokens(startingAt: start, endingBefore: end),
            430
        )
        XCTAssertEqual(
            store.totalTokens(startingAt: start, endingBefore: end, dashboardToolsOnly: false),
            1_330
        )
    }

    func testStoreReadsAllDashboardPeriodTotalsWithoutLoadingEvents() throws {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let now = try Self.date("2026-06-19T12:00:00.000Z")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        try store.appendEvent(Self.safeEvent(
            aiTool: .codex,
            spanID: "span_all_periods_today_codex",
            inputTokens: 100,
            outputTokens: 20,
            createdAt: "2026-06-19T03:00:00.000Z"
        ))
        try store.appendEvent(Self.safeEvent(
            aiTool: .claude,
            spanID: "span_all_periods_seven_claude",
            inputTokens: 200,
            outputTokens: 30,
            createdAt: "2026-06-13T12:00:00.000Z"
        ))
        try store.appendEvent(Self.safeEvent(
            aiTool: .antigravity,
            spanID: "span_all_periods_thirty_antigravity",
            inputTokens: 300,
            outputTokens: 40,
            createdAt: "2026-05-30T12:00:00.000Z"
        ))
        try store.appendEvent(Self.safeEvent(
            aiTool: .codex,
            spanID: "span_all_periods_all_codex",
            inputTokens: 400,
            outputTokens: 50,
            createdAt: "2026-05-10T12:00:00.000Z"
        ))
        try store.appendEvent(Self.safeEvent(
            aiTool: .openAI,
            spanID: "span_all_periods_today_openai",
            inputTokens: 500,
            outputTokens: 60,
            createdAt: "2026-06-19T04:00:00.000Z"
        ))

        let dashboardTotals = store.allPeriodTotalTokens(now: now, calendar: calendar)
        XCTAssertEqual(dashboardTotals[.today], 120)
        XCTAssertEqual(dashboardTotals[.sevenDays], 350)
        XCTAssertEqual(dashboardTotals[.thirtyDays], 690)
        XCTAssertEqual(dashboardTotals[.all], 1_140)

        let allToolTotals = store.allPeriodTotalTokens(
            now: now,
            calendar: calendar,
            dashboardToolsOnly: false
        )
        XCTAssertEqual(allToolTotals[.today], 680)
        XCTAssertEqual(allToolTotals[.sevenDays], 910)
        XCTAssertEqual(allToolTotals[.thirtyDays], 1_250)
        XCTAssertEqual(allToolTotals[.all], 1_700)
    }

    func testStoreReadsDashboardSummaryWithoutLoadingEvents() throws {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        try store.appendEvent(Self.safeEvent(
            aiTool: .codex,
            spanID: "span_summary_codex",
            taskType: .analysis
        ))
        try store.appendEvent(Self.safeEvent(
            aiTool: .claude,
            spanID: "span_summary_claude",
            inputTokens: 200,
            outputTokens: 80,
            taskType: .codeReview
        ))
        try store.appendEvent(Self.safeEvent(
            aiTool: .openAI,
            spanID: "span_summary_openai",
            inputTokens: 700,
            outputTokens: 200,
            taskType: .testing
        ))

        let dashboardSummary = store.dashboardSummary()
        XCTAssertEqual(dashboardSummary.eventCount, 2)
        XCTAssertEqual(dashboardSummary.totalTokens, 430)
        XCTAssertEqual(dashboardSummary.toolTotals["codex"], 150)
        XCTAssertEqual(dashboardSummary.toolTotals["claude"], 280)
        XCTAssertNil(dashboardSummary.toolTotals["openai"])
        XCTAssertEqual(dashboardSummary.taskTotals["analysis"], 150)
        XCTAssertEqual(dashboardSummary.taskTotals["code_review"], 280)
        XCTAssertEqual(dashboardSummary.sourceTotals["system"], 10)
        XCTAssertEqual(dashboardSummary.sourceTotals["user"], 20)
        XCTAssertEqual(dashboardSummary.sourceTotals["history"], 20)
        XCTAssertEqual(dashboardSummary.sourceTotals["repo_context"], 30)
        XCTAssertEqual(dashboardSummary.sourceTotals["tool_output"], 20)
        XCTAssertEqual(dashboardSummary.sourceTotals["generated_output"], 50)
        XCTAssertEqual(dashboardSummary.sourceTotals["unknown"], 280)

        let fullSummary = store.dashboardSummary(dashboardToolsOnly: false)
        XCTAssertEqual(fullSummary.eventCount, 3)
        XCTAssertEqual(fullSummary.totalTokens, 1_330)
        XCTAssertEqual(fullSummary.toolTotals["openai"], 900)
        XCTAssertEqual(fullSummary.taskTotals["testing"], 900)
        XCTAssertEqual(fullSummary.sourceTotals["unknown"], 1_180)
    }

    func testStoreReadsDashboardSummaryForDateRangeWithoutLoadingEvents() throws {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let start = try Self.date("2026-06-05T15:00:00.000Z")
        let end = try Self.date("2026-06-06T15:00:00.000Z")
        try store.appendEvent(Self.safeEvent(
            aiTool: .codex,
            spanID: "span_summary_before_range",
            inputTokens: 9_000,
            outputTokens: 1_000,
            taskType: .testing,
            createdAt: "2026-06-05T14:59:59.000Z"
        ))
        try store.appendEvent(Self.safeEvent(
            aiTool: .codex,
            spanID: "span_summary_range_codex",
            inputTokens: 100,
            outputTokens: 50,
            taskType: .analysis,
            createdAt: "2026-06-05T15:00:00.000Z"
        ))
        try store.appendEvent(Self.safeEvent(
            aiTool: .claude,
            spanID: "span_summary_range_claude",
            inputTokens: 200,
            outputTokens: 80,
            taskType: .codeReview,
            createdAt: "2026-06-06T14:59:59.000Z"
        ))
        try store.appendEvent(Self.safeEvent(
            aiTool: .openAI,
            spanID: "span_summary_range_openai",
            inputTokens: 700,
            outputTokens: 200,
            taskType: .testing,
            createdAt: "2026-06-06T01:00:00.000Z"
        ))

        let dashboardSummary = store.dashboardSummary(startingAt: start, endingBefore: end)
        XCTAssertEqual(dashboardSummary.eventCount, 2)
        XCTAssertEqual(dashboardSummary.totalTokens, 430)
        XCTAssertEqual(dashboardSummary.toolTotals["codex"], 150)
        XCTAssertEqual(dashboardSummary.toolTotals["claude"], 280)
        XCTAssertNil(dashboardSummary.toolTotals["openai"])
        XCTAssertEqual(dashboardSummary.taskTotals["analysis"], 150)
        XCTAssertEqual(dashboardSummary.taskTotals["code_review"], 280)

        let fullSummary = store.dashboardSummary(startingAt: start, endingBefore: end, dashboardToolsOnly: false)
        XCTAssertEqual(fullSummary.eventCount, 3)
        XCTAssertEqual(fullSummary.totalTokens, 1_330)
        XCTAssertEqual(fullSummary.toolTotals["openai"], 900)
        XCTAssertEqual(fullSummary.taskTotals["testing"], 900)
    }

    func testStoreReadsPeriodTotalWithOffsetTimestamps() throws {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let start = try Self.date("2026-06-06T00:00:00.000Z")
        let end = try Self.date("2026-06-07T00:00:00.000Z")
        try store.appendEvent(Self.safeEvent(
            spanID: "span_offset_previous_day_inside",
            inputTokens: 100,
            outputTokens: 50,
            createdAt: "2026-06-05T23:30:00.000-05:00"
        ))
        try store.appendEvent(Self.safeEvent(
            aiTool: .claude,
            spanID: "span_offset_next_day_inside",
            inputTokens: 200,
            outputTokens: 80,
            createdAt: "2026-06-07T00:30:00.000+01:00"
        ))
        try store.appendEvent(Self.safeEvent(
            spanID: "span_offset_raw_day_outside_before",
            inputTokens: 9_000,
            outputTokens: 1_000,
            createdAt: "2026-06-06T00:30:00.000+01:00"
        ))
        try store.appendEvent(Self.safeEvent(
            spanID: "span_offset_raw_day_outside_after",
            inputTokens: 8_000,
            outputTokens: 2_000,
            createdAt: "2026-06-06T23:30:00.000-02:00"
        ))

        XCTAssertEqual(
            store.totalTokens(startingAt: start, endingBefore: end),
            430
        )
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
            model: "gemini-legacy",
            createdAt: "2026-06-05T23:30:00.000-05:00"
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
            SELECT
                device_id,
                project_id,
                artifact_id,
                run_id,
                task_type,
                stage,
                model,
                input_tokens,
                output_tokens,
                latency_ms,
                source_system,
                source_user,
                source_history,
                source_repo_context,
                source_tool_output,
                source_generated_output,
                source_unknown
            FROM token_usage_events
            WHERE span_id = 'span_legacy_sqlite'
            """,
            columnCount: 17
        )
        XCTAssertEqual(rows, [[
            "device_local",
            "project_local",
            "artifact_one",
            "run_legacy_sqlite",
            "debugging",
            "implement",
            "gemini-legacy",
            "300",
            "70",
            "20",
            "0",
            "0",
            "0",
            "0",
            "0",
            "0",
            "370"
        ]])
        let dateRows = try sqliteRows(
            databaseURL: databaseURL,
            sql: """
            SELECT created_at
            FROM token_usage_events
            WHERE span_id = 'span_legacy_sqlite'
            """,
            columnCount: 1
        )
        XCTAssertEqual(dateRows, [["2026-06-06T04:30:00.000Z"]])
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

    func testStoreDrainsQueuedJSONLInboxBatchEvents() throws {
        let eventsURL = temporaryEventsURL()
        let inboxURL = temporaryInboxURL()
        let store = TokenUsageStore(fileURL: eventsURL, inboxURL: inboxURL)
        let firstEvent = Self.safeEvent(
            aiTool: .codex,
            spanID: "span_jsonl_batch_01",
            inputTokens: 20,
            outputTokens: 10
        )
        let secondEvent = Self.safeEvent(
            aiTool: .claude,
            spanID: "span_jsonl_batch_02",
            inputTokens: 30,
            outputTokens: 12
        )
        try FileManager.default.createDirectory(
            at: inboxURL,
            withIntermediateDirectories: true
        )
        let batchURL = inboxURL.appendingPathComponent("001.jsonl")
        let batch = [
            String(data: try TokenUsageSanitizer.eventData(firstEvent), encoding: .utf8) ?? "",
            String(data: try TokenUsageSanitizer.eventData(secondEvent), encoding: .utf8) ?? "",
        ].joined(separator: "\n")
        try Data((batch + "\n").utf8).write(to: batchURL)

        let events = store.importQueuedEvents()

        XCTAssertEqual(events.map(\.spanID), ["span_jsonl_batch_01", "span_jsonl_batch_02"])
        XCTAssertEqual(events.map(\.aiTool), [.codex, .claude])
        XCTAssertFalse(FileManager.default.fileExists(atPath: batchURL.path))
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

    func testStoreDrainsQueuedInboxEventsInBatchesWithoutLoadingAllFiles() throws {
        let eventsURL = temporaryEventsURL()
        let inboxURL = temporaryInboxURL()
        let store = TokenUsageStore(fileURL: eventsURL, inboxURL: inboxURL)

        for index in 0..<3 {
            try store.enqueueInboxEvent(Self.safeEvent(
                spanID: "span_batch_\(index)",
                inputTokens: 10 + index,
                outputTokens: 1
            ))
        }

        XCTAssertTrue(store.importQueuedEventsWithoutLoading(maximumInboxEventCount: 2))
        XCTAssertEqual(store.loadEvents().count, 2)
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(at: inboxURL, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }
                .count,
            1
        )

        XCTAssertTrue(store.importQueuedEventsWithoutLoading(maximumInboxEventCount: 2))
        XCTAssertEqual(store.loadEvents().count, 3)
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(at: inboxURL, includingPropertiesForKeys: nil)
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

    func testBridgeClearEndpointIsDebugOnly() throws {
        let bridgeServer = try Self.source(named: "TokenUsageBridgeServer.swift")

        XCTAssertTrue(bridgeServer.contains(#"case ("DELETE", "/v1/usage/events")"#))
        XCTAssertTrue(bridgeServer.contains("guard SpillBuildOptions.developerOptionsEnabled else"))
        XCTAssertTrue(bridgeServer.contains(#"errorBody("debug_only")"#))
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
        XCTAssertTrue(prompt.contains("read-only Spill status commands"))
        XCTAssertTrue(prompt.contains("spill-token-metering-stats.mjs --tool <current-tool>"))
        XCTAssertTrue(prompt.contains("spill-token-metering-stats.mjs --tool codex"))
        XCTAssertTrue(prompt.contains("spill-token-metering-stats.mjs --tool claude"))
        XCTAssertTrue(prompt.contains("spill-token-metering-stats.mjs --tool antigravity"))
        XCTAssertTrue(prompt.contains("full self-scoped aggregate summary"))
        XCTAssertTrue(prompt.contains("workflow label coverage"))
        XCTAssertTrue(prompt.contains("unavailable detail attribution"))
        XCTAssertTrue(prompt.contains("Workflow runner permissions are separate"))
        XCTAssertTrue(prompt.contains("runtime-specific exact-count input shapes"))
        XCTAssertTrue(prompt.contains("Do not install AGY PostInvocation, Stop, or lifecycle hooks"))
        XCTAssertTrue(prompt.contains("remove managed Spill AGY hook entries"))
        XCTAssertTrue(prompt.contains("antigravity-active-importer-last.json"))
        XCTAssertFalse(prompt.contains("antigravity-last-entry.json"))
        XCTAssertFalse(prompt.contains("antigravity-hook-trace.jsonl"))
        XCTAssertTrue(prompt.contains("Claude Code uses a different Stop-hook contract"))
        XCTAssertTrue(prompt.contains("claude-last-empty.json"))
        XCTAssertTrue(prompt.contains("claude-last-mismatch.json"))
        XCTAssertTrue(prompt.contains("claude-last-success.json"))
        XCTAssertTrue(prompt.contains("observed_safe_shape booleans only"))
        XCTAssertTrue(prompt.contains("Diagnostics must never store transcript paths"))
        XCTAssertTrue(prompt.contains("Do not confuse Spill label handoff with usage metering"))
        XCTAssertTrue(prompt.contains("permission prompts alone"))
        XCTAssertTrue(prompt.contains("Do not add forced dummy tool calls"))
        XCTAssertTrue(prompt.contains("Do not implement a heuristic classifier"))
        XCTAssertTrue(prompt.contains("heuristic token-detail classifier"))
        XCTAssertTrue(prompt.contains("AGY importer side effects"))
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
        XCTAssertTrue(prompt.contains("Match the user's current conversation language"))
        XCTAssertTrue(prompt.contains("if the user has been speaking Korean, ask in Korean"))
        XCTAssertTrue(prompt.contains("visibly a decision request"))
        XCTAssertTrue(prompt.contains("not a completion summary"))
        XCTAssertTrue(prompt.contains("Connecting workflow labels is more effective for meaningful stats"))
        XCTAssertTrue(prompt.contains("Connect workflow labels (recommended)"))
        XCTAssertTrue(prompt.contains("Skip workflow labels"))
        XCTAssertTrue(prompt.contains("Should I connect workflow-aware labels now?"))
        XCTAssertFalse(prompt.contains("Do you want Spill token usage to follow your workflow steps?"))
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
        XCTAssertTrue(prompt.contains("local active importer"))
        XCTAssertTrue(prompt.contains("managed Spill AGY hook entries"))
        XCTAssertFalse(prompt.contains("~/.gemini/spill-hook.py"))
        XCTAssertFalse(prompt.contains("~/.gemini/spill-hook-wrapper.py"))
        XCTAssertFalse(prompt.contains("hook wrapper"))
        XCTAssertFalse(prompt.contains("compatibility symlink or fresh copy"))
        XCTAssertFalse(prompt.contains("root-level PostInvocation array"))
        XCTAssertFalse(prompt.contains("workflow-setup-prompt.md"))
        XCTAssertFalse(prompt.contains("Do not nest AGY hooks under \"spill-metering\""))
        XCTAssertFalse(prompt.contains("root-level PostInvocation[] with matcher"))
    }

    func testHostedTokenMeteringSetupDocsDefineRuntimeContract() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let setup = try String(contentsOf: root.appendingPathComponent("docs/token-metering/setup-prompt.md"))
        let runtime = try String(contentsOf: root.appendingPathComponent("docs/token-metering/runtime-instruction.md"))
        let installer = try String(contentsOf: root.appendingPathComponent("docs/token-metering/install.sh"))
        let helper = try String(contentsOf: root.appendingPathComponent("adapters/setup/spill-token-metering-setup.mjs"))
        let publicHelper = try String(contentsOf: root.appendingPathComponent("scripts/spill-token-metering-setup.mjs"))
        let bundledHelper = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Resources/adapters/setup/spill-token-metering-setup.mjs"))
        let statsHelper = try String(contentsOf: root.appendingPathComponent("adapters/setup/spill-token-metering-stats.mjs"))
        let publicStatsHelper = try String(contentsOf: root.appendingPathComponent("scripts/spill-token-metering-stats.mjs"))
        let bundledStatsHelper = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Resources/adapters/setup/spill-token-metering-stats.mjs"))
        let codexImporter = try String(contentsOf: root.appendingPathComponent("adapters/codex/spill-importer.mjs"))
        let antigravityImporter = try [
            "TokenUsageAntigravityImporter.swift",
            "TokenUsageAntigravityImporter+DatabaseReader.swift",
            "TokenUsageAntigravityImporter+Defaults.swift",
            "TokenUsageAntigravityImporter+Diagnostics.swift",
            "TokenUsageAntigravityImporter+EventFactory.swift",
            "TokenUsageAntigravityImporter+UsageParser.swift",
            ].map(Self.source(named:)).joined(separator: "\n")
        let claudeHook = try String(contentsOf: root.appendingPathComponent("adapters/claude-code/spill-hook.py"))
        let bundledClaudeHook = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Resources/adapters/claude-code/spill-hook.py"))
        let preferencesSection = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Preferences/TokenMeteringPreferencesSection.swift"))
        let adapterDiagnostics = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Preferences/TokenMetering/Support/TokenMeteringAdapterConnectionDiagnostics.swift"))

        XCTAssertTrue(setup.contains("MANDATORY ACTION: install or repair Spill token metering now"))
        XCTAssertTrue(setup.contains("https://spill.thdev.app/token-metering/install.sh"))
        XCTAssertTrue(setup.contains("install and repair Codex, Claude Code, and Antigravity/AGY together"))
        XCTAssertTrue(setup.contains("Codex is the OpenAI-backed agent runtime hook"))
        XCTAssertTrue(setup.contains("SPILL_AI_TOOL=claude"))
        XCTAssertTrue(setup.contains("SPILL_AI_TOOL=antigravity"))
        XCTAssertTrue(setup.contains("Spill label handoff and explicit"))
        XCTAssertTrue(setup.contains("explicit user-requested local status commands"))
        XCTAssertTrue(setup.contains("spill-token-metering-stats.mjs"))
        XCTAssertTrue(setup.contains("self-scoped summary with total"))
        XCTAssertTrue(setup.contains("workflow label coverage"))
        XCTAssertTrue(setup.contains("unavailable detail attribution"))
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
        XCTAssertTrue(setup.contains("Match the user's current\nconversation language"))
        XCTAssertTrue(setup.contains("if the user has been speaking Korean, ask in Korean"))
        XCTAssertTrue(setup.contains("visibly a decision request"))
        XCTAssertTrue(setup.contains("not a completion summary"))
        XCTAssertTrue(setup.contains("Connecting workflow labels\nis more effective for meaningful stats"))
        XCTAssertTrue(setup.contains("Connect workflow labels (recommended)"))
        XCTAssertTrue(setup.contains("Skip workflow labels"))
        XCTAssertTrue(setup.contains("Should I connect workflow-aware labels now?"))
        XCTAssertFalse(setup.contains("Do you want Spill token usage to follow your workflow steps?"))
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
        XCTAssertTrue(setup.contains("AGY collection path is the local active importer"))
        XCTAssertTrue(setup.contains("Do not install AGY `PostInvocation`, Stop, or lifecycle hooks"))
        XCTAssertTrue(setup.contains("remove managed Spill AGY hook entries"))
        XCTAssertTrue(setup.contains("antigravity-active-importer-last.json"))
        XCTAssertTrue(setup.contains("--label <current-tool>"))
        XCTAssertTrue(setup.contains("Never let Claude"))
        XCTAssertTrue(setup.contains("Never encode project names"))
        XCTAssertTrue(setup.contains("Never encode conversation titles"))
        XCTAssertFalse(setup.contains("workflow-setup-prompt.md"))
        XCTAssertFalse(setup.contains("spill-hook-wrapper.py"))
        XCTAssertFalse(setup.contains("compatibility files resolve"))
        XCTAssertFalse(setup.contains("PostInvocation[]"))
        XCTAssertTrue(setup.contains("force one strict Spill output event schema"))
        XCTAssertTrue(setup.contains("shared runtime hook input schema"))
        XCTAssertTrue(setup.contains("active importer can read exact\nnumeric usage fields"))
        XCTAssertFalse(setup.contains("antigravity-last-empty.json"))
        XCTAssertFalse(setup.contains("antigravity-last-mismatch.json"))
        XCTAssertFalse(setup.contains("antigravity-last-success.json"))
        XCTAssertFalse(setup.contains("antigravity-last-entry.json"))
        XCTAssertFalse(setup.contains("antigravity-hook-trace.jsonl"))
        XCTAssertTrue(setup.contains("claude-last-empty.json"))
        XCTAssertTrue(setup.contains("claude-last-mismatch.json"))
        XCTAssertTrue(setup.contains("claude-last-success.json"))
        XCTAssertTrue(setup.contains("observed_safe_shape"))
        XCTAssertTrue(setup.contains("Claude Code diagnostic files must use the same local-only separation"))
        XCTAssertTrue(setup.contains("Do not confuse Spill label handoff with usage metering"))
        XCTAssertTrue(setup.contains("permission prompts alone"))
        XCTAssertTrue(setup.contains("Do not add forced dummy tool calls"))
        XCTAssertTrue(setup.contains("Do not implement a heuristic classifier"))
        XCTAssertTrue(setup.contains("heuristic token-detail classifier"))
        XCTAssertTrue(setup.contains("AGY importer side effects"))
        XCTAssertFalse(setup.contains("root-level `PostInvocation[]`"))
        XCTAssertFalse(setup.contains("Do not nest this under `\"spill-metering\"`"))

        XCTAssertTrue(runtime.contains("silent background metering instruction"))
        XCTAssertTrue(runtime.contains("Do not add Spill metering status lines to normal replies"))
        XCTAssertTrue(runtime.contains("Explicit local usage status requests"))
        XCTAssertTrue(runtime.contains("spill-token-metering-stats.mjs --tool <current-tool>"))
        XCTAssertTrue(runtime.contains("spill-token-metering-stats.mjs --tool codex"))
        XCTAssertTrue(runtime.contains("spill-token-metering-stats.mjs --tool claude"))
        XCTAssertTrue(runtime.contains("spill-token-metering-stats.mjs --tool antigravity"))
        XCTAssertTrue(runtime.contains("`--self` is also allowed"))
        XCTAssertTrue(runtime.contains("workflow label coverage"))
        XCTAssertTrue(runtime.contains("model breakdown,\n  task breakdown"))
        XCTAssertTrue(runtime.contains("input/output totals first"))
        XCTAssertTrue(runtime.contains("measurement-quality data"))
        XCTAssertTrue(runtime.contains("This command is a read-only status query"))
        XCTAssertTrue(runtime.contains("Runtime input normalization"))
        XCTAssertTrue(runtime.contains("strict contract is the Spill output event schema"))
        XCTAssertTrue(runtime.contains("Runtime hook input formats are allowed to differ by tool"))
        XCTAssertTrue(runtime.contains("Antigravity/AGY uses Spill's local active importer"))
        XCTAssertTrue(runtime.contains("Do not install AGY runtime hooks"))
        XCTAssertTrue(runtime.contains("write a local-only diagnostic"))
        XCTAssertTrue(runtime.contains("antigravity-active-importer-last.json"))
        XCTAssertFalse(runtime.contains("AGY empty stdin is a normal no-event hook call"))
        XCTAssertFalse(runtime.contains("antigravity-last-entry.json"))
        XCTAssertFalse(runtime.contains("antigravity-hook-trace.jsonl"))
        XCTAssertTrue(runtime.contains("Claude Code uses a different Stop-hook contract"))
        XCTAssertTrue(runtime.contains("claude-last-mismatch.json"))
        XCTAssertTrue(runtime.contains("AGY evidence discipline"))
        XCTAssertTrue(runtime.contains("label handoff command or permission prompt"))
        XCTAssertTrue(runtime.contains("Do not force dummy tool calls"))
        XCTAssertTrue(runtime.contains("Do not add AGY Stop, PostInvocation, or lifecycle hooks"))
        XCTAssertTrue(runtime.contains("short-lived safe label context"))
        XCTAssertTrue(runtime.contains("Workflow integration is an enhancement, not a prerequisite"))
        XCTAssertTrue(runtime.contains("Workflow-provided labels win"))
        XCTAssertTrue(runtime.contains("two active layers, not as a\n  choice between modes"))
        XCTAssertTrue(runtime.contains("Do not remove, disable, or overwrite existing workflow-provided label hooks"))
        XCTAssertTrue(runtime.contains("--if-absent"))
        XCTAssertTrue(runtime.contains("Always attempt the per-turn fallback label with `--if-absent`"))
        XCTAssertTrue(runtime.contains("omit `--if-absent`"))
        XCTAssertTrue(runtime.contains("Do not infer labels from tool names"))
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
        XCTAssertTrue(runtime.contains("Spill applies its own\n  sync policy from app settings"))
        XCTAssertFalse(runtime.contains("`sync_mode`"))
        XCTAssertTrue(runtime.contains("unknown` equal to `total_tokens`"))
        XCTAssertTrue(runtime.contains("unavailable detail attribution"))
        XCTAssertFalse(runtime.contains("ollama"))

        XCTAssertTrue(installer.contains("BASE_URL"))
        XCTAssertTrue(installer.contains("adapters/setup/spill-token-metering-setup.mjs"))
        XCTAssertTrue(installer.contains("adapters/setup/spill-token-metering-stats.mjs"))
        XCTAssertTrue(installer.contains("adapters/codex/spill-importer.mjs"))
        XCTAssertTrue(installer.contains("adapters/claude-code/spill-hook.py"))
        XCTAssertFalse(installer.contains("adapters/antigravity/spill-hook.py"))
        XCTAssertFalse(installer.contains("adapters/antigravity/spill-hook-wrapper.py"))
        XCTAssertTrue(installer.contains("--include codex,claude,antigravity"))
        XCTAssertTrue(installer.contains("--source-root \"$TMP_DIR/adapters\""))

        XCTAssertTrue(helper.contains("configureRuntimeLabelDefaults"))
        XCTAssertEqual(helper, publicHelper)
        XCTAssertEqual(helper, bundledHelper)
        XCTAssertEqual(statsHelper, publicStatsHelper)
        XCTAssertEqual(statsHelper, bundledStatsHelper)
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
        XCTAssertTrue(helper.contains("active_importer_only"))
        XCTAssertTrue(helper.contains("removeAgyHookFile"))
        XCTAssertTrue(helper.contains("removeLegacyClaudeScannerLaunchAgent"))
        XCTAssertTrue(helper.contains("net.thdev.spill.claude-scanner.plist"))
        XCTAssertTrue(helper.contains(#""bootout""#))
        XCTAssertFalse(helper.contains("runtime_restart_required"))
        XCTAssertFalse(helper.contains("installAntigravityWrapper"))
        XCTAssertFalse(helper.contains("agentcatd"))
        XCTAssertFalse(helper.contains("daemon_restarted"))
        XCTAssertTrue(helper.contains(#".claude", "settings.json"#))
        XCTAssertTrue(helper.contains(#""spill-hook.py""#))
        XCTAssertTrue(helper.contains(#""spill-hook-wrapper.py""#))
        XCTAssertTrue(helper.contains(#".gemini", "antigravity-cli", "settings.json"#))
        XCTAssertFalse(helper.contains("Allow trusted AgentPlaybook"))
        XCTAssertTrue(helper.contains("permissionPathVariants"))
        XCTAssertTrue(helper.contains("homeEnvironmentPathVariants"))
        XCTAssertTrue(helper.contains("doubleQuote(path)"))
        XCTAssertFalse(preferencesSection.contains(#"compatibilityURLs: [homeURL(".gemini/spill-hook.py")]"#))
        XCTAssertTrue(adapterDiagnostics.contains("resolvingSymlinksInPath()"))
        XCTAssertTrue(adapterDiagnostics.contains("contentsEqual("))
        XCTAssertTrue(helper.contains("$HOME/${suffix}"))
        XCTAssertTrue(helper.contains(#"\${HOME}/${suffix}"#))
        XCTAssertTrue(helper.contains(#"normalized === "agy""#))
        XCTAssertTrue(helper.contains(#"return "antigravity""#))
        XCTAssertTrue(helper.contains("isStaleAgentRuntimePermissionEntry"))
        XCTAssertTrue(helper.contains("shellQuote(path)"))
        XCTAssertTrue(helper.contains("node ${path} --label ${tool}"))
        XCTAssertTrue(helper.contains("statsHelperPath"))
        XCTAssertTrue(helper.contains("resolveStatsHelperSource"))
        XCTAssertTrue(helper.contains("node ${path} --self"))
        XCTAssertTrue(helper.contains("node ${path} --tool ${tool}"))
        XCTAssertTrue(helper.contains(#"pattern: ["node", path, "--label", "codex"]"#))
        XCTAssertTrue(helper.contains(#"pattern: ["node", path, "--self"]"#))
        XCTAssertTrue(helper.contains(#"pattern: ["node", path, "--tool", "codex"]"#))
        XCTAssertFalse(helper.contains("python3 scripts/${script}"))
        XCTAssertFalse(helper.contains("--agent-playbook-home"))
        XCTAssertTrue(helper.contains("--if-absent"))
        XCTAssertTrue(helper.contains("readActiveRuntimeLabel"))
        XCTAssertTrue(helper.contains("project_id"))
        XCTAssertTrue(helper.contains("project-identity-salt"))
        XCTAssertTrue(helper.contains(#""label_exists""#))
        XCTAssertFalse(helper.contains("dominantStageForTask"))
        XCTAssertFalse(helper.contains("implementationDominantTaskTypes"))

        XCTAssertTrue(statsHelper.contains("spill-token-metering-stats.mjs"))
        XCTAssertTrue(statsHelper.contains(#""-readonly", "-json""#))
        XCTAssertTrue(statsHelper.contains("token_usage_events"))
        XCTAssertTrue(statsHelper.contains("source_system"))
        XCTAssertTrue(statsHelper.contains("json_extract(CAST(payload_json AS TEXT), '$.input_tokens')"))
        XCTAssertTrue(statsHelper.contains("model/task/stage breakdowns"))
        XCTAssertTrue(statsHelper.contains("workflow_labeled_events"))
        XCTAssertTrue(statsHelper.contains("workflow label coverage"))
        XCTAssertTrue(statsHelper.contains("Label Coverage"))
        XCTAssertTrue(statsHelper.contains("Detail Quality"))
        XCTAssertTrue(statsHelper.contains("recent activity"))
        XCTAssertTrue(statsHelper.contains("--self"))
        XCTAssertFalse(statsHelper.contains("INSERT "))
        XCTAssertFalse(statsHelper.contains("UPDATE "))
        XCTAssertFalse(statsHelper.contains("DELETE "))
        XCTAssertFalse(statsHelper.contains("writeFile"))
        XCTAssertFalse(statsHelper.contains("appendFile"))

        XCTAssertTrue(codexImporter.contains("labelForTimestamp(runtimeLabel, record.timestamp)"))
        XCTAssertTrue(codexImporter.contains("const records = []"))
        XCTAssertTrue(codexImporter.contains("shouldAdvanceCursor(cursor, nextCursor)"))
        XCTAssertTrue(codexImporter.contains("timestamp < entry.updatedAt"))
        XCTAssertTrue(codexImporter.contains("timestamp > entry.expiresAt"))
        XCTAssertTrue(codexImporter.contains("usedRuntimeLabel"))
        XCTAssertTrue(codexImporter.contains("taskType: taskTypeOverride ?? eventLabel.taskType ?? fallbackLabel.taskType"))

        XCTAssertTrue(antigravityImporter.contains("SELECT idx, data FROM gen_metadata ORDER BY idx"))
        XCTAssertTrue(antigravityImporter.contains("SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX"))
        XCTAssertTrue(antigravityImporter.contains("artifactID: \"artifact_global\""))
        XCTAssertTrue(antigravityImporter.contains("Observed AGY gen_metadata usage fields"))
        XCTAssertTrue(antigravityImporter.contains("Observed AGY model fields"))
        XCTAssertTrue(antigravityImporter.contains("antigravity-active-importer-last.json"))
        XCTAssertTrue(antigravityImporter.contains("opaqueHash"))
        XCTAssertFalse(antigravityImporter.contains("transcript_path"))
        XCTAssertFalse(antigravityImporter.contains("PostInvocation"))
        XCTAssertTrue(claudeHook.contains("DIAGNOSTICS_DIR"))
        XCTAssertTrue(claudeHook.contains("claude-last-empty.json"))
        XCTAssertTrue(claudeHook.contains("claude-last-mismatch.json"))
        XCTAssertTrue(claudeHook.contains("claude-last-success.json"))
        XCTAssertTrue(claudeHook.contains("transcript_path"))
        XCTAssertTrue(claudeHook.contains("No payload values"))
        XCTAssertFalse(claudeHook.contains("traceback.print_exc"))
        XCTAssertEqual(claudeHook, bundledClaudeHook)
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
        XCTAssertEqual(success["total_tokens"] as? Int, 132)
        XCTAssertNil(success["run_id"])
        XCTAssertNil(success["span_id"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: mismatchURL.path))

        let events = try antigravityEventObjects(in: inboxURL)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?["ai_tool"] as? String, "claude")
        XCTAssertEqual(events.first?["input_tokens"] as? Int, 125)
        XCTAssertEqual(events.first?["output_tokens"] as? Int, 7)
        let stateURL = sessionStateURL.appendingPathComponent("claudeDiag01.json")
        let state = try String(contentsOf: stateURL)
        XCTAssertTrue(state.contains(#""byte_offset""#))
        XCTAssertFalse(state.contains(transcriptURL.path))

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
            #"{"message":{"role":"assistant","model":"claude-sonnet-4","usage":{"iterations":[{"usage":{"input_tokens":6,"cache_creation":{"ephemeral_1h_input_tokens":2},"cache_read_input_tokens":1,"output_tokens":3}}]},"content":[{"type":"tool_use","name":"Edit"}]}}"#,
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
        XCTAssertEqual(refreshedEvents.compactMap { $0["total_tokens"] as? Int }.sorted(), [21, 132])
        XCTAssertFalse(FileManager.default.fileExists(atPath: emptyURL.path))
    }

    func testAdapterHookConfigsUseExactRuntimeHookShapes() throws {
        let claudePath = URL(fileURLWithPath: "/tmp/Spill Support/adapters/claude-code/spill-hook.py")
        let codexPath = URL(fileURLWithPath: "/tmp/Spill Support/adapters/codex/spill-importer.mjs")

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

        XCTAssertNil(TokenMeteringAdapterKit.agy.hookConfig(installedAt: URL(fileURLWithPath: "/tmp/unused")))
        XCTAssertNil(TokenMeteringAdapterKit.agy.hookConfigTarget)
        XCTAssertEqual(TokenMeteringAdapterKit.agy.subtitle, "Active importer — no runtime hook")
    }

    func testAdapterInstallPathsUseHookRuntimeDirectories() {
        XCTAssertEqual(
            TokenMeteringAdapterKit.hookAdapters.map(\.aiTool),
            [.claude, .codex]
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
        XCTAssertEqual(
            TokenMeteringSetupInstaller.setupCommand(),
            #"/bin/bash -c "$(curl -fsSL https://spill.thdev.app/token-metering/install.sh)""#
        )
        XCTAssertTrue(
            TokenMeteringSetupInstaller.defaultStatsInstallURL()
                .path
                .contains("/adapters/setup/spill-token-metering-stats.mjs")
        )
    }

    func testDashboardSnapshotShowsTokensWithShareBadges() {
        let event = Self.safeEvent(
            aiTool: .claude,
            spanID: "span_cost_01",
            inputTokens: 100_000,
            outputTokens: 50_000,
            taskType: .codeReview,
            stage: .verify
        )
        let events = [event]

        let tokensSnapshot = TokenUsageDashboardSnapshot(events: events)
        XCTAssertEqual(tokensSnapshot.totalTokens, 150_000)
        XCTAssertEqual(tokensSnapshot.kpis.first(where: { $0.id == "total" })?.value, "150K")
        XCTAssertEqual(tokensSnapshot.toolRows.first?.value, "150K (100.0%)")
        XCTAssertEqual(tokensSnapshot.sessions.first?.value, "150K")

        let emptySnapshot = TokenUsageDashboardSnapshot(events: [])
        XCTAssertEqual(emptySnapshot.kpis.first(where: { $0.id == "total" })?.value, "0")
    }

    func testDashboardSnapshotShowsWorkflowUsageRatios() {
        let assisted = Self.safeEvent(
            runID: "run_workflow_assisted",
            spanID: "span_workflow_assisted",
            inputTokens: 80,
            outputTokens: 20,
            taskType: .codeGeneration,
            stage: .implement
        )
        let untracked = Self.safeEvent(
            runID: "run_untracked",
            spanID: "span_untracked",
            inputTokens: 300,
            outputTokens: 100,
            taskType: .uncategorized,
            stage: .summarize
        )

        let snapshot = TokenUsageDashboardSnapshot(events: [assisted, untracked], language: .english)
        let rowsByID = Dictionary(uniqueKeysWithValues: snapshot.workflowUsage.rows.map { ($0.id, $0) })
        let workRow = rowsByID["work"]
        let tokensRow = rowsByID["tokens"]

        XCTAssertEqual(workRow?.title, "Assisted work")
        XCTAssertEqual(workRow?.value, "50.0%")
        XCTAssertEqual(workRow?.ratio ?? -1, 0.5, accuracy: 0.0001)
        XCTAssertEqual(tokensRow?.title, "Assisted tokens")
        XCTAssertEqual(tokensRow?.value, "20.0%")
        XCTAssertEqual(tokensRow?.ratio ?? -1, 0.2, accuracy: 0.0001)
    }

    func testDashboardSnapshotLeavesWorkflowUsageEmptyWithoutEvents() {
        let snapshot = TokenUsageDashboardSnapshot(events: [])

        XCTAssertTrue(snapshot.workflowUsage.rows.isEmpty)
    }

    func testDashboardTokenFormattingCompactsLargeValuesAndKeepsSmallValues() {
        XCTAssertEqual(TokenUsageDashboardSnapshot.formatTokens(9_999), "9,999")
        XCTAssertEqual(TokenUsageDashboardSnapshot.formatTokens(10_000), "10K")
        XCTAssertEqual(TokenUsageDashboardSnapshot.formatTokens(1_439_865), "1.44M")
        XCTAssertEqual(TokenUsageDashboardSnapshot.formatTokens(282_196_651), "282.2M")
        XCTAssertEqual(TokenUsageDashboardSnapshot.formatCount(10_000), "10,000")
        XCTAssertEqual(TokenMeteringL10n.localEventsDetail(eventCount: 10_000, language: .english), "10,000 local records")
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

    func testDashboardSnapshotSeparatesWorkItemsByProjectID() {
        let first = Self.safeEvent(
            spanID: "span_project_first",
            inputTokens: 80,
            outputTokens: 20,
            projectID: "project_aaaaaaaaaaaa5aaaaaaa9aaaaaaaaaaa",
            taskType: .codeGeneration,
            stage: .implement,
            model: "project-first-model",
            createdAt: "2026-06-05T00:00:00.000Z"
        )
        let second = Self.safeEvent(
            spanID: "span_project_second",
            inputTokens: 30,
            outputTokens: 20,
            projectID: "project_bbbbbbbbbbbb5bbbbbbb9bbbbbbbbbbb",
            taskType: .codeGeneration,
            stage: .implement,
            model: "project-second-model",
            createdAt: "2026-06-05T00:01:00.000Z"
        )
        let initial = TokenUsageDashboardSnapshot(events: [first, second])

        XCTAssertEqual(initial.sessions.count, 2)
        XCTAssertEqual(Set(initial.sessions.map { $0.id }).count, 2)
        XCTAssertEqual(Set(initial.sessions.map { $0.title }), ["Code generation - Implement"])

        let selectedID = try! XCTUnwrap(initial.sessions.first?.id)
        let selected = TokenUsageDashboardSnapshot(events: [first, second], selectedSessionID: selectedID)

        XCTAssertEqual(selected.eventCount, 1)
        XCTAssertEqual(selected.totalTokens, 50)
    }

    func testDashboardSnapshotFiltersWorkItemsByProjectID() {
        let first = Self.safeEvent(
            spanID: "span_project_filter_first",
            inputTokens: 20,
            outputTokens: 5,
            projectID: "project_aaaaaaaaaaaa5aaaaaaa9aaaaaaaaaaa",
            taskType: .codeGeneration,
            stage: .implement,
            model: "project-filter-first-model",
            createdAt: "2026-06-05T00:00:00.000Z"
        )
        let second = Self.safeEvent(
            spanID: "span_project_filter_second",
            inputTokens: 300,
            outputTokens: 200,
            projectID: "project_bbbbbbbbbbbb5bbbbbbb9bbbbbbbbbbb",
            taskType: .codeGeneration,
            stage: .implement,
            model: "project-filter-second-model",
            createdAt: "2026-06-05T00:01:00.000Z"
        )

        let initial = TokenUsageDashboardSnapshot(events: [first, second], language: .english)
        XCTAssertEqual(initial.projectFilters.map(\.title), ["All folders", "Folder aaaaaaaa", "Folder bbbbbbbb"])
        XCTAssertEqual(initial.projectFilters.first?.isSelected, true)
        XCTAssertEqual(Set(initial.sessions.map(\.projectTitle)), ["Folder aaaaaaaa", "Folder bbbbbbbb"])

        let filtered = TokenUsageDashboardSnapshot(
            events: [first, second],
            selectedProjectID: "project_aaaaaaaaaaaa5aaaaaaa9aaaaaaaaaaa",
            language: .english
        )

        XCTAssertEqual(filtered.selectedProjectID, "project_aaaaaaaaaaaa5aaaaaaa9aaaaaaaaaaa")
        XCTAssertEqual(filtered.sessions.count, 1)
        XCTAssertEqual(filtered.sessions.first?.projectTitle, "Folder aaaaaaaa")
        XCTAssertEqual(filtered.totalTokens, 25)
        XCTAssertEqual(filtered.projectFilters.first { $0.projectID == "project_aaaaaaaaaaaa5aaaaaaa9aaaaaaaaaaa" }?.isSelected, true)
    }

    func testDashboardSnapshotToolFiltersRespectSelectedProjectID() {
        let projectA = "project_aaaaaaaaaaaa5aaaaaaa9aaaaaaaaaaa"
        let projectB = "project_bbbbbbbbbbbb5bbbbbbb9bbbbbbbbbbb"
        let codexProjectA = Self.safeEvent(
            aiTool: .codex,
            spanID: "span_tool_filter_codex_project_a",
            inputTokens: 20,
            outputTokens: 5,
            projectID: projectA,
            createdAt: "2026-06-05T00:00:00.000Z"
        )
        let claudeProjectB = Self.safeEvent(
            aiTool: .claude,
            spanID: "span_tool_filter_claude_project_b",
            inputTokens: 300,
            outputTokens: 200,
            projectID: projectB,
            createdAt: "2026-06-05T00:01:00.000Z"
        )
        let antigravityProjectB = Self.safeEvent(
            aiTool: .antigravity,
            spanID: "span_tool_filter_antigravity_project_b",
            inputTokens: 20,
            outputTokens: 10,
            projectID: projectB,
            createdAt: "2026-06-05T00:02:00.000Z"
        )

        let filtered = TokenUsageDashboardSnapshot(
            events: [codexProjectA, claudeProjectB, antigravityProjectB],
            selectedProjectID: projectB,
            language: .english
        )

        XCTAssertEqual(filtered.totalTokens, 530)
        XCTAssertEqual(filtered.toolRows.map(\.title), ["Claude", "Antigravity (agy)"])
        XCTAssertEqual(filtered.toolFilters.first?.title, "All")
        XCTAssertTrue(filtered.toolFilters.first?.detail.contains("530") == true)
        XCTAssertEqual(filtered.toolFilters.first { $0.tool == .codex }?.detail, "0")
        XCTAssertEqual(filtered.toolFilters.first { $0.tool == .claude }?.detail, "500")
        XCTAssertEqual(filtered.toolFilters.first { $0.tool == .antigravity }?.detail, "30")
        XCTAssertEqual(filtered.toolFilters.first { $0.tool == .claude }?.shareLabel, "94.3%")
        XCTAssertEqual(filtered.toolFilters.first { $0.tool == .antigravity }?.shareLabel, "5.7%")
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

    func testDashboardSnapshotBuildsDailyTrendBucketsForPeriodRanges() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let now = try Self.date("2026-06-15T12:00:00.000Z")
        let events = [
            Self.safeEvent(
                spanID: "span_before_30_days",
                inputTokens: 900,
                outputTokens: 100,
                createdAt: "2026-05-01T12:00:00.000Z"
            ),
            Self.safeEvent(
                spanID: "span_inside_30_days",
                inputTokens: 100,
                outputTokens: 50,
                createdAt: "2026-06-01T12:00:00.000Z"
            ),
            Self.safeEvent(
                spanID: "span_before_seven_calendar_days",
                inputTokens: 1_000,
                outputTokens: 0,
                createdAt: "2026-06-08T13:00:00.000Z"
            ),
            Self.safeEvent(
                spanID: "span_seven_days_start",
                inputTokens: 100,
                outputTokens: 50,
                createdAt: "2026-06-09T12:00:00.000Z"
            ),
            Self.safeEvent(
                spanID: "span_seven_days_peak",
                inputTokens: 250,
                outputTokens: 50,
                createdAt: "2026-06-10T12:00:00.000Z"
            ),
            Self.safeEvent(
                spanID: "span_today_trend",
                inputTokens: 40,
                outputTokens: 10,
                createdAt: "2026-06-15T08:00:00.000Z"
            )
        ]

        let sevenDays = TokenUsageDashboardSnapshot(
            events: events,
            selectedPeriod: .sevenDays,
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: timeZone
        )
        XCTAssertEqual(sevenDays.trendBuckets.count, 7)
        XCTAssertEqual(sevenDays.trendBuckets.first?.id, "2026-06-09")
        XCTAssertEqual(sevenDays.trendBuckets.last?.id, "2026-06-15")
        XCTAssertFalse(sevenDays.trendBuckets.contains { $0.id == "2026-06-01" })
        XCTAssertEqual(sevenDays.totalTokens, 500)
        XCTAssertEqual(sevenDays.trendBuckets.first { $0.id == "2026-06-10" }?.ratio ?? -1, 1.0, accuracy: 0.0001)
        XCTAssertTrue(sevenDays.trendBuckets.first { $0.id == "2026-06-15" }?.hasEvents == true)

        let thirtyDays = TokenUsageDashboardSnapshot(
            events: events,
            selectedPeriod: .thirtyDays,
            now: now,
            calendar: calendar,
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: timeZone
        )
        XCTAssertEqual(thirtyDays.trendBuckets.count, 30)
        XCTAssertEqual(thirtyDays.trendBuckets.first?.id, "2026-05-17")
        XCTAssertEqual(thirtyDays.trendBuckets.last?.id, "2026-06-15")
        XCTAssertTrue(thirtyDays.trendBuckets.contains { $0.id == "2026-06-01" && $0.hasEvents })
    }

    func testDashboardSnapshotBuildsMonthlyTrendBucketsForAllPeriod() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let events = [
            Self.safeEvent(
                spanID: "span_january_trend",
                inputTokens: 100,
                outputTokens: 0,
                createdAt: "2026-01-15T12:00:00.000Z"
            ),
            Self.safeEvent(
                spanID: "span_march_trend",
                inputTokens: 200,
                outputTokens: 0,
                createdAt: "2026-03-03T12:00:00.000Z"
            )
        ]

        let snapshot = TokenUsageDashboardSnapshot(
            events: events,
            selectedPeriod: .all,
            now: try Self.date("2026-06-15T12:00:00.000Z"),
            calendar: calendar,
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: timeZone
        )

        XCTAssertEqual(snapshot.trendBuckets.map(\.id), ["2026-01", "2026-02", "2026-03"])
        XCTAssertTrue(snapshot.trendBuckets.contains { $0.id == "2026-02" && !$0.hasEvents && $0.ratio == 0 })
        XCTAssertEqual(snapshot.trendBuckets.first { $0.id == "2026-01" }?.ratio ?? -1, 0.5, accuracy: 0.0001)
        XCTAssertEqual(snapshot.trendBuckets.first { $0.id == "2026-03" }?.ratio ?? -1, 1.0, accuracy: 0.0001)
        XCTAssertTrue(snapshot.trendBuckets.first { $0.id == "2026-03" }?.title.contains("Mar") == true)
    }

    private static func safeEvent(
        aiTool: TokenUsageAITool = .codex,
        runID: String = "run_local_01",
        spanID: String = "span_local_01",
        inputTokens: Int = 100,
        outputTokens: Int = 50,
        generatedOutput: Int? = nil,
        tokenBreakdown overrideTokenBreakdown: TokenUsageBreakdown? = nil,
        projectID: String = "project_local",
        taskType: TokenUsageTaskType = .analysis,
        stage: TokenUsageStage = .plan,
        model: String = "local-manual",
        latencyMS: Int = 20,
        createdAt: String? = nil
    ) -> TokenUsageEvent {
        let resolvedCreatedAt = createdAt ?? ISO8601DateFormatter.tokenUsage.string(from: Date())
        let totalTokens = inputTokens + outputTokens
        let tokenBreakdown: TokenUsageBreakdown
        if let overrideTokenBreakdown {
            tokenBreakdown = overrideTokenBreakdown
        } else if let generatedOutput {
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
            projectID: projectID,
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
            createdAt: resolvedCreatedAt
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

    private func writeAntigravityConversationDatabase(at databaseURL: URL, rows: [(Int, Data)]) throws {
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let database = try openSQLiteDatabase(databaseURL)
        defer { sqlite3_close(database) }

        try executeSQLite(
            """
            CREATE TABLE gen_metadata (
                idx integer,
                data blob,
                size integer NOT NULL DEFAULT 0,
                PRIMARY KEY (idx)
            )
            """,
            database: database
        )

        let sql = "INSERT INTO gen_metadata (idx, data, size) VALUES (?, ?, ?)"
        for row in rows {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
                  let statement
            else {
                throw sqliteError(database)
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_int64(statement, 1, sqlite3_int64(row.0))
            sqlite3_bind_int64(statement, 3, sqlite3_int64(row.1.count))
            let result = row.1.withUnsafeBytes { buffer -> Int32 in
                sqlite3_bind_blob(statement, 2, buffer.baseAddress, Int32(buffer.count), TEST_SQLITE_TRANSIENT)
                return sqlite3_step(statement)
            }

            guard result == SQLITE_DONE else {
                throw sqliteError(database)
            }
        }
    }

    private func antigravityGenerationMetadataBlob(
        inputTokens: Int,
        outputTokens: Int,
        cachedInputTokens: Int,
        model: String
    ) -> Data {
        var usage = Data()
        usage.append(protoVarintField(1, 1020))
        usage.append(protoVarintField(2, inputTokens))
        usage.append(protoVarintField(3, outputTokens))
        usage.append(protoVarintField(5, cachedInputTokens))
        usage.append(protoVarintField(9, 12))
        usage.append(protoVarintField(10, max(0, outputTokens - 12)))

        var generation = Data()
        generation.append(protoBytesField(4, usage))
        generation.append(protoBytesField(9, antigravityTimestampBlob(seconds: 1_781_740_800)))
        generation.append(protoBytesField(19, Data(model.utf8)))

        var envelope = Data()
        envelope.append(protoBytesField(1, generation))
        return envelope
    }

    private func antigravityTimestampBlob(seconds: Int) -> Data {
        var timestampMessage = Data()
        timestampMessage.append(protoVarintField(1, seconds))

        var timestampContainer = Data()
        timestampContainer.append(protoBytesField(4, timestampMessage))
        return timestampContainer
    }

    private func protoVarintField(_ number: Int, _ value: Int) -> Data {
        var data = protoVarint(UInt64(number << 3))
        data.append(protoVarint(UInt64(max(0, value))))
        return data
    }

    private func protoBytesField(_ number: Int, _ value: Data) -> Data {
        var data = protoVarint(UInt64((number << 3) | 2))
        data.append(protoVarint(UInt64(value.count)))
        data.append(value)
        return data
    }

    private func protoVarint(_ value: UInt64) -> Data {
        var value = value
        var bytes = [UInt8]()

        repeat {
            var byte = UInt8(value & 0x7f)
            value >>= 7
            if value != 0 {
                byte |= 0x80
            }
            bytes.append(byte)
        } while value != 0

        return Data(bytes)
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

    private func temporaryDirectoryURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    @MainActor
    private func dashboardStore(usageStore: TokenUsageStore) -> TokenUsageDashboardStore {
        TokenUsageDashboardStore(usageStore: usageStore)
    }

    @MainActor
    private func waitForDashboardStoreRefresh(_ store: TokenUsageDashboardStore) async throws {
        for _ in 0..<20 {
            if !store.isDashboardRefreshInProgress {
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("Dashboard store refresh did not finish")
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

    private static func source(named fileName: String) throws -> String {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let sourcesURL = root.appendingPathComponent("Sources/Spill", isDirectory: true)
        let urls = FileManager.default.enumerator(
            at: sourcesURL,
            includingPropertiesForKeys: nil
        )?
            .compactMap { $0 as? URL }
            .filter { $0.lastPathComponent == fileName }
            .sorted { $0.path < $1.path } ?? []
        let sourceURL = try XCTUnwrap(urls.first, "Missing source file named \(fileName)")
        return try String(contentsOf: sourceURL)
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
