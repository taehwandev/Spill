import AppKit
import SwiftUI

struct TokenMeteringPreferencesSection: View {
    @ObservedObject var settings: SpillSettings
    let tokenUsageStore: TokenUsageStore
    let openDashboardAction: () -> Void
    @StateObject private var privateUsageUploadStore: PrivateUsageUploadStore
    @State private var copiedTarget: String?
    @State private var showsLocalDataDeleteControls = false
    @State private var adapterStatuses: [String: TokenMeteringAdapterConnectionStatus] = [:]
    @State private var localDataPreview = TokenUsageClearPreview(scopeTitle: "", eventCount: 0, totalTokens: 0)
    @State private var pendingClearAllPreview: TokenUsageClearPreview?
    @State private var clearAllError: String?

    init(
        settings: SpillSettings,
        tokenUsageStore: TokenUsageStore,
        openDashboardAction: @escaping () -> Void
    ) {
        self.settings = settings
        self.tokenUsageStore = tokenUsageStore
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

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.teal)
                    Text(t(.installPromptTitle))
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

                Toggle(isOn: $settings.tokenMeteringPromptAllowsLocalDisplayNames) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 7) {
                            Text(t(.promptDisplayNamesTitle))
                                .font(.system(size: 12, weight: .bold))
                            Text(settings.tokenMeteringPromptAllowsLocalDisplayNames ? t(.promptDisplayNamesEnabled) : t(.promptDisplayNamesDisabled))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(settings.tokenMeteringPromptAllowsLocalDisplayNames ? .orange : .secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(settings.tokenMeteringPromptAllowsLocalDisplayNames ? Color.orange.opacity(0.13) : Color.primary.opacity(0.06))
                                )
                        }
                        Text(t(.promptDisplayNamesDetail))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .toggleStyle(.switch)

                if settings.tokenMeteringPromptAllowsLocalDisplayNames {
                    Label(t(.promptDisplayNamesReapplyWarning), systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider().opacity(0.45)

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

            }
            .padding(10)
            .background(tokenMeteringOptionBackground)

            // Agent Connection Status
            agentStatusSection

            // Local & Remote Mode Status - Main visible area!
            VStack(spacing: 8) {
                ForEach(TokenMeteringPreferencesModel.modes) { mode in
                    TokenMeteringModeRow(mode: mode)
                }
            }

            if PrivateUsageUploadFeatureAvailability.isEnabledInCurrentBuild {
                privateUsageUploadSection
            }

            localDataManagementSection

            localEventQueueSection

            privacyBoundarySection
        }
        .onAppear {
            refreshAdapterStatuses()
            refreshLocalDataPreview()
            refreshPrivateUsageUploadIfAvailable()
        }
        .onReceive(NotificationCenter.default.publisher(for: TokenUsageStore.eventsDidChangeNotification)) { _ in
            refreshLocalDataPreview()
            refreshPrivateUsageUploadIfAvailable()
        }
        .onChange(of: settings.privateUsageUploadEnabled) { _, _ in
            refreshPrivateUsageUploadIfAvailable()
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

    private var localEventQueueSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            TokenMeteringOptionHeader(
                title: t(.localEventQueue),
                state: t(.defaultState),
                systemImage: "tray.and.arrow.down",
                tint: .green
            )

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
                    TokenMeteringGlobalSetup.prompt(
                        allowsLocalDisplayNames: settings.tokenMeteringPromptAllowsLocalDisplayNames
                    ),
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

    private var localDataManagementSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            TokenMeteringOptionHeader(
                title: t(.dataManagement),
                state: t(.localOnly),
                systemImage: "externaldrive.fill",
                tint: .orange
            )

            Text(TokenMeteringL10n.eventsTokensDetail(
                eventCount: localDataPreview.eventCount,
                tokens: TokenUsageDashboardSnapshot.formatTokens(localDataPreview.totalTokens),
                language: currentLanguage
            ))
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(.secondary)

            if localDataPreview.hasEvents {
                DisclosureGroup(isExpanded: $showsLocalDataDeleteControls) {
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
    }

    private func refreshLocalDataPreview() {
        let preview = makeAllLocalDataPreview()
        localDataPreview = preview
        if !preview.hasEvents {
            showsLocalDataDeleteControls = false
        }
    }

    private func makeAllLocalDataPreview() -> TokenUsageClearPreview {
        let events = tokenUsageStore.loadEvents()
        return TokenUsageClearPreview(
            scopeTitle: t(.allLocalData),
            eventCount: events.count,
            totalTokens: events.reduce(0) { $0 + $1.totalTokens }
        )
    }

    private func clearAllLocalTokenData() {
        do {
            try tokenUsageStore.clearEvents()
            clearAllError = nil
            pendingClearAllPreview = nil
            showsLocalDataDeleteControls = false
            refreshLocalDataPreview()
        } catch {
            clearAllError = TokenMeteringL10n.text(.clearFailed, language: currentLanguage)
            pendingClearAllPreview = nil
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
