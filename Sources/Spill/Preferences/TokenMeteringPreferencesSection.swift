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
                    value: TokenUsageDashboardSnapshot.formatCount(status.queuedBucketCount)
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
