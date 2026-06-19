import AppKit
import SwiftUI

struct TokenMeteringPreferencesSection: View {
    @ObservedObject var settings: SpillSettings
    let tokenUsageStore: TokenUsageStore
    @ObservedObject var tokenHistoryImportCoordinator: TokenUsageHistoryImportCoordinator
    let openDashboardAction: () -> Void
    @StateObject private var privateUsageUploadStore: PrivateUsageUploadStore
    @State private var copiedTarget: String?
    @State private var adapterStatuses: [String: TokenMeteringAdapterConnectionStatus] = [:]

    init(
        settings: SpillSettings,
        tokenUsageStore: TokenUsageStore,
        tokenHistoryImportCoordinator: TokenUsageHistoryImportCoordinator,
        openDashboardAction: @escaping () -> Void
    ) {
        self.settings = settings
        self.tokenUsageStore = tokenUsageStore
        self.tokenHistoryImportCoordinator = tokenHistoryImportCoordinator
        self.openDashboardAction = openDashboardAction
        _privateUsageUploadStore = StateObject(
            wrappedValue: PrivateUsageUploadStore(
                settings: settings,
                usageStore: tokenUsageStore
            )
        )
    }

    private var currentLanguage: TokenMeteringLanguage {
        TokenMeteringLanguage.current(appLanguage: settings.appLanguage)
    }

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(key, language: currentLanguage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(t(.preferencesTitle))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)

