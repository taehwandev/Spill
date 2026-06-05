import Foundation

enum TokenMeteringLanguage: String, CaseIterable {
    case english = "en"
    case korean = "ko"
    case japanese = "ja"

    static func current(
        preferredLanguages: [String] = Locale.preferredLanguages,
        appLanguage: SpillAppLanguage = .persisted()
    ) -> TokenMeteringLanguage {
        if let languageCode = appLanguage.languageCode,
           let language = matching(languageCode)
        {
            return language
        }

        for languageID in preferredLanguages {
            if let language = matching(languageID) {
                return language
            }
        }
        return .english
    }

    private static func matching(_ languageID: String) -> TokenMeteringLanguage? {
        let normalized = languageID.lowercased()
        if normalized.hasPrefix("ko") { return .korean }
        if normalized.hasPrefix("ja") { return .japanese }
        if normalized.hasPrefix("en") { return .english }
        return nil
    }
}

enum TokenMeteringTextKey: String {
    case dashboardTitle
    case dashboardSubtitle
    case refresh
    case copied
    case copyPrompt
    case clear
    case period
    case aiTool
    case workflowFocus
    case noTaskSplit
    case noStageSplit
    case receivers
    case localQueue
    case defaultState
    case adapters
    case onDemand
    case aiToolDistribution
    case aiToolDistributionSubtitle
    case modelBreakdown
    case noModelData
    case modelUnavailable
    case workflowBreakdown
    case workflowBreakdownSubtitle
    case stageBreakdown
    case stageBreakdownSubtitle
    case sourceBreakdown
    case sourceBreakdownSubtitle
    case noAIToolData
    case noWorkflowData
    case noStageData
    case noSourceBreakdown
    case selectedRun
    case total
    case events
    case noRunSelected
    case noRunSelectedDetail
    case sourceDetail
    case noSourceBuckets
    case privacyBoundary
    case privacyBoundaryDetail
    case runs
    case runsSubtitle
    case noLocalTokenEvents
    case noLocalTokenEventsDetail
    case run
    case spans
    case tokens
    case diagnostics
    case diagnosticsDetail
    case writing
    case queueTest
    case waitingForEvents
    case localOnly

    case periodToday
    case periodSevenDays
    case periodThirtyDays
    case periodAll
    case allTools
    case unknownAITool
    case displayModeTokens
    case displayModeShare
    case displayModeInfoTitle
    case displayModeInfoDetail
    case aiToolInfoTitle
    case aiToolInfoDetail
    case workflowInfoTitle
    case workflowInfoDetail
    case stageInfoTitle
    case stageInfoDetail
    case sourceInfoTitle
    case sourceInfoDetail
    case modelInfoTitle
    case modelInfoDetail
    case runsInfoTitle
    case runsInfoDetail
    case totalTokens
    case input
    case output
    case avgLatency
    case latencyUnavailable
    case runtimeTimingUnavailable
    case perLocalSpan
    case zeroPercentOfTotal
    case zeroPointPercentOfTotal
    case totalShare
    case inputShare
    case outputShare

    case sourceSystem
    case sourceUser
    case sourceHistory
    case sourceRepoContext
    case sourceToolOutput
    case sourceGeneratedOutput
    case sourceUnavailable

    case preferencesTitle
    case preferencesSubtitle
    case installPromptTitle
    case recommended
    case installPromptDetail
    case promptDisplayNamesTitle
    case promptDisplayNamesDisabled
    case promptDisplayNamesEnabled
    case promptDisplayNamesDetail
    case promptDisplayNamesReapplyWarning
    case copyInstallPrompt
    case copyWebSetup
    case dashboard
    case localEventQueue
    case copyPath
    case advancedInstallCommands
    case copyOneStepCommand
    case adapterScripts
    case neverCollectedOrUploaded
    case advancedDetails
    case copyScript
    case install
    case installed
    case copy
    case hookConfig
    case installFailed
    case setupInstalled
    case agentConnectionStatus
    case adapterSetupRequired
    case adapterHookMissing
    case active

    case modeLocalOnlyTitle
    case modeLocalOnlyState
    case modeLocalOnlyDetail
    case modeCloudAggregateTitle
    case modeCloudAggregateState
    case modeCloudAggregateDetail
    case modeCloudDetailedTitle
    case modeCloudDetailedState
    case modeCloudDetailedDetail

    case clearFailed
    case queueSelfTestSuccess
    case queueSelfTestFailed
    case queueSelfTestWriteFailed
    case saveTestFailed
}

enum TokenMeteringL10n {
    static func text(_ key: TokenMeteringTextKey, language: TokenMeteringLanguage = .current()) -> String {
        table[language]?[key] ?? table[.english]?[key] ?? key.rawValue
    }

    static func eventsTokensDetail(
        eventCount: Int,
        tokens: String,
        language: TokenMeteringLanguage = .current()
    ) -> String {
        switch language {
        case .english:
            return "\(eventCount) events / \(tokens) tokens"
        case .korean:
            return "\(eventCount)개 이벤트 / \(tokens) 토큰"
        case .japanese:
            return "\(eventCount)件 / \(tokens)トークン"
        }
    }

    static func localEventsDetail(eventCount: Int, language: TokenMeteringLanguage = .current()) -> String {
        switch language {
        case .english:
            return "\(eventCount) local events"
        case .korean:
            return "로컬 이벤트 \(eventCount)개"
        case .japanese:
            return "ローカルイベント \(eventCount)件"
        }
    }

