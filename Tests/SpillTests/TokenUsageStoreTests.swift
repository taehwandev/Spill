import Foundation
import Darwin
import SQLite3
import XCTest
@testable import Spill

private let TEST_SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

extension TokenUsageStoreTests {
    func testSetupActionsAndInstalledToolSectionsUseSharedAvailability() throws {
        let preferencesSection = try Self.source(named: "TokenMeteringPreferencesSection.swift")
        let promptCard = try Self.source(named: "TokenMeteringPromptInstructionCard.swift")
        let setupControls = try Self.source(named: "TokenMeteringSetupActionControls.swift")
        let setupActionStore = try Self.source(named: "TokenMeteringSetupActionStore.swift")
        let dashboardAgentStatus = try Self.source(named: "TokenMeteringDashboardAgentStatusPanel.swift")
        let dashboardSetupPanel = try Self.source(named: "TokenMeteringDashboardSetupPanel.swift")
        let historyImportSection = try Self.source(named: "TokenUsageHistoryImportSection.swift")
        let adapterStatusSection = try Self.source(named: "TokenMeteringAdapterStatusSection.swift")
        let spillBarAISection = try Self.source(named: "SpillBarAISection.swift")

        XCTAssertTrue(promptCard.contains("TokenMeteringSetupActionControls("))
        XCTAssertTrue(setupControls.contains("store.installOrRepair(installedTools: installedTools)"))
        XCTAssertTrue(setupControls.contains("installedTools.isEmpty"))
        XCTAssertTrue(setupControls.contains("store.isInstalled ? .setupReinstall : .setupInstall"))
        XCTAssertTrue(setupControls.contains("t(.copyInstallPrompt)"))
        XCTAssertTrue(setupActionStore.contains("static let shared = TokenMeteringSetupActionStore()"))
        XCTAssertTrue(setupActionStore.contains("\"--include\""))
        XCTAssertTrue(setupActionStore.contains("\"--metering-only\""))
        XCTAssertTrue(setupActionStore.contains("includedTools.joined(separator: \",\")"))
        XCTAssertTrue(setupControls.contains("t(.setupQuickStartTitle)"))
        XCTAssertTrue(setupControls.contains("t(.setupWorkflowLabelsTitle)"))
        XCTAssertFalse(dashboardAgentStatus.contains("TokenMeteringSetupActionControls("))
        XCTAssertTrue(dashboardSetupPanel.contains("TokenMeteringSetupActionControls("))
        XCTAssertTrue(dashboardAgentStatus.contains("isLocalAIToolVisible(status.kind)"))
        XCTAssertTrue(spillBarAISection.contains("isLocalAIToolVisible(status.kind)"))
        XCTAssertTrue(preferencesSection.contains("installedHistoryImportTools"))
        XCTAssertTrue(preferencesSection.contains("startImport(for: installedTools)"))
        XCTAssertTrue(historyImportSection.contains("availableSnapshots"))
        XCTAssertTrue(historyImportSection.contains("historyImportNoInstalledTools"))
        XCTAssertTrue(adapterStatusSection.contains("installedAdapters"))
        XCTAssertTrue(adapterStatusSection.contains("TokenMeteringAdapterKit.localRuntimeAdapters"))
        XCTAssertTrue(adapterStatusSection.contains("installedTools.contains($0.aiTool)"))
        XCTAssertTrue(adapterStatusSection.contains("adapter.aiTool == .antigravity"))
        XCTAssertTrue(preferencesSection.contains("TokenMeteringSetupActionStore.shared"))
        XCTAssertTrue(dashboardSetupPanel.contains("TokenMeteringSetupActionStore.shared"))
        XCTAssertTrue(preferencesSection.contains("aiStatusStore.detectedStatuses"))
        XCTAssertTrue(dashboardSetupPanel.contains("aiStatusStore.detectedStatuses"))
    }
}

extension TokenUsageStoreTests {
    func testDashboardToolVisibilityUsesSupportedToolsAndUserPreference() {
        let statuses = [
            LocalAIToolStatus(
                kind: .codex,
                value: "Ready",
                subtitle: nil,
                state: .normal
            ),
            LocalAIToolStatus(
                kind: .antigravity,
                value: "Running",
                subtitle: nil,
                state: .normal
            ),
            LocalAIToolStatus(
                kind: .ollama,
                value: "Ready",
                subtitle: nil,
                state: .normal
            )
        ]

        XCTAssertEqual(
            TokenUsageDashboardToolVisibility.visibleTools(hiddenTools: []),
            Set(TokenUsageAITool.dashboardTools)
        )
        XCTAssertEqual(
            TokenUsageDashboardToolVisibility.visibleTools(
                hiddenTools: [.codex]
            ),
            Set([.claude, .antigravity])
        )
        XCTAssertEqual(
            TokenUsageDashboardToolVisibility.visibleTools(
                hiddenTools: [.openAI, .unknown]
            ),
            Set(TokenUsageAITool.dashboardTools)
        )
        XCTAssertEqual(
            TokenUsageDashboardToolVisibility.dashboardFilterTools(
                visibleTools: [.codex],
                showAdvancedTools: false
            ),
            [.codex]
        )
        XCTAssertEqual(
            TokenUsageDashboardToolVisibility.dashboardFilterTools(
                visibleTools: [.codex],
                showAdvancedTools: true
            ),
            Set([.codex, .openAI, .unknown])
        )
        XCTAssertEqual(
            TokenMeteringToolAvailability.installedHistoryImportTools(from: statuses),
            [.codex, .antigravity]
        )
    }

    func testSupportedLocalToolKindsAlwaysIncludesAllDashboardAgents() {
        XCTAssertEqual(
            TokenMeteringToolAvailability.supportedLocalToolKinds,
            [.codex, .claude, .antigravity]
        )
    }
}

extension TokenUsageStoreTests {
    @MainActor
    func testMenuBarServerHealthUsesOnlyInstalledTools() throws {
        let defaultsName = "spill.tests.menu-bar-health.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsName))
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }
        let settings = SpillSettings(defaults: defaults)
        settings.setTokenUsageAITool(.codex, isVisible: false)

        let cacheDirectoryURL = temporaryDirectoryURL()
        try FileManager.default.createDirectory(
            at: cacheDirectoryURL,
            withIntermediateDirectories: true
        )
        let cacheURL = cacheDirectoryURL.appendingPathComponent("cloud-status.json")
        let snapshot = CloudServiceStatusSnapshot(
            fetchedAt: Date(),
            items: [
                CloudServiceStatusItem(
                    kind: .codex,
                    health: .operational,
                    detail: "test",
                    source: "test"
                ),
                CloudServiceStatusItem(
                    kind: .claudeCode,
                    health: .outage,
                    detail: "test",
                    source: "test"
                ),
                CloudServiceStatusItem(
                    kind: .antigravity,
                    health: .outage,
                    detail: "test",
                    source: "test"
                )
            ]
        )
        try JSONEncoder().encode(snapshot).write(to: cacheURL)

        let coordinator = TokenMeteringCoordinator(
            settings: settings,
            cloudServiceStatusStore: CloudServiceStatusStore(cacheURL: cacheURL),
            aiStatusStore: AIStatusStore(statuses: [
                LocalAIToolStatus(
                    kind: .codex,
                    value: "Ready",
                    subtitle: nil,
                    state: .normal
                )
            ]),
            usageStore: TokenUsageStore(fileURL: temporaryEventsURL())
        )

        XCTAssertEqual(coordinator.menuBarServerHealth, .operational)
    }
}

extension TokenUsageStoreTests {
    func testMenuBarTokenTotalsRespectVisibleSupportedTools() throws {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let end = start.addingTimeInterval(60)
        try store.replaceEvents([
            Self.safeEvent(
                aiTool: .codex,
                spanID: "span_menu_visibility_codex",
                inputTokens: 80,
                outputTokens: 20,
                createdAt: ISO8601DateFormatter.tokenUsage.string(from: start.addingTimeInterval(10))
            ),
            Self.safeEvent(
                aiTool: .antigravity,
                spanID: "span_menu_visibility_agy",
                inputTokens: 160,
                outputTokens: 40,
                createdAt: ISO8601DateFormatter.tokenUsage.string(from: start.addingTimeInterval(20))
            )
        ])

        let totals = try XCTUnwrap(
            store.menuBarTokenTotals(
                startingAt: start,
                endingBefore: end,
                visibleTools: [.codex]
            )
        )

        XCTAssertEqual(totals.dailyTokens, 100)
        XCTAssertEqual(totals.allTimeTokens, 100)
    }

    func testMenuBarTokenTotalsApplyFreshOnlyToDailyAndAllTimeValues() throws {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let end = start.addingTimeInterval(60)
        try store.replaceEvents([
            Self.safeEvent(
                aiTool: .codex,
                spanID: "span_menu_fresh_unsplit",
                inputTokens: 60,
                outputTokens: 10,
                createdAt: ISO8601DateFormatter.tokenUsage.string(from: start.addingTimeInterval(10))
            ),
            Self.safeEvent(
                aiTool: .claude,
                spanID: "span_menu_fresh_split",
                inputTokens: 125,
                outputTokens: 7,
                tokenAccounting: TokenUsageAccounting(
                    uncachedInputTokens: 20,
                    cacheCreationInputTokens: 5,
                    cacheReadInputTokens: 100
                ),
                createdAt: ISO8601DateFormatter.tokenUsage.string(from: start.addingTimeInterval(20))
            ),
            Self.safeEvent(
                aiTool: .antigravity,
                spanID: "span_menu_fresh_all_time",
                inputTokens: 90,
                outputTokens: 15,
                tokenAccounting: TokenUsageAccounting(
                    uncachedInputTokens: 50,
                    cacheReadInputTokens: 40
                ),
                createdAt: ISO8601DateFormatter.tokenUsage.string(from: end.addingTimeInterval(10))
            )
        ])

        let included = try XCTUnwrap(
            store.menuBarTokenTotals(
                startingAt: start,
                endingBefore: end,
                inputScope: .includeCache
            )
        )
        let fresh = try XCTUnwrap(
            store.menuBarTokenTotals(
                startingAt: start,
                endingBefore: end,
                inputScope: .freshOnly
            )
        )

        XCTAssertEqual(included, TokenUsageMenuBarTotals(dailyTokens: 202, allTimeTokens: 307))
        XCTAssertEqual(fresh, TokenUsageMenuBarTotals(dailyTokens: 37, allTimeTokens: 102))
    }
}

extension TokenUsageStoreTests {
    @MainActor
    func testSetupActionStoreRefreshesStateAfterDirectInstall() async throws {
        let store = TokenMeteringSetupActionStore(
            installationReader: { tools in
                tools == [.codex]
            },
            setupRunner: { tools in
                tools == [.codex] ? .succeeded : .failed
            }
        )

        store.refresh(installedTools: [.codex])
        XCTAssertTrue(store.isInstalled)

        store.installOrRepair(installedTools: [.codex])
        for _ in 0..<100 where store.operationState == .running {
            try await Task.sleep(nanoseconds: 5_000_000)
        }

        XCTAssertEqual(store.operationState, .succeeded)
        XCTAssertTrue(store.isInstalled)

        store.refresh(installedTools: [.claude])
        XCTAssertEqual(store.operationState, .idle)
        XCTAssertFalse(store.isInstalled)

        store.refresh(installedTools: [])
        XCTAssertEqual(store.operationState, .idle)
        XCTAssertFalse(store.isInstalled)
        XCTAssertFalse(TokenMeteringSetupInstallationDiagnostics.isInstalled(for: []))
    }
}

extension TokenUsageStoreTests {
    func testAntigravityConnectionStatusUsesBuiltInImporterAvailability() {
        XCTAssertTrue(
            TokenMeteringSetupInstallationDiagnostics.connectionStatus(
                for: .antigravity,
                runtimeInstalled: true
            ).isActive
        )
        XCTAssertFalse(
            TokenMeteringSetupInstallationDiagnostics.connectionStatus(
                for: .antigravity,
                runtimeInstalled: false
            ).isActive
        )
    }
}

extension TokenUsageStoreTests {
    @MainActor
    func testMenuBarAITokenStatusKeepsLastValueWhenStoreReadTemporarilyFails() async throws {
        let eventsURL = temporaryEventsURL()
        let storeDirectoryURL = eventsURL.deletingLastPathComponent()
        let store = TokenUsageStore(fileURL: eventsURL)
        let now = try Self.date("2026-07-05T10:15:00.000Z")
        try store.appendEvent(Self.safeEvent(
            spanID: "span_menu_bar_cache_survives_read_failure",
            createdAt: ISO8601DateFormatter.tokenUsage.string(from: now)
        ))

        let defaultsName = "spill.tests.menu-bar-cache.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsName))
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }
        let coordinator = TokenMeteringCoordinator(
            settings: SpillSettings(defaults: defaults),
            cloudServiceStatusStore: CloudServiceStatusStore(),
            aiStatusStore: AIStatusStore(statuses: [
                LocalAIToolStatus(
                    kind: .codex,
                    value: "Ready",
                    subtitle: nil,
                    state: .normal
                )
            ]),
            usageStore: store
        )

        await coordinator.refreshMenuBarTokenTotalAsync(now: now, force: true)
        XCTAssertEqual(coordinator.menuBarTokenTotal, 150)
        XCTAssertEqual(coordinator.menuBarAllTimeTokenTotal, 150)

        try FileManager.default.removeItem(at: storeDirectoryURL)
        try Data().write(to: storeDirectoryURL)
        defer {
            try? FileManager.default.removeItem(at: storeDirectoryURL)
        }

        await coordinator.refreshMenuBarTokenTotalAsync(now: now.addingTimeInterval(60), force: true)

        XCTAssertEqual(coordinator.menuBarTokenTotal, 150)
        XCTAssertEqual(coordinator.menuBarAllTimeTokenTotal, 150)
    }
}

extension TokenUsageStoreTests {
    func testLocalRuntimeAdaptersIncludeActiveImporterTools() {
        XCTAssertEqual(
            TokenMeteringAdapterKit.localRuntimeAdapters.map(\.aiTool),
            [.claude, .codex, .antigravity]
        )
    }
}

