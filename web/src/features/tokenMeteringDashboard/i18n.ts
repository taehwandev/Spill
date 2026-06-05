import type {
  AITool,
  SyncMode,
  TaskType,
  TokenSource,
  UsageStage
} from "./syncSafeUsage";

export type TokenMeteringLocale = "en" | "ko" | "ja";

type SyncModeCopy = {
  label: string;
  status: string;
  summary: string;
  cloudPayload: string;
};

type TokenMeteringMessages = {
  localeName: string;
  nav: {
    features: string;
    setup: string;
    about: string;
    download: string;
    overview: string;
    hotspots: string;
    sessions: string;
    settings: string;
    intro: string;
    privacy: string;
  };
  intro: {
    navLabel: string;
    footerLabel: string;
    dashboardPreviewAria: string;
    dashboardPreview: string;
    cloudDashboardPreview: string;
    heroLineOne: string;
    heroLineTwo: string;
    currentUsage: string;
    tokenTotal: (tokens: string) => string;
    tokenMetering: string;
    cloudPreviewData: string;
    syncModeStatus: string;
    cloudNotConnected: string;
    localDetailUntilSync: string;
    modelBreakdown: string;
    taskBreakdown: string;
    getStarted: string;
    headline: string;
    body: string;
    continueWithGitHub: string;
    manualSetupDivider: string;
    installSpill: string;
    tokenMeteringInstallPrompt: string;
    alreadyHaveAccount: string;
    signIn: string;
    copyright: string;
    terms: string;
    twitter: string;
    instagram: string;
  };
  dashboard: {
    brand: string;
    navLabel: string;
    accountLabel: string;
    syncModeStatus: string;
    viewConfiguration: string;
    cloudSync: string;
    kpiAria: string;
    cloudPreviewTitle: string;
    cloudPreviewHeading: string;
    cloudPreviewBody: string;
    cloudRows: string;
    authNotConnected: string;
    openSyncContract: string;
    footerBody: string;
  };
  panels: {
    taskTypeBreakdown: string;
    aiToolDistribution: string;
    aiToolDistributionDescription: string;
    noAIToolRows: string;
    previewTokens: (tokens: string) => string;
    viewDetails: string;
    noTaskRows: string;
    tokenShare: (label: string) => string;
    sourceHotspots: string;
    sourceHotspotsDescription: string;
    source: string;
    tokens: string;
    share: string;
    optimizationTip: string;
    optimizationTipBody: string;
    sessions: string;
    sessionsDescription: (count: number) => string;
    noSessions: string;
    tokenLatency: (tokens: string, latency: string) => string;
    spans: (count: number) => string;
    stepTokenDetail: (model: string, tokens: string) => string;
    unknownWorkItem: string;
    tokenOnlyContract: string;
    tokenOnlyContractDescription: string;
    sanitizerStatus: string;
    sanitizerDetail: (events: number, fields: number, safe: boolean) => string;
    safeOutput: string;
    reviewNeeded: string;
    allowlistPass: string;
    check: string;
    neverIncluded: string;
    toggle: string;
  };
  syncContract: {
    ariaLabel: string;
    title: string;
    closeAria: string;
    syncModeAria: string;
    signInFirstTitle: string;
    signInFirstBody: string;
    chooseDepthTitle: string;
    chooseDepthBody: string;
    allowlistTitle: string;
    allowlistBody: (fields: number) => string;
    close: string;
  };
  setupStep: {
    copied: string;
    copy: string;
    hiddenPromptDetail: string;
  };
  kpis: {
    totalTokens: string;
    inputTokens: string;
    outputTokens: string;
    avgLatency: string;
    unavailable: string;
    runtimeTimingUnavailable: string;
    modelUnavailable: string;
    previewSpans: (count: number) => string;
    percentOfTotal: (percent: string) => string;
    perRunSpanStep: string;
  };
  privacyRows: {
    localOnlyLabel: string;
    localOnlyDetail: string;
    cloudAggregateLabel: string;
    cloudAggregateDetail: string;
    cloudDetailedLabel: string;
    cloudDetailedDetail: string;
    settingsSyncLabel: string;
    settingsSyncDetail: string;
    selectedSettingsLabel: string;
    selectedSettingsDetail: string;
    active: string;
    available: string;
    demoSelected: string;
    futureOptIn: string;
    separateOptIn: string;
  };
  aiToolLabels: Record<AITool, string>;
  taskTypeLabels: Record<TaskType, string>;
  usageStageLabels: Record<UsageStage, string>;
  tokenSourceLabels: Record<TokenSource, string>;
  syncModeContent: Record<SyncMode, SyncModeCopy>;
  forbiddenFieldLabels: readonly string[];
};

