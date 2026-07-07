import Foundation

enum AppL10n {
    static func text(
        _ key: AppTextKey,
        appLanguage: SpillAppLanguage = .persisted(),
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        let language = resolvedLanguage(appLanguage: appLanguage, preferredLanguages: preferredLanguages)
        return table[language]?[key] ?? table[.english]?[key] ?? key.rawValue
    }
}

extension AppL10n {
    static func sleepDurationTitle(
        _ duration: SleepGuardDuration,
        appLanguage: SpillAppLanguage = .persisted(),
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        let language = resolvedLanguage(appLanguage: appLanguage, preferredLanguages: preferredLanguages)
        switch (language, duration) {
        case (.english, .fiveMinutes): return "5 Minutes"
        case (.english, .tenMinutes): return "10 Minutes"
        case (.english, .fifteenMinutes): return "15 Minutes"
        case (.english, .thirtyMinutes): return "30 Minutes"
        case (.english, .fortyFiveMinutes): return "45 Minutes"
        case (.english, .oneHour): return "1 Hour"
        case (.english, .twoHours): return "2 Hours"
        case (.english, .fourHours): return "4 Hours"
        case (.english, .eightHours): return "8 Hours"
        case (.english, .indefinitely): return "Never"
        case (.korean, .fiveMinutes): return "5분"
        case (.korean, .tenMinutes): return "10분"
        case (.korean, .fifteenMinutes): return "15분"
        case (.korean, .thirtyMinutes): return "30분"
        case (.korean, .fortyFiveMinutes): return "45분"
        case (.korean, .oneHour): return "1시간"
        case (.korean, .twoHours): return "2시간"
        case (.korean, .fourHours): return "4시간"
        case (.korean, .eightHours): return "8시간"
        case (.korean, .indefinitely): return "무제한"
        case (.japanese, .fiveMinutes): return "5分"
        case (.japanese, .tenMinutes): return "10分"
        case (.japanese, .fifteenMinutes): return "15分"
        case (.japanese, .thirtyMinutes): return "30分"
        case (.japanese, .fortyFiveMinutes): return "45分"
        case (.japanese, .oneHour): return "1時間"
        case (.japanese, .twoHours): return "2時間"
        case (.japanese, .fourHours): return "4時間"
        case (.japanese, .eightHours): return "8時間"
        case (.japanese, .indefinitely): return "無期限"
        }
    }

    static func statusModuleTitle(
        _ module: SpillStatusModule,
        appLanguage: SpillAppLanguage = .persisted(),
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        let language = resolvedLanguage(appLanguage: appLanguage, preferredLanguages: preferredLanguages)
        switch (language, module) {
        case (_, .cpu): return "CPU"
        case (.english, .memory): return "Memory"
        case (.english, .storage): return "Storage"
        case (_, .gpu): return "GPU"
        case (.english, .network): return "Network"
        case (.korean, .memory): return "메모리"
        case (.korean, .storage): return "저장 공간"
        case (.korean, .network): return "네트워크"
        case (.japanese, .memory): return "メモリ"
        case (.japanese, .storage): return "ストレージ"
        case (.japanese, .network): return "ネットワーク"
        }
    }

    static func itemCount(_ count: Int, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.menuBarItemCount, appLanguage: appLanguage), count)
    }

    static func pinnedCount(_ count: Int, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.pinned, appLanguage: appLanguage), count)
    }

    static func actionsReady(_ count: Int, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.actionsReady, appLanguage: appLanguage), count)
    }

    static func servicesFromOfficialSources(_ count: Int, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.servicesFromOfficialSources, appLanguage: appLanguage), count)
    }

    static func minutesAgo(_ minutes: Int, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.minutesAgo, appLanguage: appLanguage), minutes)
    }

    static func hoursAgo(_ hours: Int, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.hoursAgo, appLanguage: appLanguage), hours)
    }

    static func lastChecked(_ time: String, age: String, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.lastChecked, appLanguage: appLanguage), time, age)
    }

}

extension AppL10n {
    static func serverStatusWithIssues(
        status: String,
        issueCount: Int,
        appLanguage: SpillAppLanguage = .persisted()
    ) -> String {
        String(format: text(.serverStatusWithIssues, appLanguage: appLanguage), status, issueCount)
    }

    static func openStatusPage(
        _ service: String,
        appLanguage: SpillAppLanguage = .persisted()
    ) -> String {
        String(format: text(.openStatusPage, appLanguage: appLanguage), service)
    }

    static func eventsSummary(
        eventCount: Int,
        task: String,
        source: String,
        appLanguage: SpillAppLanguage = .persisted()
    ) -> String {
        String(format: text(.eventsSummary, appLanguage: appLanguage), formattedCount(eventCount), task, source)
    }

