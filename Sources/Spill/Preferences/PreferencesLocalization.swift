import Foundation

enum PreferencesTextKey: String {
    case preferencesWindowTitle
    case general
    case menuBar
    case menuBarAndNotch
    case tokenMetering
    case windowManagement
    case statusAndCaffeine
    case developerOptions
    case developerOptionsDetail
    case debugOnly
    case checking
    case checkForUpdates
    case launchSettings
    case launchAtLogin
    case launchAtLoginUnavailable
    case dashboardOnboardingPreview
    case dashboardOnboardingPreviewDetail
    case aiDashboardOnboardingPreview
    case aiDashboardOnboardingPreviewDetail
    case languageSettings
    case appLanguage
    case language
    case permissionsAndDiagnostics
    case updates
    case menuBarIconAnimation
    case useSpillAnimation
    case menuBarTriggerIcon
    case globalShortcut
    case keyboardShortcut
    case windowSnapShortcuts
    case statusModules
    case caffeineSettings
    case feedbackContribution
    case githubOpenSource
    case openSourceLicense
    case preview
    case currentVersion
    case copied
    case copyInstallCommand
    case notes
    case terminalInstallCommand
    case checkingForUpdates
    case upToDate
    case updateNow
    case openInstaller
    case downloadDMG
    case dashboardChecksInApp
    case dashboardChecksGitHub
    case updateInsideApp
    case updateWithInstaller
    case updateWithCommandOrDMG
    case unsupportedVersion
    case newerThanVersion
    case accessibilityActive
    case accessibilityNeeded
    case on
    case off
    case openPanel
    case scanning
    case refreshScanner
    case accessibilityPermissionDetail
    case accessibilityPermissionRelaunch
    case requestAccess
    case systemSettings
    case recheck
    case relaunch
    case permissionDiagnostics
    case itemCount
    case caffeine
    case defaultDuration
    case keepDisplayAwakeDuringCaffeine
    case showRemainingTimeInClockArea
    case warningShowNeverDuration
    case neverCaffeineWarning
    case panelStatus
    case panelStatusDetail
    case aggregate
    case statusValueBold
    case statusFontDesign
    case statusValueSize
    case panelSectionSpacing
    case fontDefault
    case fontRounded
    case fontMono
    case clockAreaStatus
    case clockAreaStatusDetail
    case clockAreaCompactMode
    case clockAreaCompactModeDetail
    case clockAreaSplitGroups
    case clockAreaSplitGroupsDetail
    case clockAreaTextBold
    case clockAreaTextSize
    case layout
    case decimals
    case highlight
    case inline
    case stacked
    case iconOnly
    case bundleID
    case bundle
    case executable
    case pid
    case appBundleLaunch
    case axTrusted
}

enum PreferencesL10n {
    static func text(
        _ key: PreferencesTextKey,
        appLanguage: SpillAppLanguage = .persisted(),
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        let language = resolvedLanguage(appLanguage: appLanguage, preferredLanguages: preferredLanguages)
        return table[language]?[key] ?? table[.english]?[key] ?? key.rawValue
    }

    static func languageDetail(
        _ selectedLanguage: SpillAppLanguage,
        appLanguage: SpillAppLanguage = .persisted(),
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        let language = resolvedLanguage(appLanguage: appLanguage, preferredLanguages: preferredLanguages)
        switch (language, selectedLanguage) {
        case (.english, .automatic):
            return "Follow macOS language"
        case (.english, .english):
            return "Use English"
        case (.english, .korean):
            return "Use Korean"
        case (.english, .japanese):
            return "Use Japanese"
        case (.korean, .automatic):
            return "macOS 언어를 따릅니다"
        case (.korean, .english):
            return "영어 사용"
        case (.korean, .korean):
            return "한국어 사용"
        case (.korean, .japanese):
            return "일본어 사용"
        case (.japanese, .automatic):
            return "macOS の言語に合わせる"
        case (.japanese, .english):
            return "英語を使用"
        case (.japanese, .korean):
            return "韓国語を使用"
        case (.japanese, .japanese):
            return "日本語を使用"
        }
    }

