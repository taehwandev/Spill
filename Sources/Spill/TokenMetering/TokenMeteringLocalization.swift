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
    case dataManagement
    case clearCurrentScope
    case clearSelectedWorkItem
    case clearAllLocalData
    case localDataDeleteOptions
    case reviewLocalDataDelete
    case localDataManagementDetail
    case clearSelection
    case recentMonth
    case pickDate
    case previousMonth
    case nextMonth
    case allLocalData
    case currentDashboardScope
    case selectedWorkItem
    case deleteTokenDataTitle
    case deleteTokenDataConfirm
    case deleteTokenDataCancel
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
    case developerOptions
    case debugOnly
    case tokenDashboardOnboardingPreview
    case tokenDashboardOnboardingPreviewDetail
    case aiToolDistribution
    case aiToolDistributionSubtitle
    case modelBreakdown
    case noModelData
    case modelUnavailable
    case workflowUsage
    case workflowUsageInfoTitle
    case workflowUsageInfoDetail
    case workflowAssistedWork
    case workflowAssistedTokens
    case noWorkflowUsageData
    case workflowBreakdown
    case workflowBreakdownSubtitle
    case stageBreakdown
    case stageBreakdownSubtitle
    case sourceBreakdown
    case sourceBreakdownSubtitle
    case trendTitle
    case trendSubtitle
    case noTrendData
    case trendHoverGuide
    case noAIToolData
    case noWorkflowData
    case noStageData
    case noSourceBreakdown
    case selectedRun
    case total
    case events
    case noRunSelected
    case noRunSelectedDetail
    case dashboardEmptyGuideTitle
    case dashboardEmptyGuideDetail
    case dashboardEmptyOpenSettings
    case dashboardEmptyAutomaticTitle
    case dashboardEmptyAutomaticDetail
    case dashboardEmptySetupTitle
    case dashboardEmptySetupDetail
    case dashboardEmptyPrivacyTitle
    case dashboardEmptyPrivacyDetail
    case dashboardEmptyPreview
    case dashboardEmptyPreviewDetail
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
    case periodAllHistory
    case relativeYesterday
    case relativePreviousWeek
    case relativePreviousMonth
    case activeWindowLabel
    case allTools
    case allFolders
    case folderFilterHeader
    case folderUnassigned
    case unknownAITool
    case aiToolHeader
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
    case lastUpdatedLabel
    case localAlias
    case localAliasPlaceholder
    case applyAlias
    case clearAlias
    case localAliasDetail
    case cumulativeOnlyBadge
    case cumulativeOnlyInfoTitle
    case cumulativeOnlyInfoDetail
    case diagnosticsCodes
    case diagnosticsSessionID
    case diagnosticsRunID
    case selectedWorkItemHeader
    case previewBadge

    case sourceSystem
    case sourceUser
    case sourceHistory
    case sourceRepoContext
    case sourceToolOutput
    case sourceGeneratedOutput
    case sourceUnavailable

    case preferencesTitle
    case preferencesSubtitle
    case step1Title
    case localSyncStatusTitle
    case installPromptTitle
    case recommended
    case installPromptDetail
    case setupQuickStartTitle
    case setupQuickStartDetail
    case setupGlobalInstructionTitle
    case setupGlobalInstructionDetail
    case setupWorkflowLabelsTitle
    case setupWorkflowLabelsDetail
    case setupApplyWhereTitle
    case setupApplyWhereDetail
    case promptInstructionCardTitle
    case promptInstructionCardDetail
    case menuBarTokenDisplayModeTitle
    case menuBarTokenDisplayModeDetail
    case copyInstallPrompt
    case copyWebSetup
    case dashboard
    case localEventQueue
    case historyImportTitle
    case historyImportReady
    case historyImportRunning
    case historyImportExperimental
    case historyImportDetail
    case historyImportAllStart
    case historyImportStart
    case historyImportToolStart
    case historyImportCancel
    case historyImportFirstMode
    case historyImportIncrementalMode
    case historyImportLastFinished
    case historyImportLastSync
    case historyImportStateWaiting
    case historyImportStateScanning
    case historyImportStateDone
    case historyImportStateNoSource
    case historyImportStateFailed
    case historyImportStateCancelled
    case historyImportMetricSources
    case historyImportMetricNew
    case historyImportMetricDuplicates
    case historyImportMetricUnsupported
    case historyImportFullScanWarning
    case copyPath
    case adapterScripts
    case neverCollectedOrUploaded
    case copyScript
    case install
    case installed
    case copy
    case hookConfig
    case agentConnectionStatus
    case agentStatusSubtitle
    case agentStatusInfoTitle
    case agentStatusInfoDetail
    case agentStatusDetected
    case noAgentStatusData
    case noAgentStatusDetail
    case adapterSetupRequired
    case adapterHookMissing
    case active
    case privateUsageUploadTitle
    case privateUsageUploadStateEnabled
    case privateUsageUploadStateConnected
    case privateUsageUploadStateOptional
    case privateUsageUploadDetail
    case privateUsageUploadEnvironment
    case privateUsageUploadEnvironmentDevelopment
    case privateUsageUploadEnvironmentDevelopmentDetail
    case privateUsageUploadEnvironmentProduction
    case privateUsageUploadEnvironmentProductionDetail
    case privateUsageUploadOpenWeb
    case privateUsageUploadOpenWebDetail
    case privateUsageUploadToggleTitle
    case privateUsageUploadToggleDetail
    case privateUsageUploadQueued
    case privateUsageUploadLastBackup
    case privateUsageUploadNextAuto
    case privateUsageUploadNone
    case privateUsageUploadSyncing
    case privateUsageUploadSyncNow
    case privateUsageUploadDisconnect
    case privateUsageUploadConnectedMessage
    case privateUsageUploadUploadedMessage
    case privateUsageUploadNoQueuedMessage
    case privateUsageUploadDisconnectedMessage
    case privateUsageUploadUnavailableMessage
    case privateUsageUploadInvalidConnectionCodeMessage
    case privateUsageUploadInvalidGrantCodeMessage
    case privateUsageUploadDisabledMessage
    case privateUsageUploadMissingCredentialMessage
    case privateUsageUploadMissingSealingKeyMessage
    case privateUsageUploadMissingKeyWrappingSecretMessage
    case privateUsageUploadRelayURLUnavailableMessage
    case privateUsageUploadInvalidRelayResponseMessage
    case privateUsageUploadConnectionExpiredMessage
    case privateUsageUploadConnectionRequiredMessage
    case privateUsageUploadRelayUnavailableMessage
    case privateUsageUploadKeychainReadFailedMessage
    case privateUsageUploadKeychainWriteFailedMessage
    case privateUsageUploadEncryptionFailedMessage
    case privateUsageUploadKeyWrappingFailedMessage

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
    private static let tableName = "TokenMetering"
    private static let keyPrefix = "token_metering"

    static func text(_ key: TokenMeteringTextKey, language: TokenMeteringLanguage = .current()) -> String {
        localized(key.localizationKey, language: language)
    }

    static func eventsTokensDetail(
        eventCount: Int,
        tokens: String,
        language: TokenMeteringLanguage = .current()
    ) -> String {
        localizedFormat("format.events_tokens_detail", language: language, formattedCount(eventCount), tokens)
    }

    static func localEventsDetail(eventCount: Int, language: TokenMeteringLanguage = .current()) -> String {
        localizedFormat("format.local_events_detail", language: language, formattedCount(eventCount))
    }

    static func spansDetail(
        spanCount: Int,
        latencyMS: Int?,
        latest: String,
        language: TokenMeteringLanguage = .current()
    ) -> String {
        if let latencyMS {
            return localizedFormat(
                "format.spans_detail_with_latency",
                language: language,
                formattedCount(spanCount),
                "\(formattedCount(latencyMS)) ms",
                latest
            )
        }
        return localizedFormat("format.spans_detail", language: language, formattedCount(spanCount), latest)
    }

    static func percentOfTotal(_ percent: Int, language: TokenMeteringLanguage = .current()) -> String {
        localizedFormat("format.percent_of_total", language: language, Int64(percent))
    }

    static func percentStringOfTotal(_ percent: String, language: TokenMeteringLanguage = .current()) -> String {
        localizedFormat("format.percent_string_of_total", language: language, percent)
    }

    static func folderTitle(_ shortID: String, language: TokenMeteringLanguage = .current()) -> String {
        localizedFormat("format.folder_title", language: language, shortID)
    }

    static func clearToolData(_ tool: String, language: TokenMeteringLanguage = .current()) -> String {
        localizedFormat("format.clear_tool_data", language: language, tool)
    }

    static func clearPeriodData(_ period: String, language: TokenMeteringLanguage = .current()) -> String {
        localizedFormat("format.clear_period_data", language: language, period)
    }

    static func deleteTokenDataMessage(
        scope: String,
        eventCount: Int,
        tokens: String,
        language: TokenMeteringLanguage = .current()
    ) -> String {
        localizedFormat("format.delete_token_data_message", language: language, scope, formattedCount(eventCount), tokens)
    }

    private static func formattedCount(_ value: Int) -> String {
        NumberFormatter.tokenUsageFull.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func installedAt(_ path: String, language: TokenMeteringLanguage = .current()) -> String {
        localizedFormat("format.installed_at", language: language, text(.installed, language: language), path)
    }

    static func adapterInstalled(_ path: String, language: TokenMeteringLanguage = .current()) -> String {
        localizedFormat("format.adapter_installed", language: language, text(.installed, language: language), path)
    }

    static func forbiddenContentLabels(language: TokenMeteringLanguage = .current()) -> [String] {
        [
            "prompts",
            "commands",
            "responses",
            "file_paths",
            "repo_names",
            "changes",
            "logs",
            "code_content",
            "environment_values",
            "secrets"
        ].map { suffix in
            localized("token_metering.forbidden.\(suffix)", language: language)
        }
    }

    static func taskLabel(_ rawValue: String, language: TokenMeteringLanguage = .current()) -> String {
        localizedFallback("task.\(rawValue)", fallback: rawValue.tokenMeteringFallbackTitle, language: language)
    }

    static func stageLabel(_ rawValue: String, language: TokenMeteringLanguage = .current()) -> String {
        localizedFallback("stage.\(rawValue)", fallback: rawValue.tokenMeteringFallbackTitle, language: language)
    }

    static func adapterTitle(
        _ adapterID: String,
        fallback: String,
        language: TokenMeteringLanguage = .current()
    ) -> String {
        localizedFallback("adapter.\(adapterID).title", fallback: fallback, language: language)
    }

    static func adapterSubtitle(
        _ adapterID: String,
        fallback: String,
        language: TokenMeteringLanguage = .current()
    ) -> String {
        localizedFallback("adapter.\(adapterID).subtitle", fallback: fallback, language: language)
    }

    static func hookConfigTarget(_ target: String, language: TokenMeteringLanguage = .current()) -> String {
        localizedFormat("format.hook_config_target", language: language, text(.hookConfig, language: language), target)
    }

    static func privateUsageEnvironmentTitle(
        _ environment: PrivateUsageUploadEnvironment,
        language: TokenMeteringLanguage = .current()
    ) -> String {
        switch environment {
        case .development:
            return text(.privateUsageUploadEnvironmentDevelopment, language: language)
        case .production:
            return text(.privateUsageUploadEnvironmentProduction, language: language)
        }
    }

    static func privateUsageEnvironmentDetail(
        _ environment: PrivateUsageUploadEnvironment,
        language: TokenMeteringLanguage = .current()
    ) -> String {
        switch environment {
        case .development:
            return text(.privateUsageUploadEnvironmentDevelopmentDetail, language: language)
        case .production:
            return text(.privateUsageUploadEnvironmentProductionDetail, language: language)
        }
    }

    private static func localizedFallback(
        _ suffix: String,
        fallback: String,
        language: TokenMeteringLanguage
    ) -> String {
        let key = "\(keyPrefix).\(suffix)"
        let value = localized(key, language: language)
        return value == key ? fallback : value
    }

    private static func localizedFormat(
        _ suffix: String,
        language: TokenMeteringLanguage,
        _ arguments: CVarArg...
    ) -> String {
        let template = localized("\(keyPrefix).\(suffix)", language: language)
        return String(format: template, locale: language.formatLocale, arguments: arguments)
    }

    private static func localized(_ key: String, language: TokenMeteringLanguage) -> String {
        if let bundle = localizedBundle(for: language) {
            let value = bundle.localizedString(forKey: key, value: nil, table: tableName)
            if value != key {
                return value
            }
        }
        if let catalogValue = stringCatalogValue(for: key, language: language) {
            return catalogValue
        }
        return resourceBundle()?.localizedString(forKey: key, value: key, table: tableName) ?? key
    }

    private static func localizedBundle(for language: TokenMeteringLanguage) -> Bundle? {
        guard let path = resourceBundle()?.path(forResource: language.localizationResourceName, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else {
            return resourceBundle()
        }
        return bundle
    }

    private static func resourceBundle() -> Bundle? {
        if let packagedBundle = packagedResourceBundle() {
            return packagedBundle
        }

        #if DEBUG
        return .module
        #else
        return nil
        #endif
    }

    private static func packagedResourceBundle(
        mainBundleURL: URL = Bundle.main.bundleURL,
        mainResourceURL: URL? = Bundle.main.resourceURL,
        fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) -> Bundle? {
        let candidateURLs = [
            mainResourceURL?.appendingPathComponent("Spill_Spill.bundle", isDirectory: true),
            mainBundleURL
                .appendingPathComponent("Contents", isDirectory: true)
                .appendingPathComponent("Resources", isDirectory: true)
                .appendingPathComponent("Spill_Spill.bundle", isDirectory: true)
        ].compactMap(\.self)

        for candidateURL in candidateURLs where fileExists(candidateURL.path) {
            if let bundle = Bundle(url: candidateURL) {
                return bundle
            }
        }
        return nil
    }

    private static func stringCatalogValue(for key: String, language: TokenMeteringLanguage) -> String? {
        guard let entry = stringCatalog?.strings[key] else {
            return nil
        }
        return entry.localizations[language.rawValue]?.value
            ?? entry.localizations[TokenMeteringLanguage.english.rawValue]?.value
    }

    private static let stringCatalog: StringCatalog? = {
        guard let bundle = resourceBundle() else {
            return nil
        }

        let candidateURLs = [
            bundle.url(forResource: tableName, withExtension: "xcstrings"),
            bundle.url(
                forResource: tableName,
                withExtension: "xcstrings",
                subdirectory: "Localization"
            )
        ].compactMap(\.self)

        for url in candidateURLs {
            do {
                let data = try Data(contentsOf: url)
                return try JSONDecoder().decode(StringCatalog.self, from: data)
            } catch {
                continue
            }
        }
        return nil
    }()

    #if DEBUG
    static func testingStringCatalogValue(
        from data: Data,
        key: String,
        language: TokenMeteringLanguage
    ) throws -> String? {
        let catalog = try JSONDecoder().decode(StringCatalog.self, from: data)
        guard let entry = catalog.strings[key] else {
            return nil
        }
        return entry.localizations[language.rawValue]?.value
            ?? entry.localizations[TokenMeteringLanguage.english.rawValue]?.value
    }
    #endif
}

private struct StringCatalog: Decodable, Sendable {
    let strings: [String: StringCatalogEntry]
}

private struct StringCatalogEntry: Decodable, Sendable {
    let localizations: [String: StringCatalogLocalization]
}

private struct StringCatalogLocalization: Decodable, Sendable {
    let stringUnit: StringCatalogStringUnit?
    let variations: [String: [String: StringCatalogVariation]]?

    var value: String? {
        stringUnit?.value ?? variations?
            .sorted(by: { $0.key < $1.key })
            .lazy
            .flatMap { $0.value.sorted(by: { $0.key < $1.key }).map(\.value) }
            .compactMap(\.value)
            .first
    }
}

private struct StringCatalogStringUnit: Decodable, Sendable {
    let value: String
}

private struct StringCatalogVariation: Decodable, Sendable {
    let stringUnit: StringCatalogStringUnit?
    let variations: [String: [String: StringCatalogVariation]]?

    var value: String? {
        stringUnit?.value ?? variations?
            .sorted(by: { $0.key < $1.key })
            .lazy
            .flatMap { $0.value.sorted(by: { $0.key < $1.key }).map(\.value) }
            .compactMap(\.value)
            .first
    }
}

private extension TokenMeteringTextKey {
    var localizationKey: String {
        "token_metering.\(rawValue)"
    }
}

private extension TokenMeteringLanguage {
    var localizationResourceName: String {
        rawValue
    }

    var formatLocale: Locale {
        Locale(identifier: rawValue)
    }
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