    static func spansDetail(
        spanCount: Int,
        latencyMS: Int?,
        latest: String,
        language: TokenMeteringLanguage = .current()
    ) -> String {
        let latency = latencyMS.map { "\($0) ms" } ?? text(.latencyUnavailable, language: language)
        switch language {
        case .english:
            return "\(spanCount) events / \(latency) / \(latest)"
        case .korean:
            return "이벤트 \(spanCount)개 / \(latency) / \(latest)"
        case .japanese:
            return "イベント \(spanCount)件 / \(latency) / \(latest)"
        }
    }

    static func percentOfTotal(_ percent: Int, language: TokenMeteringLanguage = .current()) -> String {
        switch language {
        case .english:
            return "\(percent)% of total"
        case .korean:
            return "전체의 \(percent)%"
        case .japanese:
            return "全体の\(percent)%"
        }
    }

    static func percentStringOfTotal(_ percent: String, language: TokenMeteringLanguage = .current()) -> String {
        switch language {
        case .english:
            return "\(percent) of total"
        case .korean:
            return "전체의 \(percent)"
        case .japanese:
            return "全体の\(percent)"
        }
    }

    static func tokenCountDetail(_ tokens: String, language: TokenMeteringLanguage = .current()) -> String {
        switch language {
        case .english:
            return "\(tokens) tokens"
        case .korean:
            return "\(tokens) 토큰"
        case .japanese:
            return "\(tokens) トークン"
        }
    }

    static func installedAt(_ path: String, language: TokenMeteringLanguage = .current()) -> String {
        "\(text(.installed, language: language)) -> \(path)"
    }

    static func adapterInstalled(_ path: String, language: TokenMeteringLanguage = .current()) -> String {
        "\(text(.installed, language: language)): \(path)"
    }

    static func installFailed(_ error: String, language: TokenMeteringLanguage = .current()) -> String {
        "\(text(.installFailed, language: language)): \(error)"
    }

    static func forbiddenContentLabels(language: TokenMeteringLanguage = .current()) -> [String] {
        switch language {
        case .english:
            return ["prompts", "commands", "responses", "file paths", "repo names", "diffs", "logs", "source content", "environment values", "secrets"]
        case .korean:
            return ["프롬프트", "명령", "응답", "파일 경로", "저장소 이름", "diff", "로그", "소스 내용", "환경 값", "비밀"]
        case .japanese:
            return ["プロンプト", "コマンド", "応答", "ファイルパス", "リポジトリ名", "diff", "ログ", "ソース内容", "環境値", "シークレット"]
        }
    }

    static func taskLabel(_ rawValue: String, language: TokenMeteringLanguage = .current()) -> String {
        taskLabels[language]?[rawValue] ?? taskLabels[.english]?[rawValue] ?? rawValue.tokenMeteringFallbackTitle
    }

    static func stageLabel(_ rawValue: String, language: TokenMeteringLanguage = .current()) -> String {
        stageLabels[language]?[rawValue] ?? stageLabels[.english]?[rawValue] ?? rawValue.tokenMeteringFallbackTitle
    }

    static func adapterTitle(
        _ adapterID: String,
        fallback: String,
        language: TokenMeteringLanguage = .current()
    ) -> String {
        adapterTitles[language]?[adapterID] ?? adapterTitles[.english]?[adapterID] ?? fallback
    }

    static func adapterSubtitle(
        _ adapterID: String,
        fallback: String,
        language: TokenMeteringLanguage = .current()
    ) -> String {
        adapterSubtitles[language]?[adapterID] ?? adapterSubtitles[.english]?[adapterID] ?? fallback
    }

    static func hookConfigTarget(_ target: String, language: TokenMeteringLanguage = .current()) -> String {
        "\(text(.hookConfig, language: language)) -> \(target)"
    }