export const tokenMeteringMessages = {
  en: {
    localeName: "en-US",
    nav: {
      features: "Features",
      setup: "Setup",
      about: "About",
      download: "Download",
      overview: "Overview",
      hotspots: "Hotspots",
      sessions: "Work Items",
      settings: "Settings",
      intro: "Intro",
      privacy: "Privacy"
    },
    intro: {
      navLabel: "Intro navigation",
      footerLabel: "Intro footer links",
      dashboardPreviewAria: "Dashboard preview",
      dashboardPreview: "Dashboard preview",
      cloudDashboardPreview: "Cloud dashboard preview",
      heroLineOne: "Intelligence,",
      heroLineTwo: "Metered.",
      currentUsage: "Current token usage",
      tokenTotal: (tokens) => `${tokens} tokens`,
      tokenMetering: "Token Metering",
      cloudPreviewData: "Cloud preview data",
      syncModeStatus: "Sync mode status",
      cloudNotConnected: "Cloud not connected",
      localDetailUntilSync: "Local detail stays in the macOS app until sync is enabled.",
      modelBreakdown: "Model breakdown",
      taskBreakdown: "Task breakdown",
      getStarted: "Get started",
      headline: "Spill it all.",
      body: "Join the ecosystem where AI usage metering fluidly integrates with your workflow. No content collection, just flow.",
      continueWithGitHub: "Continue with GitHub",
      manualSetupDivider: "Or set up manually",
      installSpill: "Install Spill",
      tokenMeteringInstallPrompt: "Token Metering Install Prompt",
      alreadyHaveAccount: "Already have an account?",
      signIn: "Sign In",
      copyright: "© 2024 Spill. All rights reserved. Don't hold it back, Just Spill it.",
      terms: "Terms",
      twitter: "Twitter",
      instagram: "Instagram"
    },
    dashboard: {
      brand: "Spill Meter",
      navLabel: "Dashboard sections",
      accountLabel: "Signed in demo account",
      syncModeStatus: "Sync Mode Status",
      viewConfiguration: "View Configuration",
      cloudSync: "Cloud Sync",
      kpiAria: "Token key metrics",
      cloudPreviewTitle: "Cloud dashboard preview",
      cloudPreviewHeading: "Sign in will unlock hosted sync.",
      cloudPreviewBody: "Local token aggregation lives in the macOS app. This web surface is the future account dashboard and currently shows safe preview data only.",
      cloudRows: "cloud rows",
      authNotConnected: "Auth not connected",
      openSyncContract: "Open sync contract",
      footerBody: "Token counts, safe categories, and explicit sync controls."
    },
    panels: {
      taskTypeBreakdown: "Task-Type Breakdown",
      aiToolDistribution: "AI Tool Distribution",
      aiToolDistributionDescription: "Codex, Claude Code, and Antigravity/AGY local events only",
      noAIToolRows: "Local agent events will show here.",
      previewTokens: (tokens) => `${tokens} preview tokens`,
      viewDetails: "View details",
      noTaskRows: "Synced token rows will show task attribution here.",
      tokenShare: (label) => `${label} token share`,
      sourceHotspots: "Token-Source Hotspots",
      sourceHotspotsDescription: "Numeric source categories only",
      source: "Source",
      tokens: "Tokens",
      share: "Share",
      optimizationTip: "Optimization Tip",
      optimizationTipBody: "Source category totals are high. Tune category rules before enabling any cloud aggregate view.",
      sessions: "Work Items",
      sessionsDescription: (count) => `${count} work items generated from safe labels and time buckets`,
      noSessions: "Safe local work items will appear here.",
      tokenLatency: (tokens, latency) => `${tokens} tokens / ${latency}`,
      spans: (count) => `${count} events`,
      stepTokenDetail: (model, tokens) => `${model} / ${tokens} tokens`,
      unknownWorkItem: "Unlabeled work item",
      tokenOnlyContract: "Token-Only Contract",
      tokenOnlyContractDescription: "Local detail first, cloud sync only by explicit opt-in",
      sanitizerStatus: "Sanitizer status",
      sanitizerDetail: (events, fields, safe) =>
        `${events} sync-safe events prepared / ${fields} allowed fields emitted / ${safe ? "safe output" : "review needed"}`,
      safeOutput: "safe output",
      reviewNeeded: "review needed",
      allowlistPass: "Allowlist pass",
      check: "Check",
      neverIncluded: "Never included in cloud payloads",
      toggle: "Toggle"
    },
    syncContract: {
      ariaLabel: "Sync contract",
      title: "Sync Contract",
      closeAria: "Close sync contract",
      syncModeAria: "Sync mode",
      signInFirstTitle: "Sign in first",
      signInFirstBody: "Cloud dashboard rows require an authenticated account.",
      chooseDepthTitle: "Choose sync depth",
      chooseDepthBody: "Usage data sync and settings sync are separate. Settings may later sync all settings or selected settings only.",
      allowlistTitle: "Allowlist payload",
      allowlistBody: (fields) => `${fields} safe fields are eligible; content-like fields are rejected.`,
      close: "Close contract"
    },
    setupStep: {
      copied: "Copied",
      copy: "Copy",
      hiddenPromptDetail: "Copies the full setup prompt without displaying the long instruction on this page."
    },
    kpis: {
      totalTokens: "Total tokens",
      inputTokens: "Input tokens",
      outputTokens: "Output tokens",
      avgLatency: "Avg latency",
      unavailable: "Unavailable",
      runtimeTimingUnavailable: "Runtime did not provide timing",
      modelUnavailable: "Model unavailable",
      previewSpans: (count) => `${count} local events`,
      percentOfTotal: (percent) => `${percent}% of total`,
      perRunSpanStep: "Per work item event"
    },
    privacyRows: {
      localOnlyLabel: "Local-only mode",
      localOnlyDetail: "Sends nothing. Full detail remains on this computer.",
      cloudAggregateLabel: "Cloud aggregate",
      cloudAggregateDetail: "Would send totals, timestamps, model ids, and latency only.",
      cloudDetailedLabel: "Cloud detailed",
      cloudDetailedDetail: "Would send numeric counts plus task and source enum labels.",
      settingsSyncLabel: "Settings sync",
      settingsSyncDetail: "Separate from usage data. Account sync must not copy local prompt preferences unless settings sync is explicitly enabled.",
      selectedSettingsLabel: "Selected settings",
      selectedSettingsDetail: "Future accounts can sync all settings or only selected settings, such as prompt display-name policy.",
      active: "Active",
      available: "Available",
      demoSelected: "Demo selected",
      futureOptIn: "Future opt-in",
      separateOptIn: "Separate opt-in"
    },
    aiToolLabels: {
      unknown: "Unknown",
      codex: "Codex",
      claude: "Claude Code",
      antigravity: "Antigravity (agy)",
      openai: "OpenAI SDK"
    },
    taskTypeLabels: {
      uncategorized: "Uncategorized",
      analysis: "Analysis",
      prd_drafting: "PRD drafting",
      architecture: "Architecture",
      code_generation: "Code generation",
      ui_design: "UI design",
      prompt_design: "Prompt design",
      refactoring: "Refactoring",
      code_review: "Code review",
      review_response: "Review response",
      test_generation: "Test generation",
      testing: "Testing",
      build_verification: "Build verification",
      debugging: "Debugging",
      bug_reproduction: "Bug reproduction",
      documentation: "Documentation",
      changelog: "Changelog",
      release_notes: "Release notes",
      release_packaging: "Release packaging",
      git_commit: "Git commit",
      commit_message: "Commit message",
      pull_request: "Pull request",
      workflow_setup: "Workflow setup"
    },
    usageStageLabels: {
      monitor: "Monitor",
      classify: "Classify",
      plan: "Plan",
      draft: "Draft",
      revise: "Revise",
      implement: "Implement",
      verify: "Verify",
      summarize: "Summarize"
    },
    tokenSourceLabels: {
      system: "System",
      user: "User",
      history: "History",
      repo_context: "Repo context",
      tool_output: "Tool output",
      generated_output: "Generated output",
      unknown: "Runtime total only"
    },
    syncModeContent: {
      local_only: {
        label: "Local only",
        status: "No cloud transfer",
        summary: "Detailed categorization stays on this computer.",
        cloudPayload: "Nothing is sent."
      },
      cloud_aggregate: {
        label: "Cloud aggregate",
        status: "Future opt-in",
        summary: "Account sync would include totals, timestamps, models, and latency.",
        cloudPayload: "Numeric aggregate fields only."
      },
      cloud_detailed: {
        label: "Cloud detailed",
        status: "Separate future opt-in",
        summary: "Detailed cloud charts would use numeric counts and enum labels only.",
        cloudPayload: "Numeric counts plus enum labels."
      }
    },
    forbiddenFieldLabels: [
      "command",
      "prompt",
      "response",
      "file path",
      "repo name",
      "branch name",
      "commit message",
      "terminal output",
      "log body",
      "diff",
      "source content",
      "environment value",
      "secret",
      "arbitrary extra fields"
    ]
  },
  ko: {
    localeName: "ko-KR",
    nav: {
      features: "기능",
      setup: "설정",
      about: "정보",
      download: "다운로드",
      overview: "개요",
      hotspots: "핫스팟",
      sessions: "작업",
      settings: "설정",
      intro: "인트로",
      privacy: "프라이버시"
    },
    intro: {
      navLabel: "인트로 탐색",
      footerLabel: "인트로 푸터 링크",
      dashboardPreviewAria: "대시보드 미리보기",
      dashboardPreview: "대시보드 미리보기",
      cloudDashboardPreview: "클라우드 대시보드 미리보기",
      heroLineOne: "AI 사용량을",
      heroLineTwo: "정확하게.",
      currentUsage: "현재 토큰 사용량",
      tokenTotal: (tokens) => `${tokens} 토큰`,
      tokenMetering: "토큰 미터링",
      cloudPreviewData: "클라우드 미리보기 데이터",
      syncModeStatus: "동기화 모드 상태",
      cloudNotConnected: "클라우드 미연결",
      localDetailUntilSync: "동기화를 켜기 전까지 상세 데이터는 macOS 앱에만 남습니다.",
      modelBreakdown: "모델 분류",
      taskBreakdown: "작업 분류",
      getStarted: "시작하기",
      headline: "모든 사용량을 Spill에.",
      body: "AI 사용량 미터링을 워크플로우에 연결합니다. 콘텐츠 수집 없이 안전한 토큰 수와 분류만 다룹니다.",
      continueWithGitHub: "GitHub로 계속",
      manualSetupDivider: "또는 수동 설정",
      installSpill: "Spill 설치",
      tokenMeteringInstallPrompt: "토큰 미터링 설치 프롬프트",
      alreadyHaveAccount: "이미 계정이 있나요?",
      signIn: "로그인",
      copyright: "© 2024 Spill. 모든 권리 보유. Don't hold it back, Just Spill it.",
      terms: "약관",
      twitter: "Twitter",
      instagram: "Instagram"
    },
    dashboard: {
      brand: "Spill Meter",
      navLabel: "대시보드 섹션",
      accountLabel: "로그인된 데모 계정",
      syncModeStatus: "동기화 모드 상태",
      viewConfiguration: "설정 보기",
      cloudSync: "클라우드 동기화",
      kpiAria: "토큰 핵심 지표",
      cloudPreviewTitle: "클라우드 대시보드 미리보기",
      cloudPreviewHeading: "로그인하면 호스팅 동기화를 사용할 수 있습니다.",
      cloudPreviewBody: "로컬 토큰 집계는 macOS 앱에 있습니다. 이 웹 화면은 향후 계정 대시보드이며 현재는 안전한 미리보기 데이터만 보여줍니다.",
      cloudRows: "클라우드 행",
      authNotConnected: "인증 미연결",
      openSyncContract: "동기화 계약 열기",
      footerBody: "토큰 수, 안전한 카테고리, 명시적인 동기화 제어."
    },
    panels: {
      taskTypeBreakdown: "작업 유형 분류",
      aiToolDistribution: "AI 도구 분포",
      aiToolDistributionDescription: "Codex, Claude Code, Antigravity/AGY 로컬 이벤트만 표시",
      noAIToolRows: "로컬 에이전트 이벤트가 여기에 표시됩니다.",
      previewTokens: (tokens) => `미리보기 토큰 ${tokens}`,
      viewDetails: "상세 보기",
      noTaskRows: "동기화된 토큰 행의 작업 분류가 여기에 표시됩니다.",
      tokenShare: (label) => `${label} 토큰 비율`,
      sourceHotspots: "토큰 소스 핫스팟",
      sourceHotspotsDescription: "숫자 소스 카테고리만 표시",
      source: "소스",
      tokens: "토큰",
      share: "비율",
      optimizationTip: "최적화 팁",
      optimizationTipBody: "소스 카테고리 합계가 높습니다. 클라우드 집계 보기를 켜기 전에 카테고리 규칙을 조정하세요.",
      sessions: "작업",
      sessionsDescription: (count) => `안전한 라벨과 시간 버킷으로 생성된 작업 ${count}개`,
      noSessions: "안전한 로컬 작업이 여기에 표시됩니다.",
      tokenLatency: (tokens, latency) => `${tokens} 토큰 / ${latency}`,
      spans: (count) => `이벤트 ${count}개`,
      stepTokenDetail: (model, tokens) => `${model} / ${tokens} 토큰`,
      unknownWorkItem: "라벨 없는 작업",
      tokenOnlyContract: "토큰 전용 계약",
      tokenOnlyContractDescription: "로컬 상세 우선, 클라우드 동기화는 명시적 opt-in만",
      sanitizerStatus: "정제 상태",
      sanitizerDetail: (events, fields, safe) =>
        `sync-safe 이벤트 ${events}개 준비 / 허용 필드 ${fields}개 출력 / ${safe ? "안전한 출력" : "검토 필요"}`,
      safeOutput: "안전한 출력",
      reviewNeeded: "검토 필요",
      allowlistPass: "Allowlist 통과",
      check: "확인 필요",
      neverIncluded: "클라우드 payload에 절대 포함하지 않음",
      toggle: "접기/펼치기"
    },
    syncContract: {
      ariaLabel: "동기화 계약",
      title: "동기화 계약",
      closeAria: "동기화 계약 닫기",
      syncModeAria: "동기화 모드",
      signInFirstTitle: "먼저 로그인",
      signInFirstBody: "클라우드 대시보드 행에는 인증된 계정이 필요합니다.",
      chooseDepthTitle: "동기화 깊이 선택",
      chooseDepthBody: "사용량 데이터 동기화와 설정 동기화는 별도입니다. 설정은 나중에 전체 또는 선택한 설정만 동기화할 수 있어야 합니다.",
      allowlistTitle: "허용 목록 payload",
      allowlistBody: (fields) => `안전한 필드 ${fields}개만 가능하며, 콘텐츠성 필드는 거부됩니다.`,
      close: "계약 닫기"
    },
    setupStep: {
      copied: "복사됨",
      copy: "복사",
      hiddenPromptDetail: "긴 지침을 이 화면에 펼치지 않고 전체 설정 프롬프트를 바로 복사합니다."
    },
    kpis: {
      totalTokens: "전체 토큰",
      inputTokens: "입력 토큰",
      outputTokens: "출력 토큰",
      avgLatency: "평균 지연",
      unavailable: "사용 불가",
      runtimeTimingUnavailable: "런타임이 timing을 제공하지 않음",
      modelUnavailable: "모델 정보 없음",
      previewSpans: (count) => `로컬 이벤트 ${count}개`,
      percentOfTotal: (percent) => `전체의 ${percent}%`,
      perRunSpanStep: "작업 이벤트당"
    },
    privacyRows: {
      localOnlyLabel: "로컬 전용 모드",
      localOnlyDetail: "아무것도 보내지 않습니다. 전체 상세 정보는 이 컴퓨터에 남습니다.",
      cloudAggregateLabel: "클라우드 집계",
      cloudAggregateDetail: "합계, 타임스탬프, 모델 ID, 지연 시간만 보냅니다.",
      cloudDetailedLabel: "클라우드 상세",
      cloudDetailedDetail: "숫자 카운트와 작업/소스 enum 라벨만 보냅니다.",
      settingsSyncLabel: "설정 동기화",
      settingsSyncDetail: "사용량 데이터와 별도입니다. 설정 동기화를 명시적으로 켜기 전에는 로컬 프롬프트 선호도를 계정에 복사하지 않습니다.",
      selectedSettingsLabel: "선택한 설정",
      selectedSettingsDetail: "향후 계정에서는 전체 설정 또는 프롬프트 표시명 정책 같은 특정 설정만 동기화할 수 있어야 합니다.",
      active: "활성",
      available: "사용 가능",
      demoSelected: "데모 선택됨",
      futureOptIn: "향후 opt-in",
      separateOptIn: "별도 opt-in"
    },
    aiToolLabels: {
      unknown: "알 수 없음",
      codex: "Codex",
      claude: "Claude Code",
      antigravity: "Antigravity (agy)",
      openai: "OpenAI SDK"
    },
    taskTypeLabels: {
      uncategorized: "미분류",
      analysis: "분석",
      prd_drafting: "PRD 작성",
      architecture: "아키텍처",
      code_generation: "코드 작성",
      ui_design: "UI 디자인",
      prompt_design: "프롬프트 설계",
      refactoring: "리팩터링",
      code_review: "코드 리뷰",
      review_response: "리뷰 대응",
      test_generation: "테스트 작성",
      testing: "테스트 실행",
      build_verification: "빌드 검증",
      debugging: "디버깅",
      bug_reproduction: "버그 재현",
      documentation: "문서화",
      changelog: "변경 로그",
      release_notes: "릴리스 노트",
      release_packaging: "릴리스 패키징",
      git_commit: "Git 커밋",
      commit_message: "커밋 메시지",
      pull_request: "Pull request",
      workflow_setup: "워크플로우 설정"
    },
    usageStageLabels: {
      monitor: "모니터링",
      classify: "분류",
      plan: "계획",
      draft: "초안",
      revise: "수정",
      implement: "구현",
      verify: "검증",
      summarize: "요약"
    },
    tokenSourceLabels: {
      system: "시스템",
      user: "사용자",
      history: "히스토리",
      repo_context: "저장소 컨텍스트",
      tool_output: "도구 출력",
      generated_output: "생성 출력",
      unknown: "런타임 합계만"
    },
    syncModeContent: {
      local_only: {
        label: "로컬 전용",
        status: "클라우드 전송 없음",
        summary: "상세 분류는 이 컴퓨터에만 남습니다.",
        cloudPayload: "아무것도 전송하지 않습니다."
      },
      cloud_aggregate: {
        label: "클라우드 집계",
        status: "향후 opt-in",
        summary: "계정 동기화는 합계, 타임스탬프, 모델, 지연 시간만 포함합니다.",
        cloudPayload: "숫자 집계 필드만."
      },
      cloud_detailed: {
        label: "클라우드 상세",
        status: "별도 향후 opt-in",
        summary: "상세 클라우드 차트는 숫자 카운트와 enum 라벨만 사용합니다.",
        cloudPayload: "숫자 카운트와 enum 라벨."
      }
    },
    forbiddenFieldLabels: [
      "명령",
      "프롬프트",
      "응답",
      "파일 경로",
      "저장소 이름",
      "브랜치 이름",
      "커밋 메시지",
      "터미널 출력",
      "로그 본문",
      "diff",
      "소스 내용",
      "환경 값",
      "비밀",
      "임의 추가 필드"
    ]
  },
  ja: {
    localeName: "ja-JP",
    nav: {
      features: "機能",
      setup: "設定",
      about: "概要",
      download: "ダウンロード",
      overview: "概要",
      hotspots: "ホットスポット",
      sessions: "作業",
      settings: "設定",
      intro: "イントロ",
      privacy: "プライバシー"
    },
    intro: {
      navLabel: "イントロナビゲーション",
      footerLabel: "イントロフッターリンク",
      dashboardPreviewAria: "ダッシュボードプレビュー",
      dashboardPreview: "ダッシュボードプレビュー",
      cloudDashboardPreview: "クラウドダッシュボードプレビュー",
      heroLineOne: "AI 使用量を",
      heroLineTwo: "正確に。",
      currentUsage: "現在のトークン使用量",
      tokenTotal: (tokens) => `${tokens} トークン`,
      tokenMetering: "トークン計測",
      cloudPreviewData: "クラウドプレビューデータ",
      syncModeStatus: "同期モード状態",
      cloudNotConnected: "クラウド未接続",
      localDetailUntilSync: "同期を有効にするまで詳細データは macOS アプリに残ります。",
      modelBreakdown: "モデル分類",
      taskBreakdown: "タスク分類",
      getStarted: "はじめる",
      headline: "すべての使用量を Spill へ。",
      body: "AI 使用量計測をワークフローに接続します。コンテンツ収集なしで、安全なトークン数と分類だけを扱います。",
      continueWithGitHub: "GitHub で続行",
      manualSetupDivider: "または手動で設定",
      installSpill: "Spill をインストール",
      tokenMeteringInstallPrompt: "トークン計測インストールプロンプト",
      alreadyHaveAccount: "すでにアカウントがありますか？",
      signIn: "サインイン",
      copyright: "© 2024 Spill. All rights reserved. Don't hold it back, Just Spill it.",
      terms: "利用規約",
      twitter: "Twitter",
      instagram: "Instagram"
    },
    dashboard: {
      brand: "Spill Meter",
      navLabel: "ダッシュボードセクション",
      accountLabel: "サインイン済みデモアカウント",
      syncModeStatus: "同期モード状態",
      viewConfiguration: "設定を見る",
      cloudSync: "クラウド同期",
      kpiAria: "トークン主要指標",
      cloudPreviewTitle: "クラウドダッシュボードプレビュー",
      cloudPreviewHeading: "サインインするとホスト同期を利用できます。",
      cloudPreviewBody: "ローカルトークン集計は macOS アプリにあります。この Web 画面は将来のアカウントダッシュボードで、現在は安全なプレビューデータのみを表示します。",
      cloudRows: "クラウド行",
      authNotConnected: "認証未接続",
      openSyncContract: "同期契約を開く",
      footerBody: "トークン数、安全なカテゴリ、明示的な同期制御。"
    },
    panels: {
      taskTypeBreakdown: "タスクタイプ分類",
      aiToolDistribution: "AI ツール分布",
      aiToolDistributionDescription: "Codex、Claude Code、Antigravity/AGY のローカルイベントのみ",
      noAIToolRows: "ローカルエージェントイベントがここに表示されます。",
      previewTokens: (tokens) => `${tokens} プレビュートークン`,
      viewDetails: "詳細を見る",
      noTaskRows: "同期されたトークン行のタスク分類がここに表示されます。",
      tokenShare: (label) => `${label} トークン比率`,
      sourceHotspots: "トークンソースホットスポット",
      sourceHotspotsDescription: "数値ソースカテゴリのみ",
      source: "ソース",
      tokens: "トークン",
      share: "比率",
      optimizationTip: "最適化ヒント",
      optimizationTipBody: "ソースカテゴリ合計が高い状態です。クラウド集計ビューを有効にする前にカテゴリルールを調整してください。",
      sessions: "作業",
      sessionsDescription: (count) => `安全なラベルと時間バケットから生成された作業 ${count}件`,
      noSessions: "安全なローカル作業がここに表示されます。",
      tokenLatency: (tokens, latency) => `${tokens} トークン / ${latency}`,
      spans: (count) => `イベント ${count}件`,
      stepTokenDetail: (model, tokens) => `${model} / ${tokens} トークン`,
      unknownWorkItem: "ラベルなし作業",
      tokenOnlyContract: "トークン専用契約",
      tokenOnlyContractDescription: "ローカル詳細を優先し、クラウド同期は明示的 opt-in のみ",
      sanitizerStatus: "サニタイズ状態",
      sanitizerDetail: (events, fields, safe) =>
        `sync-safe イベント ${events} 件準備 / 許可フィールド ${fields} 件出力 / ${safe ? "安全な出力" : "確認が必要"}`,
      safeOutput: "安全な出力",
      reviewNeeded: "確認が必要",
      allowlistPass: "Allowlist 通過",
      check: "確認",
      neverIncluded: "クラウド payload に含めないもの",
      toggle: "切り替え"
    },
    syncContract: {
      ariaLabel: "同期契約",
      title: "同期契約",
      closeAria: "同期契約を閉じる",
      syncModeAria: "同期モード",
      signInFirstTitle: "まずサインイン",
      signInFirstBody: "クラウドダッシュボード行には認証済みアカウントが必要です。",
      chooseDepthTitle: "同期深度を選択",
      chooseDepthBody: "使用量データ同期と設定同期は別です。設定は将来、全設定または選択した設定だけを同期できる必要があります。",
      allowlistTitle: "許可リスト payload",
      allowlistBody: (fields) => `安全なフィールド ${fields} 件のみ対象で、コンテンツ性フィールドは拒否されます。`,
      close: "契約を閉じる"
    },
    setupStep: {
      copied: "コピー済み",
      copy: "コピー",
      hiddenPromptDetail: "長い指示をこの画面に表示せず、完全な設定プロンプトをコピーします。"
    },
    kpis: {
      totalTokens: "総トークン",
      inputTokens: "入力トークン",
      outputTokens: "出力トークン",
      avgLatency: "平均遅延",
      unavailable: "利用不可",
      runtimeTimingUnavailable: "ランタイムが timing を提供していません",
      modelUnavailable: "モデル情報なし",
      previewSpans: (count) => `ローカルイベント ${count}件`,
      percentOfTotal: (percent) => `全体の${percent}%`,
      perRunSpanStep: "作業イベントごと"
    },
    privacyRows: {
      localOnlyLabel: "ローカル専用モード",
      localOnlyDetail: "何も送信しません。全詳細はこのコンピューターに残ります。",
      cloudAggregateLabel: "クラウド集計",
      cloudAggregateDetail: "合計、タイムスタンプ、モデル ID、遅延のみを送信します。",
      cloudDetailedLabel: "クラウド詳細",
      cloudDetailedDetail: "数値カウントとタスク/ソース enum ラベルのみを送信します。",
      settingsSyncLabel: "設定同期",
      settingsSyncDetail: "使用量データとは別です。設定同期を明示的に有効にするまで、ローカルのプロンプト設定はアカウントへコピーされません。",
      selectedSettingsLabel: "選択した設定",
      selectedSettingsDetail: "将来のアカウントでは、全設定またはプロンプト表示名ポリシーなど選択した設定だけを同期できる必要があります。",
      active: "有効",
      available: "利用可能",
      demoSelected: "デモ選択中",
      futureOptIn: "将来 opt-in",
      separateOptIn: "別途 opt-in"
    },
    aiToolLabels: {
      unknown: "不明",
      codex: "Codex",
      claude: "Claude Code",
      antigravity: "Antigravity (agy)",
      openai: "OpenAI SDK"
    },
    taskTypeLabels: {
      uncategorized: "未分類",
      analysis: "分析",
      prd_drafting: "PRD 作成",
      architecture: "アーキテクチャ",
      code_generation: "コード生成",
      ui_design: "UI デザイン",
      prompt_design: "プロンプト設計",
      refactoring: "リファクタリング",
      code_review: "コードレビュー",
      review_response: "レビュー対応",
      test_generation: "テスト作成",
      testing: "テスト実行",
      build_verification: "ビルド検証",
      debugging: "デバッグ",
      bug_reproduction: "バグ再現",
      documentation: "ドキュメント",
      changelog: "変更ログ",
      release_notes: "リリースノート",
      release_packaging: "リリースパッケージ",
      git_commit: "Git コミット",
      commit_message: "コミットメッセージ",
      pull_request: "Pull request",
      workflow_setup: "ワークフロー設定"
    },
    usageStageLabels: {
      monitor: "監視",
      classify: "分類",
      plan: "計画",
      draft: "下書き",
      revise: "修正",
      implement: "実装",
      verify: "検証",
      summarize: "要約"
    },
    tokenSourceLabels: {
      system: "システム",
      user: "ユーザー",
      history: "履歴",
      repo_context: "リポジトリコンテキスト",
      tool_output: "ツール出力",
      generated_output: "生成出力",
      unknown: "ランタイム合計のみ"
    },
    syncModeContent: {
      local_only: {
        label: "ローカルのみ",
        status: "クラウド転送なし",
        summary: "詳細分類はこのコンピューターに残ります。",
        cloudPayload: "何も送信しません。"
      },
      cloud_aggregate: {
        label: "クラウド集計",
        status: "将来 opt-in",
        summary: "アカウント同期には合計、タイムスタンプ、モデル、遅延のみが含まれます。",
        cloudPayload: "数値集計フィールドのみ。"
      },
      cloud_detailed: {
        label: "クラウド詳細",
        status: "別途将来 opt-in",
        summary: "詳細クラウドチャートは数値カウントと enum ラベルのみを使用します。",
        cloudPayload: "数値カウントと enum ラベル。"
      }
    },
    forbiddenFieldLabels: [
      "コマンド",
      "プロンプト",
      "応答",
      "ファイルパス",
      "リポジトリ名",
      "ブランチ名",
      "コミットメッセージ",
      "ターミナル出力",
      "ログ本文",
      "diff",
      "ソース内容",
      "環境値",
      "シークレット",
      "任意の追加フィールド"
    ]
  }
} satisfies Record<TokenMeteringLocale, TokenMeteringMessages>;

export type { TokenMeteringMessages };

export function detectTokenMeteringLocale(language = browserLanguage()): TokenMeteringLocale {
  const normalized = language.toLowerCase();
  if (normalized.startsWith("ko")) {
    return "ko";
  }
  if (normalized.startsWith("ja")) {
    return "ja";
  }
  return "en";
}

export function getTokenMeteringMessages(
  locale = detectTokenMeteringLocale()
): TokenMeteringMessages {
  return tokenMeteringMessages[locale];
}

export function tokenMeteringLocaleName(locale = detectTokenMeteringLocale()): string {
  return tokenMeteringMessages[locale].localeName;
}

function browserLanguage(): string {
  return typeof navigator === "undefined" ? "en-US" : navigator.language;
}