final class TokenUsageStoreTests: XCTestCase {
    func testPreferencesModelKeepsForbiddenContentLabels() {
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
        XCTAssertEqual(TokenMeteringL10n.text(.dashboardTitle, language: .english), "Spill - AI Token Metering")
        XCTAssertEqual(TokenMeteringL10n.text(.dashboardTitle, language: .korean), "Spill - AI Token Metering")
        XCTAssertEqual(TokenMeteringL10n.text(.dashboardTitle, language: .japanese), "Spill - AI Token Metering")
        XCTAssertEqual(TokenMeteringL10n.text(.agentConnectionStatus, language: .korean), "에이전트 연결 상태")
        XCTAssertEqual(TokenMeteringL10n.text(.agentStatusDetected, language: .english), "Detected")
        XCTAssertTrue(TokenMeteringL10n.text(.agentStatusInfoDetail, language: .korean).contains("프롬프트"))
        XCTAssertEqual(TokenMeteringL10n.text(.noAgentStatusData, language: .japanese), "ローカルエージェントは検出されていません")
        XCTAssertEqual(TokenMeteringL10n.text(.setupWorkflowLabelsTitle, language: .english), "Workflow-aware metering")
        XCTAssertTrue(TokenMeteringL10n.text(.usageInputScopeDetail, language: .english).contains("menu bar AI"))
        XCTAssertTrue(TokenMeteringL10n.text(.usageInputScopeDetail, language: .english).contains("compact panel"))
        XCTAssertTrue(TokenMeteringL10n.text(.usageInputScopeInfoDetail, language: .korean).contains("즉시 반영"))
        XCTAssertTrue(TokenMeteringL10n.text(.usageInputScopeInfoDetail, language: .korean).contains("컴팩트 패널"))
        XCTAssertEqual(TokenMeteringL10n.text(.copyWebSetup, language: .korean), "설치 명령 복사")
        XCTAssertEqual(TokenMeteringL10n.text(.adapterSetupRequired, language: .japanese), "ローカルトークン記録の設定が必要")
        XCTAssertEqual(TokenMeteringL10n.adapterInstalled("spill-hook.py", language: .english), "Installed: spill-hook.py")
        XCTAssertEqual(TokenMeteringL10n.hookConfigTarget("~/.claude/settings.json", language: .korean), "연결 설정 -> ~/.claude/settings.json")
        XCTAssertEqual(TokenMeteringL10n.text(.sourceBreakdown, language: .english), "Token Detail")
        XCTAssertEqual(TokenMeteringL10n.text(.sourceBreakdown, language: .korean), "토큰 세부 내역")
        XCTAssertEqual(TokenMeteringL10n.text(.inputAccounting, language: .korean), "원시 입력 회계")
        XCTAssertTrue(TokenMeteringL10n.text(.inputAccountingInfoDetail, language: .english).contains("Codex input already includes cache reads"))
        XCTAssertEqual(TokenMeteringL10n.text(.folderFilterHeader, language: .korean), "폴더 필터")
        XCTAssertEqual(TokenMeteringL10n.folderTitle("abcd1234", language: .english), "Folder abcd1234")
        XCTAssertEqual(TokenMeteringL10n.text(.sourceUnavailable, language: .korean), "세부 미분류")
        XCTAssertEqual(TokenMeteringL10n.text(.cumulativeOnlyBadge, language: .japanese), "合計のみ")
        XCTAssertEqual(TokenMeteringL10n.text(.clearAlias, language: .korean), "삭제")
        XCTAssertEqual(TokenMeteringL10n.text(.relativePreviousWeek, language: .english), "prev week")
        XCTAssertEqual(TokenMeteringL10n.text(.runs, language: .korean), "작업 항목")
        XCTAssertEqual(TokenMeteringL10n.text(.previewBadge, language: .english), "ALPHA")
        XCTAssertEqual(TokenMeteringL10n.text(.webSyncEnabled, language: .korean), "웹 동기화 켜짐")
        XCTAssertEqual(TokenMeteringL10n.text(.privateUsageUploadTitle, language: .korean), "비공개 사용량 업로드")
        XCTAssertEqual(
            TokenMeteringL10n.text(.privateUsageUploadConnectedDetail, language: .korean),
            "이 Mac은 연결되어 있습니다. 아래에서 업로드를 켜면 암호화된 일별 합계를 동기화하고, 연결 해제로 저장된 연결을 교체할 수 있습니다."
        )
        XCTAssertEqual(TokenMeteringL10n.text(.privateUsageUploadSyncNow, language: .japanese), "今すぐ同期")
        XCTAssertEqual(TokenMeteringL10n.text(.localDataDeleteOptions, language: .korean), "로컬 데이터 삭제")
        XCTAssertEqual(TokenMeteringL10n.text(.reviewLocalDataDelete, language: .korean), "삭제 전 확인")
        XCTAssertTrue(TokenMeteringL10n.text(.localDataManagementDetail, language: .korean).contains("연결 해제"))
        XCTAssertEqual(TokenMeteringL10n.text(.workflowUsage, language: .korean), "작업 라벨 적용률")
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

    func testBrandLockupIsSharedAcrossAppSurfaces() throws {
        let root = Self.repositoryRootURL()
        let package = try String(contentsOf: root.appendingPathComponent("Package.swift"))
        let brandLockupView = try Self.source(named: "SpillBrandLockupView.swift")
        let spillBarView = try Self.source(named: "SpillBarView.swift")
        let preferencesSidebarView = try Self.source(named: "PreferencesSidebarView.swift")
        let dashboardView = try Self.source(named: "TokenMeteringDashboardView.swift")
        let wordmarkURL = root.appendingPathComponent("Sources/Spill/Resources/Brand/spill-logo-wordmark.png")

        XCTAssertTrue(FileManager.default.fileExists(atPath: wordmarkURL.path))
        XCTAssertTrue(package.contains(".process(\"Resources/Brand\")"))
        XCTAssertTrue(brandLockupView.contains("struct SpillBrandLockupView"))
        XCTAssertTrue(brandLockupView.contains("var markStyle: MenuBarTriggerIconStyle?"))
        XCTAssertTrue(brandLockupView.contains("if let markStyle"))
        XCTAssertTrue(brandLockupView.contains("SpillResourceBundle.image(named: \"spill-logo-wordmark\")"))
        XCTAssertFalse(brandLockupView.contains("Bundle.module.image(forResource: \"spill-logo-wordmark\")"))
        XCTAssertTrue(brandLockupView.contains("Image(nsImage: image)"))
        XCTAssertTrue(spillBarView.contains("SpillBrandLockupView("))
        XCTAssertTrue(spillBarView.contains("markStyle: nil"))
        XCTAssertTrue(spillBarView.contains("private var headerSubtitle: String?"))
        XCTAssertTrue(spillBarView.contains("if panelState.readiness == .ready"))
        XCTAssertTrue(spillBarView.contains("return nil"))
        XCTAssertTrue(preferencesSidebarView.contains("SpillBrandLockupView("))
        XCTAssertTrue(preferencesSidebarView.contains("markStyle: nil"))
        XCTAssertTrue(dashboardView.contains("SpillBrandLockupView("))
        XCTAssertTrue(dashboardView.contains("subtitle: nil"))
        XCTAssertTrue(dashboardView.contains("markStyle: nil"))
        XCTAssertFalse(dashboardView.contains("Image(systemName: \"chart.bar.xaxis\")"))

        let statusModulesPreferences = try Self.source(named: "StatusModulesPreferencesSection.swift")
        XCTAssertTrue(statusModulesPreferences.contains("triggerStyle: settings.menuBarTriggerIconStyle"))
        XCTAssertTrue(statusModulesPreferences.contains("MenuBarTriggerIconRenderer.image("))
    }

    func testBrandResourceBundleResolverUsesPackagedAppResourceLocationBeforeDebugFallback() {
        let appBundleURL = URL(fileURLWithPath: "/Applications/Spill.app")
        let resourceURL = appBundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
        let candidates = SpillResourceBundle.packagedResourceBundleCandidateURLs(
            mainBundleURL: appBundleURL,
            mainResourceURL: resourceURL
        )

        XCTAssertEqual(
            candidates.first?.path,
            "/Applications/Spill.app/Contents/Resources/Spill_Spill.bundle"
        )
        XCTAssertTrue(
            candidates.contains(appBundleURL.appendingPathComponent("Spill_Spill.bundle", isDirectory: true))
        )
    }

    func testWebDashboardLinkIsAvailableFromSettingsAndLocalDashboard() throws {
        let preferencesSection = try String(contentsOf: Self.repositoryRootURL().appendingPathComponent("Sources/Spill/Preferences/TokenMeteringPreferencesSection.swift"))
        let uploadSection = try Self.source(named: "PrivateUsageUploadPreferencesSection.swift")
        let dashboardView = try Self.source(named: "TokenMeteringDashboardView.swift")
        let webConnection = try Self.source(named: "PrivateUsageWebConnection.swift")

        XCTAssertTrue(webConnection.contains("static func dashboardURL("))
        XCTAssertTrue(webConnection.contains("appendingPath(\"/dashboard\""))
        XCTAssertTrue(preferencesSection.contains("openWebDashboardAction: openPrivateUsageWebDashboard"))
        XCTAssertTrue(uploadSection.contains("Label(t(.privateUsageUploadOpenDashboard), systemImage: \"safari\")"))
        XCTAssertTrue(uploadSection.contains("PreferencesSyncLegalLinksView(language: preferencesLanguage)"))
        XCTAssertTrue(dashboardView.contains("private func openWebDashboard()"))
        XCTAssertTrue(dashboardView.contains("accessibilityLabel: t(.privateUsageUploadOpenDashboard)"))
        XCTAssertTrue(dashboardView.contains("action: openWebDashboard"))
        XCTAssertFalse(dashboardView.contains("_dummyTestReferences"))
        XCTAssertEqual(TokenMeteringL10n.text(.privateUsageUploadOpenDashboard, language: .korean), "웹 대시보드 열기")
        XCTAssertEqual(TokenMeteringL10n.text(.privateUsageUploadOpenDashboard, language: .english), "Open Web Dashboard")
        XCTAssertEqual(TokenMeteringL10n.text(.privateUsageUploadOpenDashboard, language: .japanese), "Webダッシュボードを開く")
    }

    func testLegalLinksAreAvailableFromGeneralSettingsAndSyncUpload() throws {
        let generalSection = try Self.source(named: "GeneralPreferencesSection.swift")
        let uploadSection = try Self.source(named: "PrivateUsageUploadPreferencesSection.swift")
        let legalLinkSource = try Self.source(named: "PreferencesLegalLink.swift")
        let legalLinksCard = try Self.source(named: "PreferencesLegalLinksCard.swift")
        let syncLegalLinksView = try Self.source(named: "PreferencesSyncLegalLinksView.swift")
        let legalButtons = try Self.source(named: "PreferencesLegalLinkButtons.swift")

        XCTAssertTrue(generalSection.contains("legalAndPrivacyCard"))
        XCTAssertTrue(generalSection.contains("PreferencesLegalLinksCard(language: language)"))
        XCTAssertTrue(uploadSection.contains("PreferencesSyncLegalLinksView(language: preferencesLanguage)"))
        XCTAssertTrue(legalLinksCard.contains("PreferenceCard("))
        XCTAssertTrue(syncLegalLinksView.contains("source: \"preferences_private_usage_upload\""))
        XCTAssertTrue(legalButtons.contains("link.open(source: source)"))
        XCTAssertTrue(legalLinkSource.contains("https://spill.thdev.app/privacy"))
        XCTAssertTrue(legalLinkSource.contains("https://spill.thdev.app/terms"))
        XCTAssertTrue(legalLinkSource.contains("legal_link_clicked"))
        XCTAssertEqual(PreferencesLegalL10n.text(.legalAndPrivacy, appLanguage: .korean), "개인정보 및 약관")
        XCTAssertEqual(PreferencesLegalL10n.text(.privacyPolicy, appLanguage: .english), "Privacy Policy")
        XCTAssertEqual(PreferencesLegalL10n.text(.termsOfService, appLanguage: .japanese), "利用規約")
        XCTAssertEqual(PreferencesLegalL10n.text(.syncDataHandling, appLanguage: .korean), "동기화 데이터 처리 안내")
        XCTAssertEqual(PreferencesLegalL10n.text(.syncDataLegalDetail, appLanguage: .korean), "동기화는 이 Mac을 연결한 뒤 암호화된 일별 사용량 합계와 기기 메타데이터만 업로드합니다. 켜기 전에 처리방침과 약관을 확인하세요.")
        XCTAssertEqual(PreferencesLegalL10n.text(.legalAndPrivacyDetail, appLanguage: .english), "Review how Spill handles app data, optional encrypted sync, and service terms.")
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
        XCTAssertTrue(localizationSource.contains("private static let cachedResourceBundle: Bundle? ="))
        XCTAssertTrue(localizationSource.contains("private static let cachedLocalizedBundles: [TokenMeteringLanguage: Bundle] ="))
        XCTAssertTrue(localizationSource.contains("cachedLocalizedBundles[language] ?? cachedResourceBundle"))
        XCTAssertTrue(localizationSource.contains("return cachedResourceBundle"))
        XCTAssertTrue(packageSource.contains("defaultLocalization: \"en\""))
        XCTAssertTrue(packageSource.contains(".process(\"Resources/Localization\")"))
        XCTAssertNotNil(strings["token_metering.sourceBreakdown"])
        XCTAssertNotNil(strings["token_metering.format.delete_token_data_message"])
        XCTAssertNotNil(strings["token_metering.task.git_commit"])
        XCTAssertNotNil(strings["token_metering.forbidden.code_content"])
        XCTAssertNotNil(strings["token_metering.forbidden.transcripts"])
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

    func testDashboardSnapshotShowsRawInputAccountingSeparateFromWorkflowLabels() {
        let codex = Self.safeEvent(
            aiTool: .codex,
            spanID: "span_codex_unsplit_input",
            inputTokens: 60,
            outputTokens: 10,
            generatedOutput: 10
        )
        let claude = Self.safeEvent(
            aiTool: .claude,
            spanID: "span_claude_split_input",
            inputTokens: 125,
            outputTokens: 7,
            generatedOutput: 7,
            tokenAccounting: TokenUsageAccounting(
                uncachedInputTokens: 20,
                cacheCreationInputTokens: 5,
                cacheReadInputTokens: 100
            )
        )
        let antigravity = Self.safeEvent(
            aiTool: .antigravity,
            spanID: "span_agy_split_input",
            inputTokens: 90,
            outputTokens: 15,
            generatedOutput: 15,
            tokenAccounting: TokenUsageAccounting(
                uncachedInputTokens: 50,
                cacheReadInputTokens: 40
            )
        )

        let snapshot = TokenUsageDashboardSnapshot(events: [codex, claude, antigravity], language: .english)
        let rowsByID = Dictionary(uniqueKeysWithValues: snapshot.inputAccounting.rows.map { ($0.id, $0) })

        XCTAssertEqual(snapshot.kpis.first { $0.id == "input" }?.value, "275")
        XCTAssertEqual(rowsByID["cache_read_input"]?.value, "140 (50.9%)")
        XCTAssertEqual(rowsByID["uncached_input"]?.value, "70 (25.5%)")
        XCTAssertEqual(rowsByID["unclassified_input"]?.value, "60 (21.8%)")
        XCTAssertEqual(rowsByID["cache_creation_input"]?.value, "5 (1.8%)")
        XCTAssertEqual(snapshot.taskRows.map(\.id), ["analysis"])
        XCTAssertEqual(snapshot.taskRows.first?.value, "307 (100.0%)")

        let freshKPIs = Dictionary(
            uniqueKeysWithValues: snapshot.usageKPIs(for: .freshOnly, language: .english).map { ($0.id, $0) }
        )
        XCTAssertEqual(freshKPIs["total"]?.value, "102")
        XCTAssertEqual(freshKPIs["input"]?.value, "70")
        XCTAssertEqual(freshKPIs["output"]?.value, "32")
        XCTAssertEqual(snapshot.inputAccounting.exactFreshInputTokens, 70)
        XCTAssertEqual(snapshot.usageInputScopeTotals.includeCache, 307)
        XCTAssertEqual(snapshot.usageInputScopeTotals.freshOnly, 102)

        let codexSnapshot = TokenUsageDashboardSnapshot(events: [codex, claude], selectedTool: .codex, language: .english)
        XCTAssertEqual(codexSnapshot.inputAccounting.rows.map(\.id), ["unclassified_input"])
        XCTAssertEqual(codexSnapshot.inputAccounting.rows.first?.value, "60 (100.0%)")
        XCTAssertEqual(codexSnapshot.usageKPIs(for: .freshOnly, language: .english).first?.value, "10")

        let claudeSnapshot = TokenUsageDashboardSnapshot(events: [codex, claude], selectedTool: .claude, language: .english)
        let claudeRowsByID = Dictionary(uniqueKeysWithValues: claudeSnapshot.inputAccounting.rows.map { ($0.id, $0) })
        XCTAssertEqual(claudeRowsByID["cache_read_input"]?.value, "100 (80.0%)")
        XCTAssertEqual(claudeRowsByID["uncached_input"]?.value, "20 (16.0%)")
        XCTAssertEqual(claudeRowsByID["cache_creation_input"]?.value, "5 (4.0%)")
        XCTAssertNil(claudeRowsByID["unclassified_input"])
        XCTAssertEqual(claudeSnapshot.usageKPIs(for: .freshOnly, language: .english).first?.value, "27")
    }

    func testFreshOnlyDashboardScopesUsageSurfacesAndWorkflowGroups() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let now = try Self.date("2026-07-14T12:00:00.000Z")
        let codex = Self.safeEvent(
            aiTool: .codex,
            spanID: "span_fresh_dashboard_codex",
            inputTokens: 60,
            outputTokens: 10,
            model: "codex-fresh-model",
            createdAt: "2026-07-14T10:00:00.000Z"
        )
        let claude = Self.safeEvent(
            aiTool: .claude,
            spanID: "span_fresh_dashboard_claude",
            inputTokens: 125,
            outputTokens: 7,
            tokenAccounting: TokenUsageAccounting(
                uncachedInputTokens: 20,
                cacheCreationInputTokens: 5,
                cacheReadInputTokens: 100
            ),
            model: "claude-fresh-model",
            createdAt: "2026-07-14T11:00:00.000Z"
        )

        let snapshot = TokenUsageDashboardSnapshot(
            events: [codex, claude],
            selectedPeriod: .sevenDays,
            language: .english,
            now: now,
            inputScope: .freshOnly,
            calendar: calendar,
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: timeZone
        )

        XCTAssertEqual(snapshot.totalTokens, 202)
        XCTAssertEqual(snapshot.usageKPIs(for: .freshOnly, language: .english).first?.value, "37")
        XCTAssertEqual(snapshot.toolFilters.first?.detail, "2 records / 37 tokens")
        XCTAssertEqual(snapshot.toolFilters.first { $0.tool == .codex }?.detail, "10")
        XCTAssertEqual(snapshot.toolFilters.first { $0.tool == .claude }?.detail, "27")
        XCTAssertEqual(snapshot.periodFilters.first { $0.period == .today }?.detail, "37")
        XCTAssertEqual(snapshot.periodFilters.first { $0.period == .all }?.detail, "37")
        XCTAssertEqual(snapshot.toolRows.map(\.value), ["27 (73.0%)", "10 (27.0%)"])
        XCTAssertEqual(snapshot.modelRows.map(\.value), ["27 (73.0%)", "10 (27.0%)"])
        XCTAssertEqual(snapshot.trendBuckets.last { $0.hasEvents }?.totalTokens, 37)
        XCTAssertEqual(snapshot.taskRows.first?.value, "37 (100.0%)")
        XCTAssertEqual(snapshot.stageRows.first?.value, "37 (100.0%)")
        XCTAssertEqual(snapshot.sessions.first?.value, "37")
        XCTAssertEqual(snapshot.inputAccounting.rawInputTokens, 185)

        let selectedWorkItemID = try XCTUnwrap(snapshot.sessions.first?.id)
        let selectedSnapshot = TokenUsageDashboardSnapshot(
            events: [codex, claude],
            selectedPeriod: .sevenDays,
            selectedSessionID: selectedWorkItemID,
            language: .english,
            now: now,
            inputScope: .freshOnly,
            calendar: calendar,
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: timeZone
        )
        XCTAssertEqual(selectedSnapshot.selectedSession?.value, "37")
        XCTAssertEqual(
            selectedSnapshot.usageKPIs(for: .freshOnly, language: .english).map(\.value),
            ["37", "20", "17"]
        )
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

    func testDashboardSnapshotShowsOnlyVisibleSupportedAgentTools() {
        let codex = Self.safeEvent(
            aiTool: .codex,
            spanID: "span_visible_codex",
            inputTokens: 100,
            outputTokens: 10
        )
        let claude = Self.safeEvent(
            aiTool: .claude,
            spanID: "span_hidden_claude",
            inputTokens: 200,
            outputTokens: 20
        )
        let antigravity = Self.safeEvent(
            aiTool: .antigravity,
            spanID: "span_visible_antigravity",
            inputTokens: 300,
            outputTokens: 30
        )

        let snapshot = TokenUsageDashboardSnapshot(
            events: [codex, claude, antigravity],
            visibleTools: [.codex, .antigravity]
        )

        XCTAssertEqual(snapshot.eventCount, 2)
        XCTAssertEqual(snapshot.totalTokens, 440)
        XCTAssertEqual(snapshot.toolRows.map(\.title), ["Antigravity (agy)", "Codex"])
        XCTAssertEqual(snapshot.toolFilters.compactMap(\.tool), [.codex, .antigravity])
        XCTAssertNil(snapshot.toolFilters.first { $0.tool == .claude })

        let hiddenSelection = TokenUsageDashboardSnapshot(
            events: [codex, claude],
            selectedTool: .claude,
            visibleTools: [.codex]
        )
        XCTAssertEqual(hiddenSelection.totalTokens, 110)
        XCTAssertTrue(hiddenSelection.toolFilters.first?.isSelected == true)
        XCTAssertNil(hiddenSelection.toolFilters.first { $0.tool == .claude })
    }

    func testAdvancedDashboardRetainsHiddenSupportedTools() {
        let visibleTools = TokenUsageDashboardToolVisibility.dashboardFilterTools(
            visibleTools: [.codex],
            showAdvancedTools: true
        )
        let snapshot = TokenUsageDashboardSnapshot(
            events: [
                Self.safeEvent(
                    aiTool: .codex,
                    spanID: "span_advanced_codex",
                    inputTokens: 100,
                    outputTokens: 10
                ),
                Self.safeEvent(
                    aiTool: .claude,
                    spanID: "span_advanced_hidden_claude",
                    inputTokens: 200,
                    outputTokens: 20
                ),
                Self.safeEvent(
                    aiTool: .openAI,
                    spanID: "span_advanced_openai",
                    inputTokens: 300,
                    outputTokens: 30
                ),
                Self.safeEvent(
                    aiTool: .unknown,
                    spanID: "span_advanced_unknown",
                    inputTokens: 400,
                    outputTokens: 40
                )
            ],
            showAdvancedTools: true,
            visibleTools: visibleTools
        )

        XCTAssertEqual(snapshot.eventCount, 3)
        XCTAssertEqual(snapshot.totalTokens, 880)
        XCTAssertEqual(
            Set(snapshot.toolFilters.compactMap(\.tool)),
            Set([.codex, .openAI, .unknown])
        )
        XCTAssertNil(snapshot.toolFilters.first { $0.tool == .claude })
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
        XCTAssertFalse(dashboardView.contains("localOnlyBadge"))
        XCTAssertTrue(dashboardView.contains("syncStateBadge"))
        XCTAssertTrue(dashboardView.contains("settings.privateUsageUploadEnabled"))
        XCTAssertTrue(dashboardView.contains("t(.webSyncEnabled)"))
        XCTAssertTrue(sessionsTable.contains("if SpillBuildOptions.developerOptionsEnabled"))
        XCTAssertTrue(sessionsTable.contains("requestClear(.workItem(session.id))"))
        XCTAssertFalse(dashboardView.contains("requestClear(.workItem(detailSession.id))"))
        XCTAssertTrue(dashboardView.contains("action: settingsAction"))
        XCTAssertTrue(dashboardView.contains("accessibilityLabel: AppL10n.text(.settings"))
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
        let aiToolVisibilitySection = try Self.source(named: "TokenMeteringAIToolVisibilitySection.swift")
        let privacyBoundarySection = try Self.source(named: "TokenMeteringPrivacyBoundarySection.swift")

        XCTAssertTrue(preferencesSection.contains("TokenMeteringSetupSection("))
        XCTAssertTrue(setupSection.contains("t(.step1Title)"))
        XCTAssertTrue(setupSection.contains("TokenMeteringPromptInstructionCard("))
        XCTAssertTrue(promptCard.contains("TokenMeteringGlobalSetup.workflowPrompt"))
        XCTAssertTrue(promptCard.contains("t(.promptInstructionCardDetail)"))
        XCTAssertFalse(preferencesSection.contains("TokenMeteringGlobalSetup.prompt("))
        XCTAssertFalse(preferencesSection.contains("Text(TokenMeteringSetupInstaller.setupCommand())"))
        XCTAssertTrue(localSyncSection.contains("t(.menuBarTokenDisplayModeTitle)"))
        XCTAssertTrue(localSyncSection.contains("t(.menuBarTokenDisplayModeDetail)"))
        XCTAssertFalse(localSyncSection.contains("t(.localEventQueue)"))
        XCTAssertFalse(localSyncSection.contains("t(.copyPath)"))
        XCTAssertFalse(localSyncSection.contains("TokenUsageStore.defaultInboxURL"))
        XCTAssertTrue(preferencesSection.contains("localSyncAndDisplaySettingsSection"))
        XCTAssertTrue(preferencesSection.contains("TokenMeteringLocalSyncSettingsSection("))
        XCTAssertFalse(preferencesSection.contains("copyInboxPathAction"))
        XCTAssertTrue(preferencesSection.contains("aiToolVisibilitySection"))
        XCTAssertTrue(preferencesSection.contains("TokenMeteringAIToolVisibilitySection("))
        XCTAssertTrue(aiToolVisibilitySection.contains("TokenMeteringToolAvailability.supportedLocalToolKinds"))
        XCTAssertFalse(aiToolVisibilitySection.contains("installedLocalToolKinds"))
        XCTAssertFalse(aiToolVisibilitySection.contains("installedAndAdapterConnectedLocalToolKinds"))
        XCTAssertTrue(aiToolVisibilitySection.contains("settings.setLocalAITool(kind, isVisible: $0)"))
        XCTAssertFalse(aiToolVisibilitySection.contains("aiStatusStore"))
        XCTAssertFalse(aiToolVisibilitySection.contains("adapterStatuses"))
        XCTAssertTrue(preferencesSection.contains(".onChange(of: aiStatusStore.detectedStatuses)"))
        XCTAssertTrue(preferencesSection.contains("privacyBoundarySection"))
        XCTAssertTrue(privacyBoundarySection.contains("t(.privacyBoundaryDetail)"))
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
        XCTAssertTrue(dashboardView.contains("!showsDashboardPlaceholder"))
        XCTAssertTrue(dashboardView.contains("inputScope: store.snapshotInputScope"))
        XCTAssertTrue(sessionsTable.contains("store.selectSession(session.id)"))
        XCTAssertFalse(dashboardView.contains("store.snapshotForWorkItem(session.id)"))
        XCTAssertTrue(detailPanel.contains("let inputScope: TokenUsageInputScope"))
        XCTAssertTrue(detailPanel.contains("snapshot.usageKPIs(for: inputScope, language: language)"))
        XCTAssertTrue(detailPanel.contains("title: t(.aiTool)"))
        XCTAssertTrue(detailPanel.contains("title: t(.modelBreakdown)"))
        XCTAssertTrue(dashboardView.contains("title: t(.workflowUsage)"))
        XCTAssertTrue(analyticsGrid.contains("title: t(.workflowBreakdown)"))
        XCTAssertTrue(analyticsGrid.contains("title: t(.stageBreakdown)"))
        XCTAssertFalse(analyticsGrid.contains("title: t(.sourceBreakdown)"))
        XCTAssertFalse(detailPanel.contains("detailSourceBreakdownSection"))
        XCTAssertFalse(detailPanel.contains("t(.sourceBreakdown)"))
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
        let dashboardWindowMetrics = try Self.source(named: "TokenMeteringDashboardWindowMetrics.swift")
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
        let localSyncSettingsSection = try Self.source(named: "TokenMeteringLocalSyncSettingsSection.swift")
        let historyImportSection = try Self.source(named: "TokenUsageHistoryImportSection.swift")
        let localDataSection = try Self.source(named: "TokenMeteringLocalDataManagementSection.swift")
        let developerOptionsSection = try Self.source(named: "DeveloperOptionsPreferencesSection.swift")
        let dashboardStore = try Self.source(named: "TokenUsageDashboardStore.swift")
        let dashboardSetupPanel = try Self.source(named: "TokenMeteringDashboardSetupPanel.swift")

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
        XCTAssertTrue(toolTab.contains("tabAccent.opacity(0.14)"))
        XCTAssertTrue(toolTab.contains("tabAccent.opacity(0.28)"))
        let tabDetailRange = try XCTUnwrap(toolTab.range(of: "Text(detail)"))
        let tabBadgeRange = try XCTUnwrap(toolTab.range(of: "toolShareBadge("))
        let tabLiveDotRange = try XCTUnwrap(toolTab.range(of: "TokenMeteringLiveUpdateDot"))
        XCTAssertLessThan(tabDetailRange.lowerBound, tabBadgeRange.lowerBound)
        XCTAssertLessThan(tabBadgeRange.lowerBound, tabLiveDotRange.lowerBound)
        XCTAssertTrue(analyticsGrid.contains("rowTint: aiToolTint"))
        XCTAssertTrue(analyticsGrid.contains("metricValueBadge("))
        XCTAssertTrue(analyticsGrid.contains(".padding(.top, 10)"))
        XCTAssertTrue(analyticsGrid.contains(".frame(minHeight: rowsMinimumHeight, alignment: .topLeading)"))
        XCTAssertTrue(analyticsGrid.contains("infoDetail: t(.inputAccountingInfoDetail)"))
        XCTAssertTrue(analyticsGrid.contains("rows: store.snapshot.inputAccounting.rows"))
        XCTAssertFalse(analyticsGrid.contains("Picker("))
        XCTAssertFalse(analyticsGrid.contains("settings.tokenUsageInputScope"))
        XCTAssertTrue(localSyncSettingsSection.contains("selection: $settings.tokenUsageInputScope"))
        XCTAssertTrue(localSyncSettingsSection.contains("TokenMeteringInfoButton("))
        // Every rendered number follows the applied snapshot's scope, so a scope
        // toggle keeps the previous data visible (no placeholder pass) until the
        // rebuilt snapshot lands and everything switches together.
        XCTAssertTrue(dashboardView.contains("store.snapshot.usageKPIs(for: store.snapshotInputScope"))
        XCTAssertTrue(dashboardView.contains("store.setUsageInputScope(settings.tokenUsageInputScope)"))
        XCTAssertTrue(dashboardView.contains("store.setUsageInputScope(scope)"))
        XCTAssertFalse(dashboardView.contains("isUsageScopeTransitioning"))
        XCTAssertFalse(dashboardView.contains("usageKPIs(for: settings.tokenUsageInputScope"))
        XCTAssertFalse(analyticsGrid.contains("maximumRows"))
        XCTAssertFalse(analyticsGrid.contains(".prefix(maximumRows)"))
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
        XCTAssertFalse(dashboardView.contains("store.refreshAsyncIfIdle()"))
        XCTAssertEqual(
            dashboardView.components(separatedBy: "aiStatusStore.refreshInBackground()").count - 1,
            1
        )
        XCTAssertTrue(dashboardWindowController.contains("store.refreshAsyncIfIdle()"))
        XCTAssertFalse(dashboardWindowController.contains("store.refreshAsync()"))
        XCTAssertTrue(dashboardWindowController.contains("deferredRefreshDelayNanoseconds"))
        XCTAssertTrue(dashboardWindowController.contains("aiStatusRefreshIntervalNanoseconds: UInt64 = 30_000_000_000"))
        XCTAssertTrue(dashboardWindowController.contains("tokenDataRefreshIntervalNanoseconds: UInt64 = 15_000_000_000"))
        XCTAssertTrue(dashboardWindowController.contains("startAIStatusRefreshLoop()"))
        XCTAssertTrue(dashboardWindowController.contains("startTokenDataRefreshLoop()"))
        XCTAssertTrue(dashboardWindowController.contains("requestTokenDataRefresh()"))
        XCTAssertTrue(dashboardWindowController.contains("self.window?.isVisible == true"))
        XCTAssertTrue(dashboardWindowController.contains("!store.isDashboardRefreshInProgress"))
        XCTAssertTrue(dashboardWindowMetrics.contains("static let minimumContentSize = CGSize(width: 1060, height: 640)"))
        XCTAssertTrue(dashboardWindowMetrics.contains("static let preferredContentSize = CGSize(width: 1060, height: 680)"))
        XCTAssertTrue(dashboardWindowController.contains("TokenMeteringDashboardWindowMetrics.preferredContentSize"))
        XCTAssertTrue(dashboardWindowController.contains("TokenMeteringDashboardWindowMetrics.minimumContentSize"))
        XCTAssertTrue(dashboardWindowController.contains("window.contentMinSize = minimumSize"))
        XCTAssertTrue(dashboardView.contains("minWidth: TokenMeteringDashboardWindowMetrics.minimumContentSize.width"))
        XCTAssertTrue(dashboardView.contains("minHeight: TokenMeteringDashboardWindowMetrics.minimumContentSize.height"))
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
        XCTAssertTrue(dashboardSetupPanel.contains("TokenMeteringSetupActionControls("))
        let agentStatusRange = try XCTUnwrap(dashboardView.range(of: "agentStatusPanel"))
        let modelRange = try XCTUnwrap(dashboardView.range(of: "modelPanel"))
        let workflowRange = try XCTUnwrap(dashboardView.range(of: "workflowUsagePanel"))
        let setupRange = try XCTUnwrap(dashboardView.range(of: "setupPanel"))
        XCTAssertLessThan(agentStatusRange.lowerBound, modelRange.lowerBound)
        XCTAssertLessThan(modelRange.lowerBound, workflowRange.lowerBound)
        XCTAssertLessThan(workflowRange.lowerBound, setupRange.lowerBound)
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
        let preferencesView = try Self.source(named: "PreferencesView.swift")
        let preferencesWindowController = try Self.source(named: "PreferencesWindowController.swift")
        let tokenMeteringPreferencesSection = try Self.source(named: "TokenMeteringPreferencesSection.swift")
        let privateUsageUploadStore = try Self.source(named: "PrivateUsageUploadStore.swift")
        let privateUsageUploadActions = try Self.source(named: "PrivateUsageUploadStore+Actions.swift")

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
        XCTAssertTrue(tokenMeteringCoordinator.contains("func preparePrivateUsageUpload() async"))
        XCTAssertTrue(tokenMeteringCoordinator.contains("await collectorCoordinator.requestCollectionAndWait(reason: \"private_usage_upload\")"))
        XCTAssertLessThan(
            try XCTUnwrap(tokenMeteringCoordinator.range(of: "await preparePrivateUsageUpload()")?.lowerBound),
            try XCTUnwrap(tokenMeteringCoordinator.range(of: "coordinator.runAutomaticUploadIfNeeded")?.lowerBound)
        )
        XCTAssertTrue(appDelegate.contains("preparePrivateUsageUploadAction"))
        XCTAssertTrue(appDelegate.contains("await self.tokenMeteringCoordinator.preparePrivateUsageUpload()"))
        XCTAssertTrue(preferencesView.contains("preparePrivateUsageUploadAction"))
        XCTAssertTrue(preferencesWindowController.contains("preparePrivateUsageUploadAction"))
        XCTAssertTrue(tokenMeteringPreferencesSection.contains("preparePrivateUsageUploadAction"))
        XCTAssertTrue(privateUsageUploadStore.contains("let prepareForUpload"))
        XCTAssertTrue(privateUsageUploadActions.contains("await prepareForUpload()"))
        XCTAssertLessThan(
            try XCTUnwrap(privateUsageUploadActions.range(of: "await prepareForUpload()")?.lowerBound),
            try XCTUnwrap(privateUsageUploadActions.range(of: "coordinator.syncNow(")?.lowerBound)
        )
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
        XCTAssertTrue(collector.contains("Drain app-owned queued inbox events"))
        XCTAssertTrue(collector.contains("func requestCollectionAndWait(reason: String) async"))
        XCTAssertTrue(collector.contains("runAntigravityActiveImporter()"))
        XCTAssertTrue(collector.contains("AGY and Claude Code use native active importers"))
        XCTAssertFalse(collector.contains("runLocalImportersIfAvailable()"))
        XCTAssertFalse(collector.contains("runCodexImporterIfAvailable()"))
        XCTAssertFalse(collector.contains("runClaudeTranscriptScanIfAvailable()"))
        XCTAssertFalse(collector.contains("Process()"))
        XCTAssertFalse(collector.contains("--scan-dir"))
    }

    func testDashboardLocalRefreshIsSeparatedFromServerStatusRefresh() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let dashboardView = try Self.source(named: "TokenMeteringDashboardView.swift")
        let dashboardStore = try Self.source(named: "TokenUsageDashboardStore.swift")
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
        XCTAssertTrue(spillBarAITokenSummary.contains("tokenSyncBadge"))
        XCTAssertTrue(spillBarAITokenSummary.contains("settings.privateUsageUploadEnabled"))
        XCTAssertTrue(spillBarAITokenSummary.contains(".webSyncEnabled"))
        XCTAssertTrue(spillBarAITokenSummary.contains("snapshot.usageTotal(for: settings.tokenUsageInputScope)"))
        XCTAssertFalse(spillBarAITokenSummary.contains("tokenUsageDashboardStore.refreshPanelSummary()"))
        XCTAssertTrue(dashboardStore.contains("loadPanelSummaryIfAvailable"))
        XCTAssertTrue(dashboardStore.contains("guard let panelSummary else"))
        XCTAssertFalse(spillBarAITokenSummary.contains("let displayTotalTokens = snapshot.totalTokens"))
        XCTAssertTrue(spillBarAITokenSummary.contains("if snapshot.totalTokens > 0, !visibleToolRows.isEmpty"))
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

    func testLongRunningAppShutdownAndWakeContracts() throws {
        let root = Self.repositoryRootURL()
        let appDelegate = try String(contentsOf: root.appendingPathComponent("Sources/Spill/App/AppDelegate.swift"))
        let menuBarScanCoordinator = try String(contentsOf: root.appendingPathComponent("Sources/Spill/MenuBar/MenuBarScanCoordinator.swift"))
        let panelController = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Panel/SpillPanelController.swift"))
        let preferencesWindowController = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Preferences/PreferencesWindowController.swift"))
        let aiStatusStore = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Providers/AIStatusStore.swift"))
        let cloudServiceStatusStore = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Providers/CloudServiceStatusStore.swift"))
        let inboxMonitor = try String(contentsOf: root.appendingPathComponent("Sources/Spill/TokenMetering/Storage/Inbox/TokenUsageInboxMonitor.swift"))

        XCTAssertTrue(appDelegate.contains("SpillCrashReporter.markCleanShutdown(processRole: \"main_app\")"))
        XCTAssertTrue(appDelegate.contains("preferencesWindowController.prepareForTermination()"))
        XCTAssertTrue(menuBarScanCoordinator.contains("NSWorkspace.didWakeNotification"))
        XCTAssertTrue(panelController.contains("panel.isRestorable = false"))
        XCTAssertTrue(preferencesWindowController.contains("window.isRestorable = false"))
        XCTAssertTrue(preferencesWindowController.contains("func prepareForTermination()"))
        XCTAssertTrue(aiStatusStore.contains("func cancelRefresh()"))
        XCTAssertTrue(cloudServiceStatusStore.contains("func cancelRefresh()"))
        XCTAssertTrue(inboxMonitor.contains("private var isStopped = true"))
        XCTAssertTrue(inboxMonitor.contains("guard !isStopped, !isDraining else"))
    }

    @MainActor
    func testPanelSummaryRefreshDoesNotCancelScheduledDashboardRefresh() async throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        let dashboardStore = TokenUsageDashboardStore(
            usageStore: usageStore,
            loadsInitialPanelSummary: false
        )
        // Establish a dashboard consumer so the scheduled refresh below is a
        // full snapshot rebuild rather than the panel-summary-only path.
        dashboardStore.refresh(trackLiveUpdates: false)
        try usageStore.appendEvent(Self.safeEvent(spanID: "span_scheduled_refresh_survives_panel_summary"))

        NotificationCenter.default.post(
            name: TokenUsageStore.eventsDidChangeNotification,
            object: usageStore
        )
        dashboardStore.refreshPanelSummary()

        try await waitForDashboardStoreRefreshToLoadEvents(dashboardStore, eventCount: 1)
        XCTAssertEqual(dashboardStore.snapshot.eventCount, 1)
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
        XCTAssertTrue(collector.contains("runClaudeCodeActiveImporter()"))
        XCTAssertTrue(collector.contains("TokenUsageAntigravityImporter().importRecentEvents"))
        XCTAssertTrue(collector.contains("let importer = TokenUsageClaudeCodeImporter()"))
        XCTAssertTrue(collector.contains("importer.importRecentSessions"))
        XCTAssertTrue(collector.contains("func stop()"))
        XCTAssertTrue(collector.contains("private var isStopping = false"))
        XCTAssertTrue(collector.contains("shouldCancel: shouldCancel"))
        // Process management must stay in the importer, not bleed into the coordinator.
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
            antigravityImportRunner: { _, startDate, _ in
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
            antigravityLookbackInterval: 3600,
            claudeCodeImportRunner: { _, _ in TokenUsageClaudeCodeImportSummary(scannedFiles: 0, parsedTurns: 0, importedEvents: 0, skippedDuplicateEvents: 0, cursorAdvancedFiles: 0, failedToWriteEvents: false) }
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

    func testTokenUsageCollectorPacesTimerImportsAndForcesUserActions() async {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let lock = NSLock()
        var antigravityRuns = 0
        var claudeRuns = 0
        var currentDate = Date(timeIntervalSince1970: 10_000)
        let collector = TokenUsageCollectorCoordinator(
            store: store,
            antigravityImportRunner: { _, _, _ in
                lock.withLock { antigravityRuns += 1 }
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
            claudeCodeImportRunner: { _, _ in
                lock.withLock { claudeRuns += 1 }
                return TokenUsageClaudeCodeImportSummary(
                    scannedFiles: 0,
                    parsedTurns: 0,
                    importedEvents: 0,
                    skippedDuplicateEvents: 0,
                    cursorAdvancedFiles: 0,
                    failedToWriteEvents: false
                )
            },
            activeImporterMinimumInterval: 30,
            now: { lock.withLock { currentDate } }
        )

        // First timer request runs both importers (no prior run to pace against).
        await collector.requestCollectionAndWait(reason: "dashboard_refresh")
        XCTAssertEqual(lock.withLock { antigravityRuns }, 1)
        XCTAssertEqual(lock.withLock { claudeRuns }, 1)

        // A second timer request inside the floor coalesces into an inbox-only pass.
        lock.withLock { currentDate = currentDate.addingTimeInterval(15) }
        await collector.requestCollectionAndWait(reason: "menu_bar_status")
        XCTAssertEqual(lock.withLock { antigravityRuns }, 1)
        XCTAssertEqual(lock.withLock { claudeRuns }, 1)

        // A user action forces both importers even inside the floor.
        await collector.requestCollectionAndWait(reason: "manual_refresh")
        XCTAssertEqual(lock.withLock { antigravityRuns }, 2)
        XCTAssertEqual(lock.withLock { claudeRuns }, 2)

        // Once the floor elapses, timer requests import again.
        lock.withLock { currentDate = currentDate.addingTimeInterval(31) }
        await collector.requestCollectionAndWait(reason: "dashboard_refresh")
        XCTAssertEqual(lock.withLock { antigravityRuns }, 3)
        XCTAssertEqual(lock.withLock { claudeRuns }, 3)
    }

    func testAllPeriodInputScopeTotalsCachesUntilTheStoreChanges() throws {
        // Two instances over one database file model the main app and the
        // dashboard helper sharing the store across processes.
        let eventsURL = temporaryEventsURL()
        let reader = TokenUsageStore(fileURL: eventsURL)
        let writer = TokenUsageStore(fileURL: eventsURL)
        try reader.appendEvent(Self.safeEvent(inputTokens: 100, outputTokens: 50))
        let now = Date()
        let calendar = Calendar.autoupdatingCurrent

        let first = reader.allPeriodInputScopeTotals(now: now, calendar: calendar)
        XCTAssertEqual(first[.all]?.includeCache, 150)

        // Another instance changes the shared database; this instance has not
        // observed that change yet, so the read must answer from cache (a real
        // rescan would already see 300).
        try writer.appendEvent(
            Self.safeEvent(spanID: "span_totals_cache_writer", inputTokens: 100, outputTokens: 50)
        )
        let cached = reader.allPeriodInputScopeTotals(now: now, calendar: calendar)
        XCTAssertEqual(cached[.all]?.includeCache, 150)

        // The distributed change observers call this for cross-process changes;
        // it invalidates the cache so the next read rescans.
        reader.noteDataChanged()
        let refreshed = reader.allPeriodInputScopeTotals(now: now, calendar: calendar)
        XCTAssertEqual(refreshed[.all]?.includeCache, 300)

        // Filter changes miss the cache instead of returning the wrong totals.
        let filtered = reader.allPeriodInputScopeTotals(
            now: now,
            calendar: calendar,
            visibleTools: [.claude]
        )
        XCTAssertEqual(filtered[.all]?.includeCache, 0)
    }

    /// A caller-provided database connection is a read transaction that may be
    /// older or newer than the cached revision, so it must bypass the cache in
    /// both directions: never serve cached totals into a transaction, and never
    /// store transaction reads into the cache.
    func testAllPeriodTotalsBypassTheCacheForCallerProvidedTransactions() throws {
        let eventsURL = temporaryEventsURL()
        let reader = TokenUsageStore(fileURL: eventsURL)
        let writer = TokenUsageStore(fileURL: eventsURL)
        try reader.appendEvent(Self.safeEvent(inputTokens: 100, outputTokens: 50))
        let now = Date()
        let calendar = Calendar.autoupdatingCurrent

        // Populate the cache at 150, then change the data through the other
        // instance without this instance observing it.
        XCTAssertEqual(
            reader.allPeriodInputScopeTotals(now: now, calendar: calendar)[.all]?.includeCache,
            150
        )
        try writer.appendEvent(
            Self.safeEvent(spanID: "span_tx_bypass_writer", inputTokens: 100, outputTokens: 50)
        )

        // A transaction read must see its own connection's data (300), not the
        // stale cached 150.
        let database = try reader.lock.withLock { try reader.openDatabase() }
        defer { sqlite3_close(database) }
        let transactionTotals = reader.allPeriodInputScopeTotals(
            now: now,
            calendar: calendar,
            database: database
        )
        XCTAssertEqual(transactionTotals[.all]?.includeCache, 300)

        // And that read must not have been stored: the cached-path read still
        // answers from the (stale but revision-consistent) cache until a change
        // notification bumps the revision.
        XCTAssertEqual(
            reader.allPeriodInputScopeTotals(now: now, calendar: calendar)[.all]?.includeCache,
            150
        )
        reader.noteDataChanged()
        XCTAssertEqual(
            reader.allPeriodInputScopeTotals(now: now, calendar: calendar)[.all]?.includeCache,
            300
        )
    }

    func testTokenUsageCollectorRunsClaudeCodeActiveImporter() {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let lock = NSLock()
        var didRunImporter = false
        let collector = TokenUsageCollectorCoordinator(
            store: store,
            antigravityImportRunner: { _, _, _ in
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
            },
            claudeCodeImportRunner: { _, _ in
                lock.withLock { didRunImporter = true }
                return TokenUsageClaudeCodeImportSummary(scannedFiles: 0, parsedTurns: 0, importedEvents: 0, skippedDuplicateEvents: 0, cursorAdvancedFiles: 0, failedToWriteEvents: false)
            }
        )
        let notification = expectation(description: "collection finished")
        let observer = NotificationCenter.default.addObserver(
            forName: TokenUsageCollectorCoordinator.collectionDidFinishNotification,
            object: collector,
            queue: .main
        ) { _ in notification.fulfill() }
        defer { NotificationCenter.default.removeObserver(observer) }

        collector.requestCollection(reason: "test")
        wait(for: [notification], timeout: 1)

        XCTAssertTrue(lock.withLock { didRunImporter })
    }

    func testTokenUsageCollectorPostsCollectionFinishedNotification() {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let collector = TokenUsageCollectorCoordinator(
            store: store,
            antigravityImportRunner: { _, _, _ in
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
            },
            claudeCodeImportRunner: { _, _ in TokenUsageClaudeCodeImportSummary(scannedFiles: 0, parsedTurns: 0, importedEvents: 0, skippedDuplicateEvents: 0, cursorAdvancedFiles: 0, failedToWriteEvents: false) }
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

    func testTokenUsageCollectorRequestCollectionAndWaitAwaitsImporters() async {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let lock = NSLock()
        var didRunAntigravityImporter = false
        var didRunClaudeCodeImporter = false
        let collector = TokenUsageCollectorCoordinator(
            store: store,
            antigravityImportRunner: { _, _, _ in
                lock.withLock {
                    didRunAntigravityImporter = true
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
            claudeCodeImportRunner: { _, _ in
                lock.withLock {
                    didRunClaudeCodeImporter = true
                }
                return TokenUsageClaudeCodeImportSummary(
                    scannedFiles: 0,
                    parsedTurns: 0,
                    importedEvents: 0,
                    skippedDuplicateEvents: 0,
                    cursorAdvancedFiles: 0,
                    failedToWriteEvents: false
                )
            }
        )

        await collector.requestCollectionAndWait(reason: "test")

        XCTAssertTrue(lock.withLock { didRunAntigravityImporter })
        XCTAssertTrue(lock.withLock { didRunClaudeCodeImporter })
    }

    func testClaudeCodeActiveImporterParsesHookTranscriptShapeAndIterations() throws {
        let rootURL = temporaryDirectoryURL()
        let projectsURL = rootURL.appendingPathComponent("projects", isDirectory: true)
        let projectURL = projectsURL.appendingPathComponent("project-opaque", isDirectory: true)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)

        let transcriptURL = projectURL.appendingPathComponent("11111111111111111111111111111111.jsonl")
        let transcript = [
            #"{"message":{"role":"user"}}"#,
            #"{"timestamp":"2026-06-26T00:00:01.000Z","requestId":"req_read","message":{"id":"msg_read","role":"assistant","model":"claude-sonnet-4","usage":{"input_tokens":20,"cache_creation_input_tokens":5,"cache_read_input_tokens":100,"output_tokens":7},"content":[{"type":"tool_use","name":"Read"}]}}"#,
            #"{"timestamp":"2026-06-26T00:00:02.000Z","requestId":"req_read","message":{"id":"msg_read","role":"assistant","model":"claude-sonnet-4","usage":{"input_tokens":20,"cache_creation_input_tokens":5,"cache_read_input_tokens":100,"output_tokens":9},"content":[{"type":"tool_use","name":"Read"}]}}"#,
            #"{"timestamp":"2026-06-26T00:00:30.000Z","requestId":"req_cache_read","message":{"id":"msg_cache_read","role":"assistant","model":"claude-sonnet-4","usage":{"cache_read_input_tokens":100},"content":[]}}"#,
            #"{"timestamp":"2026-06-26T00:01:01.000Z","message":{"id":"msg_iter","role":"assistant","model":"claude-sonnet-4","usage":{"iterations":[{"usage":{"input_tokens":6,"cache_creation":{"ephemeral_1h_input_tokens":2},"cache_read_input_tokens":1,"output_tokens":3}}]},"content":[{"type":"tool_use","name":"Edit"}]}}"#,
        ].joined(separator: "\n")
        try "\(transcript)\n".write(to: transcriptURL, atomically: true, encoding: .utf8)

        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let importer = TokenUsageClaudeCodeImporter(
            projectsDirectory: projectsURL,
            labelTimelineURL: rootURL.appendingPathComponent("missing-labels.jsonl"),
            stateURL: rootURL.appendingPathComponent("claude-active-state.json")
        )

        let summary = importer.importRecentSessions(into: store)
        XCTAssertEqual(summary.scannedFiles, 1)
        XCTAssertEqual(summary.parsedTurns, 3)
        XCTAssertEqual(summary.importedEvents, 3)
        // The transcript has two "req_read" lines (output 7, then 9) representing the
        // same requestId written twice. Dedup always keeps the FIRST occurrence (output
        // 7, total 132) so within-batch and cross-batch dedup agree on the same turn.
        XCTAssertEqual(store.loadEvents().map(\.totalTokens).sorted(), [12, 100, 132])
        XCTAssertEqual(store.loadEvents().map(\.inputTokens).sorted(), [9, 100, 125])
        let readTurn = try XCTUnwrap(store.loadEvents().first { $0.outputTokens == 7 })
        XCTAssertEqual(readTurn.tokenAccounting?.uncachedInputTokens, 20)
        XCTAssertEqual(readTurn.tokenAccounting?.cacheCreationInputTokens, 5)
        XCTAssertEqual(readTurn.tokenAccounting?.cacheReadInputTokens, 100)
        let cacheOnlyTurn = try XCTUnwrap(store.loadEvents().first { $0.inputTokens == 100 && $0.outputTokens == 0 })
        XCTAssertEqual(cacheOnlyTurn.tokenAccounting?.uncachedInputTokens, 0)
        XCTAssertEqual(cacheOnlyTurn.tokenAccounting?.cacheReadInputTokens, 100)
        let iterationTurn = try XCTUnwrap(store.loadEvents().first { $0.outputTokens == 3 })
        XCTAssertEqual(iterationTurn.tokenAccounting?.uncachedInputTokens, 6)
        XCTAssertEqual(iterationTurn.tokenAccounting?.cacheCreationInputTokens, 2)
        XCTAssertEqual(iterationTurn.tokenAccounting?.cacheReadInputTokens, 1)
        XCTAssertEqual(Set(store.loadEvents().map(\.stage.rawValue)), ["summarize"])
        let state = try decodedJSONObject(from: Data(contentsOf: rootURL.appendingPathComponent("claude-active-state.json")))
        let nextTurnIndices = try XCTUnwrap(state["next_turn_index_by_source"] as? [String: Any])
        XCTAssertEqual(nextTurnIndices.values.compactMap { $0 as? Int }, [3])
        XCTAssertEqual(TokenUsageClaudeCodeImporter.safeModel("unsafe model!"), "claude-unknown")

        let secondSummary = importer.importRecentSessions(into: store)
        XCTAssertEqual(secondSummary.importedEvents, 0)
        XCTAssertEqual(store.loadEvents().count, 3)
    }

    func testClaudeCodeLabelTimelineReadsOnlyAppendedBytesAndResetsAfterTruncation() throws {
        let rootURL = temporaryDirectoryURL()
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let timelineURL = rootURL.appendingPathComponent("claude-timeline.jsonl")
        let firstLine = #"{"ai_tool":"claude","task_type":"debugging","stage":"implement","project_id":"project_one","updated_at":"2026-06-26T00:00:00.000Z","expires_at":"2026-06-26T00:10:00.000Z"}"#
        let firstData = Data("\(firstLine)\n".utf8)
        try firstData.write(to: timelineURL)

        let importer = TokenUsageClaudeCodeImporter(
            projectsDirectory: rootURL,
            labelTimelineURL: timelineURL,
            stateURL: nil
        )
        let firstTimestamp = try XCTUnwrap(
            ISO8601DateFormatter.parseTokenUsageDate(from: "2026-06-26T00:05:00.000Z")
        )

        XCTAssertEqual(importer.readLabelTimeline().label(for: firstTimestamp).taskType, .debugging)
        XCTAssertEqual(importer.labelTimelineBytesRead, firstData.count)

        _ = importer.readLabelTimeline()
        XCTAssertEqual(importer.labelTimelineBytesRead, firstData.count)

        let secondLine = #"{"ai_tool":"claude","task_type":"testing","stage":"verify","project_id":"project_two","updated_at":"2026-06-26T00:10:00.000Z","expires_at":"2026-06-26T00:20:00.000Z"}"#
        let appendedData = Data("\(secondLine)\n".utf8)
        let appendHandle = try FileHandle(forWritingTo: timelineURL)
        try appendHandle.seekToEnd()
        try appendHandle.write(contentsOf: appendedData)
        try appendHandle.close()

        let secondTimestamp = try XCTUnwrap(
            ISO8601DateFormatter.parseTokenUsageDate(from: "2026-06-26T00:15:00.000Z")
        )
        XCTAssertEqual(importer.readLabelTimeline().label(for: secondTimestamp).taskType, .testing)
        XCTAssertEqual(importer.labelTimelineBytesRead, firstData.count + appendedData.count)

        let replacementLine = #"{"ai_tool":"claude","task_type":"analysis","stage":"plan","updated_at":"2026-06-26T01:00:00.000Z","expires_at":"2026-06-26T01:10:00.000Z"}"#
        let replacementData = Data("\(replacementLine)\n".utf8)
        try replacementData.write(to: timelineURL)
        let replacementTimestamp = try XCTUnwrap(
            ISO8601DateFormatter.parseTokenUsageDate(from: "2026-06-26T01:05:00.000Z")
        )

        let replacementTimeline = importer.readLabelTimeline()
        XCTAssertEqual(replacementTimeline.entries.count, 1)
        XCTAssertEqual(replacementTimeline.label(for: replacementTimestamp).taskType, .analysis)
        XCTAssertEqual(
            importer.labelTimelineBytesRead,
            firstData.count + appendedData.count + replacementData.count
        )
    }

    func testClaudeCodeSessionDiscoveryReusesShortLivedCacheWithoutAddingLookback() throws {
        let rootURL = temporaryDirectoryURL()
        let projectURL = rootURL.appendingPathComponent("project-opaque", isDirectory: true)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        let firstSessionID = "11111111111111111111111111111111"
        try Data().write(to: projectURL.appendingPathComponent("\(firstSessionID).jsonl"))

        var currentDate = Date(timeIntervalSince1970: 1_000)
        let importer = TokenUsageClaudeCodeImporter(
            projectsDirectory: rootURL,
            labelTimelineURL: rootURL.appendingPathComponent("missing-labels.jsonl"),
            stateURL: nil,
            sessionDiscoveryCacheLifetime: 60,
            now: { currentDate }
        )

        XCTAssertEqual(importer.discoverSessionFiles().map(\.sessionID), [firstSessionID])
        XCTAssertEqual(importer.sessionDiscoveryScanCount, 1)

        let secondSessionID = "22222222222222222222222222222222"
        try Data().write(to: projectURL.appendingPathComponent("\(secondSessionID).jsonl"))
        XCTAssertEqual(importer.discoverSessionFiles().map(\.sessionID), [firstSessionID])
        XCTAssertEqual(importer.sessionDiscoveryScanCount, 1)

        currentDate.addTimeInterval(61)
        XCTAssertEqual(
            importer.discoverSessionFiles().map(\.sessionID).sorted(),
            [firstSessionID, secondSessionID]
        )
        XCTAssertEqual(importer.sessionDiscoveryScanCount, 2)
    }

    func testClaudeCodeActiveImporterSkipsCrossBatchRequestIdDuplicates() throws {
        // Bug #2 cross-batch scenario: Claude Code writes the same requestId a second
        // time to the transcript after the first incremental read has already advanced
        // the byte-offset cursor. The second occurrence has a slightly different timestamp
        // (1 s later) so span_id dedup alone cannot catch it — requestId tracking must.
        let rootURL = temporaryDirectoryURL()
        let projectsURL = rootURL.appendingPathComponent("projects", isDirectory: true)
        let projectURL = projectsURL.appendingPathComponent("project-opaque", isDirectory: true)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)

        let transcriptURL = projectURL.appendingPathComponent("11111111111111111111111111111111.jsonl")
        let stateURL = rootURL.appendingPathComponent("claude-active-state.json")
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let importer = TokenUsageClaudeCodeImporter(
            projectsDirectory: projectsURL,
            labelTimelineURL: rootURL.appendingPathComponent("missing-labels.jsonl"),
            stateURL: stateURL
        )

        // Batch 1: first occurrence of req_bug2 at T=0s.
        try """
        {"timestamp":"2026-06-26T00:00:00.000Z","requestId":"req_bug2","message":{"role":"assistant","model":"claude-sonnet-4","usage":{"input_tokens":100,"output_tokens":10},"content":[]}}
        """.write(to: transcriptURL, atomically: true, encoding: .utf8)

        let batch1 = importer.importRecentSessions(into: store)
        XCTAssertEqual(batch1.importedEvents, 1, "first occurrence should be imported")
        XCTAssertEqual(store.loadEvents().count, 1)

        // Batch 2: Claude Code appends the same requestId again with a 1-second offset
        // timestamp (Bug #2). The importer reads from the updated cursor position.
        let existingContent = try String(contentsOf: transcriptURL)
        let duplicate = #"{"timestamp":"2026-06-26T00:00:01.000Z","requestId":"req_bug2","message":{"role":"assistant","model":"claude-sonnet-4","usage":{"input_tokens":100,"output_tokens":10},"content":[]}}"#
        try (existingContent + "\n" + duplicate + "\n").write(to: transcriptURL, atomically: true, encoding: .utf8)

        let batch2 = importer.importRecentSessions(into: store)
        XCTAssertEqual(batch2.importedEvents, 0, "cross-batch duplicate requestId must be skipped")
        XCTAssertEqual(store.loadEvents().count, 1, "store must contain exactly one event")

        // A genuinely new turn with a different requestId must still be imported.
        let newContent = try String(contentsOf: transcriptURL)
        let newTurn = #"{"timestamp":"2026-06-26T00:01:00.000Z","requestId":"req_new","message":{"role":"assistant","model":"claude-sonnet-4","usage":{"input_tokens":50,"output_tokens":5},"content":[]}}"#
        try (newContent + "\n" + newTurn + "\n").write(to: transcriptURL, atomically: true, encoding: .utf8)

        let batch3 = importer.importRecentSessions(into: store)
        XCTAssertEqual(batch3.importedEvents, 1, "new requestId in subsequent batch must be imported")
        XCTAssertEqual(store.loadEvents().count, 2, "store must contain two distinct events")
    }

    func testClaudeCodeActiveImporterLeavesSubagentTranscriptFilesForStopHook() throws {
        let rootURL = temporaryDirectoryURL()
        let projectsURL = rootURL.appendingPathComponent("projects", isDirectory: true)
        let subagentsURL = projectsURL
            .appendingPathComponent("project-opaque", isDirectory: true)
            .appendingPathComponent("subagents", isDirectory: true)
        try FileManager.default.createDirectory(at: subagentsURL, withIntermediateDirectories: true)

        let transcriptURL = subagentsURL.appendingPathComponent("agent-a2805a322318cb80e.jsonl")
        try """
        {"timestamp":"2026-06-26T00:00:01.000Z","message":{"id":"msg_subagent","role":"assistant","model":"claude-sonnet-4","usage":{"input_tokens":12,"output_tokens":4},"content":[]}}

        """.write(to: transcriptURL, atomically: true, encoding: .utf8)

        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let importer = TokenUsageClaudeCodeImporter(
            projectsDirectory: projectsURL,
            labelTimelineURL: rootURL.appendingPathComponent("missing-labels.jsonl"),
            stateURL: rootURL.appendingPathComponent("claude-active-state.json")
        )

        let summary = importer.importRecentSessions(into: store)
        XCTAssertEqual(summary.scannedFiles, 0)
        XCTAssertEqual(summary.importedEvents, 0)
        XCTAssertEqual(store.loadEvents(), [])
    }

    func testTokenUsageCollectorStopPreventsQueuedAntigravityImport() {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let lock = NSLock()
        var didRunImporter = false
        let collector = TokenUsageCollectorCoordinator(
            store: store,
            antigravityImportRunner: { _, _, _ in
                lock.withLock {
                    didRunImporter = true
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
            claudeCodeImportRunner: { _, _ in TokenUsageClaudeCodeImportSummary(scannedFiles: 0, parsedTurns: 0, importedEvents: 0, skippedDuplicateEvents: 0, cursorAdvancedFiles: 0, failedToWriteEvents: false) }
        )

        collector.stop()
        collector.requestCollection(reason: "test")

        Thread.sleep(forTimeInterval: 0.1)
        XCTAssertFalse(lock.withLock { didRunImporter })
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
        XCTAssertEqual(event.tokenAccounting?.uncachedInputTokens, 120)
        XCTAssertEqual(event.tokenAccounting?.cacheReadInputTokens, 56)
        XCTAssertEqual(event.tokenAccounting?.cacheCreationInputTokens, 0)

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

    func testAntigravityTemporaryDatabaseCopiesArePrunedOnImport() throws {
        let rootURL = temporaryDirectoryURL()
        let conversationsURL = rootURL.appendingPathComponent("conversations", isDirectory: true)
        let databaseURL = conversationsURL.appendingPathComponent("opaque-conversation.db")
        let stateURL = rootURL
            .appendingPathComponent("state", isDirectory: true)
            .appendingPathComponent("antigravity-active-importer-state.json")
        try writeAntigravityConversationDatabase(at: databaseURL, rows: [])

        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("spill-agy-import", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        let staleURL = temporaryDirectory
            .appendingPathComponent("stale-\(UUID().uuidString)")
            .appendingPathExtension("db")
        try Data("stale".utf8).write(to: staleURL)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-(25 * 60 * 60))],
            ofItemAtPath: staleURL.path
        )
        defer {
            try? FileManager.default.removeItem(at: staleURL)
        }

        let importer = TokenUsageAntigravityImporter(
            conversationsDirectory: conversationsURL,
            diagnosticsURL: nil,
            stateURL: stateURL,
            forceTemporaryCopyFallback: true
        )

        _ = importer.importRecentEvents(into: TokenUsageStore(fileURL: temporaryEventsURL()), since: .distantPast)

        XCTAssertFalse(FileManager.default.fileExists(atPath: staleURL.path))
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
        XCTAssertTrue(tokenMeteringCoordinator.contains("usageStore.menuBarTokenTotals("))
        XCTAssertTrue(tokenMeteringCoordinator.contains("inputScope: inputScope"))
        XCTAssertTrue(tokenMeteringCoordinator.contains("settings.$tokenUsageInputScope"))
        XCTAssertTrue(tokenMeteringCoordinator.contains("guard let totals"))
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
        let main = try Self.source(named: "SpillMain.swift")
        let appDelegate = try String(contentsOf: root.appendingPathComponent("Sources/Spill/App/AppDelegate.swift"))
        let process = try Self.source(named: "TokenMeteringDashboardProcess.swift")
        let launcher = try Self.source(named: "TokenMeteringDashboardLauncher.swift")
        let lifecycle = try Self.source(named: "TokenMeteringDashboardLifecycle.swift")
        let tokenMeteringCoordinator = try Self.source(named: "TokenMeteringCoordinator.swift")
        let helperDelegate = try Self.source(named: "TokenMeteringDashboardAppDelegate.swift")
        let windowController = try Self.source(named: "TokenMeteringDashboardWindowController.swift")
        let buildScript = try String(contentsOf: root.appendingPathComponent("scripts/build-app.sh"))
        let smokeScript = try String(contentsOf: root.appendingPathComponent("scripts/verify-runtime-smoke.sh"))
        let renderSmokeScript = try String(
            contentsOf: root.appendingPathComponent("scripts/verify-token-dashboard-render-smoke.sh")
        )
        let workflowScript = try String(contentsOf: root.appendingPathComponent(".agents/scripts/workflow.py"))

        XCTAssertTrue(main.contains("TokenMeteringDashboardProcess.isDashboardProcess"))
        XCTAssertTrue(main.contains("TokenMeteringDashboardLifecycle.shared.observeDashboardMainApplicationTermination"))
        XCTAssertTrue(main.contains("TokenMeteringDashboardProcess.mainBundleIdentifierForDashboardHelper()"))
        XCTAssertTrue(main.contains("TokenMeteringDashboardLifecycle.shared.observeMainApplicationTermination"))
        XCTAssertTrue(main.contains("TokenMeteringDashboardAppDelegate()"))
        XCTAssertTrue(main.contains("application.setActivationPolicy(.regular)"))
        XCTAssertTrue(main.contains("application.setActivationPolicy(.accessory)"))
        XCTAssertTrue(process.contains(#"static let helperBundleName = "Spill Token Dashboard.app""#))
        XCTAssertTrue(process.contains(#"static let helperBundleIdentifierSuffix = ".TokenDashboard""#))
        XCTAssertTrue(process.contains("mainBundleIdentifierForDashboardHelper"))
        XCTAssertTrue(process.contains("shouldRequestMainAppLaunch"))
        XCTAssertTrue(process.contains("settingsDidChangeNotification"))
        XCTAssertTrue(process.contains("postAppLanguageDidChange"))
        XCTAssertTrue(process.contains("postTokenUsageDashboardOnboardingPreviewDidChange"))
        XCTAssertTrue(process.contains("postTokenUsageInputScopeDidChange"))
        XCTAssertTrue(process.contains("cloudServiceStatusRefreshRequestNotification"))
        XCTAssertTrue(process.contains("cloudServiceStatusDidChangeNotification"))
        XCTAssertTrue(process.contains("postCloudServiceStatusRefreshRequest"))
        XCTAssertTrue(process.contains("postCloudServiceStatusDidChange"))
        XCTAssertTrue(lifecycle.contains("mainAppWillTerminateNotification"))
        XCTAssertTrue(lifecycle.contains("observeMainApplicationTermination"))
        XCTAssertTrue(lifecycle.contains("observeDashboardMainApplicationTermination"))
        XCTAssertTrue(lifecycle.contains("NSApplication.willTerminateNotification"))
        XCTAssertTrue(lifecycle.contains("NSWorkspace.didTerminateApplicationNotification"))
        XCTAssertTrue(lifecycle.contains("postMainAppWillTerminate()"))
        XCTAssertTrue(lifecycle.contains("terminateDashboardHelperProcesses()"))
        XCTAssertTrue(lifecycle.contains("workspaceApplicationDidTerminate"))
        XCTAssertTrue(lifecycle.contains("runningApplication.terminate()"))
        XCTAssertTrue(lifecycle.contains("runningApplication.forceTerminate()"))
        XCTAssertTrue(lifecycle.contains("terminateCurrentDashboardProcess()"))
        XCTAssertTrue(lifecycle.contains("prepareWindowsForFastTermination()"))
        XCTAssertTrue(lifecycle.contains("SpillCrashReporter.markUncleanShutdownPending(processRole: \"token_dashboard\")"))
        XCTAssertTrue(lifecycle.contains("Darwin.kill(processID, SIGKILL)"))
        XCTAssertTrue(lifecycle.contains("dashboardBundleIdentifier(forMainBundleIdentifier"))
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
        XCTAssertTrue(launcher.contains("nonisolated static func runOnMainActor"))
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
        XCTAssertTrue(appDelegate.contains("TokenMeteringDashboardProcess.postTokenUsageInputScopeDidChange()"))
        XCTAssertTrue(appDelegate.contains("cloudServiceStatusRefreshRequestFromDashboard"))
        XCTAssertTrue(appDelegate.contains("postCloudServiceStatusDidChange"))

        XCTAssertTrue(helperDelegate.contains("applicationShouldTerminateAfterLastWindowClosed"))
        XCTAssertTrue(helperDelegate.contains("SPILL_TOKEN_DASHBOARD_SMOKE_READY"))
        XCTAssertTrue(helperDelegate.contains("SPILL_TOKEN_DASHBOARD_SMOKE_EXIT"))
        XCTAssertTrue(helperDelegate.contains("SPILL_TOKEN_DASHBOARD_RENDER_SMOKE"))
        XCTAssertTrue(helperDelegate.contains("SPILL_TOKEN_DASHBOARD_RENDER_READY"))
        XCTAssertTrue(helperDelegate.contains("Spill - AI Token Metering"))
        XCTAssertTrue(helperDelegate.contains("Quit Spill - AI Token Metering"))
        XCTAssertTrue(helperDelegate.contains("shouldHideWindowInSmokeTest"))
        XCTAssertTrue(helperDelegate.contains("SPILL_TOKEN_DASHBOARD_SMOKE_NO_WINDOW"))
        XCTAssertTrue(helperDelegate.contains("openMainAppTokenMeteringSettings"))
        XCTAssertTrue(helperDelegate.contains("launchMainAppIfNeeded()"))
        XCTAssertTrue(helperDelegate.contains("private var hasRequestedMainAppLaunch = false"))
        XCTAssertTrue(helperDelegate.contains("TokenMeteringDashboardProcess.shouldRequestMainAppLaunch"))
        XCTAssertTrue(helperDelegate.contains("hasRequestedLaunch: hasRequestedMainAppLaunch"))
        XCTAssertFalse(helperDelegate.contains("NSWorkspace.shared.runningApplications"))
        XCTAssertTrue(helperDelegate.contains("configuration.activates = false"))
        XCTAssertTrue(helperDelegate.contains("NSWorkspace.shared.openApplication(at: mainAppURL"))
        XCTAssertTrue(helperDelegate.contains("TokenMeteringWorkspaceOpenCompletion.runOnMainActor(completion)"))
        XCTAssertTrue(helperDelegate.contains("openMainAppDeveloperOptions"))
        XCTAssertTrue(helperDelegate.contains("TokenMeteringDashboardProcess.postOpenPreferencesRequest(tab: tab)"))
        XCTAssertTrue(helperDelegate.contains("TokenMeteringWorkspaceOpenCompletion.postOpenPreferencesRequest(tab: tab)"))
        XCTAssertTrue(helperDelegate.contains("TokenMeteringDashboardLifecycle.shared.terminateCurrentDashboardProcess()"))
        XCTAssertTrue(helperDelegate.contains("windowController?.prepareForTermination()"))
        XCTAssertTrue(helperDelegate.contains("aiStatusStore.cancelRefresh()"))
        XCTAssertTrue(helperDelegate.contains("observeSettingsChanges()"))
        XCTAssertTrue(helperDelegate.contains("settingsDidChangeFromMainApp"))
        XCTAssertTrue(helperDelegate.contains("observeCloudServiceStatusChanges()"))
        XCTAssertTrue(helperDelegate.contains("cloudServiceStatusDidChangeFromMainApp"))
        XCTAssertTrue(helperDelegate.contains("requestCloudServiceStatusRefresh(force: force)"))
        XCTAssertTrue(helperDelegate.contains("reloadFromCacheIfNewer()"))
        XCTAssertTrue(helperDelegate.contains("settings.reloadAppLanguageFromDefaults()"))
        XCTAssertTrue(helperDelegate.contains("settings.reloadTokenUsageDashboardOnboardingPreviewFromDefaults()"))
        XCTAssertTrue(helperDelegate.contains("settings.reloadTokenUsageInputScopeFromDefaults()"))
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
        XCTAssertTrue(windowController.contains("window.isRestorable = false"))
        XCTAssertTrue(windowController.contains("func prepareForTermination()"))
        XCTAssertTrue(windowController.contains("aiStatusStore.cancelRefresh()"))
        XCTAssertFalse(windowController.contains("scheduleDeferredRefreshAction()"))
        XCTAssertTrue(windowController.contains("scheduleDeferredCollectionRequest()"))
        // The user-facing refresh flows (deferred open refresh, view button)
        // carry the forced manual reason; only the periodic loop stays paced.
        XCTAssertTrue(windowController.contains("self.manualRefreshAction()"))
        XCTAssertTrue(windowController.contains("refreshAction: manualRefreshAction"))
        XCTAssertTrue(windowController.contains("refreshAction()"))
        XCTAssertTrue(windowController.contains("deferredRefreshDelayNanoseconds: UInt64 = 1_500_000_000"))
        XCTAssertTrue(windowController.contains("tokenDataRefreshIntervalNanoseconds: UInt64 = 15_000_000_000"))
        XCTAssertTrue(windowController.contains("Task.sleep(nanoseconds: delay)"))
        XCTAssertTrue(windowController.contains("startTokenDataRefreshLoop()"))
        XCTAssertTrue(windowController.contains("tokenDataRefreshTask?.cancel()"))
        XCTAssertTrue(windowController.contains("requestTokenDataRefresh()"))
        XCTAssertFalse(windowController.contains("store.refreshAsync()"))
        XCTAssertTrue(windowController.contains("!store.isDashboardRefreshInProgress"))
        XCTAssertTrue(windowController.contains("prepareVisibleRenderForSmokeTest()"))
        XCTAssertTrue(appDelegate.contains("SpillCrashReporter.markCleanShutdown(processRole: \"main_app\")"))
        XCTAssertTrue(appDelegate.contains("tokenMeteringCoordinator.stop()"))
        XCTAssertTrue(appDelegate.contains("aiStatusStore.cancelRefresh()"))
        XCTAssertTrue(appDelegate.contains("cloudServiceStatusStore.cancelRefresh()"))
        XCTAssertTrue(appDelegate.contains("preferencesWindowController.prepareForTermination()"))
        XCTAssertLessThan(
            try XCTUnwrap(
                appDelegate.range(of: "SpillCrashReporter.markCleanShutdown(processRole: \"main_app\")")
            ).lowerBound,
            try XCTUnwrap(appDelegate.range(of: "tokenMeteringCoordinator.stop()")).lowerBound
        )
        XCTAssertLessThan(
            try XCTUnwrap(
                helperDelegate.range(of: "SpillCrashReporter.markCleanShutdown(processRole: \"token_dashboard\")")
            ).lowerBound,
            try XCTUnwrap(helperDelegate.range(of: "aiStatusStore.cancelRefresh()")).lowerBound
        )

        XCTAssertTrue(buildScript.contains(#"HELPER_APP_NAME="Spill Token Dashboard.app""#))
        XCTAssertTrue(buildScript.contains("<string>Spill - AI Token Metering</string>"))
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
        XCTAssertTrue(renderSmokeScript.contains("SPILL_TOKEN_DASHBOARD_RENDER_SMOKE=1"))
        XCTAssertTrue(renderSmokeScript.contains("SPILL_TOKEN_DASHBOARD_RENDER_READY"))
        XCTAssertTrue(renderSmokeScript.contains("RENDER_BUDGET_MS=1500"))
        XCTAssertFalse(renderSmokeScript.contains("SPILL_TOKEN_DASHBOARD_SMOKE_NO_WINDOW"))
        XCTAssertTrue(workflowScript.contains("token-dashboard-render-smoke"))
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
        XCTAssertEqual(
            TokenMeteringDashboardLifecycle.dashboardBundleIdentifier(forMainBundleIdentifier: "dev.spill.Spill"),
            "dev.spill.Spill.TokenDashboard"
        )
        XCTAssertNil(TokenMeteringDashboardLifecycle.dashboardBundleIdentifier(forMainBundleIdentifier: nil))
        XCTAssertTrue(TokenMeteringDashboardProcess.isDashboardBundleIdentifier("dev.spill.Spill.TokenDashboard"))
        XCTAssertFalse(TokenMeteringDashboardProcess.isDashboardBundleIdentifier("dev.spill.Spill"))
        XCTAssertFalse(TokenMeteringDashboardProcess.shouldRequestMainAppLaunch(
            environment: [
                TokenMeteringDashboardProcess.mainBundleIdentifierEnvironmentKey: "dev.spill.Spill"
            ],
            hasRequestedLaunch: false
        ))
        XCTAssertTrue(TokenMeteringDashboardProcess.shouldRequestMainAppLaunch(
            environment: [:],
            hasRequestedLaunch: false
        ))
        XCTAssertFalse(TokenMeteringDashboardProcess.shouldRequestMainAppLaunch(
            environment: [:],
            hasRequestedLaunch: true
        ))
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

    func testTokenUsageCollectorIgnoresGenericNodeBinaryEnvironmentVariable() {
        // NODE_BINARY is a generic name many unrelated tools and shell profiles set; only
        // the Spill-namespaced override may redirect which binary Spill executes.
        let resolved = TokenUsageCollectorCoordinator.nodeExecutableURL(
            environment: ["NODE_BINARY": "/attacker/controlled/node"],
            isExecutableFile: { $0 == "/attacker/controlled/node" },
            isRegularFile: { $0 == "/attacker/controlled/node" }
        )
        XCTAssertNil(resolved)
    }

    func testTokenUsageCollectorResolvesNodeAndPython3FromVersionManagerShims() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        let volta = TokenUsageCollectorCoordinator.nodeExecutableURL(
            environment: [:],
            isExecutableFile: { $0 == "\(home)/.volta/bin/node" },
            isRegularFile: { $0 == "\(home)/.volta/bin/node" }
        )
        XCTAssertEqual(volta?.path, "\(home)/.volta/bin/node")

        let asdfNode = TokenUsageCollectorCoordinator.nodeExecutableURL(
            environment: [:],
            isExecutableFile: { $0 == "\(home)/.asdf/shims/node" },
            isRegularFile: { $0 == "\(home)/.asdf/shims/node" }
        )
        XCTAssertEqual(asdfNode?.path, "\(home)/.asdf/shims/node")

        let asdfPython = TokenUsageCollectorCoordinator.python3ExecutableURL(
            environment: [:],
            isExecutableFile: { $0 == "\(home)/.asdf/shims/python3" },
            isRegularFile: { $0 == "\(home)/.asdf/shims/python3" }
        )
        XCTAssertEqual(asdfPython?.path, "\(home)/.asdf/shims/python3")

        let pyenvPython = TokenUsageCollectorCoordinator.python3ExecutableURL(
            environment: [:],
            isExecutableFile: { $0 == "\(home)/.pyenv/shims/python3" },
            isRegularFile: { $0 == "\(home)/.pyenv/shims/python3" }
        )
        XCTAssertEqual(pyenvPython?.path, "\(home)/.pyenv/shims/python3")
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

    func testAppendEventsWithoutLoadingRepairsDuplicateSpanTokenCountsAndPreservesMetadata() throws {
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

        XCTAssertEqual(insertedCount, 1)
        XCTAssertEqual(event.projectID, "project_existing")
        XCTAssertEqual(event.taskType, .codeReview)
        XCTAssertEqual(event.stage, .verify)
        XCTAssertEqual(event.inputTokens, 20)
        XCTAssertEqual(event.outputTokens, 4)
    }

    func testAppendEventsWithoutLoadingRepairsClaudeDuplicateSpanTokenCountsAndPreservesMetadata() throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        let existing = Self.safeEvent(
            aiTool: .claude,
            spanID: "span_claude_reconciled_history",
            inputTokens: 25,
            outputTokens: 7,
            generatedOutput: 7,
            projectID: "project_existing",
            taskType: .analysis,
            stage: .plan
        )
        let incoming = Self.safeEvent(
            aiTool: .claude,
            spanID: "span_claude_reconciled_history",
            inputTokens: 125,
            outputTokens: 7,
            generatedOutput: 7,
            tokenAccounting: TokenUsageAccounting(
                uncachedInputTokens: 20,
                cacheCreationInputTokens: 5,
                cacheReadInputTokens: 100
            ),
            projectID: "project_new",
            taskType: .reviewResponse,
            stage: .implement
        )

        try usageStore.appendEvent(existing)
        let insertedCount = try usageStore.appendEventsWithoutLoading([incoming])
        let event = try XCTUnwrap(usageStore.loadEvents().first)

        XCTAssertEqual(insertedCount, 1)
        XCTAssertEqual(event.projectID, "project_existing")
        XCTAssertEqual(event.taskType, .analysis)
        XCTAssertEqual(event.stage, .plan)
        XCTAssertEqual(event.inputTokens, 125)
        XCTAssertEqual(event.outputTokens, 7)
        XCTAssertEqual(event.totalTokens, 132)
        XCTAssertEqual(event.tokenBreakdown.generatedOutput, 7)
        XCTAssertEqual(event.tokenBreakdown.unknown, 125)
        XCTAssertEqual(event.tokenAccounting?.uncachedInputTokens, 20)
        XCTAssertEqual(event.tokenAccounting?.cacheCreationInputTokens, 5)
        XCTAssertEqual(event.tokenAccounting?.cacheReadInputTokens, 100)
    }

    func testAppendEventsWithoutLoadingRepairsAntigravityDuplicateSpanAccountingAndPreservesMetadata() throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        let existing = Self.safeEvent(
            aiTool: .antigravity,
            spanID: "span_agy_reconciled_history",
            inputTokens: 120,
            outputTokens: 20,
            generatedOutput: 20,
            projectID: "project_existing",
            taskType: .analysis,
            stage: .plan,
            model: "antigravity-old"
        )
        let incoming = Self.safeEvent(
            aiTool: .antigravity,
            spanID: "span_agy_reconciled_history",
            inputTokens: 176,
            outputTokens: 34,
            generatedOutput: 34,
            tokenAccounting: TokenUsageAccounting(
                uncachedInputTokens: 120,
                cacheReadInputTokens: 56
            ),
            projectID: "project_new",
            taskType: .debugging,
            stage: .implement,
            model: "antigravity-new"
        )

        try usageStore.appendEvent(existing)
        let insertedCount = try usageStore.appendEventsWithoutLoading([incoming])
        let event = try XCTUnwrap(usageStore.loadEvents().first)

        XCTAssertEqual(insertedCount, 1)
        XCTAssertEqual(event.projectID, "project_existing")
        XCTAssertEqual(event.taskType, .analysis)
        XCTAssertEqual(event.stage, .plan)
        XCTAssertEqual(event.model, "antigravity-old")
        XCTAssertEqual(event.inputTokens, 176)
        XCTAssertEqual(event.outputTokens, 34)
        XCTAssertEqual(event.totalTokens, 210)
        XCTAssertEqual(event.tokenBreakdown.generatedOutput, 34)
        XCTAssertEqual(event.tokenBreakdown.unknown, 176)
        XCTAssertEqual(event.tokenAccounting?.uncachedInputTokens, 120)
        XCTAssertEqual(event.tokenAccounting?.cacheCreationInputTokens, 0)
        XCTAssertEqual(event.tokenAccounting?.cacheReadInputTokens, 56)
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
    func testScopedClearAfterSQLOnlyRefreshDoesNotWipeStore() async throws {
        // Regression test: the SQL-only dashboard refresh path (no project/session/day
        // drill-down, includeCache scope) never populates the store's cached `events` array.
        // clearEvents(in:) for anything other than .all used to compute "events to keep" by
        // subtracting from that cached array directly -- with an empty cache, that produced an
        // empty "remaining" set and called usageStore.replaceEvents([]), silently deleting every
        // stored event instead of only the ones in scope. events(matching:)/clearEvents(in:) now
        // always do a fresh load instead of trusting the cache.
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        let dashboardStore = dashboardStore(usageStore: usageStore)
        let codex = Self.safeEvent(aiTool: .codex, spanID: "span_wipe_guard_codex")
        let claude = Self.safeEvent(aiTool: .claude, spanID: "span_wipe_guard_claude")
        try usageStore.replaceEvents([codex, claude])

        // Unfiltered, includeCache: eligible for the SQL-only path, so this refresh must not
        // need to hold the raw events array to answer with the correct totals.
        dashboardStore.refreshAsyncIfIdle()
        try await waitForDashboardStoreRefreshToLoadEvents(dashboardStore, eventCount: 2)
        XCTAssertEqual(dashboardStore.snapshot.toolFilters.first?.detail, "2 records / 300 tokens")

        dashboardStore.clearEvents(in: .tool(.claude))

        // Only the Claude event must be gone -- a stale-cache bug here would have deleted both.
        XCTAssertEqual(usageStore.loadEvents().map(\.spanID), ["span_wipe_guard_codex"])
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
    func testDashboardStoreInitializesPanelSummaryWithoutFullSnapshot() async throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        try usageStore.appendEvent(Self.safeEvent(aiTool: .codex, spanID: "span_panel_summary"))

        let dashboardStore = dashboardStore(usageStore: usageStore)

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 0)
        XCTAssertEqual(dashboardStore.unfilteredSnapshot.eventCount, 0)
        try await waitForPanelSummary(dashboardStore, eventCount: 1, totalTokens: 150)
        XCTAssertEqual(dashboardStore.panelSummary.eventCount, 1)
        XCTAssertEqual(dashboardStore.panelSummary.totalTokens, 150)

        dashboardStore.refresh()

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 1)
        XCTAssertEqual(dashboardStore.unfilteredSnapshot.eventCount, 1)
        XCTAssertEqual(dashboardStore.panelSummary.eventCount, 1)
    }

    @MainActor
    func testDashboardGlanceSummaryIgnoresPanelToolVisibilityInSummaryOnlyRefresh() async throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        try usageStore.replaceEvents([
            Self.safeEvent(
                aiTool: .codex,
                spanID: "span_glance_summary_codex",
                inputTokens: 80,
                outputTokens: 20
            ),
            Self.safeEvent(
                aiTool: .claude,
                spanID: "span_glance_summary_claude",
                inputTokens: 160,
                outputTokens: 40
            ),
            Self.safeEvent(
                aiTool: .antigravity,
                spanID: "span_glance_summary_antigravity",
                inputTokens: 240,
                outputTokens: 60
            ),
            Self.safeEvent(
                aiTool: .openAI,
                spanID: "span_glance_summary_openai",
                inputTokens: 320,
                outputTokens: 80
            )
        ])
        let dashboardStore = TokenUsageDashboardStore(
            usageStore: usageStore,
            loadsInitialPanelSummary: false
        )

        dashboardStore.setVisibleAITools([.codex])
        try await waitForPanelSummary(dashboardStore, eventCount: 1, totalTokens: 100)
        try await waitForGlanceSummary(dashboardStore, eventCount: 3, totalTokens: 600)

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 0)
        XCTAssertEqual(dashboardStore.panelSummary.toolRows.map(\.id), ["codex"])
        XCTAssertEqual(
            Set(dashboardStore.glanceSummary.toolRows.map(\.id)),
            Set(TokenUsageAITool.dashboardTools.map(\.rawValue))
        )
    }

    @MainActor
    func testDashboardGlanceSummaryRefreshesThroughSyncSQLAndNonSQLPaths() async throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        try usageStore.replaceEvents([
            Self.safeEvent(
                aiTool: .codex,
                spanID: "span_glance_sync_codex",
                inputTokens: 80,
                outputTokens: 20
            ),
            Self.safeEvent(
                aiTool: .claude,
                spanID: "span_glance_sync_claude",
                inputTokens: 160,
                outputTokens: 40
            )
        ])
        let dashboardStore = TokenUsageDashboardStore(
            usageStore: usageStore,
            loadsInitialPanelSummary: false
        )
        dashboardStore.setVisibleAITools([.codex])

        dashboardStore.refresh(trackLiveUpdates: false)
        XCTAssertEqual(dashboardStore.panelSummary.totalTokens, 100)
        XCTAssertEqual(dashboardStore.glanceSummary.totalTokens, 300)

        try usageStore.appendEvent(Self.safeEvent(
            aiTool: .antigravity,
            spanID: "span_glance_async_sql_antigravity",
            inputTokens: 240,
            outputTokens: 60
        ))
        dashboardStore.refreshAsync(trackLiveUpdates: false)
        try await waitForGlanceSummary(dashboardStore, eventCount: 3, totalTokens: 600)
        XCTAssertEqual(dashboardStore.panelSummary.totalTokens, 100)

        dashboardStore.setSelectedProjectID("project_local")
        try await waitForDashboardStoreRefresh(dashboardStore)
        try usageStore.appendEvent(Self.safeEvent(
            aiTool: .claude,
            spanID: "span_glance_async_events_claude",
            inputTokens: 320,
            outputTokens: 80
        ))
        dashboardStore.refreshAsync(trackLiveUpdates: false)
        try await waitForGlanceSummary(dashboardStore, eventCount: 4, totalTokens: 1_000)

        XCTAssertEqual(dashboardStore.panelSummary.totalTokens, 100)
        XCTAssertEqual(dashboardStore.glanceSummary.toolRows.count, 3)
    }

    @MainActor
    func testDashboardCalendarInvalidationNotificationsRunFullRefresh() async throws {
        let previousAdvancedTools = SpillSettings.shared.tokenUsageShowAdvancedTools
        defer {
            SpillSettings.shared.tokenUsageShowAdvancedTools = previousAdvancedTools
        }
        SpillSettings.shared.tokenUsageShowAdvancedTools = false

        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        try usageStore.replaceEvents([
            Self.safeEvent(
                aiTool: .codex,
                spanID: "span_calendar_invalidation_codex",
                inputTokens: 80,
                outputTokens: 20
            ),
            Self.safeEvent(
                aiTool: .openAI,
                spanID: "span_calendar_invalidation_openai",
                inputTokens: 160,
                outputTokens: 40
            )
        ])
        let notificationCenter = NotificationCenter()
        let dashboardStore = TokenUsageDashboardStore(
            usageStore: usageStore,
            loadsInitialPanelSummary: false,
            notificationCenter: notificationCenter
        )
        dashboardStore.refresh(trackLiveUpdates: false)

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 1)
        XCTAssertEqual(dashboardStore.panelSummary.eventCount, 1)
        XCTAssertEqual(dashboardStore.glanceSummary.eventCount, 1)

        let invalidations: [(Notification.Name, Bool, Int)] = [
            (.NSCalendarDayChanged, true, 2),
            (.NSSystemClockDidChange, false, 1),
            (.NSSystemTimeZoneDidChange, true, 2)
        ]
        for (name, showsAdvancedTools, expectedCount) in invalidations {
            SpillSettings.shared.tokenUsageShowAdvancedTools = showsAdvancedTools
            notificationCenter.post(name: name, object: nil)
            try await waitForDashboardSnapshot(
                dashboardStore,
                eventCount: expectedCount
            )

            XCTAssertEqual(dashboardStore.panelSummary.eventCount, expectedCount)
            XCTAssertEqual(dashboardStore.glanceSummary.eventCount, 1)
            XCTAssertEqual(dashboardStore.liveUpdateMarker, .empty)
        }
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
        XCTAssertEqual(dashboardStore.panelSummary.eventCount, 1)

        dashboardStore.selectCalendarDay(yesterdayDayID)
        try await waitForDashboardStoreRefresh(dashboardStore)

        XCTAssertEqual(dashboardStore.selectedCalendarDayID, yesterdayDayID)
        XCTAssertEqual(dashboardStore.snapshot.eventCount, 1)
        XCTAssertEqual(dashboardStore.snapshot.totalTokens, 200)
        XCTAssertEqual(dashboardStore.snapshot.toolRows.map(\.id), ["claude"])
        XCTAssertEqual(dashboardStore.panelSummary.eventCount, 1)
    }

    func testDashboardStoreScopeChangesSkipPanelSummaryRefresh() throws {
        let dashboardStore = try Self.source(named: "TokenUsageDashboardStore.swift")

        XCTAssertTrue(dashboardStore.contains("refreshesPanelSummary ? loadPanelSummary"))
        XCTAssertTrue(dashboardStore.contains("refreshesPanelSummary ? Self.loadPanelSummary"))
        XCTAssertEqual(
            dashboardStore.components(
                separatedBy: "reusesPeriodFilterTotals: true"
            ).count - 1,
            8
        )
        XCTAssertTrue(dashboardStore.contains("let cachedPeriodFilterTotals = reusesPeriodFilterTotals ? periodFilterTotals : [:]"))
        XCTAssertTrue(dashboardStore.contains("dateRange(cachedDateRange, contains: requestedRange)"))
        XCTAssertTrue(dashboardStore.contains("func setUsageInputScope(_ scope: TokenUsageInputScope)"))
        XCTAssertTrue(dashboardStore.contains("rebuildSnapshotFromCurrentEventsAsync()"))
        XCTAssertTrue(dashboardStore.contains("if isRefreshing"))
        XCTAssertTrue(dashboardStore.contains("@Published private(set) var snapshotInputScope"))

        let moveCalendarStart = try XCTUnwrap(dashboardStore.range(of: "private func moveCalendarMonth"))
        let runSelfTestStart = try XCTUnwrap(dashboardStore.range(of: "func runLocalQueueSelfTest"))
        let moveCalendarSource = String(dashboardStore[moveCalendarStart.lowerBound..<runSelfTestStart.lowerBound])
        XCTAssertFalse(moveCalendarSource.contains("loadPanelSummary"))
        XCTAssertTrue(moveCalendarSource.contains("snapshotBuildQueue.async"))
    }

    @MainActor
    func testDashboardStoreScopeChangeRebuildsUsageSurfacesAndWorkflowGroups() async throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 1
        let todayStart = calendar.startOfDay(for: Date())
        let createdAt = try XCTUnwrap(calendar.date(byAdding: .hour, value: 1, to: todayStart))
        try usageStore.replaceEvents([
            Self.safeEvent(
                aiTool: .codex,
                spanID: "span_scope_store_codex",
                inputTokens: 60,
                outputTokens: 10,
                model: "scope-store-codex",
                createdAt: ISO8601DateFormatter.tokenUsage.string(from: createdAt)
            ),
            Self.safeEvent(
                aiTool: .claude,
                spanID: "span_scope_store_claude",
                inputTokens: 125,
                outputTokens: 7,
                tokenAccounting: TokenUsageAccounting(
                    uncachedInputTokens: 20,
                    cacheCreationInputTokens: 5,
                    cacheReadInputTokens: 100
                ),
                model: "scope-store-claude",
                createdAt: ISO8601DateFormatter.tokenUsage.string(from: createdAt.addingTimeInterval(60))
            )
        ])
        let dashboardStore = TokenUsageDashboardStore(
            usageStore: usageStore,
            loadsInitialPanelSummary: false
        )

        dashboardStore.refreshAsyncIfIdle()
        try await waitForDashboardStoreRefresh(dashboardStore)
        XCTAssertEqual(dashboardStore.snapshotInputScope, .includeCache)
        XCTAssertEqual(dashboardStore.snapshot.toolFilters.first?.detail, "2 records / 202 tokens")

        dashboardStore.setUsageInputScope(.freshOnly)
        XCTAssertEqual(dashboardStore.snapshotInputScope, .includeCache)
        try await waitForDashboardStoreRefresh(dashboardStore)

        XCTAssertEqual(dashboardStore.usageInputScope, .freshOnly)
        XCTAssertEqual(dashboardStore.snapshotInputScope, .freshOnly)
        XCTAssertEqual(dashboardStore.snapshot.toolFilters.first?.detail, "2 records / 37 tokens")
        XCTAssertEqual(dashboardStore.snapshot.periodFilters.first { $0.period == .today }?.detail, "37")
        XCTAssertEqual(dashboardStore.snapshot.toolRows.map(\.value), ["27 (73.0%)", "10 (27.0%)"])
        XCTAssertEqual(dashboardStore.snapshot.modelRows.map(\.value), ["27 (73.0%)", "10 (27.0%)"])
        XCTAssertEqual(dashboardStore.snapshot.taskRows.first?.value, "37 (100.0%)")
        XCTAssertEqual(dashboardStore.snapshot.sessions.first?.value, "37")
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

        _ = usageStore.importQueuedEvents()
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
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(at: inboxURL, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "jsonl" }
                .map(\.lastPathComponent),
            ["001.jsonl"]
        )

        XCTAssertTrue(usageStore.drainQueuedEventsWithoutLoading(maximumInboxEventCount: 2))
        XCTAssertEqual(
            usageStore.loadEvents().map(\.spanID),
            ["span_jsonl_chunk_1", "span_jsonl_chunk_2", "span_jsonl_chunk_3"]
        )
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(at: inboxURL, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "jsonl" }
                .count,
            0
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

        // A dashboard surface must have loaded once before store changes
        // rebuild the full snapshot; without a consumer only the panel summary
        // refreshes (see testStoreChangeWithoutDashboardConsumer...).
        dashboardStore.refresh(trackLiveUpdates: false)
        XCTAssertEqual(dashboardStore.snapshot.eventCount, 0)

        try usageStore.appendEvent(Self.safeEvent())
        try await waitForDashboardStoreRefreshToLoadEvents(dashboardStore, eventCount: 1)

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 1)
        XCTAssertEqual(dashboardStore.snapshot.totalTokens, 150)
    }

    @MainActor
    func testStoreChangeWithoutDashboardConsumerRefreshesOnlyPanelSummary() async throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        let dashboardStore = dashboardStore(usageStore: usageStore)

        try usageStore.appendEvent(Self.safeEvent(spanID: "span_no_consumer_panel_only"))
        try await waitForPanelSummary(dashboardStore, eventCount: 1)

        // Give the 250ms scheduled-refresh debounce time to fire, then confirm
        // it refreshed the panel summary without paying for a snapshot build.
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(dashboardStore.panelSummary.eventCount, 1)
        XCTAssertEqual(dashboardStore.snapshot.eventCount, 0)
        XCTAssertEqual(dashboardStore.loadState, .idle)
    }

    @MainActor
    func testDashboardStoreDoesNotRefreshOnlyBecauseLocalCollectionFinishes() async throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        try usageStore.appendEvent(Self.safeEvent(spanID: "span_collection_finish"))
        let dashboardStore = TokenUsageDashboardStore(
            usageStore: usageStore,
            loadsInitialPanelSummary: false
        )

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 0)

        NotificationCenter.default.post(
            name: TokenUsageCollectorCoordinator.collectionDidFinishNotification,
            object: nil
        )
        try await Task.sleep(nanoseconds: 350_000_000)

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 0)
        XCTAssertEqual(dashboardStore.loadState, .idle)
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
    func testDashboardHelperCanSkipUnusedGlanceSummaryLoad() async throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        try usageStore.appendEvent(Self.safeEvent(spanID: "span_helper_without_glance_summary"))
        let dashboardStore = TokenUsageDashboardStore(
            usageStore: usageStore,
            loadsInitialPanelSummary: false,
            loadsGlanceSummary: false
        )

        dashboardStore.refreshAsyncIfIdle()
        try await waitForDashboardStoreRefresh(dashboardStore)

        XCTAssertEqual(dashboardStore.panelSummary.eventCount, 1)
        XCTAssertEqual(dashboardStore.glanceSummary, .empty)
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
        XCTAssertEqual(dashboardStore.panelSummary.eventCount, 1)
        XCTAssertEqual(dashboardStore.panelSummary.totalTokens, 100)

        dashboardStore.setSelectedPeriod(.sevenDays)
        try await waitForDashboardStoreRefresh(dashboardStore)

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 2)
        XCTAssertEqual(dashboardStore.snapshot.totalTokens, 1_100)
    }

    @MainActor
    func testDashboardStoreTreatsPastOnlyHistoryAsExistingData() async throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let todayStart = calendar.startOfDay(for: Date())
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .hour, value: -1, to: todayStart))
        try usageStore.replaceEvents([
            Self.safeEvent(
                aiTool: .codex,
                spanID: "span_past_only_history",
                inputTokens: 90,
                outputTokens: 10,
                createdAt: ISO8601DateFormatter.tokenUsage.string(from: yesterday)
            )
        ])
        let dashboardStore = TokenUsageDashboardStore(
            usageStore: usageStore,
            loadsInitialPanelSummary: false
        )

        dashboardStore.refreshAsyncIfIdle()
        try await waitForDashboardStoreRefresh(dashboardStore)

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 0)
        XCTAssertEqual(dashboardStore.panelSummary.eventCount, 0)
        XCTAssertTrue(dashboardStore.hasDashboardEvents)
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
    func testDashboardStoreReloadsPeriodFilterTotalsWhenVisibleAIToolsChange() async throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let todayStart = calendar.startOfDay(for: Date())
        let today = try XCTUnwrap(calendar.date(byAdding: .hour, value: 1, to: todayStart))
        let sixDaysAgo = try XCTUnwrap(calendar.date(byAdding: .day, value: -6, to: todayStart))
        try usageStore.replaceEvents([
            Self.safeEvent(
                aiTool: .codex,
                spanID: "span_visible_tools_today_codex",
                inputTokens: 80,
                outputTokens: 20,
                createdAt: ISO8601DateFormatter.tokenUsage.string(from: today)
            ),
            Self.safeEvent(
                aiTool: .claude,
                spanID: "span_visible_tools_today_claude",
                inputTokens: 160,
                outputTokens: 40,
                createdAt: ISO8601DateFormatter.tokenUsage.string(from: today)
            ),
            Self.safeEvent(
                aiTool: .codex,
                spanID: "span_visible_tools_week_codex",
                inputTokens: 24,
                outputTokens: 6,
                createdAt: ISO8601DateFormatter.tokenUsage.string(from: sixDaysAgo)
            ),
            Self.safeEvent(
                aiTool: .claude,
                spanID: "span_visible_tools_week_claude",
                inputTokens: 56,
                outputTokens: 14,
                createdAt: ISO8601DateFormatter.tokenUsage.string(from: sixDaysAgo)
            )
        ])
        let dashboardStore = TokenUsageDashboardStore(
            usageStore: usageStore,
            loadsInitialPanelSummary: false
        )

        dashboardStore.refreshAsyncIfIdle()
        try await waitForDashboardStoreRefresh(dashboardStore)

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 2)
        XCTAssertEqual(dashboardStore.snapshot.periodFilters.map(\.detail), ["300", "400", "400", "400"])

        dashboardStore.setVisibleAITools([.codex])
        try await waitForDashboardPeriodDetails(dashboardStore, details: ["100", "130", "130", "130"])

        XCTAssertEqual(dashboardStore.snapshot.eventCount, 1)
        XCTAssertEqual(dashboardStore.snapshot.periodFilters.map(\.detail), ["100", "130", "130", "130"])
    }

    /// The SQL-eligible refresh (no project/session/day drill-down) now reads the period-filter
    /// chips and the panel summary inside buildSnapshotOutputFromSQL's single connection and returns
    /// them alongside the snapshot, instead of pre-reading them on separate connections. This pins
    /// that one such refresh publishes a snapshot whose period chips agree with an independent
    /// allPeriodInputScopeTotals query AND a non-empty panel summary consistent with the same data,
    /// so the rewiring keeps every field sourced from one build. (Single-transaction atomicity under
    /// a concurrent writer is not cheaply unit-testable; the SQL path structurally prevents the
    /// cross-connection seam this replaces.)
    @MainActor
    func testDashboardStoreSQLRefreshPublishesPeriodTotalsAndPanelSummaryTogether() async throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let todayStart = calendar.startOfDay(for: Date())
        let today = try XCTUnwrap(calendar.date(byAdding: .hour, value: 1, to: todayStart))
        let sixDaysAgo = try XCTUnwrap(calendar.date(byAdding: .day, value: -6, to: todayStart))
        try usageStore.replaceEvents([
            Self.safeEvent(
                aiTool: .codex,
                spanID: "span_sql_together_today_codex",
                inputTokens: 80,
                outputTokens: 20,
                createdAt: ISO8601DateFormatter.tokenUsage.string(from: today)
            ),
            Self.safeEvent(
                aiTool: .claude,
                spanID: "span_sql_together_today_claude",
                inputTokens: 160,
                outputTokens: 40,
                createdAt: ISO8601DateFormatter.tokenUsage.string(from: today)
            ),
            Self.safeEvent(
                aiTool: .codex,
                spanID: "span_sql_together_week_codex",
                inputTokens: 70,
                outputTokens: 30,
                createdAt: ISO8601DateFormatter.tokenUsage.string(from: sixDaysAgo)
            )
        ])

        let dashboardStore = TokenUsageDashboardStore(
            usageStore: usageStore,
            loadsInitialPanelSummary: false
        )

        // refreshAsyncIfIdle takes the SQL path here: no project/session/day is selected.
        dashboardStore.refreshAsyncIfIdle()
        try await waitForDashboardStoreRefresh(dashboardStore)

        // Today's chip must match today's total (300) and the week chip the 7-day total (400),
        // i.e. the stored period-filter totals returned by the SQL build.
        XCTAssertEqual(dashboardStore.snapshot.periodFilters.map(\.detail), ["300", "400", "400", "400"])

        // The panel summary is now returned by the same SQL build; it must be populated (not left
        // at .empty) and consistent with today's aggregate from an independent query.
        let todaySummary = usageStore.dashboardSummary(
            startingAt: todayStart,
            endingBefore: try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: todayStart))
        )
        XCTAssertEqual(todaySummary.eventCount, 2)
        XCTAssertEqual(dashboardStore.panelSummary.eventCount, todaySummary.eventCount)
        XCTAssertEqual(dashboardStore.panelSummary.totalTokens, todaySummary.totalTokens)
    }

    @MainActor
    func testDashboardStoreVisibleToolsBeforeFirstLoadDoesNotBlockInitialRefresh() async throws {
        let usageStore = TokenUsageStore(fileURL: temporaryEventsURL())
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let todayStart = calendar.startOfDay(for: Date())
        let today = try XCTUnwrap(calendar.date(byAdding: .hour, value: 1, to: todayStart))
        try usageStore.replaceEvents([
            Self.safeEvent(
                aiTool: .codex,
                spanID: "span_visible_tools_initial_codex",
                inputTokens: 80,
                outputTokens: 20,
                createdAt: ISO8601DateFormatter.tokenUsage.string(from: today)
            ),
            Self.safeEvent(
                aiTool: .claude,
                spanID: "span_visible_tools_initial_claude",
                inputTokens: 160,
                outputTokens: 40,
                createdAt: ISO8601DateFormatter.tokenUsage.string(from: today)
            )
        ])
        let dashboardStore = TokenUsageDashboardStore(
            usageStore: usageStore,
            loadsInitialPanelSummary: false
        )

        dashboardStore.setVisibleAITools([.codex])
        try await waitForPanelSummary(dashboardStore, eventCount: 1, totalTokens: 100)

        XCTAssertEqual(dashboardStore.loadState, .idle)
        XCTAssertEqual(dashboardStore.snapshot.eventCount, 0)

        dashboardStore.refreshAsyncIfIdle()
        try await waitForDashboardStoreRefreshToLoadEvents(dashboardStore, eventCount: 1)

        XCTAssertEqual(dashboardStore.snapshot.totalTokens, 100)
        XCTAssertEqual(dashboardStore.snapshot.toolRows.map(\.id), ["codex"])
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
        XCTAssertEqual(dashboardStore.panelSummary.eventCount, 2)
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

        let scopedDashboardTotals = store.allPeriodInputScopeTotals(now: now, calendar: calendar)
        XCTAssertEqual(scopedDashboardTotals[.today]?.includeCache, 120)
        XCTAssertEqual(scopedDashboardTotals[.today]?.freshOnly, 20)
        XCTAssertEqual(scopedDashboardTotals[.sevenDays]?.freshOnly, 50)
        XCTAssertEqual(scopedDashboardTotals[.thirtyDays]?.freshOnly, 90)
        XCTAssertEqual(scopedDashboardTotals[.all]?.freshOnly, 140)

        let visibleToolTotals = store.allPeriodTotalTokens(
            now: now,
            calendar: calendar,
            visibleTools: [.codex]
        )
        XCTAssertEqual(visibleToolTotals[.today], 120)
        XCTAssertEqual(visibleToolTotals[.sevenDays], 120)
        XCTAssertEqual(visibleToolTotals[.thirtyDays], 120)
        XCTAssertEqual(visibleToolTotals[.all], 570)

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

    func testInputAccountingTotalsMatchesPerEventSwiftAggregation() throws {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        // Full accounting present: 40 uncached + 20 cache-creation + 30 cache-read = 90
        // measured, leaving max(0, 100 - 90) = 10 unclassified.
        try store.appendEvent(Self.safeEvent(
            aiTool: .codex,
            spanID: "span_accounting_codex",
            inputTokens: 100,
            outputTokens: 50,
            tokenAccounting: TokenUsageAccounting(
                uncachedInputTokens: 40,
                cacheCreationInputTokens: 20,
                cacheReadInputTokens: 30,
                reasoningOutputTokens: 5
            )
        ))
        // No accounting at all: the full 200 input tokens fall back to unclassified,
        // exactly like an event with tokenAccounting == nil in the Swift-side reducer.
        try store.appendEvent(Self.safeEvent(
            aiTool: .claude,
            spanID: "span_accounting_claude",
            inputTokens: 200,
            outputTokens: 80,
            tokenAccounting: nil
        ))
        // Zero input tokens: excluded entirely (matches the `inputTokens > 0` guard).
        try store.appendEvent(Self.safeEvent(
            aiTool: .codex,
            spanID: "span_accounting_zero_input",
            inputTokens: 0,
            outputTokens: 50,
            tokenAccounting: nil
        ))
        // Non-dashboard tool: excluded when dashboardToolsOnly is true.
        try store.appendEvent(Self.safeEvent(
            aiTool: .openAI,
            spanID: "span_accounting_openai",
            inputTokens: 700,
            outputTokens: 200,
            tokenAccounting: nil
        ))

        let totals = store.inputAccountingTotals()
        XCTAssertEqual(totals["uncached_input"], 40)
        XCTAssertEqual(totals["cache_creation_input"], 20)
        XCTAssertEqual(totals["cache_read_input"], 30)
        XCTAssertEqual(totals["unclassified_input"], 210)

        let fullTotals = store.inputAccountingTotals(dashboardToolsOnly: false)
        XCTAssertEqual(fullTotals["unclassified_input"], 910)
    }

    func testGroupedProjectTotalsMatchesPerEventSwiftAggregation() throws {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        try store.appendEvent(Self.safeEvent(
            aiTool: .codex,
            spanID: "span_project_a_1",
            inputTokens: 100,
            outputTokens: 50,
            projectID: "project_alpha"
        ))
        try store.appendEvent(Self.safeEvent(
            aiTool: .claude,
            spanID: "span_project_a_2",
            inputTokens: 200,
            outputTokens: 80,
            projectID: "project_alpha"
        ))
        try store.appendEvent(Self.safeEvent(
            aiTool: .codex,
            spanID: "span_project_b_1",
            inputTokens: 40,
            outputTokens: 10,
            projectID: "project_beta"
        ))
        // Non-dashboard tool: excluded when dashboardToolsOnly is true.
        try store.appendEvent(Self.safeEvent(
            aiTool: .openAI,
            spanID: "span_project_a_openai",
            inputTokens: 700,
            outputTokens: 200,
            projectID: "project_alpha"
        ))

        let totals = store.groupedProjectTotals()
        XCTAssertEqual(totals["project_alpha"]?.eventCount, 2)
        XCTAssertEqual(totals["project_alpha"]?.totals.includeCache, 430)
        XCTAssertEqual(totals["project_beta"]?.eventCount, 1)
        XCTAssertEqual(totals["project_beta"]?.totals.includeCache, 50)

        let fullTotals = store.groupedProjectTotals(dashboardToolsOnly: false)
        XCTAssertEqual(fullTotals["project_alpha"]?.eventCount, 3)
        XCTAssertEqual(fullTotals["project_alpha"]?.totals.includeCache, 1_330)
    }

    func testSQLSourcedSessionRowsMatchExistingEventBasedAggregation() throws {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let calendar = Calendar.autoupdatingCurrent
        let now = Date()

        try store.appendEvent(Self.safeEvent(
            aiTool: .codex,
            runID: "run_alpha_1",
            spanID: "span_alpha_1a",
            inputTokens: 100,
            outputTokens: 50,
            tokenAccounting: TokenUsageAccounting(uncachedInputTokens: 30),
            projectID: "project_alpha",
            taskType: .debugging,
            stage: .implement,
            latencyMS: 40,
            createdAt: "2026-07-10T12:00:00Z"
        ))
        // Same work item (project + taskType + stage + day), different run: should merge into
        // one session row with spanCount 2 and runCount 2.
        try store.appendEvent(Self.safeEvent(
            aiTool: .codex,
            runID: "run_alpha_2",
            spanID: "span_alpha_1b",
            inputTokens: 60,
            outputTokens: 20,
            tokenAccounting: nil,
            projectID: "project_alpha",
            taskType: .debugging,
            stage: .implement,
            latencyMS: 15,
            createdAt: "2026-07-10T13:00:00Z"
        ))
        // Same project/task/stage but a different day: must be a separate work item.
        try store.appendEvent(Self.safeEvent(
            aiTool: .codex,
            runID: "run_alpha_3",
            spanID: "span_alpha_2",
            inputTokens: 200,
            outputTokens: 90,
            tokenAccounting: TokenUsageAccounting(uncachedInputTokens: 190),
            projectID: "project_alpha",
            taskType: .debugging,
            stage: .implement,
            latencyMS: 25,
            createdAt: "2026-07-11T12:00:00Z"
        ))
        // Different project and task/stage entirely.
        try store.appendEvent(Self.safeEvent(
            aiTool: .claude,
            runID: "run_beta_1",
            spanID: "span_beta_1",
            inputTokens: 500,
            outputTokens: 150,
            tokenAccounting: nil,
            projectID: "project_beta",
            taskType: .codeReview,
            stage: .verify,
            latencyMS: 60,
            createdAt: "2026-07-12T12:00:00Z"
        ))

        let events = store.loadEvents(startingAt: nil, endingBefore: nil)
        let parsedEvents = events.map { TokenUsageDashboardParsedEvent(event: $0, calendar: calendar) }

        for inputScope: TokenUsageInputScope in [.includeCache, .freshOnly] {
            let expected = TokenUsageDashboardSnapshot.sessionRows(
                events: parsedEvents,
                inputScope: inputScope,
                language: .english,
                localAliases: [:],
                calendar: calendar,
                now: now,
                locale: .autoupdatingCurrent,
                timeZone: .autoupdatingCurrent
            )

            let sourceRows = store.sessionSourceRows(calendar: calendar)
            let actual = TokenUsageDashboardSnapshot.sessionRows(
                sourceRows: sourceRows,
                inputScope: inputScope,
                language: .english,
                localAliases: [:],
                calendar: calendar,
                now: now,
                locale: .autoupdatingCurrent,
                timeZone: .autoupdatingCurrent
            )

            XCTAssertEqual(actual, expected, "mismatch for inputScope \(inputScope)")
        }

        XCTAssertEqual(parsedEvents.count, 4)
        let sourceRows = store.sessionSourceRows(calendar: calendar)
        XCTAssertEqual(sourceRows.count, 4)

        let rows = TokenUsageDashboardSnapshot.sessionRows(
            sourceRows: sourceRows,
            inputScope: .includeCache,
            language: .english,
            localAliases: [:],
            calendar: calendar,
            now: now,
            locale: .autoupdatingCurrent,
            timeZone: .autoupdatingCurrent
        )
        // 4 events collapse into 3 work items: two alpha/debugging/implement events on the
        // same day merge, the next day's alpha/debugging/implement event stays separate, and
        // the beta/code_review/verify event is its own row.
        XCTAssertEqual(rows.count, 3)
        let mergedRow = try XCTUnwrap(rows.first { $0.eventCount == 2 })
        XCTAssertEqual(mergedRow.projectID, "project_alpha")
        XCTAssertEqual(mergedRow.value, TokenUsageDashboardSnapshot.formatTokens(230))

        // Project/tool filters passed to the SQL layer must narrow results the same way the
        // in-memory events array would if it had already been filtered by them.
        let alphaOnly = store.sessionSourceRows(projectID: "project_alpha", calendar: calendar)
        XCTAssertEqual(alphaOnly.count, 3)
        let codexOnly = store.sessionSourceRows(selectedTool: .codex, calendar: calendar)
        XCTAssertEqual(codexOnly.count, 3)
    }

    func testComparisonTokenTotalReturnsNilForEmptyRangeNotZero() throws {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        try store.appendEvent(Self.safeEvent(
            aiTool: .codex,
            spanID: "span_comparison_1",
            inputTokens: 100,
            outputTokens: 50,
            tokenAccounting: TokenUsageAccounting(uncachedInputTokens: 40),
            createdAt: "2026-07-10T12:00:00Z"
        ))
        let dayStart = try XCTUnwrap(ISO8601DateFormatter.parseTokenUsageDate(from: "2026-07-10T00:00:00Z"))
        let dayEnd = try XCTUnwrap(ISO8601DateFormatter.parseTokenUsageDate(from: "2026-07-11T00:00:00Z"))
        let emptyDayStart = try XCTUnwrap(ISO8601DateFormatter.parseTokenUsageDate(from: "2026-07-01T00:00:00Z"))
        let emptyDayEnd = try XCTUnwrap(ISO8601DateFormatter.parseTokenUsageDate(from: "2026-07-02T00:00:00Z"))

        XCTAssertEqual(
            store.comparisonTokenTotal(startingAt: dayStart, endingBefore: dayEnd),
            150
        )
        XCTAssertEqual(
            store.comparisonTokenTotal(startingAt: dayStart, endingBefore: dayEnd, inputScope: .freshOnly),
            90
        )
        // A range with no events must read as "no comparison data" (nil), not a real zero total.
        XCTAssertNil(store.comparisonTokenTotal(startingAt: emptyDayStart, endingBefore: emptyDayEnd))
    }

    func testGroupedTaskTypeAndStageTotalsMatchPerEventSwiftAggregation() throws {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        try store.appendEvent(Self.safeEvent(
            aiTool: .codex,
            spanID: "span_task_1",
            inputTokens: 100,
            outputTokens: 50,
            taskType: .debugging,
            stage: .implement
        ))
        try store.appendEvent(Self.safeEvent(
            aiTool: .claude,
            spanID: "span_task_2",
            inputTokens: 60,
            outputTokens: 20,
            taskType: .debugging,
            stage: .verify
        ))
        try store.appendEvent(Self.safeEvent(
            aiTool: .codex,
            spanID: "span_task_3",
            inputTokens: 40,
            outputTokens: 10,
            taskType: .codeReview,
            stage: .implement
        ))

        let taskTotals = store.groupedTaskTypeTotals()
        XCTAssertEqual(taskTotals["debugging"], 230)
        XCTAssertEqual(taskTotals["code_review"], 50)

        let stageTotals = store.groupedStageTotals()
        XCTAssertEqual(stageTotals["implement"], 200)
        XCTAssertEqual(stageTotals["verify"], 80)
    }

    func testGroupedModelTotalsMatchesModelKeyNormalization() throws {
        // TokenUsageEvent.validate() requires model to match ^[A-Za-z0-9_.:-]{2,80}$, so an
        // empty or whitespace-padded model can never actually reach the database -- this only
        // exercises the reachable equivalence class: real model IDs that happen to spell one of
        // modelKey's recognized "unknown" placeholders, in any case.
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        try store.appendEvent(Self.safeEvent(
            aiTool: .codex,
            spanID: "span_model_1",
            inputTokens: 100,
            outputTokens: 50,
            model: "Claude-Sonnet-5"
        ))
        // Same key as above: must merge into one total.
        try store.appendEvent(Self.safeEvent(
            aiTool: .codex,
            spanID: "span_model_2",
            inputTokens: 40,
            outputTokens: 10,
            model: "Claude-Sonnet-5"
        ))
        // Known "unknown" spellings, in any case, all collapse into model_unavailable.
        try store.appendEvent(Self.safeEvent(
            aiTool: .claude,
            spanID: "span_model_4",
            inputTokens: 20,
            outputTokens: 10,
            model: "UNKNOWN"
        ))
        try store.appendEvent(Self.safeEvent(
            aiTool: .claude,
            spanID: "span_model_5",
            inputTokens: 15,
            outputTokens: 5,
            model: "model_unknown"
        ))

        let events = store.loadEvents(startingAt: nil, endingBefore: nil)
        let expected = TokenUsageDashboardSnapshot.tokenTotals(
            events: events.map { TokenUsageDashboardParsedEvent(event: $0, calendar: .autoupdatingCurrent) },
            inputScope: .includeCache
        ) { TokenUsageDashboardSnapshot.modelKey($0.event.model) }

        let actual = store.groupedModelTotals()
        XCTAssertEqual(actual["Claude-Sonnet-5"], expected["Claude-Sonnet-5"])
        XCTAssertEqual(actual["Claude-Sonnet-5"], 200)
        XCTAssertEqual(actual["model_unavailable"], expected["model_unavailable"])
        XCTAssertEqual(actual["model_unavailable"], 50)
        XCTAssertNil(actual["unknown"])
        XCTAssertNil(actual["UNKNOWN"])
    }

    func testGroupedInputScopeTotalsMatchPerEventSwiftAggregationForBothScopes() throws {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        try store.appendEvent(Self.safeEvent(
            aiTool: .codex,
            spanID: "span_scope_group_1",
            inputTokens: 100,
            outputTokens: 50,
            tokenAccounting: TokenUsageAccounting(uncachedInputTokens: 40),
            taskType: .debugging,
            stage: .implement,
            model: "Claude-Sonnet-5"
        ))
        try store.appendEvent(Self.safeEvent(
            aiTool: .claude,
            spanID: "span_scope_group_2",
            inputTokens: 60,
            outputTokens: 20,
            tokenAccounting: nil,
            taskType: .debugging,
            stage: .verify,
            model: "gpt-5"
        ))
        try store.appendEvent(Self.safeEvent(
            aiTool: .codex,
            spanID: "span_scope_group_3",
            inputTokens: 40,
            outputTokens: 10,
            tokenAccounting: TokenUsageAccounting(uncachedInputTokens: 35),
            taskType: .codeReview,
            stage: .implement,
            model: "Claude-Sonnet-5"
        ))

        let events = store.loadEvents(startingAt: nil, endingBefore: nil)
        let parsedEvents = events.map { TokenUsageDashboardParsedEvent(event: $0, calendar: .autoupdatingCurrent) }

        func expectedTotals<Key: Hashable>(_ key: (TokenUsageDashboardParsedEvent) -> Key) -> [Key: TokenUsageInputScopeTotals] {
            var result = [Key: TokenUsageInputScopeTotals]()
            for scope: TokenUsageInputScope in [.includeCache, .freshOnly] {
                let totals = TokenUsageDashboardSnapshot.tokenTotals(events: parsedEvents, inputScope: scope, by: key)
                for (k, v) in totals {
                    var existing = result[k] ?? .zero
                    existing = TokenUsageInputScopeTotals(
                        includeCache: scope == .includeCache ? v : existing.includeCache,
                        freshOnly: scope == .freshOnly ? v : existing.freshOnly
                    )
                    result[k] = existing
                }
            }
            return result
        }

        let expectedToolTotals = expectedTotals { $0.event.aiTool }
        let actualToolTotals = store.groupedInputScopeTotalsByTool()
        for (tool, expected) in expectedToolTotals {
            XCTAssertEqual(actualToolTotals[tool], expected, "tool \(tool)")
        }
        XCTAssertEqual(actualToolTotals[.codex]?.includeCache, 200)
        XCTAssertEqual(actualToolTotals[.codex]?.freshOnly, 135)

        let expectedTaskTotals = expectedTotals { $0.event.taskType.rawValue }
        let actualTaskTotals = store.groupedTaskTypeInputScopeTotals()
        for (task, expected) in expectedTaskTotals {
            XCTAssertEqual(actualTaskTotals[task], expected, "task \(task)")
        }

        let expectedStageTotals = expectedTotals { $0.event.stage.rawValue }
        let actualStageTotals = store.groupedStageInputScopeTotals()
        for (stage, expected) in expectedStageTotals {
            XCTAssertEqual(actualStageTotals[stage], expected, "stage \(stage)")
        }

        let expectedModelTotals = expectedTotals { TokenUsageDashboardSnapshot.modelKey($0.event.model) }
        let actualModelTotals = store.groupedModelInputScopeTotals()
        for (model, expected) in expectedModelTotals {
            XCTAssertEqual(actualModelTotals[model], expected, "model \(model)")
        }
    }

    func testSQLSourcedTrendBucketsMatchExistingEventBasedAggregation() throws {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let calendar = Calendar.autoupdatingCurrent
        let now = Date()
        let today = ISO8601DateFormatter.tokenUsage.string(from: now)
        let yesterday = ISO8601DateFormatter.tokenUsage.string(
            from: calendar.date(byAdding: .day, value: -1, to: now) ?? now
        )

        try store.appendEvent(Self.safeEvent(
            aiTool: .codex,
            spanID: "span_trend_today_codex",
            inputTokens: 100,
            outputTokens: 50,
            tokenAccounting: TokenUsageAccounting(uncachedInputTokens: 30),
            createdAt: today
        ))
        try store.appendEvent(Self.safeEvent(
            aiTool: .claude,
            spanID: "span_trend_today_claude",
            inputTokens: 60,
            outputTokens: 20,
            createdAt: today
        ))
        try store.appendEvent(Self.safeEvent(
            aiTool: .codex,
            spanID: "span_trend_yesterday",
            inputTokens: 40,
            outputTokens: 10,
            createdAt: yesterday
        ))
        // A different month entirely: only relevant to the .all (monthly) bucketing case.
        try store.appendEvent(Self.safeEvent(
            aiTool: .codex,
            spanID: "span_trend_old_month",
            inputTokens: 200,
            outputTokens: 80,
            tokenAccounting: TokenUsageAccounting(uncachedInputTokens: 190),
            createdAt: "2026-01-15T12:00:00Z"
        ))

        let events = store.loadEvents(startingAt: nil, endingBefore: nil)
        let parsedEvents = events.map { TokenUsageDashboardParsedEvent(event: $0, calendar: calendar) }
        let sourceRows = store.trendSourceRows(calendar: calendar)
        XCTAssertEqual(sourceRows.count, parsedEvents.count)

        for period: TokenUsageDashboardPeriod in [.sevenDays, .thirtyDays, .all] {
            for inputScope: TokenUsageInputScope in [.includeCache, .freshOnly] {
                let expected = TokenUsageDashboardTrendBucketBuilder.buckets(
                    events: parsedEvents,
                    selectedPeriod: period,
                    language: .english,
                    now: now,
                    calendar: calendar,
                    locale: .autoupdatingCurrent,
                    timeZone: .autoupdatingCurrent,
                    inputScope: inputScope
                )
                let actual = TokenUsageDashboardTrendBucketBuilder.buckets(
                    sourceRows: sourceRows,
                    selectedPeriod: period,
                    language: .english,
                    now: now,
                    calendar: calendar,
                    locale: .autoupdatingCurrent,
                    timeZone: .autoupdatingCurrent,
                    inputScope: inputScope
                )
                XCTAssertEqual(actual, expected, "mismatch for period \(period), inputScope \(inputScope)")
            }
        }

        let sevenDayBuckets = TokenUsageDashboardTrendBucketBuilder.buckets(
            sourceRows: sourceRows,
            selectedPeriod: .sevenDays,
            language: .english,
            now: now,
            calendar: calendar,
            locale: .autoupdatingCurrent,
            timeZone: .autoupdatingCurrent
        )
        XCTAssertEqual(sevenDayBuckets.count, 7)
        let todayBucket = try XCTUnwrap(sevenDayBuckets.last)
        XCTAssertEqual(todayBucket.eventCount, 2)
        XCTAssertEqual(todayBucket.totalTokens, 230)
        XCTAssertEqual(todayBucket.toolRows.count, 2)

        let monthlyBuckets = TokenUsageDashboardTrendBucketBuilder.buckets(
            sourceRows: sourceRows,
            selectedPeriod: .all,
            language: .english,
            now: now,
            calendar: calendar,
            locale: .autoupdatingCurrent,
            timeZone: .autoupdatingCurrent
        )
        XCTAssertTrue(monthlyBuckets.count >= 2)
        XCTAssertEqual(monthlyBuckets.reduce(0) { $0 + $1.eventCount }, 4)
    }

    func testDashboardFocusedTotalsAndLastUpdatedByToolMatchPerEventSwiftAggregation() throws {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        // Assisted: taskType != .uncategorized (debugging here), so isAssisted is true
        // regardless of stage.
        try store.appendEvent(Self.safeEvent(
            aiTool: .codex,
            spanID: "span_focused_1",
            inputTokens: 100,
            outputTokens: 50,
            taskType: .debugging,
            stage: .summarize,
            createdAt: "2026-07-10T12:00:00Z"
        ))
        // Not assisted: uncategorized task AND summarize stage.
        try store.appendEvent(Self.safeEvent(
            aiTool: .claude,
            spanID: "span_focused_2",
            inputTokens: 60,
            outputTokens: 20,
            tokenAccounting: TokenUsageAccounting(uncachedInputTokens: 50),
            taskType: .uncategorized,
            stage: .summarize,
            createdAt: "2026-07-12T09:00:00Z"
        ))
        // Assisted: stage != .summarize.
        try store.appendEvent(Self.safeEvent(
            aiTool: .codex,
            spanID: "span_focused_3",
            inputTokens: 40,
            outputTokens: 10,
            taskType: .uncategorized,
            stage: .implement,
            createdAt: "2026-07-11T15:00:00Z"
        ))

        let totals = store.dashboardFocusedTotals()
        XCTAssertEqual(totals.eventCount, 3)
        XCTAssertEqual(totals.totalTokens, 280)
        XCTAssertEqual(totals.inputTokens, 200)
        XCTAssertEqual(totals.outputTokens, 80)
        // Assisted rows are span_focused_1 (100+50) and span_focused_3 (40+10).
        XCTAssertEqual(totals.assistedEventCount, 2)
        XCTAssertEqual(totals.assistedTotalTokens, 200)

        let lastUpdated = store.lastUpdatedByTool()
        XCTAssertEqual(
            lastUpdated[.codex],
            ISO8601DateFormatter.parseTokenUsageDate(from: "2026-07-11T15:00:00Z")
        )
        XCTAssertEqual(
            lastUpdated[.claude],
            ISO8601DateFormatter.parseTokenUsageDate(from: "2026-07-12T09:00:00Z")
        )
    }

    func testSQLOnlySnapshotFactoryMatchesExistingEventBasedSnapshot() throws {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let calendar = Calendar.autoupdatingCurrent
        let now = Date()
        let today = ISO8601DateFormatter.tokenUsage.string(from: now)
        let yesterday = ISO8601DateFormatter.tokenUsage.string(
            from: calendar.date(byAdding: .day, value: -1, to: now) ?? now
        )

        try store.appendEvent(Self.safeEvent(
            aiTool: .codex,
            spanID: "span_full_1",
            inputTokens: 100,
            outputTokens: 50,
            tokenAccounting: TokenUsageAccounting(uncachedInputTokens: 40, cacheCreationInputTokens: 10, cacheReadInputTokens: 20),
            projectID: "project_alpha",
            taskType: .debugging,
            stage: .implement,
            model: "Claude-Sonnet-5",
            latencyMS: 30,
            createdAt: today
        ))
        try store.appendEvent(Self.safeEvent(
            aiTool: .claude,
            spanID: "span_full_2",
            inputTokens: 60,
            outputTokens: 20,
            tokenAccounting: nil,
            projectID: "project_alpha",
            taskType: .uncategorized,
            stage: .summarize,
            model: "gpt-5",
            latencyMS: 12,
            createdAt: today
        ))
        try store.appendEvent(Self.safeEvent(
            aiTool: .codex,
            spanID: "span_full_3",
            inputTokens: 40,
            outputTokens: 10,
            tokenAccounting: TokenUsageAccounting(uncachedInputTokens: 35),
            projectID: "project_beta",
            taskType: .codeReview,
            stage: .verify,
            model: "Claude-Sonnet-5",
            latencyMS: 8,
            createdAt: yesterday
        ))
        try store.appendEvent(Self.safeEvent(
            aiTool: .codex,
            spanID: "span_full_old_month",
            inputTokens: 200,
            outputTokens: 80,
            tokenAccounting: TokenUsageAccounting(uncachedInputTokens: 190),
            projectID: "project_alpha",
            taskType: .debugging,
            stage: .implement,
            model: "Claude-Sonnet-5",
            latencyMS: 50,
            createdAt: "2026-01-15T12:00:00Z"
        ))

        let events = store.loadEvents(startingAt: nil, endingBefore: nil)
        let dateBounds = store.dashboardDateBounds()
        let periodFilterTotals = store.allPeriodInputScopeTotals(now: now, calendar: calendar)
        let calendarMonth = TokenUsageDashboardSnapshot.normalizedCalendarMonthStart(
            availableDateBounds: dateBounds,
            now: now,
            proposedMonthStart: nil,
            calendar: calendar
        )
        let calendarDayInputScopeTotals = store.dashboardDayInputScopeTotals(
            startingAt: calendarMonth,
            endingBefore: calendar.date(byAdding: .month, value: 1, to: calendarMonth) ?? calendarMonth,
            calendar: calendar
        )

        for period: TokenUsageDashboardPeriod in [.today, .sevenDays, .thirtyDays, .all] {
            for selectedTool: TokenUsageAITool? in [nil, .codex] {
                for inputScope: TokenUsageInputScope in [.includeCache, .freshOnly] {
                let expectedPair = TokenUsageDashboardSnapshot.buildPair(
                    events: events,
                    selectedTool: selectedTool,
                    selectedPeriod: period,
                    selectedCalendarDayID: nil,
                    selectedProjectID: nil,
                    selectedSessionID: nil,
                    language: .english,
                    localAliases: [:],
                    showAdvancedTools: false,
                    now: now,
                    proposedCalendarMonthStart: nil,
                    calendar: calendar,
                    periodFilterTotals: periodFilterTotals,
                    availableDateBounds: dateBounds,
                    calendarDayTotals: calendarDayInputScopeTotals,
                    inputScope: inputScope,
                    locale: .autoupdatingCurrent,
                    timeZone: .autoupdatingCurrent
                )

                let actual = try XCTUnwrap(TokenUsageDashboardSnapshot.buildFromSQLAggregates(
                    usageStore: store,
                    selectedTool: selectedTool,
                    selectedPeriod: period,
                    inputScope: inputScope,
                    language: .english,
                    localAliases: [:],
                    showAdvancedTools: false,
                    now: now,
                    calendar: calendar,
                    locale: .autoupdatingCurrent,
                    timeZone: .autoupdatingCurrent
                ))

                let expected = expectedPair.filtered
                let label = "period \(period), selectedTool \(String(describing: selectedTool)), inputScope \(inputScope)"
                XCTAssertEqual(actual.eventCount, expected.eventCount, "eventCount \(label)")
                XCTAssertEqual(actual.totalTokens, expected.totalTokens, "totalTokens \(label)")
                XCTAssertEqual(actual.kpis, expected.kpis, "kpis \(label)")
                XCTAssertEqual(actual.periodFilters, expected.periodFilters, "periodFilters \(label)")
                XCTAssertEqual(actual.toolFilters, expected.toolFilters, "toolFilters \(label)")
                XCTAssertEqual(actual.projectFilters, expected.projectFilters, "projectFilters \(label)")
                XCTAssertEqual(actual.toolRows, expected.toolRows, "toolRows \(label)")
                XCTAssertEqual(actual.modelRows, expected.modelRows, "modelRows \(label)")
                XCTAssertEqual(actual.workflowUsage, expected.workflowUsage, "workflowUsage \(label)")
                XCTAssertEqual(actual.inputAccounting, expected.inputAccounting, "inputAccounting \(label)")
                XCTAssertEqual(actual.taskRows, expected.taskRows, "taskRows \(label)")
                XCTAssertEqual(actual.stageRows, expected.stageRows, "stageRows \(label)")
                XCTAssertEqual(actual.sourceRows, expected.sourceRows, "sourceRows \(label)")
                XCTAssertEqual(actual.sessions, expected.sessions, "sessions \(label)")
                XCTAssertEqual(actual.trendBuckets, expected.trendBuckets, "trendBuckets \(label)")
                XCTAssertEqual(actual.calendarDays, expected.calendarDays, "calendarDays \(label)")
                XCTAssertEqual(actual.calendarMonthTitle, expected.calendarMonthTitle, "calendarMonthTitle \(label)")
                XCTAssertEqual(actual.canNavigatePreviousCalendarMonth, expected.canNavigatePreviousCalendarMonth, "canNavPrevMonth \(label)")
                XCTAssertEqual(actual.canNavigateNextCalendarMonth, expected.canNavigateNextCalendarMonth, "canNavNextMonth \(label)")
                XCTAssertEqual(actual.codexLastUpdatedString, expected.codexLastUpdatedString, "codexLastUpdated \(label)")
                XCTAssertEqual(actual.claudeLastUpdatedString, expected.claudeLastUpdatedString, "claudeLastUpdated \(label)")
                XCTAssertEqual(actual.antigravityLastUpdatedString, expected.antigravityLastUpdatedString, "antigravityLastUpdated \(label)")
                XCTAssertEqual(actual.overallLastUpdatedString, expected.overallLastUpdatedString, "overallLastUpdated \(label)")
                XCTAssertEqual(actual.comparisonTotalTokens, expected.comparisonTotalTokens, "comparisonTotalTokens \(label)")
                XCTAssertEqual(actual.canNavigatePreviousPeriod, expected.canNavigatePreviousPeriod, "canNavPrevPeriod \(label)")
                XCTAssertEqual(actual.canNavigateNextPeriod, expected.canNavigateNextPeriod, "canNavNextPeriod \(label)")
                // Full-struct check as a safety net for any field not enumerated above.
                XCTAssertEqual(actual, expected, "full snapshot \(label)")
                }
            }
        }
    }

    /// A raw connection to a fresh, schema-less database makes every statement in the batch fail
    /// with "no such table". The failure observer must catch that and force buildFromSQLAggregates
    /// to fail closed (nil), rather than publishing the silently-defaulted all-zero snapshot.
    func testSQLSnapshotFactoryFailsClosedOnStatementLevelFailure() throws {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        try store.appendEvent(Self.safeEvent(aiTool: .codex, spanID: "span_fail_closed_1"))
        let now = Date()
        let calendar = Calendar.autoupdatingCurrent

        // A healthy build over the real store returns a non-nil snapshot.
        XCTAssertNotNil(TokenUsageDashboardSnapshot.buildFromSQLAggregates(
            usageStore: store,
            now: now,
            calendar: calendar
        ))

        let emptyDatabaseURL = temporaryDirectoryURL().appendingPathComponent("empty.sqlite3")
        try FileManager.default.createDirectory(
            at: emptyDatabaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var rawConnection: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE
        XCTAssertEqual(sqlite3_open_v2(emptyDatabaseURL.path, &rawConnection, flags, nil), SQLITE_OK)
        let connection = try XCTUnwrap(rawConnection)
        defer { sqlite3_close(connection) }

        XCTAssertNil(TokenUsageDashboardSnapshot.buildFromSQLAggregates(
            usageStore: store,
            now: now,
            calendar: calendar,
            database: connection
        ))
    }

    /// Focused check of the observer wiring on one representative wrapper: a schema-less connection
    /// marks the observer and yields the empty default; the store's own healthy connection does not.
    func testGroupedInputScopeTotalsByToolMarksFailureObserver() throws {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        try store.appendEvent(Self.safeEvent(aiTool: .codex, spanID: "span_observer_wiring_1"))

        let emptyDatabaseURL = temporaryDirectoryURL().appendingPathComponent("empty.sqlite3")
        try FileManager.default.createDirectory(
            at: emptyDatabaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var rawConnection: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE
        XCTAssertEqual(sqlite3_open_v2(emptyDatabaseURL.path, &rawConnection, flags, nil), SQLITE_OK)
        let connection = try XCTUnwrap(rawConnection)
        defer { sqlite3_close(connection) }

        let failingObserver = TokenUsageQueryFailureObserver()
        let failingResult = store.groupedInputScopeTotalsByTool(
            database: connection,
            failureObserver: failingObserver
        )
        XCTAssertTrue(failingObserver.didFail)
        XCTAssertTrue(failingResult.isEmpty)

        let healthyObserver = TokenUsageQueryFailureObserver()
        let healthyResult = store.groupedInputScopeTotalsByTool(
            database: nil,
            failureObserver: healthyObserver
        )
        XCTAssertFalse(healthyObserver.didFail)
        XCTAssertFalse(healthyResult.isEmpty)
    }

    /// Passing the store's own pre-opened connection+transaction must produce the same snapshot as
    /// letting buildFromSQLAggregates open its own -- the shared-connection path is purely about
    /// read consistency, never about changing the result.
    func testSQLSnapshotFactoryWithStoreOwnedConnectionMatchesPlainCall() throws {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        try store.appendEvent(Self.safeEvent(aiTool: .codex, spanID: "span_shared_conn_1", inputTokens: 100, outputTokens: 50))
        try store.appendEvent(Self.safeEvent(aiTool: .claude, spanID: "span_shared_conn_2", inputTokens: 60, outputTokens: 20))
        let now = Date()
        let calendar = Calendar.autoupdatingCurrent

        let plain = try XCTUnwrap(TokenUsageDashboardSnapshot.buildFromSQLAggregates(
            usageStore: store,
            now: now,
            calendar: calendar
        ))

        let viaConnection = store.withDatabaseConnection(nil, default: nil as TokenUsageDashboardSnapshot?) { database in
            TokenUsageDashboardSnapshot.buildFromSQLAggregates(
                usageStore: store,
                now: now,
                calendar: calendar,
                database: database
            )
        }
        XCTAssertEqual(viaConnection, plain)
    }

    func testSQLSnapshotFactoryUsesPreloadedPeriodFilterTotals() throws {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        try store.appendEvent(Self.safeEvent(inputTokens: 400, outputTokens: 100))
        let preloaded: [TokenUsageDashboardPeriod: TokenUsageInputScopeTotals] = [
            .today: .init(includeCache: 101, freshOnly: 11),
            .sevenDays: .init(includeCache: 202, freshOnly: 22),
            .thirtyDays: .init(includeCache: 303, freshOnly: 33),
            .all: .init(includeCache: 404, freshOnly: 44)
        ]

        let snapshot = try XCTUnwrap(TokenUsageDashboardSnapshot.buildFromSQLAggregates(
            usageStore: store,
            selectedPeriod: .today,
            inputScope: .includeCache,
            preloadedPeriodFilterTotals: preloaded
        ))

        XCTAssertEqual(
            snapshot.periodFilters.map { $0.detail },
            ["101", "202", "303", "404"]
        )
    }

    func testSQLSnapshotBuildLoadsAllPeriodTotalsOnceForSharedSnapshotPair() throws {
        let snapshotBuild = try Self.source(named: "TokenUsageDashboardStore+SQLSnapshotBuild.swift")
        let snapshotFactory = try Self.source(named: "TokenUsageDashboardSnapshot+SQLFactory.swift")

        XCTAssertEqual(
            snapshotBuild.components(separatedBy: "usageStore.allPeriodInputScopeTotals(").count - 1,
            1
        )
        XCTAssertTrue(snapshotFactory.contains("preloadedPeriodFilterTotals"))
    }

    /// Fix 1 regression: a transient SQL-build failure must not leave isRefreshing stuck true.
    /// The store points at an unopenable database (a regular file occupies the directory path its
    /// database file needs), so every open fails and the SQL build returns nil. The refresh must
    /// still settle back to "not refreshing" instead of permanently disabling refreshAsyncIfIdle.
    @MainActor
    func testDashboardStoreRestoresRefreshingAfterFailedSQLBuild() async throws {
        let baseDirectory = temporaryDirectoryURL()
        try FileManager.default.createDirectory(
            at: baseDirectory.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        // Occupy the would-be token-metering directory path with a regular file so
        // createPrivateDirectoryIfNeeded -- and therefore every openDatabase -- throws.
        XCTAssertTrue(FileManager.default.createFile(atPath: baseDirectory.path, contents: Data()))
        let usageStore = TokenUsageStore(fileURL: baseDirectory.appendingPathComponent("events.json"))

        let store = TokenUsageDashboardStore(usageStore: usageStore, loadsInitialPanelSummary: false)
        store.refreshAsync()

        var settled = false
        for _ in 0..<60 {
            if !store.isDashboardRefreshInProgress {
                settled = true
                break
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertTrue(settled, "isRefreshing must return to false after a failed SQL build")
    }

    /// A transient FIRST load failure resets `loadState` to `.idle`, but the
    /// dashboard surface that requested it still exists. Once the database
    /// recovers, a store-change notification must retry the full snapshot —
    /// not stay downgraded to panel-summary-only until the user taps refresh.
    @MainActor
    func testChangeNotificationRetriesFullSnapshotAfterFailedFirstLoad() async throws {
        let baseDirectory = temporaryDirectoryURL()
        try FileManager.default.createDirectory(
            at: baseDirectory.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        // First load fails: a regular file occupies the token-metering directory
        // path, so every openDatabase throws and the SQL build returns nil.
        XCTAssertTrue(FileManager.default.createFile(atPath: baseDirectory.path, contents: Data()))
        let usageStore = TokenUsageStore(fileURL: baseDirectory.appendingPathComponent("events.json"))
        let store = TokenUsageDashboardStore(usageStore: usageStore, loadsInitialPanelSummary: false)

        store.refreshAsync()
        for _ in 0..<60 where store.isDashboardRefreshInProgress {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(store.loadState, .idle)
        XCTAssertEqual(store.snapshot.eventCount, 0)

        // The database recovers and new usage arrives; the resulting change
        // notification must rebuild the full snapshot for the waiting surface.
        try FileManager.default.removeItem(at: baseDirectory)
        try usageStore.appendEvent(Self.safeEvent(spanID: "span_recovers_after_failed_first_load"))

        try await waitForDashboardStoreRefreshToLoadEvents(store, eventCount: 1)
        XCTAssertEqual(store.snapshot.eventCount, 1)
        XCTAssertEqual(store.loadState, .loaded)
    }

    func testPanelSummaryProjectsFreshOnlyHeadlineWithoutChangingWorkflowRows() throws {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        try store.replaceEvents([
            Self.safeEvent(
                aiTool: .codex,
                spanID: "span_panel_fresh_unsplit",
                inputTokens: 60,
                outputTokens: 10
            ),
            Self.safeEvent(
                aiTool: .claude,
                spanID: "span_panel_fresh_split",
                inputTokens: 125,
                outputTokens: 7,
                tokenAccounting: TokenUsageAccounting(
                    uncachedInputTokens: 20,
                    cacheCreationInputTokens: 5,
                    cacheReadInputTokens: 100
                )
            )
        ])

        let summary = store.dashboardSummary()
        let panelSummary = TokenUsagePanelSummarySnapshot(summary: summary, language: .english)

        XCTAssertEqual(summary.totalTokens, 202)
        XCTAssertEqual(summary.exactFreshTotalTokens, 37)
        XCTAssertEqual(panelSummary.usageTotal(for: .includeCache), 202)
        XCTAssertEqual(panelSummary.usageTotal(for: .freshOnly), 37)
        XCTAssertEqual(panelSummary.toolRows.first { $0.id == "codex" }?.value, "70 (34.7%)")
        XCTAssertEqual(panelSummary.toolRows.first { $0.id == "claude" }?.value, "132 (65.3%)")
        XCTAssertEqual(panelSummary.taskRows.first?.value, "202 (100.0%)")
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

        let visibleSummary = store.dashboardSummary(
            startingAt: start,
            endingBefore: end,
            visibleTools: [.codex]
        )
        XCTAssertEqual(visibleSummary.eventCount, 1)
        XCTAssertEqual(visibleSummary.totalTokens, 150)
        XCTAssertEqual(visibleSummary.toolTotals["codex"], 150)
        XCTAssertNil(visibleSummary.toolTotals["claude"])
        XCTAssertNil(visibleSummary.toolTotals["openai"])

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

    func testTokenUsageDateParserHandlesCanonicalAndOffsetTimestamps() throws {
        let formatter = ISO8601DateFormatter.tokenUsage
        let plainFormatter = ISO8601DateFormatter()
        plainFormatter.formatOptions = [.withInternetDateTime]
        let canonical = try XCTUnwrap(ISO8601DateFormatter.parseTokenUsageDate(from: "2026-06-06T12:34:56.789Z"))
        XCTAssertEqual(
            canonical.timeIntervalSince1970,
            try XCTUnwrap(formatter.date(from: "2026-06-06T12:34:56.789Z")).timeIntervalSince1970,
            accuracy: 0.001
        )

        let plain = try XCTUnwrap(ISO8601DateFormatter.parseTokenUsageDate(from: "2026-06-06T12:34:56Z"))
        XCTAssertEqual(
            plain.timeIntervalSince1970,
            try XCTUnwrap(plainFormatter.date(from: "2026-06-06T12:34:56Z")).timeIntervalSince1970,
            accuracy: 0.001
        )

        let positiveOffset = try XCTUnwrap(ISO8601DateFormatter.parseTokenUsageDate(from: "2026-06-06T09:30:00.000+09:00"))
        XCTAssertEqual(
            positiveOffset.timeIntervalSince1970,
            try XCTUnwrap(formatter.date(from: "2026-06-06T00:30:00.000Z")).timeIntervalSince1970,
            accuracy: 0.001
        )

        let negativeOffset = try XCTUnwrap(ISO8601DateFormatter.parseTokenUsageDate(from: "2026-06-05T23:30:00.000-05:00"))
        XCTAssertEqual(
            negativeOffset.timeIntervalSince1970,
            try XCTUnwrap(formatter.date(from: "2026-06-06T04:30:00.000Z")).timeIntervalSince1970,
            accuracy: 0.001
        )
        XCTAssertNil(ISO8601DateFormatter.parseTokenUsageDate(from: "not-a-date"))
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

    func testContentDuplicateBackfillSkipsRowsWithoutTokenColumns() throws {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let databaseURL = store.eventsDatabaseURL

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
                device_id TEXT,
                project_id TEXT,
                artifact_id TEXT,
                run_id TEXT,
                created_at TEXT NOT NULL,
                ai_tool TEXT NOT NULL,
                task_type TEXT,
                stage TEXT,
                model TEXT,
                input_tokens INTEGER,
                output_tokens INTEGER,
                latency_ms INTEGER,
                total_tokens INTEGER NOT NULL,
                payload_json BLOB NOT NULL
            )
            """,
            database: database
        )
        try executeSQLite("PRAGMA user_version = 2", database: database)
        for spanID in ["span_null_tokens_a", "span_null_tokens_b"] {
            try executeSQLite(
                """
                INSERT INTO token_usage_events (
                    span_id,
                    run_id,
                    created_at,
                    ai_tool,
                    total_tokens,
                    payload_json
                ) VALUES (
                    '\(spanID)',
                    'run_null_tokens',
                    '2026-06-05T00:00:00.000Z',
                    'codex',
                    100,
                    X'7B'
                )
                """,
                database: database
            )
        }

        XCTAssertTrue(store.loadEvents().isEmpty)

        let rows = try sqliteRows(
            databaseURL: databaseURL,
            sql: """
            SELECT span_id
            FROM token_usage_events
            ORDER BY span_id
            """,
            columnCount: 1
        )
        XCTAssertEqual(rows, [["span_null_tokens_a"], ["span_null_tokens_b"]])
    }

    func testTimeWindowDuplicateBackfillRemovesSameFormatDuplicatesWithinThirtySeconds() throws {
        // Bug #2: Claude Code writes the same requestId 2-3x to the transcript with
        // slightly different timestamps. All resulting events use span- format.
        // The migration should collapse them into one, keeping the earliest.
        // The widest migration window in the chain (user_version 10) is 300 s (widened
        // from 30 s across several migrations to catch real Bug #2 gaps up to ~90 s
        // observed across the Stop hook / active importer paths), so this fixture places
        // the genuinely distinct turn at 400 s to stay unambiguously outside every window
        // this store reopen will run (this test starts from user_version 4, so every
        // migration from 5 through 10 executes).
        let eventsURL = temporaryEventsURL()
        let store = TokenUsageStore(fileURL: eventsURL)
        let databaseURL = store.eventsDatabaseURL

        let firstWrite = Self.safeEvent(
            aiTool: .claude,
            runID: "run_dupe",
            spanID: "span-first-write",
            inputTokens: 50000,
            outputTokens: 500,
            model: "claude-sonnet-4",
            createdAt: "2026-06-05T00:00:00.000Z"
        )
        let secondWrite = Self.safeEvent(
            aiTool: .claude,
            runID: "run_dupe",
            spanID: "span-second-write",
            inputTokens: 50000,
            outputTokens: 500,
            model: "claude-sonnet-4",
            createdAt: "2026-06-05T00:00:05.000Z"   // 5 s later — Bug #2 duplicate
        )
        let distinctLaterTurn = Self.safeEvent(
            aiTool: .claude,
            runID: "run_dupe",
            spanID: "span-distinct-later",
            inputTokens: 50000,
            outputTokens: 500,
            model: "claude-sonnet-4",
            createdAt: "2026-06-05T00:06:40.000Z"   // 400 s later — genuinely different turn
        )

        try store.replaceEvents([firstWrite, secondWrite, distinctLaterTurn])
        let database = try openSQLiteDatabase(databaseURL)
        try executeSQLite("PRAGMA user_version = 4", database: database)
        sqlite3_close(database)

        let migratedStore = TokenUsageStore(fileURL: eventsURL)
        XCTAssertEqual(
            migratedStore.loadEvents().map(\.spanID).sorted(),
            ["span-distinct-later", "span-first-write"]
        )
    }

    func testReconcileClaudeSessionsDeletesOnlyStaleSpansForRescannedRuns() throws {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let staleDuplicate = Self.safeEvent(
            aiTool: .claude,
            runID: "run_aaa",
            spanID: "span-old-formula-duplicate",
            createdAt: "2026-06-05T00:00:00.000Z"
        )
        let canonical = Self.safeEvent(
            aiTool: .claude,
            runID: "run_aaa",
            spanID: "span-canonical",
            createdAt: "2026-06-05T00:00:01.000Z"
        )
        let otherRunUntouched = Self.safeEvent(
            aiTool: .claude,
            runID: "run_bbb",
            spanID: "span-other-run-never-scanned",
            createdAt: "2026-06-05T00:00:02.000Z"
        )
        let codexSameSpanShapeUntouched = Self.safeEvent(
            aiTool: .codex,
            runID: "run_aaa",
            spanID: "span-codex-not-claude",
            createdAt: "2026-06-05T00:00:03.000Z"
        )
        try store.replaceEvents([staleDuplicate, canonical, otherRunUntouched, codexSameSpanShapeUntouched])

        let cutoff = store.maxRowID(forAITool: .claude)
        let deleted = store.reconcileClaudeSessions(
            authoritativeSpanIDsByRun: ["run_aaa": ["span-canonical"]],
            notInsertedAfterRowID: cutoff
        )

        XCTAssertEqual(deleted, 1)
        let remainingSpanIDs = Set(store.loadEvents().map(\.spanID))
        XCTAssertEqual(remainingSpanIDs, [
            "span-canonical",
            "span-other-run-never-scanned",
            "span-codex-not-claude",
        ])
    }

    func testReconcileClaudeSessionsProtectsRowsInsertedAfterCutoff() throws {
        // Simulates the race a full rescan can hit: a live Stop-hook turn for the same
        // run_id lands in the database after the cutoff was captured (i.e. while the scan
        // subprocess was still running), so its span_id is legitimately absent from the
        // authoritative set even though it is not stale. Without the rowid cutoff, this
        // turn would match the same "run_id scanned, span_id not authoritative" deletion
        // criteria as a genuine stale duplicate and be wiped permanently.
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let staleDuplicate = Self.safeEvent(
            aiTool: .claude,
            runID: "run_aaa",
            spanID: "span-old-formula-duplicate",
            createdAt: "2026-06-05T00:00:00.000Z"
        )
        try store.replaceEvents([staleDuplicate])
        // Captured "before the scan starts" — anything inserted after this point must
        // survive reconciliation regardless of authoritative-set membership.
        let cutoff = store.maxRowID(forAITool: .claude)

        let liveTurnDuringScan = Self.safeEvent(
            aiTool: .claude,
            runID: "run_aaa",
            spanID: "span-live-turn-during-scan",
            createdAt: "2026-06-05T00:00:05.000Z"
        )
        _ = try store.appendEventsWithoutLoading([liveTurnDuringScan])

        // Neither span_id is in the authoritative set (simulating a scan that captured
        // neither the pre-existing stale row's replacement nor the new live turn).
        let deleted = store.reconcileClaudeSessions(
            authoritativeSpanIDsByRun: ["run_aaa": ["span-canonical-the-scan-actually-saw"]],
            notInsertedAfterRowID: cutoff
        )

        // Only the row that existed at (or before) the cutoff is eligible for deletion.
        // The live turn inserted after the cutoff survives even though its span_id is
        // just as "non-authoritative" as the one that got deleted.
        XCTAssertEqual(deleted, 1)
        XCTAssertEqual(Set(store.loadEvents().map(\.spanID)), ["span-live-turn-during-scan"])
    }

    func testReconcileClaudeSessionsLeavesRemovedTranscriptSessionsUntouched() throws {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let orphanedSessionEvent = Self.safeEvent(
            aiTool: .claude,
            runID: "run_deleted_transcript",
            spanID: "span-from-a-session-not-in-this-scan"
        )
        try store.replaceEvents([orphanedSessionEvent])

        let deleted = store.reconcileClaudeSessions(
            authoritativeSpanIDsByRun: [:],
            notInsertedAfterRowID: store.maxRowID(forAITool: .claude)
        )

        XCTAssertEqual(deleted, 0)
        XCTAssertEqual(store.loadEvents(), [orphanedSessionEvent])
    }

    func testMaxRowIDReturnsZeroWhenNoMatchingEventsExist() throws {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        XCTAssertEqual(store.maxRowID(forAITool: .claude), 0)

        try store.replaceEvents([Self.safeEvent(aiTool: .codex)])
        XCTAssertEqual(store.maxRowID(forAITool: .claude), 0)

        try store.replaceEvents([Self.safeEvent(aiTool: .codex), Self.safeEvent(aiTool: .claude, spanID: "span-claude-01")])
        XCTAssertGreaterThan(store.maxRowID(forAITool: .claude), 0)
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

    func testStoreDrainsAccountingSidecarWithQueuedJSONLInboxBatchEvents() throws {
        let eventsURL = temporaryEventsURL()
        let inboxURL = temporaryInboxURL()
        let store = TokenUsageStore(fileURL: eventsURL, inboxURL: inboxURL)
        let event = Self.safeEvent(
            aiTool: .codex,
            spanID: "span_jsonl_accounting_01",
            inputTokens: 20,
            outputTokens: 5
        )
        try FileManager.default.createDirectory(
            at: inboxURL,
            withIntermediateDirectories: true
        )
        let batchURL = inboxURL.appendingPathComponent("001.jsonl")
        let accountingURL = inboxURL.appendingPathComponent("001.accounting")
        let eventLine = String(data: try TokenUsageSanitizer.eventData(event), encoding: .utf8) ?? ""
        try Data((eventLine + "\n").utf8)
            .write(to: batchURL)
        try Data(
            """
            {"schema_version":1,"span_id":"span_jsonl_accounting_01","ai_tool":"codex","uncached_input_tokens":12,"cache_creation_input_tokens":0,"cache_read_input_tokens":8,"reasoning_output_tokens":2}

            """.utf8
        ).write(to: accountingURL)

        let events = store.importQueuedEvents()

        XCTAssertEqual(events.map(\.spanID), ["span_jsonl_accounting_01"])
        XCTAssertEqual(events.first?.tokenAccounting?.uncachedInputTokens, 12)
        XCTAssertEqual(events.first?.tokenAccounting?.cacheReadInputTokens, 8)
        XCTAssertEqual(events.first?.tokenAccounting?.reasoningOutputTokens, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: batchURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: accountingURL.path))

        let encoded = try decodedJSONObject(from: TokenUsageSanitizer.eventData(events[0]))
        XCTAssertNil(encoded["uncached_input_tokens"])
        XCTAssertNil(encoded["token_accounting"])
        XCTAssertNil(encoded["accounting"])
    }

    func testStorePersistsTokenAccountingColumns() throws {
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let event = Self.safeEvent(
            aiTool: .claude,
            spanID: "span_accounting_roundtrip",
            inputTokens: 125,
            outputTokens: 7,
            tokenAccounting: TokenUsageAccounting(
                uncachedInputTokens: 20,
                cacheCreationInputTokens: 5,
                cacheReadInputTokens: 100
            )
        )

        try store.appendEvent(event)

        let loaded = try XCTUnwrap(store.loadEvents().first)
        XCTAssertEqual(loaded.tokenAccounting?.uncachedInputTokens, 20)
        XCTAssertEqual(loaded.tokenAccounting?.cacheCreationInputTokens, 5)
        XCTAssertEqual(loaded.tokenAccounting?.cacheReadInputTokens, 100)
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

    func testBridgeRejectsRequestsWithUntrustedHostHeader() throws {
        // Guards the DNS-rebinding fix: a page resolving an attacker-controlled hostname
        // to 127.0.0.1 must still fail here because the Host header itself is untrusted,
        // even though the OS-level loopback bind was reached.
        let store = TokenUsageStore(fileURL: temporaryEventsURL())
        let server = TokenUsageBridgeServer(store: store)

        let rebindingAttempt = server.response(for: httpRequest(
            method: "GET",
            path: "/v1/usage/events",
            host: "attacker.example.com"
        ))
        XCTAssertTrue(httpStatusLine(rebindingAttempt).contains("403"), httpStatusLine(rebindingAttempt))
        XCTAssertTrue(String(data: rebindingAttempt, encoding: .utf8)?.contains("untrusted_host") == true)

        let missingHost = server.response(for: Data("GET /v1/usage/events HTTP/1.1\r\n\r\n".utf8))
        XCTAssertTrue(httpStatusLine(missingHost).contains("403"), httpStatusLine(missingHost))

        let trustedLocalhost = server.response(for: httpRequest(
            method: "GET",
            path: "/v1/usage/health",
            host: "localhost:48731"
        ))
        XCTAssertTrue(httpStatusLine(trustedLocalhost).contains("200 OK"), httpStatusLine(trustedLocalhost))
    }

    func testBridgeHostnameParsingHandlesIPv6BracketNotation() {
        XCTAssertEqual(TokenUsageBridgeServer.hostname(fromHostHeaderValue: "127.0.0.1:48731"), "127.0.0.1")
        XCTAssertEqual(TokenUsageBridgeServer.hostname(fromHostHeaderValue: "127.0.0.1"), "127.0.0.1")
        XCTAssertEqual(TokenUsageBridgeServer.hostname(fromHostHeaderValue: "[::1]:48731"), "::1")
        XCTAssertEqual(TokenUsageBridgeServer.hostname(fromHostHeaderValue: "[::1]"), "::1")
        XCTAssertEqual(TokenUsageBridgeServer.hostname(fromHostHeaderValue: "attacker.example.com"), "attacker.example.com")
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

    func testWorkflowSetupPromptConnectsCurrentWorkflow() {
        let prompt = TokenMeteringGlobalSetup.workflowPrompt

        XCTAssertTrue(prompt.contains("Treat the current directory as the workflow root"))
        XCTAssertTrue(prompt.contains("basic in-app install already records exact token totals"))
        XCTAssertTrue(prompt.contains("never stores or uploads prompts"))
        XCTAssertTrue(prompt.contains(TokenMeteringSetupInstaller.publicSetupCommand))
        XCTAssertTrue(prompt.contains("Inspect only this workflow root"))
        XCTAssertTrue(prompt.contains("--label <codex|claude|antigravity>"))
        XCTAssertTrue(prompt.contains("--task-type <safe_slug> --stage <safe_slug>"))
        XCTAssertTrue(prompt.contains("start a new session or restart any AI tool session that was already running"))
        XCTAssertTrue(prompt.contains("never prompts, commands, file paths"))
        XCTAssertTrue(prompt.contains("do not install AGY lifecycle hooks"))
        XCTAssertFalse(prompt.contains("claude-last-empty.json"))
        XCTAssertFalse(prompt.contains("antigravity-active-importer-last.json"))
        XCTAssertLessThan(prompt.count, 2_500)
    }

    func testHostedTokenMeteringSetupDocsDefineRuntimeContract() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let setup = try String(contentsOf: root.appendingPathComponent("docs/token-metering/setup-prompt.md"))
        let runtime = try String(contentsOf: root.appendingPathComponent("docs/token-metering/runtime-instruction.md"))
        let installer = try String(contentsOf: root.appendingPathComponent("docs/token-metering/install.sh"))
        let helper = try String(contentsOf: root.appendingPathComponent("adapters/setup/spill-token-metering-setup.mjs"))
        let publicHelper = try String(contentsOf: root.appendingPathComponent("scripts/spill-token-metering-setup.mjs"))
        let bundledHelper = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Resources/adapters/setup/spill-token-metering-setup.mjs"))
        let adapterRuntimeInstruction = try String(contentsOf: root.appendingPathComponent("adapters/setup/runtime-instruction.md"))
        let bundledRuntimeInstruction = try String(contentsOf: root.appendingPathComponent("Sources/Spill/Resources/adapters/setup/runtime-instruction.md"))
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

        XCTAssertTrue(setup.contains("Install or repair Spill token metering now"))
        XCTAssertTrue(setup.contains("https://spill.thdev.app/token-metering/install.sh"))
        XCTAssertTrue(setup.contains("One run handles Codex, Claude Code, and Antigravity/AGY together"))
        XCTAssertTrue(setup.contains("~/.spill/runtime-instruction.md"))
        XCTAssertTrue(setup.contains("small managed discovery bridge"))
        XCTAssertTrue(setup.contains("~/.claude/CLAUDE.md"))
        XCTAssertTrue(setup.contains("~/.antigravity/AGENTS.md"))
        XCTAssertTrue(setup.contains("preserve unrelated user instructions"))
        XCTAssertTrue(setup.contains("copy the full Spill runtime prompt separately"))
        XCTAssertTrue(setup.contains("PostInvocation"))
        XCTAssertTrue(setup.contains("store or upload prompts"))
        XCTAssertTrue(setup.contains("Treat workflow-aware label integration as an optional follow-up"))
        XCTAssertTrue(setup.contains("Do not claim that setup output"))
        XCTAssertTrue(setup.contains("spill-token-metering-stats.mjs --tool codex"))
        XCTAssertTrue(setup.contains("spill-token-metering-stats.mjs --tool claude"))
        XCTAssertTrue(setup.contains("spill-token-metering-stats.mjs --tool antigravity"))
        XCTAssertFalse(setup.contains("Should I connect workflow-aware labels now?"))
        XCTAssertFalse(setup.contains("claude-last-empty.json"))
        XCTAssertLessThan(setup.count, 7_000)
        XCTAssertTrue(runtime.contains("Canonical installed path: `~/.spill/runtime-instruction.md`"))
        XCTAssertTrue(runtime.contains("only a small managed import or pointer"))
        XCTAssertEqual(runtime, adapterRuntimeInstruction)
        XCTAssertEqual(runtime, bundledRuntimeInstruction)
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
        XCTAssertTrue(runtime.contains("Claude Code adapters must include\n  `cache_read_input_tokens`"))
        XCTAssertTrue(runtime.contains("Codex `input_tokens` already includes cached input reads"))
        XCTAssertTrue(runtime.contains("Codex\n  `reasoning_output_tokens` is a subset of `output_tokens`"))
        XCTAssertTrue(runtime.contains("approximate cost; cost weighting belongs in a separate display or analysis\n  layer"))
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
        XCTAssertTrue(runtime.contains("Do not delete or disable existing Spill integration"))
        XCTAssertTrue(runtime.contains("carry the Spill responsibility forward in the same change"))
        XCTAssertTrue(runtime.contains("Removing Spill\n  integration requires explicit user approval"))
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
        XCTAssertTrue(installer.contains("download \"runtime-instruction.md\""))
        XCTAssertTrue(installer.contains("adapters/codex/spill-importer.mjs"))
        XCTAssertTrue(installer.contains("adapters/claude-code/spill-hook.py"))
        XCTAssertFalse(installer.contains("adapters/antigravity/spill-hook.py"))
        XCTAssertFalse(installer.contains("adapters/antigravity/spill-hook-wrapper.py"))
        XCTAssertTrue(installer.contains("--include codex,claude,antigravity"))
        XCTAssertTrue(installer.contains("--source-root \"$TMP_DIR/adapters\""))
        XCTAssertTrue(installer.contains("--runtime-instruction-source \"$TMP_DIR/runtime-instruction.md\""))

        XCTAssertTrue(helper.contains("configureRuntimeLabelDefaults"))
        XCTAssertTrue(helper.contains("const meteringOnly = args.meteringOnly === true"))
        XCTAssertTrue(helper.contains("--metering-only"))
        XCTAssertTrue(helper.contains("installsInstructionBridges: !meteringOnly"))
        XCTAssertTrue(helper.contains("metering_only: meteringOnly"))
        XCTAssertTrue(helper.contains("installSharedRuntimeInstruction"))
        XCTAssertTrue(helper.contains("configureRuntimeInstructionBridge"))
        XCTAssertTrue(helper.contains("~/.spill/runtime-instruction.md"))
        XCTAssertTrue(helper.contains(#".codex", "AGENTS.override.md"#))
        XCTAssertTrue(helper.contains(#".claude", "CLAUDE.md"#))
        XCTAssertTrue(helper.contains(#".antigravity", "AGENTS.md"#))
        XCTAssertTrue(helper.contains("spill-token-metering-instruction:begin"))
        XCTAssertTrue(helper.contains("importedRuntimeInstructionBlock"))
        XCTAssertTrue(helper.contains("pointerRuntimeInstructionBlock"))
        XCTAssertEqual(helper, publicHelper)
        XCTAssertEqual(helper, bundledHelper)
        XCTAssertEqual(statsHelper, publicStatsHelper)
        XCTAssertEqual(statsHelper, bundledStatsHelper)
        XCTAssertFalse(helper.contains("removeClaudeBaselineLabelHook"))
        XCTAssertFalse(helper.contains("cleaned_baseline_label"))
        XCTAssertFalse(helper.contains("would_cleanup_baseline_label"))
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
        // Per-file checkpoints may keep only opaque, safe metadata.
        XCTAssertTrue(codexImporter.contains("optionalOpaqueID(entry.sessionID)"))
        XCTAssertTrue(codexImporter.contains("safeModel(entry.model)"))
        // The setup helper must seed checkpoints so the first Stop hook run
        // after install has no history backlog to work through.
        XCTAssertTrue(helper.contains("seedCodexImportOffsets"))
        XCTAssertTrue(publicHelper.contains("seedCodexImportOffsets"))
        XCTAssertTrue(bundledHelper.contains("seedCodexImportOffsets"))
        XCTAssertTrue(codexImporter.contains("shouldAdvanceCursor(cursor, nextCursor)"))
        XCTAssertTrue(codexImporter.contains("timestamp < entry.updatedAt"))
        XCTAssertTrue(codexImporter.contains("timestamp > entry.expiresAt"))
        XCTAssertTrue(codexImporter.contains("usedRuntimeLabel"))
        XCTAssertTrue(codexImporter.contains("taskType: taskTypeOverride ?? eventLabel.taskType ?? fallbackLabel.taskType"))

        XCTAssertTrue(antigravityImporter.contains("SELECT idx, data FROM gen_metadata ORDER BY idx"))
        XCTAssertTrue(antigravityImporter.contains("SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX"))
        XCTAssertTrue(antigravityImporter.contains("artifactID: \"artifact_global\""))
        XCTAssertTrue(antigravityImporter.contains("Observed local AGY gen_metadata usage fields"))
        XCTAssertTrue(antigravityImporter.contains("not a public AGY"))
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
        XCTAssertTrue(claudeHook.contains("inferred_task_type = 'uncategorized'"))
        XCTAssertTrue(claudeHook.contains("inferred_stage = 'summarize'"))
        XCTAssertFalse(claudeHook.contains("_infer_task_type"))
        XCTAssertFalse(claudeHook.contains("_turn_tool_names"))
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
            #"{"requestId":"req_diag_read","message":{"role":"assistant","model":"claude-sonnet-4","usage":{"input_tokens":20,"cache_creation_input_tokens":5,"cache_read_input_tokens":100,"output_tokens":7},"content":[{"type":"tool_use","name":"Read"}]}}"#,
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
        let accounting = try accountingObjects(in: inboxURL)
        XCTAssertEqual(accounting.count, 1)
        XCTAssertEqual(accounting.first?["uncached_input_tokens"] as? Int, 20)
        XCTAssertEqual(accounting.first?["cache_creation_input_tokens"] as? Int, 5)
        XCTAssertEqual(accounting.first?["cache_read_input_tokens"] as? Int, 100)
        let stateURL = sessionStateURL.appendingPathComponent("claudeDiag01.json")
        let state = try String(contentsOf: stateURL)
        XCTAssertTrue(state.contains(#""byte_offset""#))
        XCTAssertTrue(state.contains(#""emitted_request_ids""#))
        XCTAssertTrue(state.contains(#""req_diag_read""#))
        XCTAssertFalse(state.contains(transcriptURL.path))

        var resetState = try decodedJSONObject(from: Data(contentsOf: stateURL))
        resetState["fresh"] = 0
        resetState["output"] = 0
        resetState["byte_offset"] = 0
        try jsonData(resetState).write(to: stateURL)

        try runClaudeHook(
            rawInput: payload,
            inboxURL: inboxURL,
            diagnosticsURL: diagnosticsURL,
            sessionStateURL: sessionStateURL
        )

        XCTAssertEqual(try antigravityEventObjects(in: inboxURL).count, 1)

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
        XCTAssertEqual(refreshedEvents.count, 3)
        XCTAssertEqual(refreshedEvents.compactMap { $0["total_tokens"] as? Int }.sorted(), [9, 12, 132])
        XCTAssertEqual(try accountingObjects(in: inboxURL).count, 3)
        XCTAssertFalse(FileManager.default.fileExists(atPath: emptyURL.path))
    }

    func testClaudeHookDoesNotApplyCurrentLabelToMultipleNewTurns() throws {
        let inboxURL = temporaryInboxURL()
        let diagnosticsURL = temporaryDiagnosticsURL()
        let sessionStateURL = temporaryDiagnosticsURL()
            .deletingLastPathComponent()
            .appendingPathComponent("claude-session-state")
        let labelURL = diagnosticsURL
            .deletingLastPathComponent()
            .appendingPathComponent("label-context", isDirectory: true)
            .appendingPathComponent("claude.json")
        try FileManager.default.createDirectory(
            at: labelURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try """
        {"ai_tool":"claude","task_type":"analysis","stage":"classify","updated_at":"2026-06-26T00:00:00.000Z","expires_at":"2099-01-01T00:00:00.000Z"}

        """.write(to: labelURL, atomically: true, encoding: .utf8)

        let transcriptURL = diagnosticsURL
            .deletingLastPathComponent()
            .appendingPathComponent("claude-multi-turn-transcript.jsonl")
        let transcript = [
            #"{"message":{"role":"user"}}"#,
            #"{"timestamp":"2026-06-26T00:00:01.000Z","requestId":"req_read","message":{"id":"msg_read","role":"assistant","model":"claude-sonnet-4","usage":{"input_tokens":20,"cache_read_input_tokens":100,"output_tokens":5},"content":[{"type":"tool_use","name":"Read"}]}}"#,
            #"{"message":{"role":"user"}}"#,
            #"{"timestamp":"2026-06-26T00:01:01.000Z","requestId":"req_edit","message":{"id":"msg_edit","role":"assistant","model":"claude-sonnet-4","usage":{"input_tokens":30,"cache_read_input_tokens":200,"output_tokens":7},"content":[{"type":"tool_use","name":"Edit"}]}}"#,
        ].joined(separator: "\n")
        try "\(transcript)\n".write(to: transcriptURL, atomically: true, encoding: .utf8)

        let payload = #"{"session_id":"claudeMulti01","transcript_path":"\#(transcriptURL.path)"}"#
        try runClaudeHook(
            rawInput: payload,
            inboxURL: inboxURL,
            diagnosticsURL: diagnosticsURL,
            sessionStateURL: sessionStateURL
        )

        let events = try antigravityEventObjects(in: inboxURL)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events.compactMap { $0["total_tokens"] as? Int }.sorted(), [125, 237])
        XCTAssertFalse(events.contains { $0["stage"] as? String == "classify" })
        XCTAssertEqual(Set(events.compactMap { $0["task_type"] as? String }), Set(["uncategorized"]))
        XCTAssertEqual(Set(events.compactMap { $0["stage"] as? String }), Set(["summarize"]))
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
        XCTAssertTrue(
            TokenMeteringSetupInstaller.defaultRuntimeInstructionInstallURL()
                .path
                .contains("/adapters/setup/runtime-instruction.md")
        )
        XCTAssertTrue(
            TokenMeteringSetupInstaller.defaultSharedRuntimeInstructionURL()
                .path
                .hasSuffix("/.spill/runtime-instruction.md")
        )
    }

    func testInstalledHookAdapterRefreshOnlyUpdatesExistingFiles() throws {
        let rootURL = temporaryDirectoryURL()
        let repoRootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let sourceURL = repoRootURL.appendingPathComponent("adapters/codex/spill-importer.mjs")
        let missingURL = rootURL.appendingPathComponent("missing/spill-importer.mjs")
        XCTAssertFalse(
            try TokenMeteringAdapterKit.codex.refreshInstallIfPresent(
                at: missingURL,
                sourceURL: sourceURL
            )
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: missingURL.path))

        let installedURL = rootURL.appendingPathComponent("codex/spill-importer.mjs")
        try FileManager.default.createDirectory(
            at: installedURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "stale importer".write(to: installedURL, atomically: true, encoding: .utf8)

        XCTAssertTrue(
            try TokenMeteringAdapterKit.codex.refreshInstallIfPresent(
                at: installedURL,
                sourceURL: sourceURL
            )
        )
        XCTAssertEqual(
            try String(contentsOf: installedURL, encoding: .utf8),
            try String(contentsOf: sourceURL, encoding: .utf8)
        )
    }

    func testInstalledSetupHelperRefreshOnlyUpdatesExistingFiles() throws {
        let rootURL = temporaryDirectoryURL()
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let sourceURL = rootURL.appendingPathComponent("source.mjs")
        let missingURL = rootURL.appendingPathComponent("missing.mjs")
        try "fresh helper".write(to: sourceURL, atomically: true, encoding: .utf8)

        XCTAssertFalse(
            try TokenMeteringSetupInstaller.refreshInstalledHelperIfPresent(
                sourceURL: sourceURL,
                destination: missingURL
            )
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: missingURL.path))

        let installedURL = rootURL.appendingPathComponent("installed.mjs")
        try "stale helper".write(to: installedURL, atomically: true, encoding: .utf8)
        XCTAssertTrue(
            try TokenMeteringSetupInstaller.refreshInstalledHelperIfPresent(
                sourceURL: sourceURL,
                destination: installedURL
            )
        )
        XCTAssertEqual(
            try String(contentsOf: installedURL, encoding: .utf8),
            "fresh helper"
        )
        let attrs = try FileManager.default.attributesOfItem(atPath: installedURL.path)
        let permissions = try XCTUnwrap(attrs[.posixPermissions] as? Int)
        XCTAssertNotEqual(permissions & 0o111, 0)
    }

    func testInstalledRuntimeInstructionRefreshPreservesManagedDestinationPermissions() throws {
        let rootURL = temporaryDirectoryURL()
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let sourceURL = rootURL.appendingPathComponent("source.md")
        let missingURL = rootURL.appendingPathComponent("missing/runtime-instruction.md")
        try "fresh shared instruction".write(to: sourceURL, atomically: true, encoding: .utf8)

        XCTAssertFalse(
            try TokenMeteringSetupInstaller.refreshInstalledRuntimeInstructionIfPresent(
                sourceURL: sourceURL,
                destination: missingURL
            )
        )

        let installedURL = rootURL
            .appendingPathComponent(".spill", isDirectory: true)
            .appendingPathComponent("runtime-instruction.md")
        try FileManager.default.createDirectory(
            at: installedURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "stale instruction".write(to: installedURL, atomically: true, encoding: .utf8)

        XCTAssertTrue(
            try TokenMeteringSetupInstaller.refreshInstalledRuntimeInstructionIfPresent(
                sourceURL: sourceURL,
                destination: installedURL
            )
        )
        XCTAssertEqual(
            try String(contentsOf: installedURL, encoding: .utf8),
            "fresh shared instruction"
        )
        let attrs = try FileManager.default.attributesOfItem(atPath: installedURL.path)
        let permissions = try XCTUnwrap(attrs[.posixPermissions] as? Int)
        XCTAssertEqual(permissions & 0o777, 0o600)
    }

    func testTokenMeteringCoordinatorRefreshesInstalledAdaptersOnStart() throws {
        let source = try Self.source(named: "TokenMeteringCoordinator.swift")
        XCTAssertTrue(
            source.contains("TokenMeteringSetupInstaller.refreshInstalledFilesIfPresent()")
        )
        XCTAssertLessThan(
            try XCTUnwrap(source.range(of: "TokenMeteringSetupInstaller.refreshInstalledFilesIfPresent()")?.lowerBound),
            try XCTUnwrap(source.range(of: "requestCollection(reason: \"app_launch\")")?.lowerBound)
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
        tokenAccounting: TokenUsageAccounting? = nil,
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
            tokenAccounting: tokenAccounting,
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

    private static func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
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

    @MainActor
    private func waitForPanelSummary(
        _ store: TokenUsageDashboardStore,
        eventCount: Int,
        totalTokens: Int? = nil
    ) async throws {
        for _ in 0..<20 {
            if store.panelSummary.eventCount == eventCount,
               totalTokens == nil || store.panelSummary.totalTokens == totalTokens {
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("Dashboard panel summary did not refresh")
    }

    @MainActor
    private func waitForGlanceSummary(
        _ store: TokenUsageDashboardStore,
        eventCount: Int,
        totalTokens: Int? = nil
    ) async throws {
        for _ in 0..<30 {
            if store.glanceSummary.eventCount == eventCount,
               totalTokens == nil || store.glanceSummary.totalTokens == totalTokens {
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("Dashboard glance summary did not refresh")
    }

    @MainActor
    private func waitForDashboardSnapshot(
        _ store: TokenUsageDashboardStore,
        eventCount: Int
    ) async throws {
        for _ in 0..<40 {
            if store.snapshot.eventCount == eventCount, !store.isDashboardRefreshInProgress {
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("Dashboard snapshot did not refresh after calendar invalidation")
    }

    @MainActor
    private func waitForDashboardStoreRefreshToLoadEvents(
        _ store: TokenUsageDashboardStore,
        eventCount: Int
    ) async throws {
        for _ in 0..<30 {
            if store.snapshot.eventCount == eventCount, !store.isDashboardRefreshInProgress {
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("Dashboard store did not load expected events")
    }

    @MainActor
    private func waitForDashboardPeriodDetails(
        _ store: TokenUsageDashboardStore,
        details: [String]
    ) async throws {
        for _ in 0..<30 {
            if store.snapshot.periodFilters.map(\.detail) == details, !store.isDashboardRefreshInProgress {
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("Dashboard store did not load expected period filter totals")
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

    private func accountingObjects(in inboxURL: URL) throws -> [[String: Any]] {
        guard FileManager.default.fileExists(atPath: inboxURL.path) else {
            return []
        }
        let files = try FileManager.default.contentsOfDirectory(
            at: inboxURL,
            includingPropertiesForKeys: nil
        )
            .filter { $0.pathExtension == "accounting" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        return try files.flatMap { url -> [[String: Any]] in
            let contents = try String(contentsOf: url)
            return try contents
                .split(whereSeparator: \.isNewline)
                .map { line in
                    try XCTUnwrap(JSONSerialization.jsonObject(with: Data(String(line).utf8)) as? [String: Any])
                }
        }
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

    private func httpRequest(method: String, path: String, body: Data = Data(), host: String = "127.0.0.1") -> Data {
        let header = """
        \(method) \(path) HTTP/1.1\r
        Host: \(host)\r
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