    private static let table: [TokenMeteringLanguage: [TokenMeteringTextKey: String]] = [
        .english: [
            .dashboardTitle: "Local Token Metering",
            .dashboardSubtitle: "Local queue first. Adapters write event files; Spill imports them into the app-owned store.",
            .refresh: "Refresh",
            .copied: "Copied",
            .copyPrompt: "Copy Prompt",
            .clear: "Clear",
            .period: "Period",
            .aiTool: "AI Tool",
            .workflowFocus: "Workflow Focus",
            .noTaskSplit: "No task split",
            .noStageSplit: "No stage split",
            .receivers: "Receivers",
            .localQueue: "Local Queue",
            .defaultState: "Default",
            .adapters: "Adapters",
            .onDemand: "On demand",
            .aiToolDistribution: "AI Tool Distribution",
            .aiToolDistributionSubtitle: "Combined and per-tool local usage",
            .modelBreakdown: "Model Breakdown",
            .noModelData: "No model data yet.",
            .modelUnavailable: "Model unavailable",
            .workflowBreakdown: "Workflow Breakdown",
            .workflowBreakdownSubtitle: "Task categories from safe slugs",
            .stageBreakdown: "Stage Breakdown",
            .stageBreakdownSubtitle: "Plan, implement, verify, and custom phases",
            .sourceBreakdown: "Source Breakdown",
            .sourceBreakdownSubtitle: "Numeric buckets only",
            .noAIToolData: "No AI tool data yet.",
            .noWorkflowData: "No workflow data yet.",
            .noStageData: "No stage data yet.",
            .noSourceBreakdown: "No source breakdown yet.",
            .selectedRun: "Selected Work Item",
            .total: "Total",
            .events: "Events",
            .noRunSelected: "No work item selected",
            .noRunSelectedDetail: "Events will appear here after a local runtime or adapter records exact token counts.",
            .sourceDetail: "Source Detail",
            .noSourceBuckets: "No source buckets",
            .privacyBoundary: "Privacy Boundary",
            .privacyBoundaryDetail: "No prompts, commands, files, logs, diffs, source content, environment values, or secrets.",
            .runs: "Work Items",
            .runsSubtitle: "Safe local aggregates from agent, workflow, stage, model, and day",
            .noLocalTokenEvents: "No local token events yet",
            .noLocalTokenEventsDetail: "This is expected until an agent runtime or adapter exposes exact token counts.",
            .run: "Work Item",
            .spans: "Events",
            .tokens: "Tokens",
            .diagnostics: "Diagnostics",
            .diagnosticsDetail: "Writes one synthetic event through the local queue and imports it into the app-owned store.",
            .writing: "Writing",
            .queueTest: "Queue Test",
            .waitingForEvents: "Waiting for safe local usage events.",
            .localOnly: "LOCAL ONLY",
            .periodToday: "Today",
            .periodSevenDays: "7 days",
            .periodThirtyDays: "30 days",
            .periodAll: "All",
            .allTools: "All",
            .unknownAITool: "Unknown",
            .displayModeTokens: "Tokens",
            .displayModeShare: "Share %",
            .displayModeInfoTitle: "Display mode",
            .displayModeInfoDetail: "Tokens shows raw local counts. Share % normalizes the same selected local events to percentages.",
            .aiToolInfoTitle: "Agent scope",
            .aiToolInfoDetail: "This comparison shows Codex, Claude Code, and Antigravity/AGY events only. Legacy unknown or direct OpenAI SDK events stay in storage but are hidden from this agent dashboard.",
            .workflowInfoTitle: "Workflow labels",
            .workflowInfoDetail: "Task categories come from safe task_type slugs written by a workflow, hook, or per-turn fallback label. They describe reusable work categories, not prompts or file names.",
            .stageInfoTitle: "Stage labels",
            .stageInfoDetail: "Stages describe the dominant workflow phase for the recorded event, such as plan, implement, verify, or summarize.",
            .sourceInfoTitle: "Source buckets",
            .sourceInfoDetail: "Source buckets are numeric token_breakdown fields. When exact source counts are not exposed, Spill keeps the count as Runtime total only without inspecting content.",
            .modelInfoTitle: "Model ids",
            .modelInfoDetail: "Model ids are reported by the runtime or adapter. Spill does not infer model names from prompts, logs, files, or commands.",
            .runsInfoTitle: "Work items",
            .runsInfoDetail: "Work items are generated from safe labels and time buckets. Raw run_id and span_id values stay in diagnostics, not the default table.",
            .totalTokens: "Total Tokens",
            .input: "Input",
            .output: "Output",
            .avgLatency: "Avg Latency",
            .latencyUnavailable: "Unavailable",
            .runtimeTimingUnavailable: "Runtime did not provide timing",
            .perLocalSpan: "per work item event",
            .zeroPercentOfTotal: "0% of total",
            .zeroPointPercentOfTotal: "0.0% of total",
            .totalShare: "Total Share",
            .inputShare: "Input Share",
            .outputShare: "Output Share",
            .sourceSystem: "System",
            .sourceUser: "User",
            .sourceHistory: "History",
            .sourceRepoContext: "Repo context",
            .sourceToolOutput: "Tool output",
            .sourceGeneratedOutput: "Generated output",
            .sourceUnavailable: "Runtime total only",
            .preferencesTitle: "Local token metering",
            .preferencesSubtitle: "Spill stores safe token counts on this Mac. Login, cloud sync, and server transfer are not active in this app slice.",
            .installPromptTitle: "Install prompt + one-step setup",
            .recommended: "Recommended",
            .installPromptDetail: "Paste this into an AI with local shell access. It forces the AI to fetch the latest setup from spill.thdev.app, install Codex, Claude, and AGY hooks, then save only the runtime instruction.",
            .promptDisplayNamesTitle: "Allow local display names in copied prompt",
            .promptDisplayNamesDisabled: "Strict",
            .promptDisplayNamesEnabled: "Enabled",
            .promptDisplayNamesDetail: "Off keeps copied prompts token-only. On adds an opt-in block that permits user-provided or trusted workflow display aliases only; commands and prompt content remain forbidden.",
            .promptDisplayNamesReapplyWarning: "Copy and reapply the install prompt now. Existing agent instructions will not change until the new prompt is applied, and local display names may be visible to the agent.",
            .copyInstallPrompt: "Copy Install Prompt",
            .copyWebSetup: "Copy Web Setup",
            .dashboard: "Dashboard",
            .localEventQueue: "Local event queue",
            .copyPath: "Copy Path",
            .advancedInstallCommands: "Advanced install commands",
            .copyOneStepCommand: "Copy One-Step Command",
            .adapterScripts: "Adapter scripts",
            .neverCollectedOrUploaded: "Never collected or uploaded",
            .advancedDetails: "Advanced details",
            .copyScript: "Copy Script",
            .install: "Install",
            .installed: "Installed",
            .copy: "Copy",
            .hookConfig: "Hook config",
            .installFailed: "Install failed",
            .setupInstalled: "Installed setup tool and adapter scripts.",
            .agentConnectionStatus: "Agent Connection Status",
            .adapterSetupRequired: "Setup required for local tracking",
            .adapterHookMissing: "Adapter script installed, hook not connected",
            .active: "Active",
            .modeLocalOnlyTitle: "Local only",
            .modeLocalOnlyState: "Active without login",
            .modeLocalOnlyDetail: "Detailed token counts and safe categories stay in this app on this computer.",
            .modeCloudAggregateTitle: "Cloud aggregate",
            .modeCloudAggregateState: "Requires login and explicit enablement",
            .modeCloudAggregateDetail: "Future sync can send totals, timestamps, model ids, latency, and opaque ids only.",
            .modeCloudDetailedTitle: "Cloud detailed",
            .modeCloudDetailedState: "Separate token-only opt-in",
            .modeCloudDetailedDetail: "Future drill-down can add task/source enum labels and numeric breakdowns, never content.",
            .clearFailed: "Could not clear local token data.",
            .queueSelfTestSuccess: "Local queue accepted and stored a categorized 64-token self-test event.",
            .queueSelfTestFailed: "Local queue self-test failed.",
            .queueSelfTestWriteFailed: "Could not write to the local token metering queue.",
            .saveTestFailed: "Could not save the local test event."
        ],
        .korean: [
            .dashboardTitle: "로컬 토큰 미터링",
            .dashboardSubtitle: "로컬 큐 우선. 어댑터가 이벤트 파일을 쓰면 Spill이 앱 소유 저장소로 가져옵니다.",
            .refresh: "새로고침",
            .copied: "복사됨",
            .copyPrompt: "프롬프트 복사",
            .clear: "지우기",
            .period: "기간",
            .aiTool: "AI 도구",
            .workflowFocus: "워크플로우 포커스",
            .noTaskSplit: "작업 분류 없음",
            .noStageSplit: "단계 분류 없음",
            .receivers: "수신기",
            .localQueue: "로컬 큐",
            .defaultState: "기본값",
            .adapters: "어댑터",
            .onDemand: "필요 시",
            .aiToolDistribution: "AI 도구 분포",
            .aiToolDistributionSubtitle: "통합 및 도구별 로컬 사용량",
            .modelBreakdown: "모델 분류",
            .noModelData: "모델 데이터 없음",
            .modelUnavailable: "모델 정보 없음",
            .workflowBreakdown: "워크플로우 분류",
            .workflowBreakdownSubtitle: "안전한 slug 기준 작업 카테고리",
            .stageBreakdown: "단계 분류",
            .stageBreakdownSubtitle: "계획, 구현, 검증 및 사용자 단계",
            .sourceBreakdown: "소스 분류",
            .sourceBreakdownSubtitle: "숫자 버킷만 표시",
            .noAIToolData: "AI 도구 데이터 없음",
            .noWorkflowData: "워크플로우 데이터 없음",
            .noStageData: "단계 데이터 없음",
            .noSourceBreakdown: "소스 분류 없음",
            .selectedRun: "선택한 작업",
            .total: "합계",
            .events: "이벤트",
            .noRunSelected: "선택한 작업 없음",
            .noRunSelectedDetail: "로컬 런타임이나 어댑터가 정확한 토큰 수를 기록하면 여기에 표시됩니다.",
            .sourceDetail: "소스 상세",
            .noSourceBuckets: "소스 버킷 없음",
            .privacyBoundary: "프라이버시 경계",
            .privacyBoundaryDetail: "프롬프트, 명령, 파일, 로그, diff, 소스 내용, 환경 값, 비밀은 저장하지 않습니다.",
            .runs: "작업",
            .runsSubtitle: "에이전트, 워크플로우, 단계, 모델, 날짜 기준 안전한 로컬 집계",
            .noLocalTokenEvents: "로컬 토큰 이벤트 없음",
            .noLocalTokenEventsDetail: "에이전트 런타임이나 어댑터가 정확한 토큰 수를 제공하기 전까지 정상입니다.",
            .run: "작업",
            .spans: "이벤트",
            .tokens: "토큰",
            .diagnostics: "진단",
            .diagnosticsDetail: "로컬 큐에 합성 이벤트 하나를 쓰고 앱 소유 저장소로 가져옵니다.",
            .writing: "기록 중",
            .queueTest: "큐 테스트",
            .waitingForEvents: "안전한 로컬 사용 이벤트를 기다리는 중입니다.",
            .localOnly: "로컬 전용",
            .periodToday: "오늘",
            .periodSevenDays: "7일",
            .periodThirtyDays: "30일",
            .periodAll: "전체",
            .allTools: "전체",
            .unknownAITool: "알 수 없음",
            .displayModeTokens: "토큰 수",
            .displayModeShare: "비중 %",
            .displayModeInfoTitle: "표시 모드",
            .displayModeInfoDetail: "토큰 수는 선택된 로컬 이벤트의 실제 카운트를 보여주고, 비중 %는 같은 이벤트를 퍼센트로 정규화합니다.",
            .aiToolInfoTitle: "에이전트 기준",
            .aiToolInfoDetail: "이 비교는 Codex, Claude Code, Antigravity/AGY 이벤트만 표시합니다. 레거시 unknown 또는 direct OpenAI SDK 이벤트는 저장소에는 남지만 이 에이전트 대시보드에서는 숨깁니다.",
            .workflowInfoTitle: "워크플로우 라벨",
            .workflowInfoDetail: "작업 카테고리는 워크플로우, hook, 또는 턴별 fallback이 쓴 안전한 task_type slug입니다. 프롬프트나 파일명이 아니라 재사용 가능한 작업 유형만 나타냅니다.",
            .stageInfoTitle: "단계 라벨",
            .stageInfoDetail: "단계는 기록된 이벤트에서 지배적인 워크플로우 phase를 뜻합니다. 예: plan, implement, verify, summarize.",
            .sourceInfoTitle: "소스 버킷",
            .sourceInfoDetail: "소스 버킷은 숫자 token_breakdown 필드입니다. 정확한 소스별 토큰 수가 없으면 콘텐츠를 검사하지 않고 해당 카운트를 런타임 합계만으로 둡니다.",
            .modelInfoTitle: "모델 ID",
            .modelInfoDetail: "모델 ID는 런타임이나 어댑터가 보고한 값입니다. Spill은 프롬프트, 로그, 파일, 명령에서 모델명을 추론하지 않습니다.",
            .runsInfoTitle: "작업 집계",
            .runsInfoDetail: "작업은 안전한 라벨과 시간 버킷으로 생성됩니다. raw run_id와 span_id는 기본 표가 아니라 진단에만 둡니다.",
            .totalTokens: "전체 토큰",
            .input: "입력",
            .output: "출력",
            .avgLatency: "평균 지연",
            .latencyUnavailable: "사용 불가",
            .runtimeTimingUnavailable: "런타임이 timing을 제공하지 않음",
            .perLocalSpan: "작업 이벤트당",
            .zeroPercentOfTotal: "전체의 0%",
            .zeroPointPercentOfTotal: "전체의 0.0%",
            .totalShare: "전체 비중",
            .inputShare: "입력 비중",
            .outputShare: "출력 비중",
            .sourceSystem: "시스템",
            .sourceUser: "사용자",
            .sourceHistory: "히스토리",
            .sourceRepoContext: "저장소 컨텍스트",
            .sourceToolOutput: "도구 출력",
            .sourceGeneratedOutput: "생성 출력",
            .sourceUnavailable: "런타임 합계만",
            .preferencesTitle: "로컬 토큰 미터링",
            .preferencesSubtitle: "Spill은 이 Mac에 안전한 토큰 수만 저장합니다. 이 앱 슬라이스에서는 로그인, 클라우드 동기화, 서버 전송이 활성화되지 않습니다.",
            .installPromptTitle: "설치 프롬프트 + 원스텝 설정",
            .recommended: "권장",
            .installPromptDetail: "로컬 shell 접근 권한이 있는 AI에 붙여넣으세요. AI가 spill.thdev.app에서 최신 설정을 가져오고 Codex, Claude, AGY hook을 설치한 뒤 런타임 지침만 저장하게 합니다.",
            .promptDisplayNamesTitle: "복사한 프롬프트에서 로컬 표시명 허용",
            .promptDisplayNamesDisabled: "엄격",
            .promptDisplayNamesEnabled: "켜짐",
            .promptDisplayNamesDetail: "꺼두면 복사된 프롬프트가 토큰 전용 정책을 유지합니다. 켜면 사용자가 지정했거나 신뢰된 워크플로우 표시 별칭만 허용하는 opt-in 블록을 추가합니다. 명령어와 프롬프트 내용은 계속 금지됩니다.",
            .promptDisplayNamesReapplyWarning: "지금 설치 프롬프트를 복사해서 다시 적용해야 합니다. 새 프롬프트를 적용하기 전까지 기존 에이전트 지침은 바뀌지 않으며, 로컬 표시명이 에이전트에 보일 수 있습니다.",
            .copyInstallPrompt: "설치 프롬프트 복사",
            .copyWebSetup: "웹 설정 복사",
            .dashboard: "대시보드",
            .localEventQueue: "로컬 이벤트 큐",
            .copyPath: "경로 복사",
            .advancedInstallCommands: "고급 설치 명령",
            .copyOneStepCommand: "원스텝 명령 복사",
            .adapterScripts: "어댑터 스크립트",
            .neverCollectedOrUploaded: "수집하거나 업로드하지 않음",
            .advancedDetails: "고급 세부 정보",
            .copyScript: "스크립트 복사",
            .install: "설치",
            .installed: "설치됨",
            .copy: "복사",
            .hookConfig: "Hook 설정",
            .installFailed: "설치 실패",
            .setupInstalled: "설정 도구와 어댑터 스크립트를 설치했습니다.",
            .agentConnectionStatus: "에이전트 연결 상태",
            .adapterSetupRequired: "로컬 추적 설정 필요",
            .adapterHookMissing: "어댑터 스크립트 설치됨, hook 연결 필요",
            .active: "활성",
            .modeLocalOnlyTitle: "로컬 전용",
            .modeLocalOnlyState: "로그인 없이 활성",
            .modeLocalOnlyDetail: "상세 토큰 수와 안전한 카테고리는 이 컴퓨터의 앱 안에만 남습니다.",
            .modeCloudAggregateTitle: "클라우드 집계",
            .modeCloudAggregateState: "로그인 및 명시적 활성화 필요",
            .modeCloudAggregateDetail: "향후 동기화는 합계, 타임스탬프, 모델 ID, 지연 시간, 불투명 ID만 보낼 수 있습니다.",
            .modeCloudDetailedTitle: "클라우드 상세",
            .modeCloudDetailedState: "별도 토큰 전용 opt-in",
            .modeCloudDetailedDetail: "향후 drill-down은 작업/소스 enum 라벨과 숫자 분류만 추가하며 콘텐츠는 절대 포함하지 않습니다.",
            .clearFailed: "로컬 토큰 데이터를 지울 수 없습니다.",
            .queueSelfTestSuccess: "로컬 큐가 분류된 64토큰 self-test 이벤트를 저장했습니다.",
            .queueSelfTestFailed: "로컬 큐 self-test에 실패했습니다.",
            .queueSelfTestWriteFailed: "로컬 토큰 미터링 큐에 쓸 수 없습니다.",
            .saveTestFailed: "로컬 테스트 이벤트를 저장할 수 없습니다."
        ],
        .japanese: [
            .dashboardTitle: "ローカルトークン計測",
            .dashboardSubtitle: "ローカルキュー優先。アダプターがイベントファイルを書き込み、Spill がアプリ所有ストアへ取り込みます。",
            .refresh: "更新",
            .copied: "コピー済み",
            .copyPrompt: "プロンプトをコピー",
            .clear: "消去",
            .period: "期間",
            .aiTool: "AI ツール",
            .workflowFocus: "ワークフロー焦点",
            .noTaskSplit: "タスク分類なし",
            .noStageSplit: "ステージ分類なし",
            .receivers: "受信先",
            .localQueue: "ローカルキュー",
            .defaultState: "既定",
            .adapters: "アダプター",
            .onDemand: "必要時",
            .aiToolDistribution: "AI ツール分布",
            .aiToolDistributionSubtitle: "統合およびツール別のローカル使用量",
            .modelBreakdown: "モデル分類",
            .noModelData: "モデルデータはまだありません",
            .modelUnavailable: "モデル情報なし",
            .workflowBreakdown: "ワークフロー分類",
            .workflowBreakdownSubtitle: "安全な slug によるタスク分類",
            .stageBreakdown: "ステージ分類",
            .stageBreakdownSubtitle: "計画、実装、検証、カスタムフェーズ",
            .sourceBreakdown: "ソース分類",
            .sourceBreakdownSubtitle: "数値バケットのみ",
            .noAIToolData: "AI ツールデータはまだありません",
            .noWorkflowData: "ワークフローデータはまだありません",
            .noStageData: "ステージデータはまだありません",
            .noSourceBreakdown: "ソース分類はまだありません",
            .selectedRun: "選択中の作業",
            .total: "合計",
            .events: "イベント",
            .noRunSelected: "作業が選択されていません",
            .noRunSelectedDetail: "ローカルランタイムまたはアダプターが正確なトークン数を記録するとここに表示されます。",
            .sourceDetail: "ソース詳細",
            .noSourceBuckets: "ソースバケットなし",
            .privacyBoundary: "プライバシー境界",
            .privacyBoundaryDetail: "プロンプト、コマンド、ファイル、ログ、diff、ソース内容、環境値、シークレットは保存しません。",
            .runs: "作業",
            .runsSubtitle: "エージェント、ワークフロー、ステージ、モデル、日付による安全なローカル集計",
            .noLocalTokenEvents: "ローカルトークンイベントはまだありません",
            .noLocalTokenEventsDetail: "エージェントランタイムまたはアダプターが正確なトークン数を提供するまでは正常です。",
            .run: "作業",
            .spans: "イベント",
            .tokens: "トークン",
            .diagnostics: "診断",
            .diagnosticsDetail: "合成イベントをローカルキューへ書き込み、アプリ所有ストアへ取り込みます。",
            .writing: "書き込み中",
            .queueTest: "キューテスト",
            .waitingForEvents: "安全なローカル使用イベントを待機しています。",
            .localOnly: "ローカルのみ",
            .periodToday: "今日",
            .periodSevenDays: "7日",
            .periodThirtyDays: "30日",
            .periodAll: "すべて",
            .allTools: "すべて",
            .unknownAITool: "不明",
            .displayModeTokens: "トークン数",
            .displayModeShare: "割合 %",
            .displayModeInfoTitle: "表示モード",
            .displayModeInfoDetail: "トークン数は選択中のローカルイベントの実数を表示します。割合 % は同じイベントをパーセントに正規化します。",
            .aiToolInfoTitle: "エージェント範囲",
            .aiToolInfoDetail: "この比較は Codex、Claude Code、Antigravity/AGY のイベントのみを表示します。レガシーの unknown や direct OpenAI SDK イベントは保存されますが、このエージェントダッシュボードでは非表示です。",
            .workflowInfoTitle: "ワークフローラベル",
            .workflowInfoDetail: "タスクカテゴリはワークフロー、hook、またはターンごとの fallback が書き込む安全な task_type slug です。プロンプトやファイル名ではなく、再利用可能な作業カテゴリを表します。",
            .stageInfoTitle: "ステージラベル",
            .stageInfoDetail: "ステージは記録されたイベントの主要なワークフローフェーズを表します。例: plan、implement、verify、summarize。",
            .sourceInfoTitle: "ソースバケット",
            .sourceInfoDetail: "ソースバケットは数値の token_breakdown フィールドです。正確なソース別カウントがない場合、内容を検査せずそのカウントをランタイム合計のみとして扱います。",
            .modelInfoTitle: "モデル ID",
            .modelInfoDetail: "モデル ID はランタイムまたはアダプターが報告した値です。Spill はプロンプト、ログ、ファイル、コマンドからモデル名を推測しません。",
            .runsInfoTitle: "作業集計",
            .runsInfoDetail: "作業は安全なラベルと時間バケットから生成されます。raw run_id と span_id は既定の表ではなく診断に残します。",
            .totalTokens: "総トークン",
            .input: "入力",
            .output: "出力",
            .avgLatency: "平均遅延",
            .latencyUnavailable: "利用不可",
            .runtimeTimingUnavailable: "ランタイムが timing を提供していません",
            .perLocalSpan: "作業イベントごと",
            .zeroPercentOfTotal: "全体の0%",
            .zeroPointPercentOfTotal: "全体の0.0%",
            .totalShare: "合計割合",
            .inputShare: "入力割合",
            .outputShare: "出力割合",
            .sourceSystem: "システム",
            .sourceUser: "ユーザー",
            .sourceHistory: "履歴",
            .sourceRepoContext: "リポジトリコンテキスト",
            .sourceToolOutput: "ツール出力",
            .sourceGeneratedOutput: "生成出力",
            .sourceUnavailable: "ランタイム合計のみ",
            .preferencesTitle: "ローカルトークン計測",
            .preferencesSubtitle: "Spill はこの Mac に安全なトークン数のみを保存します。このアプリ範囲ではログイン、クラウド同期、サーバー転送は有効ではありません。",
            .installPromptTitle: "インストールプロンプト + ワンステップ設定",
            .recommended: "推奨",
            .installPromptDetail: "ローカル shell へアクセスできる AI に貼り付けてください。AI が spill.thdev.app から最新設定を取得し、Codex、Claude、AGY hook をインストールして、ランタイム指示だけを保存します。",
            .promptDisplayNamesTitle: "コピーしたプロンプトでローカル表示名を許可",
            .promptDisplayNamesDisabled: "厳格",
            .promptDisplayNamesEnabled: "有効",
            .promptDisplayNamesDetail: "オフではコピーしたプロンプトをトークン専用ポリシーのままにします。オンでは、ユーザー指定または信頼済みワークフローの表示エイリアスだけを許可する opt-in ブロックを追加します。コマンドとプロンプト内容は引き続き禁止です。",
            .promptDisplayNamesReapplyWarning: "今すぐインストールプロンプトをコピーして再適用してください。新しいプロンプトを適用するまで既存のエージェント指示は変わらず、ローカル表示名がエージェントに見える場合があります。",
            .copyInstallPrompt: "インストールプロンプトをコピー",
            .copyWebSetup: "Web 設定をコピー",
            .dashboard: "ダッシュボード",
            .localEventQueue: "ローカルイベントキュー",
            .copyPath: "パスをコピー",
            .advancedInstallCommands: "高度なインストールコマンド",
            .copyOneStepCommand: "ワンステップコマンドをコピー",
            .adapterScripts: "アダプタースクリプト",
            .neverCollectedOrUploaded: "収集・アップロードしないもの",
            .advancedDetails: "詳細",
            .copyScript: "スクリプトをコピー",
            .install: "インストール",
            .installed: "インストール済み",
            .copy: "コピー",
            .hookConfig: "Hook 設定",
            .installFailed: "インストール失敗",
            .setupInstalled: "設定ツールとアダプタースクリプトをインストールしました。",
            .agentConnectionStatus: "エージェント接続状態",
            .adapterSetupRequired: "ローカル追跡の設定が必要",
            .adapterHookMissing: "アダプタースクリプトはインストール済み、hook 接続が必要",
            .active: "有効",
            .modeLocalOnlyTitle: "ローカルのみ",
            .modeLocalOnlyState: "ログインなしで有効",
            .modeLocalOnlyDetail: "詳細なトークン数と安全なカテゴリはこのコンピューター上のアプリ内に残ります。",
            .modeCloudAggregateTitle: "クラウド集計",
            .modeCloudAggregateState: "ログインと明示的な有効化が必要",
            .modeCloudAggregateDetail: "将来の同期では合計、タイムスタンプ、モデル ID、遅延、不透明 ID のみを送信できます。",
            .modeCloudDetailedTitle: "クラウド詳細",
            .modeCloudDetailedState: "別途トークン専用 opt-in",
            .modeCloudDetailedDetail: "将来の drill-down ではタスク/ソース enum ラベルと数値内訳だけを追加し、内容は含めません。",
            .clearFailed: "ローカルトークンデータを消去できません。",
            .queueSelfTestSuccess: "ローカルキューが分類済み 64 トークンの self-test イベントを保存しました。",
            .queueSelfTestFailed: "ローカルキュー self-test に失敗しました。",
            .queueSelfTestWriteFailed: "ローカルトークン計測キューへ書き込めません。",
            .saveTestFailed: "ローカルテストイベントを保存できません。"
        ]
    ]