    static func itemCount(
        _ count: Int,
        appLanguage: SpillAppLanguage = .persisted(),
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        let language = resolvedLanguage(appLanguage: appLanguage, preferredLanguages: preferredLanguages)
        switch language {
        case .english:
            return "\(count) items"
        case .korean:
            return "\(count)개 항목"
        case .japanese:
            return "\(count)件"
        }
    }

    static func upToDate(
        version: String,
        appLanguage: SpillAppLanguage = .persisted(),
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        let template = text(.upToDate, appLanguage: appLanguage, preferredLanguages: preferredLanguages)
        return String(format: template, version)
    }

    static func unsupportedVersion(
        version: String,
        requirement: String,
        appLanguage: SpillAppLanguage = .persisted(),
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        let template = text(.unsupportedVersion, appLanguage: appLanguage, preferredLanguages: preferredLanguages)
        return String(format: template, version, requirement)
    }

    static func newerThanVersion(
        _ version: String,
        appLanguage: SpillAppLanguage = .persisted(),
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        let template = text(.newerThanVersion, appLanguage: appLanguage, preferredLanguages: preferredLanguages)
        return String(format: template, version)
    }

    static func availableUpdateMessage(
        version: String,
        key: PreferencesTextKey,
        appLanguage: SpillAppLanguage = .persisted(),
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        let template = text(key, appLanguage: appLanguage, preferredLanguages: preferredLanguages)
        return String(format: template, version)
    }

    private enum ResolvedLanguage {
        case english
        case korean
        case japanese
    }