                Text(t(.preferencesSubtitle))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Step 1: Automatic AI usage tracking Setup & Status
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.teal)
                    Text(t(.step1Title))
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                    Text(t(.recommended))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.teal)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.teal.opacity(0.12), in: Capsule())
                }

                promptInstructionCard

                Divider().opacity(0.45)

                agentStatusSection
            }
            .padding(10)
            .background(tokenMeteringOptionBackground)

            // Step 2: Local history import (Optional)
            historyImportSection

            // Local sync status & display settings
            localSyncAndDisplaySettingsSection

            // Local & Cloud Sync Mode List
            VStack(spacing: 8) {
                ForEach(TokenMeteringPreferencesModel.modes) { mode in
                    TokenMeteringModeRow(mode: mode)
                }
            }

            if PrivateUsageUploadFeatureAvailability.isEnabledInCurrentBuild {
                privateUsageUploadSection
            }

            privacyBoundarySection
        }
        .onAppear {
            refreshAdapterStatuses()
            refreshPrivateUsageUploadIfAvailable()
        }
        .onReceive(NotificationCenter.default.publisher(for: TokenUsageStore.eventsDidChangeNotification)) { _ in
            refreshPrivateUsageUploadIfAvailable()
        }
        .onChange(of: settings.privateUsageUploadEnabled) { _, _ in
            refreshPrivateUsageUploadIfAvailable()
        }
    }

    private var localSyncAndDisplaySettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            TokenMeteringOptionHeader(
                title: t(.localSyncStatusTitle),
                state: t(.defaultState),
                systemImage: "folder.badge.gearshape",
                tint: .blue
            )

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t(.menuBarTokenDisplayModeTitle))
                        .font(.system(size: 12, weight: .bold))
                    Text(t(.menuBarTokenDisplayModeDetail))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Picker("", selection: $settings.menuBarTokenDisplayMode) {
                    ForEach(MenuBarTokenDisplayMode.allCases) { mode in
                        Text(mode.title(appLanguage: settings.appLanguage)).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 140)
            }

            Divider().opacity(0.45)

            VStack(alignment: .leading, spacing: 6) {
                Text(t(.localEventQueue))
                    .font(.system(size: 12, weight: .bold))
                HStack(spacing: 8) {
                    Text(TokenUsageStore.defaultInboxURL().path)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)

                    Spacer(minLength: 8)

                    Button {
                        copyToClipboard(TokenUsageStore.defaultInboxURL().path, target: "inbox")
                    } label: {
                        Label(
                            copiedTarget == "inbox" ? t(.copied) : t(.copyPath),
                            systemImage: copiedTarget == "inbox" ? "checkmark" : "doc.on.doc"
                        )
                    }
                    .font(.system(size: 12, weight: .semibold))
                }
            }
        }
        .padding(10)
        .background(tokenMeteringOptionBackground)
    }

    private var privateUsageUploadSection: some View {
        let status = privateUsageUploadStore.status
        let stateText = status.isConnected
            ? (settings.privateUsageUploadEnabled ? t(.privateUsageUploadStateEnabled) : t(.privateUsageUploadStateConnected))
            : t(.privateUsageUploadStateOptional)
        let stateColor: Color = status.isConnected
            ? (settings.privateUsageUploadEnabled ? .green : .teal)
            : .secondary

        return VStack(alignment: .leading, spacing: 10) {
            TokenMeteringOptionHeader(
                title: t(.privateUsageUploadTitle),
                state: stateText,
                systemImage: status.isConnected ? "checkmark.shield.fill" : "lock.shield.fill",
                tint: status.isConnected ? stateColor : .indigo
            )

            Text(t(.privateUsageUploadDetail))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            if !status.isConnected {
                HStack(alignment: .top, spacing: 10) {
                    Button {
                        openPrivateUsageWebConnection()
                    } label: {
                        Label(t(.privateUsageUploadOpenWeb), systemImage: "safari")
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.system(size: 12, weight: .semibold))
                    .disabled(privateUsageWebConnectionURL == nil)

                    Text(t(.privateUsageUploadOpenWebDetail))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Toggle(isOn: $settings.privateUsageUploadEnabled) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t(.privateUsageUploadToggleTitle))
                        .font(.system(size: 12, weight: .bold))
                    Text(t(.privateUsageUploadToggleDetail))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .disabled(!status.isConnected)

            HStack(spacing: 10) {
                PrivateUsageUploadMetric(
                    title: t(.privateUsageUploadQueued),
                    value: "\(status.queuedBucketCount)"
                )
                PrivateUsageUploadMetric(
                    title: t(.privateUsageUploadLastBackup),
                    value: formatUploadDate(status.lastSuccessfulUploadAt)
                )
                PrivateUsageUploadMetric(
                    title: t(.privateUsageUploadNextAuto),
                    value: formatUploadDate(status.nextAutomaticAttemptAfter)
                )
            }

            HStack(spacing: 8) {
                Button {
                    Task { @MainActor in
                        await privateUsageUploadStore.syncNow()
                    }
                } label: {
                    if privateUsageUploadStore.isSyncing {
                        Label(t(.privateUsageUploadSyncing), systemImage: "hourglass")
                    } else {
                        Label(t(.privateUsageUploadSyncNow), systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
                .font(.system(size: 12, weight: .semibold))
                .disabled(!status.isConnected || !settings.privateUsageUploadEnabled || privateUsageUploadStore.isSyncing)

                Button(role: .destructive) {
                    privateUsageUploadStore.disconnect()
                } label: {
                    Label(t(.privateUsageUploadDisconnect), systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
                .font(.system(size: 12, weight: .semibold))
                .disabled(!status.isConnected)
            }

            if let message = privateUsageUploadStore.message {
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.green)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let errorMessage = privateUsageUploadStore.errorMessage ?? status.lastFailureReason {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(tokenMeteringOptionBackground)
    }

    private var privacyBoundarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TokenMeteringOptionHeader(
                title: t(.neverCollectedOrUploaded),
                state: t(.localOnly),
                systemImage: "lock.shield.fill",
                tint: .indigo
            )

            FlowingTokenMeteringLabels(labels: TokenMeteringPreferencesModel.forbiddenContentLabels)
        }
        .padding(10)
        .background(tokenMeteringOptionBackground)
    }

    private var tokenMeteringOptionBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(NSColor.controlBackgroundColor).opacity(0.35))
    }

    private func copyToClipboard(_ text: String, target: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedTarget = target

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            if copiedTarget == target {
                copiedTarget = nil
            }
        }
    }

    private func formatUploadDate(_ date: Date?) -> String {
        guard let date else {
            return t(.privateUsageUploadNone)
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: currentLanguage.rawValue)
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func refreshPrivateUsageUploadIfAvailable() {
        guard PrivateUsageUploadFeatureAvailability.isEnabledInCurrentBuild else {
            return
        }

        privateUsageUploadStore.refresh()
    }

    private func openPrivateUsageWebConnection() {
        guard let url = privateUsageWebConnectionURL else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private var privateUsageWebConnectionURL: URL? {
        PrivateUsageWebConnection.connectDeviceURL()
    }

    private func status(for adapter: TokenMeteringAdapter) -> TokenMeteringAdapterConnectionStatus {
        adapterStatuses[adapter.id] ?? .missing
    }

    private func refreshAdapterStatuses() {
        adapterStatuses = Dictionary(
            uniqueKeysWithValues: TokenMeteringAdapterKit.hookAdapters.map { adapter in
                (adapter.id, TokenMeteringAdapterConnectionDiagnostics.status(for: adapter))
            }
        )
    }

    private var promptInstructionCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.teal.opacity(0.15), Color.blue.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)

                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.teal, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(t(.promptInstructionCardTitle))
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(.primary)
                Text(t(.promptInstructionCardDetail))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button {
                copyToClipboard(
                    TokenMeteringGlobalSetup.globalPrompt,
                    target: "prompt"
                )
            } label: {
                Label(
                    copiedTarget == "prompt" ? t(.copied) : t(.copyInstallPrompt),
                    systemImage: copiedTarget == "prompt" ? "checkmark" : "doc.on.doc"
                )
            }
            .buttonStyle(.bordered)
            .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            Color.primary.opacity(0.015),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.04), lineWidth: 0.5)
        }
    }

    private var historyImportSection: some View {
        let snapshot = tokenHistoryImportCoordinator.snapshot
        let tint = snapshot.isRunning ? Color.blue : Color.teal
        let stateText = snapshot.isRunning ? t(.historyImportRunning) : t(.historyImportReady)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                TokenMeteringOptionHeader(
                    title: t(.historyImportTitle),
                    state: stateText,
                    systemImage: "arrow.triangle.2.circlepath",
                    tint: tint
                )

                Text(t(.historyImportExperimental))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule(style: .continuous).fill(Color.orange.opacity(0.12)))

                Spacer(minLength: 8)

                Button {
                    if snapshot.isRunning {
                        tokenHistoryImportCoordinator.cancelImport()
                    } else {
                        tokenHistoryImportCoordinator.startImport()
                    }
                } label: {
                    Label(
                        snapshot.isRunning ? t(.historyImportCancel) : t(.historyImportAllStart),
                        systemImage: snapshot.isRunning ? "xmark.circle" : "arrow.down.doc"
                    )
                }
                .buttonStyle(.bordered)
                .font(.system(size: 12, weight: .semibold))
                .disabled(snapshot.isRunning && snapshot.tools.allSatisfy(\.state.isFinished))
            }

            Text(t(.historyImportDetail))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Label(t(.historyImportFullScanWarning), systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 7) {
                ForEach(snapshot.tools) { toolSnapshot in
                    TokenUsageHistoryImportToolRow(
                        snapshot: toolSnapshot,
                        language: currentLanguage,
                        firstModeText: t(.historyImportFirstMode),
                        incrementalModeText: t(.historyImportIncrementalMode),
                        waitingText: t(.historyImportStateWaiting),
                        scanningText: t(.historyImportStateScanning),
                        doneText: t(.historyImportStateDone),
                        noSourceText: t(.historyImportStateNoSource),
                        failedText: t(.historyImportStateFailed),
                        cancelledText: t(.historyImportStateCancelled),
                        sourcesText: t(.historyImportMetricSources),
                        newText: t(.historyImportMetricNew),
                        duplicatesText: t(.historyImportMetricDuplicates),
                        unsupportedText: t(.historyImportMetricUnsupported),
                        syncText: t(.historyImportToolStart),
                        isImportRunning: snapshot.isRunning,
                        lastRunText: historyImportLastRunText(for: toolSnapshot.lastRun),
                        syncAction: {
                            tokenHistoryImportCoordinator.startImport(for: toolSnapshot.tool)
                        }
                    )
                }
            }

            if let finishedAt = snapshot.finishedAt {
                Label(
                    "\(t(.historyImportLastFinished)) \(formatUploadDate(finishedAt))",
                    systemImage: "clock"
                )
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(tokenMeteringOptionBackground)
    }

    private func historyImportLastRunText(for lastRun: TokenUsageHistoryImportLastRunSnapshot?) -> String? {
        guard let lastRun else {
            return nil
        }
        let metrics = [
            "\(t(.historyImportMetricSources)) \(TokenUsageDashboardSnapshot.formatCount(lastRun.scannedSources))",
            "\(t(.historyImportMetricNew)) \(TokenUsageDashboardSnapshot.formatCount(lastRun.importedEvents))",
            "\(t(.historyImportMetricDuplicates)) \(TokenUsageDashboardSnapshot.formatCount(lastRun.skippedDuplicates))",
            "\(t(.historyImportMetricUnsupported)) \(TokenUsageDashboardSnapshot.formatCount(lastRun.unsupportedRecords))"
        ]
        return [
            "\(t(.historyImportLastSync)) \(formatUploadDate(lastRun.finishedAt))",
            historyImportStateText(lastRun.state),
            metrics.joined(separator: " / ")
        ].joined(separator: " · ")
    }

    private func historyImportStateText(_ state: TokenUsageHistoryImportToolState) -> String {
        switch state {
        case .pending:
            return t(.historyImportStateWaiting)
        case .running:
            return t(.historyImportStateScanning)
        case .completed:
            return t(.historyImportStateDone)
        case .unavailable:
            return t(.historyImportStateNoSource)
        case .failed:
            return t(.historyImportStateFailed)
        case .cancelled:
            return t(.historyImportStateCancelled)
        }
    }

    private var agentStatusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(t(.agentConnectionStatus), systemImage: "bolt.horizontal.circle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)

            VStack(spacing: 7) {
                ForEach(TokenMeteringAdapterKit.hookAdapters) { adapter in
                    let status = status(for: adapter)
                    HStack(spacing: 10) {
                        Image(systemName: status.isActive ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(status.isActive ? .green : .orange)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(adapter.title)
                                .font(.system(size: 12, weight: .bold))
                            Text(adapterStatusDetail(status, adapter: adapter))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if !status.isActive {
                            Button {
                                let path = TokenMeteringAdapterKit.defaultInstallURL(for: adapter)
                                if let config = adapter.hookConfig(installedAt: path) {
                                    copyToClipboard(config, target: "prompt_\(adapter.id)")
                                }
                            } label: {
                                Label(
                                    copiedTarget == "prompt_\(adapter.id)" ? t(.copied) : t(.copyPrompt),
                                    systemImage: copiedTarget == "prompt_\(adapter.id)" ? "checkmark" : "doc.on.doc"
                                )
                            }
                            .buttonStyle(.bordered)
                            .font(.system(size: 11, weight: .semibold))
                        } else {
                            Text(t(.active))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.green.opacity(0.12)))
                        }
                    }
                    .padding(8)
                    .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.04), lineWidth: 0.5)
                    }
                }
            }
        }
    }

    private func adapterStatusDetail(
        _ status: TokenMeteringAdapterConnectionStatus,
        adapter: TokenMeteringAdapter
    ) -> String {
        if !status.scriptInstalled {
            return t(.adapterSetupRequired)
        }

        if !status.hookConfigured {
            return t(.adapterHookMissing)
        }

        return TokenMeteringL10n.adapterInstalled(
            TokenMeteringAdapterKit.defaultInstallURL(for: adapter).lastPathComponent,
            language: currentLanguage
        )
    }
}