    private static let taskLabels: [TokenMeteringLanguage: [String: String]] = [
        .english: [
            "uncategorized": "Uncategorized",
            "analysis": "Analysis",
            "prd_drafting": "PRD drafting",
            "architecture": "Architecture",
            "code_generation": "Code generation",
            "ui_design": "UI design",
            "prompt_design": "Prompt design",
            "refactoring": "Refactoring",
            "code_review": "Code review",
            "review_response": "Review response",
            "test_generation": "Test generation",
            "testing": "Testing",
            "build_verification": "Build verification",
            "debugging": "Debugging",
            "bug_reproduction": "Bug reproduction",
            "documentation": "Documentation",
            "changelog": "Changelog",
            "release_notes": "Release notes",
            "release_packaging": "Release packaging",
            "git_commit": "Git commit",
            "commit_message": "Commit message",
            "pull_request": "Pull request",
            "workflow_setup": "Workflow setup"
        ],
        .korean: [
            "uncategorized": "미분류",
            "analysis": "분석",
            "prd_drafting": "PRD 작성",
            "architecture": "아키텍처",
            "code_generation": "코드 작성",
            "ui_design": "UI 디자인",
            "prompt_design": "프롬프트 설계",
            "refactoring": "리팩터링",
            "code_review": "코드 리뷰",
            "review_response": "리뷰 대응",
            "test_generation": "테스트 작성",
            "testing": "테스트",
            "build_verification": "빌드 검증",
            "debugging": "디버깅",
            "bug_reproduction": "버그 재현",
            "documentation": "문서화",
            "changelog": "변경 로그",
            "release_notes": "릴리스 노트",
            "release_packaging": "릴리스 패키징",
            "git_commit": "Git 커밋",
            "commit_message": "커밋 메시지",
            "pull_request": "Pull Request",
            "workflow_setup": "워크플로우 설정"
        ],
        .japanese: [
            "uncategorized": "未分類",
            "analysis": "分析",
            "prd_drafting": "PRD 作成",
            "architecture": "アーキテクチャ",
            "code_generation": "コード生成",
            "ui_design": "UI デザイン",
            "prompt_design": "プロンプト設計",
            "refactoring": "リファクタリング",
            "code_review": "コードレビュー",
            "review_response": "レビュー対応",
            "test_generation": "テスト作成",
            "testing": "テスト",
            "build_verification": "ビルド検証",
            "debugging": "デバッグ",
            "bug_reproduction": "バグ再現",
            "documentation": "ドキュメント",
            "changelog": "変更履歴",
            "release_notes": "リリースノート",
            "release_packaging": "リリースパッケージ",
            "git_commit": "Git コミット",
            "commit_message": "コミットメッセージ",
            "pull_request": "Pull Request",
            "workflow_setup": "ワークフロー設定"
        ]
    ]