    private static func resolvedLanguage(
        appLanguage: SpillAppLanguage,
        preferredLanguages: [String]
    ) -> ResolvedLanguage {
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

    private static func matching(_ languageID: String) -> ResolvedLanguage? {
        let normalized = languageID.lowercased()
        if normalized.hasPrefix("ko") { return .korean }
        if normalized.hasPrefix("ja") { return .japanese }
        if normalized.hasPrefix("en") { return .english }
        return nil
    }

    private static let table: [ResolvedLanguage: [PreferencesTextKey: String]] = [
        .english: [
            .preferencesWindowTitle: "Spill Preferences",
            .general: "General",
            .menuBar: "Menu Bar",
            .menuBarAndNotch: "Menu Bar",
            .tokenMetering: "Token Metering",
            .windowManagement: "Window Management",
            .statusAndCaffeine: "Status & Caffeine",
            .developerOptions: "Developer Options",
            .developerOptionsDetail: "Debug-only preview switches for checking first-run states without changing saved data.",
            .debugOnly: "Debug only",
            .checking: "Checking",
            .checkForUpdates: "Check for Updates",
            .launchSettings: "Launch Settings",
            .launchAtLogin: "Launch at Login",
            .launchAtLoginUnavailable: "Launch at Login is available after packaging Spill as a .app bundle.",
            .dashboardOnboardingPreview: "Dashboard onboarding preview",
            .dashboardOnboardingPreviewDetail: "Shows the panel as a first-run preview without changing local actions or token usage data.",
            .aiDashboardOnboardingPreview: "AI dashboard onboarding preview",
            .aiDashboardOnboardingPreviewDetail: "Shows the local token dashboard and panel token card as the setup preview without deleting token records.",
            .languageSettings: "Language Settings",
            .appLanguage: "App Language",
            .language: "Language",
            .permissionsAndDiagnostics: "Permissions & Diagnostics",
            .updates: "Updates",
            .menuBarIconAnimation: "Menu Bar Icon & Animation",
            .useSpillAnimation: "Use spill animation",
            .menuBarTriggerIcon: "Menu bar trigger icon",
            .globalShortcut: "Global Shortcut",
            .keyboardShortcut: "Keyboard shortcut",
            .windowSnapShortcuts: "Window Snap Shortcuts",
            .statusModules: "Status Modules",
            .caffeineSettings: "Caffeine Settings",
            .feedbackContribution: "Feedback & Contribution",
            .githubOpenSource: "GitHub Open Source",
            .openSourceLicense: "Spill is proudly open-source under the MIT license.",
            .preview: "Preview",
            .currentVersion: "Current version",
            .copied: "Copied",
            .copyInstallCommand: "Copy Install Command",
            .notes: "Notes",
            .terminalInstallCommand: "Terminal install command",
            .checkingForUpdates: "Checking for updates...",
            .upToDate: "Spill is up to date (%@).",
            .updateNow: "Update Now",
            .openInstaller: "Open Installer",
            .downloadDMG: "Download DMG",
            .dashboardChecksInApp: "Dashboard checks once per day. Use Check for Updates here to start the in-app updater.",
            .dashboardChecksGitHub: "Dashboard checks once per day. Manual checks use the latest GitHub release metadata.",
            .updateInsideApp: "Version %@ is available. Update inside the app.",
            .updateWithInstaller: "Version %@ is available. Open the signed installer package to update.",
            .updateWithCommandOrDMG: "Version %@ is available. Copy the terminal command or download the DMG.",
            .unsupportedVersion: "Version %@ requires macOS %@.",
            .newerThanVersion: "newer than %@",
            .accessibilityActive: "Accessibility Active",
            .accessibilityNeeded: "Accessibility Needed",
            .on: "ON",
            .off: "OFF",
            .openPanel: "Open Panel",
            .scanning: "Scanning",
            .refreshScanner: "Refresh Scanner",
            .accessibilityPermissionDetail: "Spill needs Accessibility permission to discover and activate menu bar items owned by other apps.",
            .accessibilityPermissionRelaunch: "After granting permission in System Settings, relaunch Spill if it still shows as inactive.",
            .requestAccess: "Request Access",
            .systemSettings: "System Settings",
            .recheck: "Recheck",
            .relaunch: "Relaunch",
            .permissionDiagnostics: "Permission Diagnostics",
            .itemCount: "Items",
            .caffeine: "Caffeine",
            .defaultDuration: "Default duration",
            .keepDisplayAwakeDuringCaffeine: "Keep display awake during Caffeine",
            .showRemainingTimeInClockArea: "Show remaining time in clock area",
            .warningShowNeverDuration: "Warning: show Never duration",
            .neverCaffeineWarning: "Never keeps Caffeine active until you stop it manually.",
            .panelStatus: "Panel Status",
            .panelStatusDetail: "Controls the status cards inside the Spill panel.",
            .aggregate: "Aggregate",
            .statusValueBold: "Bold Values",
            .statusFontDesign: "Value Font",
            .statusValueSize: "Value Size",
            .panelSectionSpacing: "Panel Section Spacing",
            .fontDefault: "Default",
            .fontRounded: "Rounded",
            .fontMono: "Mono",
            .clockAreaStatus: "Clock Area",
            .clockAreaStatusDetail: "Shown next to the macOS clock. Clicking AI opens the local token dashboard.",
            .clockAreaCompactMode: "Compact Status Values",
            .clockAreaCompactModeDetail: "Use tighter icon/value rendering only when you choose a compact menu bar.",
            .clockAreaSplitGroups: "Split Status Groups",
            .clockAreaSplitGroupsDetail: "Separate Main, System, and AI into independent menu bar items.",
            .clockAreaTextBold: "Bold Clock Text",
            .clockAreaTextSize: "Clock Text Size",
            .layout: "Layout",
            .decimals: "CPU/MEM Decimals",
            .highlight: "High Usage",
            .inline: "Horizontal",
            .stacked: "Vertical",
            .iconOnly: "Icon Only",
            .bundleID: "Bundle ID",
            .bundle: "Bundle",
            .executable: "Executable",
            .pid: "PID",
            .appBundleLaunch: "App bundle launch",
            .axTrusted: "AX trusted"
        ],
        .korean: [
            .preferencesWindowTitle: "Spill 설정",
            .general: "일반",
            .menuBar: "메뉴 막대",
            .menuBarAndNotch: "메뉴 막대",
            .tokenMetering: "토큰 미터링",
            .windowManagement: "윈도우 관리",
            .statusAndCaffeine: "상태 및 카페인",
            .developerOptions: "개발옵션",
            .developerOptionsDetail: "저장된 데이터는 유지한 채 첫 실행 상태를 확인하는 디버그 전용 옵션입니다.",
            .debugOnly: "디버그 전용",
            .checking: "확인 중",
            .checkForUpdates: "업데이트 확인",
            .launchSettings: "실행 설정",
            .launchAtLogin: "로그인 시 실행",
            .launchAtLoginUnavailable: "Spill이 .app 번들로 패키징된 뒤 로그인 시 실행을 사용할 수 있습니다.",
            .dashboardOnboardingPreview: "대시보드 온보딩 미리보기",
            .dashboardOnboardingPreviewDetail: "로컬 액션과 토큰 사용량 데이터는 유지한 채 패널을 첫 실행 상태로 보여줍니다.",
            .aiDashboardOnboardingPreview: "AI 대시보드 온보딩 미리보기",
            .aiDashboardOnboardingPreviewDetail: "토큰 기록을 삭제하지 않고 로컬 토큰 대시보드와 패널 토큰 카드를 설정 미리보기 상태로 보여줍니다.",
            .languageSettings: "언어 설정",
            .appLanguage: "앱 언어",
            .language: "언어",
            .permissionsAndDiagnostics: "권한 및 진단",
            .updates: "업데이트",
            .menuBarIconAnimation: "메뉴 막대 아이콘 및 애니메이션",
            .useSpillAnimation: "Spill 애니메이션 사용",
            .menuBarTriggerIcon: "메뉴 막대 트리거 아이콘",
            .globalShortcut: "전역 단축키",
            .keyboardShortcut: "키보드 단축키",
            .windowSnapShortcuts: "윈도우 스냅 단축키",
            .statusModules: "상태 모듈",
            .caffeineSettings: "카페인 설정",
            .feedbackContribution: "피드백 및 기여",
            .githubOpenSource: "GitHub 오픈소스",
            .openSourceLicense: "Spill은 MIT 라이선스의 오픈소스 앱입니다.",
            .preview: "미리보기",
            .currentVersion: "현재 버전",
            .copied: "복사됨",
            .copyInstallCommand: "설치 명령 복사",
            .notes: "노트",
            .terminalInstallCommand: "터미널 설치 명령",
            .checkingForUpdates: "업데이트 확인 중...",
            .upToDate: "Spill은 최신 상태입니다 (%@).",
            .updateNow: "지금 업데이트",
            .openInstaller: "설치 프로그램 열기",
            .downloadDMG: "DMG 다운로드",
            .dashboardChecksInApp: "대시보드는 하루에 한 번 확인합니다. 여기서 업데이트 확인을 누르면 앱 내 업데이터를 시작합니다.",
            .dashboardChecksGitHub: "대시보드는 하루에 한 번 확인합니다. 수동 확인은 최신 GitHub 릴리스 정보를 사용합니다.",
            .updateInsideApp: "버전 %@ 사용 가능. 앱 안에서 업데이트하세요.",
            .updateWithInstaller: "버전 %@ 사용 가능. 서명된 설치 패키지를 열어 업데이트하세요.",
            .updateWithCommandOrDMG: "버전 %@ 사용 가능. 터미널 명령을 복사하거나 DMG를 다운로드하세요.",
            .unsupportedVersion: "버전 %@은 macOS %@ 이상이 필요합니다.",
            .newerThanVersion: "%@보다 최신 버전",
            .accessibilityActive: "손쉬운 사용 활성",
            .accessibilityNeeded: "손쉬운 사용 권한 필요",
            .on: "켬",
            .off: "끔",
            .openPanel: "패널 열기",
            .scanning: "스캔 중",
            .refreshScanner: "스캐너 새로고침",
            .accessibilityPermissionDetail: "Spill이 다른 앱의 메뉴 막대 항목을 찾고 활성화하려면 손쉬운 사용 권한이 필요합니다.",
            .accessibilityPermissionRelaunch: "시스템 설정에서 권한을 부여한 뒤에도 비활성으로 표시되면 Spill을 다시 실행하세요.",
            .requestAccess: "권한 요청",
            .systemSettings: "시스템 설정",
            .recheck: "다시 확인",
            .relaunch: "다시 실행",
            .permissionDiagnostics: "권한 진단",
            .itemCount: "항목",
            .caffeine: "카페인",
            .defaultDuration: "기본 지속 시간",
            .keepDisplayAwakeDuringCaffeine: "카페인 중 디스플레이 깨우기 유지",
            .showRemainingTimeInClockArea: "시계 영역에 남은 시간 표시",
            .warningShowNeverDuration: "경고: Never 지속 시간 표시",
            .neverCaffeineWarning: "Never는 수동으로 중지할 때까지 카페인을 활성 상태로 유지합니다.",
            .panelStatus: "패널 상태",
            .panelStatusDetail: "Spill 패널 안의 상태 카드 표시를 조정합니다.",
            .aggregate: "집계",
            .statusValueBold: "값 굵게",
            .statusFontDesign: "값 글꼴",
            .statusValueSize: "값 크기",
            .panelSectionSpacing: "패널 섹션 간격",
            .fontDefault: "기본",
            .fontRounded: "둥근",
            .fontMono: "고정폭",
            .clockAreaStatus: "시계 옆 상태",
            .clockAreaStatusDetail: "macOS 시계 옆에 표시됩니다. AI를 누르면 로컬 토큰 대시보드가 열립니다.",
            .clockAreaCompactMode: "상태값 축소 표시",
            .clockAreaCompactModeDetail: "선택한 경우에만 아이콘과 값을 더 촘촘한 메뉴 막대 형태로 표시합니다.",
            .clockAreaSplitGroups: "상태 그룹 분리",
            .clockAreaSplitGroupsDetail: "Main, 시스템, AI를 각각 독립된 메뉴 막대 항목으로 나눕니다.",
            .clockAreaTextBold: "시계 옆 텍스트 굵게",
            .clockAreaTextSize: "시계 옆 텍스트 크기",
            .layout: "레이아웃",
            .decimals: "CPU/MEM 소수점",
            .highlight: "높은 사용량",
            .inline: "가로",
            .stacked: "세로",
            .iconOnly: "아이콘만",
            .bundleID: "번들 ID",
            .bundle: "번들",
            .executable: "실행 파일",
            .pid: "PID",
            .appBundleLaunch: "앱 번들 실행",
            .axTrusted: "AX 신뢰됨"
        ],
        .japanese: [
            .preferencesWindowTitle: "Spill 設定",
            .general: "一般",
            .menuBar: "メニューバー",
            .menuBarAndNotch: "メニューバー",
            .tokenMetering: "トークン計測",
            .windowManagement: "ウィンドウ管理",
            .statusAndCaffeine: "状態とカフェイン",
            .developerOptions: "開発者オプション",
            .developerOptionsDetail: "保存データを変えずに初回状態を確認するデバッグ専用オプションです。",
            .debugOnly: "デバッグのみ",
            .checking: "確認中",
            .checkForUpdates: "アップデートを確認",
            .launchSettings: "起動設定",
            .launchAtLogin: "ログイン時に起動",
            .launchAtLoginUnavailable: "Spill を .app バンドルとしてパッケージ化すると、ログイン時起動を使用できます。",
            .dashboardOnboardingPreview: "ダッシュボードオンボーディングプレビュー",
            .dashboardOnboardingPreviewDetail: "ローカルのアクションとトークン使用量データを変えずに、パネルを初回状態で表示します。",
            .aiDashboardOnboardingPreview: "AI ダッシュボードのオンボーディングプレビュー",
            .aiDashboardOnboardingPreviewDetail: "トークン記録を削除せず、ローカルトークンダッシュボードとパネルのトークンカードを設定プレビュー状態で表示します。",
            .languageSettings: "言語設定",
            .appLanguage: "アプリの言語",
            .language: "言語",
            .permissionsAndDiagnostics: "権限と診断",
            .updates: "アップデート",
            .menuBarIconAnimation: "メニューバーアイコンとアニメーション",
            .useSpillAnimation: "Spill アニメーションを使用",
            .menuBarTriggerIcon: "メニューバートリガーアイコン",
            .globalShortcut: "グローバルショートカット",
            .keyboardShortcut: "キーボードショートカット",
            .windowSnapShortcuts: "ウィンドウスナップショートカット",
            .statusModules: "状態モジュール",
            .caffeineSettings: "カフェイン設定",
            .feedbackContribution: "フィードバックと貢献",
            .githubOpenSource: "GitHub オープンソース",
            .openSourceLicense: "Spill は MIT ライセンスのオープンソースアプリです。",
            .preview: "プレビュー",
            .currentVersion: "現在のバージョン",
            .copied: "コピー済み",
            .copyInstallCommand: "インストールコマンドをコピー",
            .notes: "ノート",
            .terminalInstallCommand: "ターミナルインストールコマンド",
            .checkingForUpdates: "アップデートを確認中...",
            .upToDate: "Spill は最新です (%@)。",
            .updateNow: "今すぐアップデート",
            .openInstaller: "インストーラーを開く",
            .downloadDMG: "DMG をダウンロード",
            .dashboardChecksInApp: "ダッシュボードは 1 日 1 回確認します。ここでアップデート確認を使うとアプリ内アップデーターを開始します。",
            .dashboardChecksGitHub: "ダッシュボードは 1 日 1 回確認します。手動確認は最新の GitHub リリース情報を使用します。",
            .updateInsideApp: "バージョン %@ が利用可能です。アプリ内でアップデートしてください。",
            .updateWithInstaller: "バージョン %@ が利用可能です。署名済みインストーラーパッケージを開いて更新してください。",
            .updateWithCommandOrDMG: "バージョン %@ が利用可能です。ターミナルコマンドをコピーするか DMG をダウンロードしてください。",
            .unsupportedVersion: "バージョン %@ には macOS %@ が必要です。",
            .newerThanVersion: "%@ より新しいバージョン",
            .accessibilityActive: "アクセシビリティ有効",
            .accessibilityNeeded: "アクセシビリティ権限が必要",
            .on: "オン",
            .off: "オフ",
            .openPanel: "パネルを開く",
            .scanning: "スキャン中",
            .refreshScanner: "スキャナーを更新",
            .accessibilityPermissionDetail: "Spill が他のアプリのメニューバー項目を検出して有効化するにはアクセシビリティ権限が必要です。",
            .accessibilityPermissionRelaunch: "システム設定で権限を付与した後も無効と表示される場合は Spill を再起動してください。",
            .requestAccess: "アクセスを要求",
            .systemSettings: "システム設定",
            .recheck: "再確認",
            .relaunch: "再起動",
            .permissionDiagnostics: "権限診断",
            .itemCount: "項目",
            .caffeine: "カフェイン",
            .defaultDuration: "既定の時間",
            .keepDisplayAwakeDuringCaffeine: "カフェイン中はディスプレイを起動したままにする",
            .showRemainingTimeInClockArea: "時計エリアに残り時間を表示",
            .warningShowNeverDuration: "警告: Never の時間を表示",
            .neverCaffeineWarning: "Never は手動で停止するまでカフェインを有効にします。",
            .panelStatus: "パネル状態",
            .panelStatusDetail: "Spill パネル内の状態カード表示を調整します。",
            .aggregate: "集計",
            .statusValueBold: "値を太字",
            .statusFontDesign: "値のフォント",
            .statusValueSize: "値のサイズ",
            .panelSectionSpacing: "パネルセクション間隔",
            .fontDefault: "既定",
            .fontRounded: "丸ゴシック",
            .fontMono: "等幅",
            .clockAreaStatus: "時計横の状態",
            .clockAreaStatusDetail: "macOS の時計横に表示されます。AI をクリックするとローカルトークンダッシュボードを開きます。",
            .clockAreaCompactMode: "状態値をコンパクト表示",
            .clockAreaCompactModeDetail: "選択した場合だけ、アイコンと値をより詰めたメニューバー表示にします。",
            .clockAreaSplitGroups: "状態グループを分離",
            .clockAreaSplitGroupsDetail: "Main、システム、AI を個別のメニューバー項目に分けます。",
            .clockAreaTextBold: "時計横テキストを太字",
            .clockAreaTextSize: "時計横テキストサイズ",
            .layout: "レイアウト",
            .decimals: "CPU/MEM 小数",
            .highlight: "高使用率",
            .inline: "横",
            .stacked: "縦",
            .iconOnly: "アイコンのみ",
            .bundleID: "Bundle ID",
            .bundle: "バンドル",
            .executable: "実行ファイル",
            .pid: "PID",
            .appBundleLaunch: "アプリバンドル起動",
            .axTrusted: "AX 信頼済み"
        ]
    ]
}