private struct TokenMeteringAdapterConnectionStatus: Equatable {
    let scriptInstalled: Bool
    let hookConfigured: Bool

    var isActive: Bool {
        scriptInstalled && hookConfigured
    }

    static let missing = TokenMeteringAdapterConnectionStatus(scriptInstalled: false, hookConfigured: false)
}

private enum TokenMeteringAdapterConnectionDiagnostics {
    static func status(for adapter: TokenMeteringAdapter) -> TokenMeteringAdapterConnectionStatus {
        let scriptURL = TokenMeteringAdapterKit.defaultInstallURL(for: adapter)
        let scriptInstalled = FileManager.default.fileExists(atPath: scriptURL.path)
        return TokenMeteringAdapterConnectionStatus(
            scriptInstalled: scriptInstalled,
            hookConfigured: hookConfigured(for: adapter, scriptURL: scriptURL)
        )
    }

    private static func hookConfigured(for adapter: TokenMeteringAdapter, scriptURL: URL) -> Bool {
        switch adapter.aiTool {
        case .claude:
            return stopHookConfigured(
                configURL: homeURL(".claude/settings.json"),
                scriptURL: scriptURL
            )
        case .codex:
            return stopHookConfigured(
                configURL: homeURL(".codex/hooks.json"),
                scriptURL: scriptURL
            )
        case .antigravity:
            return false
        case .openAI, .unknown:
            return false
        }
    }

