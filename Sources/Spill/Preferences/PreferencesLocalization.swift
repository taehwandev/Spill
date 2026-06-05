import Foundation

enum PreferencesTextKey: String {
    case preferencesWindowTitle
    case general
    case menuBar
    case menuBarAndNotch
    case tokenMetering
    case windowManagement
    case statusAndCaffeine
    case checking
    case checkForUpdates
    case launchSettings
    case launchAtLogin
    case launchAtLoginUnavailable
    case languageSettings
    case appLanguage
    case language
    case permissionsAndDiagnostics
    case updates
    case menuBarIconAnimation
    case useSpillAnimation
    case menuBarTriggerIcon
    case menuBarIconSpacing
    case advancedNotchScan
    case advancedNotchScanDetail
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
    case detectedItems
    case panelItems
    case autoRefresh
    case refreshInterval
    case caffeine
    case defaultDuration
    case keepDisplayAwakeDuringCaffeine
    case showRemainingTimeInClockArea
    case warningShowNeverDuration
    case neverCaffeineWarning
    case panelStatus
    case coreBars
    case aggregate
    case cpuCoreBars
    case clockAreaStatus
    case layout
    case format
    case decimals
    case highlight
    case labelAndPercent
    case percentOnly
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
            .menuBarAndNotch: "Menu Bar & Notch",
            .tokenMetering: "Token Metering",
            .windowManagement: "Window Management",
            .statusAndCaffeine: "Status & Caffeine",
            .checking: "Checking",
            .checkForUpdates: "Check for Updates",
            .launchSettings: "Launch Settings",
            .launchAtLogin: "Launch at Login",
            .launchAtLoginUnavailable: "Launch at Login is available after packaging Spill as a .app bundle.",
            .languageSettings: "Language Settings",
            .appLanguage: "App Language",
            .language: "Language",
            .permissionsAndDiagnostics: "Permissions & Diagnostics",
            .updates: "Updates",
            .menuBarIconAnimation: "Menu Bar Icon & Animation",
            .useSpillAnimation: "Use spill animation",
            .menuBarTriggerIcon: "Menu bar trigger icon",
            .menuBarIconSpacing: "Menu bar icon spacing",
            .advancedNotchScan: "Advanced Notch Scan",
            .advancedNotchScanDetail: "Best-effort menu bar scanning is an advanced pinning and diagnostics tool. It is not required for normal panel use.",
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
            .detectedItems: "Detected Items",
            .panelItems: "Panel items",
            .autoRefresh: "Auto refresh",
            .refreshInterval: "Refresh interval",
            .caffeine: "Caffeine",
            .defaultDuration: "Default duration",
            .keepDisplayAwakeDuringCaffeine: "Keep display awake during Caffeine",
            .showRemainingTimeInClockArea: "Show remaining time in clock area",
            .warningShowNeverDuration: "Warning: show Never duration",
            .neverCaffeineWarning: "Never keeps Caffeine active until you stop it manually.",
            .panelStatus: "Panel Status",
            .coreBars: "Core Bars",
            .aggregate: "Aggregate",
            .cpuCoreBars: "CPU Core Bars",
            .clockAreaStatus: "Clock Area Status",
            .layout: "Layout",
            .format: "Format",
            .decimals: "Decimals",
            .highlight: "Highlight",
            .labelAndPercent: "Label + %",
            .percentOnly: "% Only",
            .inline: "Inline",
            .stacked: "Stacked",
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
            .menuBarAndNotch: "메뉴 막대 및 노치",
            .tokenMetering: "토큰 미터링",
            .windowManagement: "윈도우 관리",
            .statusAndCaffeine: "상태 및 카페인",
            .checking: "확인 중",
            .checkForUpdates: "업데이트 확인",
            .launchSettings: "실행 설정",
            .launchAtLogin: "로그인 시 실행",
            .launchAtLoginUnavailable: "Spill이 .app 번들로 패키징된 뒤 로그인 시 실행을 사용할 수 있습니다.",
            .languageSettings: "언어 설정",
            .appLanguage: "앱 언어",
            .language: "언어",
            .permissionsAndDiagnostics: "권한 및 진단",
            .updates: "업데이트",
            .menuBarIconAnimation: "메뉴 막대 아이콘 및 애니메이션",
            .useSpillAnimation: "Spill 애니메이션 사용",
            .menuBarTriggerIcon: "메뉴 막대 트리거 아이콘",
            .menuBarIconSpacing: "메뉴 막대 아이콘 간격",
            .advancedNotchScan: "고급 노치 스캔",
            .advancedNotchScanDetail: "메뉴 막대 스캔은 고급 고정 및 진단 도구입니다. 일반 패널 사용에는 필요하지 않습니다.",
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
            .detectedItems: "감지된 항목",
            .panelItems: "패널 항목",
            .autoRefresh: "자동 새로고침",
            .refreshInterval: "새로고침 간격",
            .caffeine: "카페인",
            .defaultDuration: "기본 지속 시간",
            .keepDisplayAwakeDuringCaffeine: "카페인 중 디스플레이 깨우기 유지",
            .showRemainingTimeInClockArea: "시계 영역에 남은 시간 표시",
            .warningShowNeverDuration: "경고: Never 지속 시간 표시",
            .neverCaffeineWarning: "Never는 수동으로 중지할 때까지 카페인을 활성 상태로 유지합니다.",
            .panelStatus: "패널 상태",
            .coreBars: "코어 바",
            .aggregate: "집계",
            .cpuCoreBars: "CPU 코어 바",
            .clockAreaStatus: "시계 영역 상태",
            .layout: "레이아웃",
            .format: "형식",
            .decimals: "소수점",
            .highlight: "강조",
            .labelAndPercent: "레이블 + %",
            .percentOnly: "%만",
            .inline: "한 줄",
            .stacked: "쌓기",
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
            .menuBarAndNotch: "メニューバーとノッチ",
            .tokenMetering: "トークン計測",
            .windowManagement: "ウィンドウ管理",
            .statusAndCaffeine: "状態とカフェイン",
            .checking: "確認中",
            .checkForUpdates: "アップデートを確認",
            .launchSettings: "起動設定",
            .launchAtLogin: "ログイン時に起動",
            .launchAtLoginUnavailable: "Spill を .app バンドルとしてパッケージ化すると、ログイン時起動を使用できます。",
            .languageSettings: "言語設定",
            .appLanguage: "アプリの言語",
            .language: "言語",
            .permissionsAndDiagnostics: "権限と診断",
            .updates: "アップデート",
            .menuBarIconAnimation: "メニューバーアイコンとアニメーション",
            .useSpillAnimation: "Spill アニメーションを使用",
            .menuBarTriggerIcon: "メニューバートリガーアイコン",
            .menuBarIconSpacing: "メニューバーアイコン間隔",
            .advancedNotchScan: "高度なノッチスキャン",
            .advancedNotchScanDetail: "メニューバースキャンは高度な固定と診断のためのツールです。通常のパネル利用には不要です。",
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
            .detectedItems: "検出項目",
            .panelItems: "パネル項目",
            .autoRefresh: "自動更新",
            .refreshInterval: "更新間隔",
            .caffeine: "カフェイン",
            .defaultDuration: "既定の時間",
            .keepDisplayAwakeDuringCaffeine: "カフェイン中はディスプレイを起動したままにする",
            .showRemainingTimeInClockArea: "時計エリアに残り時間を表示",
            .warningShowNeverDuration: "警告: Never の時間を表示",
            .neverCaffeineWarning: "Never は手動で停止するまでカフェインを有効にします。",
            .panelStatus: "パネル状態",
            .coreBars: "コアバー",
            .aggregate: "集計",
            .cpuCoreBars: "CPU コアバー",
            .clockAreaStatus: "時計エリア状態",
            .layout: "レイアウト",
            .format: "形式",
            .decimals: "小数",
            .highlight: "強調",
            .labelAndPercent: "ラベル + %",
            .percentOnly: "% のみ",
            .inline: "インライン",
            .stacked: "積み重ね",
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