    private static let stageLabels: [TokenMeteringLanguage: [String: String]] = [
        .english: [
            "monitor": "Monitor",
            "classify": "Classify",
            "plan": "Plan",
            "draft": "Draft",
            "revise": "Revise",
            "implement": "Implement",
            "verify": "Verify",
            "summarize": "Summarize"
        ],
        .korean: [
            "monitor": "모니터링",
            "classify": "분류",
            "plan": "계획",
            "draft": "초안",
            "revise": "수정",
            "implement": "구현",
            "verify": "검증",
            "summarize": "요약"
        ],
        .japanese: [
            "monitor": "監視",
            "classify": "分類",
            "plan": "計画",
            "draft": "下書き",
            "revise": "修正",
            "implement": "実装",
            "verify": "検証",
            "summarize": "要約"
        ]
    ]

    private static let adapterTitles: [TokenMeteringLanguage: [String: String]] = [
        .english: [
            "claude-code": "Claude Code",
            "codex": "Codex",
            "antigravity": "Antigravity (agy)",
            "openai": "OpenAI"
        ],
        .korean: [
            "claude-code": "Claude Code",
            "codex": "Codex",
            "antigravity": "Antigravity (agy)",
            "openai": "OpenAI"
        ],
        .japanese: [
            "claude-code": "Claude Code",
            "codex": "Codex",
            "antigravity": "Antigravity (agy)",
            "openai": "OpenAI"
        ]
    ]

    private static let adapterSubtitles: [TokenMeteringLanguage: [String: String]] = [
        .english: [
            "claude-code": "Stop hook - transcript reader",
            "codex": "Stop hook - session token_count importer",
            "antigravity": "PostInvocation hook - token usage reporter",
            "openai": "SDK wrapper - SpillOpenAIClient"
        ],
        .korean: [
            "claude-code": "Stop hook - transcript reader",
            "codex": "Stop hook - session token_count importer",
            "antigravity": "PostInvocation hook - 토큰 사용량 reporter",
            "openai": "SDK wrapper - SpillOpenAIClient"
        ],
        .japanese: [
            "claude-code": "Stop hook - transcript reader",
            "codex": "Stop hook - session token_count importer",
            "antigravity": "PostInvocation hook - トークン使用量 reporter",
            "openai": "SDK wrapper - SpillOpenAIClient"
        ]
    ]
}

private extension String {
    var tokenMeteringFallbackTitle: String {
        split(separator: "_")
            .map { part in
                guard let first = part.first else {
                    return ""
                }
                return first.uppercased() + part.dropFirst()
            }
            .joined(separator: " ")
    }
}