    private static func stopHookConfigured(configURL: URL, scriptURL: URL) -> Bool {
        guard let root = readJSONObject(configURL) as? [String: Any],
              let hooks = root["hooks"] as? [String: Any],
              let stop = hooks["Stop"]
        else {
            return false
        }

        return hookCommands(in: stop).contains { commandMatches($0, scriptURL: scriptURL) }
    }

    private static func hookCommands(in value: Any) -> [String] {
        if let dictionary = value as? [String: Any] {
            let current = (dictionary["command"] as? String).map { [$0] } ?? []
            return current + dictionary.values.flatMap { hookCommands(in: $0) }
        }

        if let array = value as? [Any] {
            return array.flatMap { hookCommands(in: $0) }
        }

        return []
    }

    private static func commandMatches(
        _ command: String,
        scriptURL: URL,
        compatibilityURLs: [URL] = []
    ) -> Bool {
        ([scriptURL] + compatibilityURLs).contains { candidateURL in
            command.contains(candidateURL.path)
                && scriptReferenceMatches(candidateURL, expectedURL: scriptURL)
        }
    }

    private static func scriptReferenceMatches(_ candidateURL: URL, expectedURL: URL) -> Bool {
        if candidateURL.path == expectedURL.path {
            return true
        }

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: candidateURL.path),
              fileManager.fileExists(atPath: expectedURL.path)
        else {
            return false
        }