    private static func formattedCount(_ value: Int) -> String {
        NumberFormatter.tokenUsageFull.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func aiProcessSummary(
        runningToolCount: Int,
        processCount: Int,
        appLanguage: SpillAppLanguage = .persisted()
    ) -> String {
        String(format: text(.aiProcessSummary, appLanguage: appLanguage), runningToolCount, processCount)
    }

    static func tokenMeteringAccessibility(
        tokenCount: String,
        appLanguage: SpillAppLanguage = .persisted()
    ) -> String {
        String(format: text(.tokenMeteringAccessibility, appLanguage: appLanguage), tokenCount)
    }

    static func activeIdle(
        active: String,
        idle: String,
        appLanguage: SpillAppLanguage = .persisted()
    ) -> String {
        String(format: text(.cpuActiveIdle, appLanguage: appLanguage), active, idle)
    }

    static func availableOfTotal(
        available: String,
        total: String,
        appLanguage: SpillAppLanguage = .persisted()
    ) -> String {
        String(format: text(.availableOfTotal, appLanguage: appLanguage), available, total)
    }

    static func updateAvailableTitle(version: String, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.updateAvailableTitle, appLanguage: appLanguage), version)
    }

    static func spillVersionCurrent(version: String, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.spillVersionCurrent, appLanguage: appLanguage), version)
    }

    static func versionNeedsMacOS(
        version: String,
        requirement: String,
        appLanguage: SpillAppLanguage = .persisted()
    ) -> String {
        String(format: text(.versionNeedsMacOS, appLanguage: appLanguage), version, requirement)
    }

    static func updateHTTPFailed(statusCode: Int, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.updateHTTPFailedFormat, appLanguage: appLanguage), statusCode)
    }

    static func invalidLatestVersion(_ version: String, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.invalidLatestVersionFormat, appLanguage: appLanguage), version)
    }

    static func invalidMacOSVersion(_ version: String, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.invalidMacOSVersionFormat, appLanguage: appLanguage), version)
    }

    static func updateDecodingFailed(_ message: String, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.updateDecodingFailedFormat, appLanguage: appLanguage), message)
    }

    static func serviceStatusAccessibility(
        status: String,
        appLanguage: SpillAppLanguage = .persisted()
    ) -> String {
        String(format: text(.serviceStatusAccessibility, appLanguage: appLanguage), status)
    }
}

extension AppL10n {
    static func opened(_ title: String, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.openedFormat, appLanguage: appLanguage), title)
    }

    static func unavailable(_ title: String, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.unavailableFormat, appLanguage: appLanguage), title)
    }

    static func permissionRequired(
        _ permission: String,
        appLanguage: SpillAppLanguage = .persisted()
    ) -> String {
        String(format: text(.permissionRequiredFormat, appLanguage: appLanguage), permission)
    }

    static func unsupported(_ title: String, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.unsupportedFormat, appLanguage: appLanguage), title)
    }

    static func pressFailed(result: Int, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.pressFailedFormat, appLanguage: appLanguage), result)
    }

    static func noMenuBarItemsFound(
        candidateCount: Int,
        menuBarRootCount: Int,
        extrasRootCount: Int,
        fallbackRootCount: Int,
        representableElementCount: Int,
        suffix: String,
        appLanguage: SpillAppLanguage = .persisted()
    ) -> String {
        String(
            format: text(.noMenuBarItemsFoundFormat, appLanguage: appLanguage),
            candidateCount,
            menuBarRootCount,
            extrasRootCount,
            fallbackRootCount,
            representableElementCount,
            suffix
        )
    }

    static func detectedNoNotch(
        itemCount: Int,
        menuBarRootCount: Int,
        suffix: String,
        appLanguage: SpillAppLanguage = .persisted()
    ) -> String {
        String(
            format: text(.detectedNoNotchFormat, appLanguage: appLanguage),
            itemCount,
            menuBarRootCount,
            suffix
        )
    }

    static func detectedNearNotch(
        itemCount: Int,
        notchCount: Int,
        suffix: String,
        appLanguage: SpillAppLanguage = .persisted()
    ) -> String {
        String(
            format: text(.detectedNearNotchFormat, appLanguage: appLanguage),
            itemCount,
            notchCount,
            suffix
        )
    }

    static func pinned(_ title: String, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.pinnedFormat, appLanguage: appLanguage), title)
    }

    static func unpinned(_ title: String, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.unpinnedFormat, appLanguage: appLanguage), title)
    }
}

extension AppL10n {
    static func windowActionTitle(
        _ kind: WindowActionKind,
        appLanguage: SpillAppLanguage = .persisted()
    ) -> String {
        switch kind {
        case .leftHalf:
            return text(.windowLeft, appLanguage: appLanguage)
        case .rightHalf:
            return text(.windowRight, appLanguage: appLanguage)
        case .topHalf:
            return text(.windowTop, appLanguage: appLanguage)
        case .bottomHalf:
            return text(.windowBottom, appLanguage: appLanguage)
        case .center:
            return text(.windowCenter, appLanguage: appLanguage)
        case .maximize:
            return text(.windowMaximize, appLanguage: appLanguage)
        case .topLeft:
            return text(.windowTopLeft, appLanguage: appLanguage)
        case .topRight:
            return text(.windowTopRight, appLanguage: appLanguage)
        case .bottomLeft:
            return text(.windowBottomLeft, appLanguage: appLanguage)
        case .bottomRight:
            return text(.windowBottomRight, appLanguage: appLanguage)
        case .previousDisplay:
            return text(.windowPreviousDisplay, appLanguage: appLanguage)
        case .nextDisplay:
            return text(.windowNextDisplay, appLanguage: appLanguage)
        case .restore:
            return text(.windowRestore, appLanguage: appLanguage)
        }
    }

    static func selectedHiddenSummary(
        selected: Int,
        hidden: Int,
        appLanguage: SpillAppLanguage = .persisted()
    ) -> String {
        String(format: text(.selectedHiddenSummary, appLanguage: appLanguage), selected, hidden)
    }

    static func activeSavedSummary(
        active: Int,
        saved: Int,
        appLanguage: SpillAppLanguage = .persisted()
    ) -> String {
        String(format: text(.activeSavedSummary, appLanguage: appLanguage), active, saved)
    }

    static func selectedSummary(_ selected: Int, appLanguage: SpillAppLanguage = .persisted()) -> String {
        String(format: text(.selectedSummary, appLanguage: appLanguage), selected)
    }
}

extension AppL10n {
    enum ResolvedLanguage {
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
}