        if candidateURL.resolvingSymlinksInPath().path == expectedURL.resolvingSymlinksInPath().path {
            return true
        }

        return fileManager.contentsEqual(
            atPath: candidateURL.path,
            andPath: expectedURL.path
        )
    }

    private static func readJSONObject(_ url: URL) -> Any? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONSerialization.jsonObject(with: data)
    }

    private static func homeURL(_ relativePath: String) -> URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(relativePath)
    }
}

private struct TokenMeteringOptionHeader: View {
    let title: String
    let state: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 18, height: 18)

            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.primary)

            Text(state)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tint)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    Capsule(style: .continuous)
                        .fill(tint.opacity(0.12))
                )
        }
    }
}

struct TokenMeteringLocalDataManagementSection: View {
    @ObservedObject var settings: SpillSettings
    let tokenUsageStore: TokenUsageStore
    @State private var showsDeleteControls = false
    @State private var localDataPreview = TokenUsageClearPreview(scopeTitle: "", eventCount: 0, totalTokens: 0)
    @State private var pendingClearAllPreview: TokenUsageClearPreview?
    @State private var clearAllError: String?

    private var currentLanguage: TokenMeteringLanguage {
        TokenMeteringLanguage.current(appLanguage: settings.appLanguage)
    }

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(key, language: currentLanguage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            TokenMeteringOptionHeader(
                title: t(.dataManagement),
                state: t(.localOnly),
                systemImage: "externaldrive.fill",
                tint: .orange
            )

            Label(t(.debugOnly), systemImage: "ladybug.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.orange)

            Text(TokenMeteringL10n.eventsTokensDetail(
                eventCount: localDataPreview.eventCount,
                tokens: TokenUsageDashboardSnapshot.formatTokens(localDataPreview.totalTokens),
                language: currentLanguage
            ))
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(.secondary)

            if localDataPreview.hasEvents {
                DisclosureGroup(isExpanded: $showsDeleteControls) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(t(.localDataManagementDetail))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Button(role: .destructive) {
                            let preview = makeAllLocalDataPreview()
                            localDataPreview = preview
                            if preview.hasEvents {
                                pendingClearAllPreview = preview
                            }
                        } label: {
                            Label(t(.reviewLocalDataDelete), systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .font(.system(size: 12, weight: .semibold))
                        .tint(.red)
                    }
                    .padding(.top, 4)
                } label: {
                    Label(t(.localDataDeleteOptions), systemImage: "trash")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            } else {
                Label(t(.noLocalTokenEvents), systemImage: "checkmark.circle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            if let clearAllError {
                Text(clearAllError)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(tokenMeteringOptionBackground)
        .onAppear {
            refreshLocalDataPreview()
        }
        .onReceive(NotificationCenter.default.publisher(for: TokenUsageStore.eventsDidChangeNotification)) { _ in
            refreshLocalDataPreview()
        }
        .alert(
            t(.deleteTokenDataTitle),
            isPresented: Binding(
                get: { pendingClearAllPreview != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingClearAllPreview = nil
                    }
                }
            ),
            presenting: pendingClearAllPreview
        ) { _ in
            Button(t(.deleteTokenDataCancel), role: .cancel) {
                pendingClearAllPreview = nil
            }
            Button(t(.deleteTokenDataConfirm), role: .destructive) {
                clearAllLocalTokenData()
            }
        } message: { preview in
            Text(TokenMeteringL10n.deleteTokenDataMessage(
                scope: preview.scopeTitle,
                eventCount: preview.eventCount,
                tokens: TokenUsageDashboardSnapshot.formatTokens(preview.totalTokens),
                language: currentLanguage
            ))
        }
    }

    private var tokenMeteringOptionBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(NSColor.controlBackgroundColor).opacity(0.35))
    }

    private func refreshLocalDataPreview() {
        let preview = makeAllLocalDataPreview()
        localDataPreview = preview
        if !preview.hasEvents {
            showsDeleteControls = false
        }
    }

    private func makeAllLocalDataPreview() -> TokenUsageClearPreview {
        let summary = tokenUsageStore.dashboardSummary(dashboardToolsOnly: false)
        return TokenUsageClearPreview(
            scopeTitle: t(.allLocalData),
            eventCount: summary.eventCount,
            totalTokens: summary.totalTokens
        )
    }

    private func clearAllLocalTokenData() {
        guard SpillBuildOptions.developerOptionsEnabled else {
            pendingClearAllPreview = nil
            return
        }
        do {
            try tokenUsageStore.clearEvents()
            clearAllError = nil
            pendingClearAllPreview = nil
            showsDeleteControls = false
            refreshLocalDataPreview()
        } catch {
            clearAllError = TokenMeteringL10n.text(.clearFailed, language: currentLanguage)
            pendingClearAllPreview = nil
        }
    }
}

private struct TokenUsageHistoryImportToolRow: View {
    let snapshot: TokenUsageHistoryImportToolSnapshot
    let language: TokenMeteringLanguage
    let firstModeText: String
    let incrementalModeText: String
    let waitingText: String
    let scanningText: String
    let doneText: String
    let noSourceText: String
    let failedText: String
    let cancelledText: String
    let sourcesText: String
    let newText: String
    let duplicatesText: String
    let unsupportedText: String
    let syncText: String
    let isImportRunning: Bool
    let lastRunText: String?
    let syncAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            statusIcon

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(snapshot.tool.aiTool.dashboardLabel(language: language))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(modeText)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(tint.opacity(0.12)))

                    Spacer(minLength: 0)

                    Button(action: syncAction) {
                        Label(syncText, systemImage: "arrow.down.doc")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(.system(size: 10, weight: .bold))
                    .disabled(isImportRunning)

                    Text(stateText)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(stateColor)
                }

                Text(detailText)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                if let lastRunText {
                    Label(lastRunText, systemImage: "clock")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.13), lineWidth: 0.5)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        if snapshot.state == .running {
            ProgressView()
                .controlSize(.small)
                .frame(width: 16, height: 16)
        } else {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(stateColor)
                .frame(width: 16, height: 16)
        }
    }

    private var tint: Color {
        snapshot.tool.aiTool.dashboardTint
    }

    private var modeText: String {
        switch snapshot.mode {
        case .firstImport:
            return firstModeText
        case .incremental:
            return incrementalModeText
        }
    }

    private var stateText: String {
        switch snapshot.state {
        case .pending:
            return waitingText
        case .running:
            return scanningText
        case .completed:
            return doneText
        case .unavailable:
            return noSourceText
        case .failed:
            return failedText
        case .cancelled:
            return cancelledText
        }
    }

    private var systemImage: String {
        switch snapshot.state {
        case .pending:
            return "clock"
        case .running:
            return "arrow.triangle.2.circlepath"
        case .completed:
            return "checkmark.circle.fill"
        case .unavailable:
            return "minus.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .cancelled:
            return "xmark.circle.fill"
        }
    }

    private var stateColor: Color {
        switch snapshot.state {
        case .completed:
            return .green
        case .running:
            return tint
        case .failed:
            return .red
        case .unavailable, .cancelled:
            return .orange
        case .pending:
            return .secondary
        }
    }

    private var detailText: String {
        if snapshot.state == .running {
            return snapshot.message ?? scanningText
        }

        if let message = snapshot.message, snapshot.scannedSources == 0 {
            return message
        }

        let parts = [
            "\(sourcesText) \(TokenUsageDashboardSnapshot.formatCount(snapshot.scannedSources))",
            "\(newText) \(TokenUsageDashboardSnapshot.formatCount(snapshot.importedEvents))",
            "\(duplicatesText) \(TokenUsageDashboardSnapshot.formatCount(snapshot.skippedDuplicates))",
            "\(unsupportedText) \(TokenUsageDashboardSnapshot.formatCount(snapshot.unsupportedRecords))"
        ]
        return parts.joined(separator: " / ")
    }
}

private struct TokenMeteringSetupGuidanceRow: View {
    let systemImage: String
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.primary)

                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct TokenMeteringSetupSummary: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.green)
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(9)
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.green.opacity(0.12), lineWidth: 0.5)
        }
    }
}

private struct TokenMeteringModeRow: View {
    let mode: TokenMeteringModeStatus

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: mode.isActive ? "checkmark.circle.fill" : "lock.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(mode.isActive ? .green : .secondary)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(mode.title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(mode.state)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(mode.isActive ? .green : .secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule(style: .continuous)
                                .fill(mode.isActive ? Color.green.opacity(0.12) : Color.primary.opacity(0.06))
                        )
                }

                Text(mode.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.35))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct PrivateUsageUploadMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
        }
    }
}

struct FlowingTokenMeteringLabels: View {
    let labels: [String]

    var body: some View {
        let columns = [
            GridItem(.adaptive(minimum: 84), spacing: 6, alignment: .leading)
        ]

        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(labels, id: \.self) { label in
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
            }
        }
    }
}
