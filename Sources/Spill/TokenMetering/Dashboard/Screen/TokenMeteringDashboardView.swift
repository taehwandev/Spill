import AppKit
import SwiftUI

private struct TokenUsageClearRequest: Identifiable {
    let id = UUID()
    let scope: TokenUsageClearScope
    let preview: TokenUsageClearPreview
}

struct TokenMeteringDashboardView: View {
    @ObservedObject var store: TokenUsageDashboardStore
    @ObservedObject var cloudServiceStatusStore: CloudServiceStatusStore
    @ObservedObject var aiStatusStore: AIStatusStore
    @ObservedObject private var settings: SpillSettings
    @State private var isCalendarPickerPresented = false
    @State private var isServiceStatusPresented = false
    @State private var pendingClearRequest: TokenUsageClearRequest?
    @State private var aliasText = ""
    @State private var resolvedLanguage: TokenMeteringLanguage
    @State private var hoveredKPI: String? = nil
    @State private var aiToolVisibilityObserver: NSObjectProtocol?
    @State private var visibleAIToolsSyncTask: Task<Void, Never>?
    private let refreshAction: () -> Void
    private let settingsAction: () -> Void
    private let developerOptionsAction: () -> Void
    private let syncsVisibleAITools: Bool
    private let titleDidChange: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            topHeader

            Divider()
                .background(Color.primary.opacity(0.05))

            topFilterBar

            Divider()
                .background(Color.primary.opacity(0.05))

            dashboardBody
        }
        .background(VisualEffectView(material: .sidebar, blendingMode: .withinWindow))
        .frame(minWidth: 1060, minHeight: 640)
        .focusEffectDisabled()
        .onAppear {
            let language = TokenMeteringLanguage.current(appLanguage: settings.appLanguage)
            resolvedLanguage = language
            titleDidChange()
            store.setLanguage(language)
            store.setUsageInputScope(settings.tokenUsageInputScope)
            syncOnboardingPreviewFromSettings()
            if syncsVisibleAITools {
                installAIToolVisibilityObserver()
            }
            aiStatusStore.refreshInBackground()
            if syncsVisibleAITools {
                syncVisibleAIToolsFromStatusStore()
            }
            store.refreshAsyncIfIdle()
        }
        .onDisappear {
            visibleAIToolsSyncTask?.cancel()
            visibleAIToolsSyncTask = nil
            removeAIToolVisibilityObserver()
        }
        .onChange(of: settings.appLanguage) { _, appLanguage in
            let language = TokenMeteringLanguage.current(appLanguage: appLanguage)
            resolvedLanguage = language
            titleDidChange()
            store.setLanguage(language)
        }
        .onChange(of: settings.tokenUsageDashboardOnboardingPreviewEnabled) { _, _ in
            syncOnboardingPreviewFromSettings()
        }
        .onChange(of: settings.tokenUsageInputScope) { _, scope in
            store.setUsageInputScope(scope)
        }
        .onChange(of: settings.hiddenTokenUsageAITools) { _, _ in
            scheduleVisibleAIToolsSync()
        }
        .onChange(of: settings.hiddenLocalAIToolKinds) { _, _ in
            scheduleVisibleAIToolsSync()
        }
        .onChange(of: aiStatusStore.statuses) { _, _ in
            scheduleVisibleAIToolsSync()
        }
        .onChange(of: aiStatusStore.hasCompletedRefresh) { _, _ in
            scheduleVisibleAIToolsSync()
        }
        .onChange(of: store.selectedSessionID) { _, newID in
            if let newID {
                aliasText = settings.tokenUsageLocalAliases[newID] ?? ""
            } else {
                aliasText = ""
            }
        }
        .alert(
            t(.deleteTokenDataTitle),
            isPresented: Binding(
                get: { pendingClearRequest != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingClearRequest = nil
                    }
                }
            ),
            presenting: pendingClearRequest
        ) { request in
            Button(t(.deleteTokenDataCancel), role: .cancel) {
                pendingClearRequest = nil
            }
            Button(t(.deleteTokenDataConfirm), role: .destructive) {
                store.clearEvents(in: request.scope)
                pendingClearRequest = nil
            }
        } message: { request in
            Text(TokenMeteringL10n.deleteTokenDataMessage(
                scope: request.preview.scopeTitle,
                eventCount: request.preview.eventCount,
                tokens: TokenUsageDashboardSnapshot.formatTokens(request.preview.totalTokens),
                language: currentLanguage
            ))
        }
    }

}

extension TokenMeteringDashboardView {
    init(
        store: TokenUsageDashboardStore,
        cloudServiceStatusStore: CloudServiceStatusStore = CloudServiceStatusStore(),
        aiStatusStore: AIStatusStore = AIStatusStore(),
        settings: SpillSettings = .shared,
        refreshAction: @escaping () -> Void = {},
        settingsAction: @escaping () -> Void = {},
        developerOptionsAction: @escaping () -> Void = {},
        syncsVisibleAITools: Bool = true,
        titleDidChange: @escaping () -> Void = {}
    ) {
        self.store = store
        self.cloudServiceStatusStore = cloudServiceStatusStore
        self.aiStatusStore = aiStatusStore
        _settings = ObservedObject(wrappedValue: settings)
        _resolvedLanguage = State(initialValue: TokenMeteringLanguage.current(appLanguage: settings.appLanguage))
        self.refreshAction = refreshAction
        self.settingsAction = settingsAction
        self.developerOptionsAction = developerOptionsAction
        self.syncsVisibleAITools = syncsVisibleAITools
        self.titleDidChange = titleDidChange
    }

    private func t(_ key: TokenMeteringTextKey) -> String {
        TokenMeteringL10n.text(
            key,
            language: currentLanguage
        )
    }

    private var currentLanguage: TokenMeteringLanguage {
        resolvedLanguage
    }

    private var selectedControlAccent: Color {
        store.selectedTool?.dashboardTint ?? TokenUsageAITool.antigravity.dashboardTint
    }

    private var selectedControlAccentHighlight: Color {
        if let tool = store.selectedTool {
            return tool.dashboardTint.opacity(1.15)
        }
        return TokenUsageAITool.antigravity.dashboardTint.opacity(1.15)
    }

    private var dashboardBody: some View {
        ZStack(alignment: .top) {
            HStack(alignment: .top, spacing: 16) {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        kpiStrip
                        analyticsGrid
                        sessionsTable
                    }
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }

                if let selectedSession = store.snapshot.selectedSession {
                    receiverPanel(selectedSession)
                } else {
                    rightRail
                        .frame(width: 286)
                }
            }
            .opacity(showsEmptyDashboardOverlay ? 0.58 : 1)
            .saturation(showsEmptyDashboardOverlay ? 0.55 : 1)
            .blur(radius: showsEmptyDashboardOverlay ? 0.4 : 0)
            .disabled(showsEmptyDashboardOverlay)
            .accessibilityHidden(showsEmptyDashboardOverlay)

            if showsEmptyDashboardOverlay {
                emptyDashboardGuide
                    .frame(maxWidth: 680)
                    .padding(.top, 42)
                    .padding(.horizontal, 48)
                    .shadow(color: Color.black.opacity(0.18), radius: 20, x: 0, y: 12)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

}

extension TokenMeteringDashboardView {
    private func receiverPanel(_ selectedSession: TokenUsageDashboardSessionRow) -> some View {
        TokenMeteringDashboardDetailPanel(
            session: selectedSession,
            snapshot: store.snapshot,
            aliasText: $aliasText,
            language: currentLanguage,
            liveUpdateMarker: store.liveUpdateMarker,
            isLiveUpdated: { store.isLiveUpdated($0) },
            clearSelection: {
                store.clearWorkItemSelection()
            },
            updateAlias: { workItemID, alias in
                store.updateAlias(for: workItemID, alias: alias)
            }
        )
        .frame(width: 320)
    }

    private var topHeader: some View {
        HStack(spacing: 12) {
            SpillBrandLockupView(
                subtitle: nil,
                markStyle: nil,
                iconSize: 36,
                titleFontSize: 18,
                titleWeight: .bold,
                subtitleFontSize: 11,
                subtitleWeight: .semibold,
                subtitleColor: .secondary,
                spacing: 14
            )

            HStack(spacing: 8) {
                alphaBadge
                syncStateBadge

                Text("•")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.5))

                Text(t(.dashboardSubtitle))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let overallUpdated = store.snapshot.overallLastUpdatedString {
                    Text("•")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary.opacity(0.5))

                    Text("\(t(.lastUpdatedLabel)): \(overallUpdated)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 16)

            HStack(spacing: 8) {
                serviceStatusButton

                headerActionButton(
                    systemImage: "safari",
                    accessibilityLabel: t(.privateUsageUploadOpenDashboard),
                    helpText: t(.privateUsageUploadOpenDashboardDetail),
                    isEnabled: PrivateUsageWebConnection.dashboardURL() != nil,
                    action: openWebDashboard
                )

                headerActionButton(
                    systemImage: (store.loadState == .loading || store.isRefreshing) ? "arrow.triangle.2.circlepath" : "arrow.clockwise",
                    accessibilityLabel: t(.refresh),
                    helpText: t(.refresh),
                    isEnabled: !(store.loadState == .loading || store.isRefreshing),
                    action: refreshLocalTokenData
                )

                headerActionButton(
                    systemImage: "gearshape",
                    accessibilityLabel: AppL10n.text(.settings, appLanguage: settings.appLanguage),
                    helpText: AppL10n.text(.settings, appLanguage: settings.appLanguage),
                    action: settingsAction
                )
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

}

extension TokenMeteringDashboardView {
    private func openWebDashboard() {
        guard let url = PrivateUsageWebConnection.dashboardURL() else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func syncOnboardingPreviewFromSettings() {
        store.setOnboardingPreviewEnabled(
            SpillBuildOptions.developerOptionsEnabled
                && settings.tokenUsageDashboardOnboardingPreviewEnabled
        )
    }

    private func syncVisibleAIToolsFromStatusStore() {
        store.setVisibleAITools(
            TokenUsageDashboardToolVisibility.visibleTools(
                statuses: aiStatusStore.statuses,
                hiddenTools: settings.hiddenTokenUsageAITools
            )
        )
    }

    private func scheduleVisibleAIToolsSync() {
        guard syncsVisibleAITools else {
            return
        }

        visibleAIToolsSyncTask?.cancel()
        visibleAIToolsSyncTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else {
                return
            }

            visibleAIToolsSyncTask = nil
            syncVisibleAIToolsFromStatusStore()
        }
    }

    private func installAIToolVisibilityObserver() {
        guard aiToolVisibilityObserver == nil else {
            return
        }

        aiToolVisibilityObserver = DistributedNotificationCenter.default().addObserver(
            forName: SpillSettings.aiToolVisibilityDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                settings.reloadAIToolVisibilityFromDefaults()
                scheduleVisibleAIToolsSync()
            }
        }
    }

    private func removeAIToolVisibilityObserver() {
        guard let aiToolVisibilityObserver else {
            return
        }
        DistributedNotificationCenter.default().removeObserver(aiToolVisibilityObserver)
        self.aiToolVisibilityObserver = nil
    }

    private var topFilterBar: some View {
        TokenMeteringDashboardFilterBar(
            store: store,
            cloudServiceStatusStore: cloudServiceStatusStore,
            isCalendarPickerPresented: $isCalendarPickerPresented,
            language: currentLanguage,
            appLanguage: settings.appLanguage,
            selectedControlAccent: selectedControlAccent,
            selectedControlAccentHighlight: selectedControlAccentHighlight
        )
    }

    private var serviceStatusButton: some View {
        CloudServiceStatusButton(
            state: serviceStatusControlState,
            appLanguage: settings.appLanguage,
            height: 28,
            fontSize: 10,
            horizontalPadding: 9
        ) {
            openServiceStatusDetails()
        }
        .popover(isPresented: $isServiceStatusPresented, arrowEdge: .top) {
            CloudServiceStatusDashboardView(store: cloudServiceStatusStore)
        }
    }

}

extension TokenMeteringDashboardView {
    private func refreshLocalTokenData() {
        refreshAction()
        aiStatusStore.refreshInBackground()
        if syncsVisibleAITools {
            syncVisibleAIToolsFromStatusStore()
        }
        store.refreshAsync()
    }

    private func openServiceStatusDetails() {
        isServiceStatusPresented = true
        refreshServerStatus()
    }

    private func refreshServerStatus(force: Bool = false) {
        cloudServiceStatusStore.refreshIfNeeded(force: force)
    }

    private var serviceStatusControlState: CloudServiceStatusControlState {
        CloudServiceStatusPresentation.controlState(
            snapshot: cloudServiceStatusStore.snapshot,
            isLoading: cloudServiceStatusStore.isLoading,
            appLanguage: settings.appLanguage
        )
    }

}

extension TokenMeteringDashboardView {
    private var kpiStrip: some View {
        HStack(spacing: 12) {
            ForEach(store.snapshot.usageKPIs(for: store.snapshotInputScope, language: currentLanguage)) { kpi in
                let liveUpdateID = "kpi:\(kpi.id)"
                let isLiveUpdated = store.isLiveUpdated(liveUpdateID)
                let isHovered = hoveredKPI == kpi.id

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 6) {
                        Text(kpi.title.uppercased())
                            .font(.system(size: 9.5, weight: .black))
                            .tracking(1.2)
                            .foregroundStyle(.secondary.opacity(0.85))
                            .lineLimit(1)
                        TokenMeteringLiveUpdateDot(isActive: isLiveUpdated, marker: store.liveUpdateMarker)
                        Spacer(minLength: 0)
                        if kpi.id == "total",
                           let comparison = store.snapshot.comparisonTotalTokens,
                           comparison > 0 {
                            let delta = store.snapshot.totalTokens - comparison
                            let pct = Double(delta) / Double(comparison) * 100
                            HStack(spacing: 2) {
                                Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                                    .font(.system(size: 7, weight: .black))
                                Text(String(format: "%.0f%%", abs(pct)))
                                    .font(.system(size: 8, weight: .black))
                            }
                            .foregroundStyle(delta >= 0 ? Color.green : Color.red)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background((delta >= 0 ? Color.green : Color.red).opacity(0.1), in: Capsule())
                        }
                    }
                    Text(kpi.value)
                        .font(.system(size: 23, weight: .heavy, design: .rounded))
                        .foregroundStyle(kpi.id == "total" ? selectedControlAccent : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.35), value: kpi.value)
                    HStack(spacing: 4) {
                        Text(kpi.detail)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary.opacity(0.8))
                            .lineLimit(1)
                        if kpi.id == "total",
                           let comparison = store.snapshot.comparisonTotalTokens {
                            Text("· \(comparisonPeriodLabel): \(TokenUsageDashboardSnapshot.formatTokens(comparison))")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary.opacity(0.55))
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            isHovered
                                ? (kpi.id == "total" ? selectedControlAccent.opacity(0.09) : Color.primary.opacity(0.055))
                                : Color(NSColor.controlBackgroundColor).opacity(0.55)
                        )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: isHovered
                                    ? (kpi.id == "total" ? [selectedControlAccent.opacity(0.36), selectedControlAccent.opacity(0.16)] : [Color.primary.opacity(0.14), Color.primary.opacity(0.05)])
                                    : [Color.primary.opacity(0.08), Color.primary.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.6
                        )
                }
                .onHover { hovering in
                    hoveredKPI = hovering ? kpi.id : nil
                }
                .modifier(TokenMeteringLiveUpdateEffect(isActive: isLiveUpdated && !isHovered, marker: store.liveUpdateMarker, cornerRadius: 12))
            }
        }
        .redacted(reason: showsDashboardPlaceholder ? .placeholder : [])
    }

    private var hasAnyDashboardEvents: Bool {
        store.hasDashboardEvents
    }

    // Scope toggles keep showing the applied snapshot (whose scope drives every
    // rendered number, including the KPI strip) until the rebuilt snapshot lands,
    // so no placeholder pass is needed for the transition.
    private var isDashboardLoading: Bool {
        store.loadState == .idle || store.loadState == .loading
    }

}

extension TokenMeteringDashboardView {
    private var showsEmptyDashboardOverlay: Bool {
        guard aiStatusStore.statuses.isEmpty else {
            return false
        }

        guard !hasAnyDashboardEvents else {
            return false
        }

        switch store.loadState {
        case .loaded, .previewingEmpty:
            return true
        case .idle, .loading:
            return false
        }
    }

    private var showsDashboardPlaceholder: Bool {
        isDashboardLoading || showsEmptyDashboardOverlay
    }

    private var comparisonPeriodLabel: String {
        switch store.selectedPeriod {
        case .today:
            return t(.relativeYesterday)
        case .sevenDays:
            return t(.relativePreviousWeek)
        case .thirtyDays:
            return t(.relativePreviousMonth)
        case .all:
            return ""
        }
    }

    private var analyticsGrid: some View {
        TokenMeteringDashboardAnalyticsGrid(
            store: store,
            language: currentLanguage,
            showsPlaceholder: showsDashboardPlaceholder,
            hasEvents: hasAnyDashboardEvents,
            settingsAction: settingsAction,
            developerOptionsAction: developerOptionsAction
        )
    }

    private var emptyDashboardGuide: some View {
        TokenMeteringDashboardOnboardingGuide(
            language: currentLanguage,
            showsDeveloperOptions: store.isOnboardingPreviewEnabled && SpillBuildOptions.developerOptionsEnabled,
            settingsAction: settingsAction,
            developerOptionsAction: developerOptionsAction
        )
    }

    private var rightRail: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                agentStatusPanel
                modelPanel
                workflowUsagePanel
                setupPanel
            }
            .padding(.vertical, 18)
        }
    }

    private var agentStatusPanel: some View {
        TokenMeteringDashboardAgentStatusPanel(
            aiStatusStore: aiStatusStore,
            settings: settings,
            language: currentLanguage,
            appLanguage: settings.appLanguage
        )
    }

    private var setupPanel: some View {
        TokenMeteringDashboardSetupPanel(
            aiStatusStore: aiStatusStore,
            language: currentLanguage
        )
    }

}

extension TokenMeteringDashboardView {
    private var modelPanel: some View {
        TokenMeteringDashboardRailPanel(
            title: t(.modelBreakdown),
            infoTitle: t(.modelInfoTitle),
            infoDetail: t(.modelInfoDetail)
        ) {
            VStack(spacing: 8) {
                if showsDashboardPlaceholder {
                    TokenMeteringDashboardCompactLoadingRows()
                } else {
                    TokenMeteringDashboardCompactSummaryRows(
                        rows: store.snapshot.modelRows.prefix(5),
                        emptyText: t(.noModelData),
                        idPrefix: "model",
                        marker: store.liveUpdateMarker,
                        isLiveUpdated: { store.isLiveUpdated($0) }
                    )
                }
            }
        }
    }

    private var workflowUsagePanel: some View {
        TokenMeteringDashboardRailPanel(
            title: t(.workflowUsage),
            infoTitle: t(.workflowUsageInfoTitle),
            infoDetail: t(.workflowUsageInfoDetail)
        ) {
            VStack(spacing: 8) {
                if showsDashboardPlaceholder {
                    TokenMeteringDashboardCompactLoadingRows()
                } else {
                    TokenMeteringDashboardCompactSummaryRows(
                        rows: store.snapshot.workflowUsage.rows,
                        emptyText: t(.noWorkflowUsageData),
                        idPrefix: "workflow_usage",
                        marker: store.liveUpdateMarker,
                        isLiveUpdated: { store.isLiveUpdated($0) }
                    )
                }
            }
        }
    }

    private var sessionsTable: some View {
        TokenMeteringDashboardSessionsTable(
            store: store,
            language: currentLanguage,
            selectedControlAccent: selectedControlAccent,
            showsPlaceholder: showsDashboardPlaceholder,
            requestClear: requestClear
        )
    }

    private func requestClear(_ scope: TokenUsageClearScope) {
        guard SpillBuildOptions.developerOptionsEnabled else {
            return
        }
        let preview = store.clearPreview(for: scope)
        guard preview.hasEvents else {
            return
        }
        pendingClearRequest = TokenUsageClearRequest(scope: scope, preview: preview)
    }

    private var alphaBadge: some View {
        Text(t(.previewBadge).uppercased())
            .font(.system(size: 8, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(.orange.opacity(0.85))
            .padding(.horizontal, 6)
            .frame(height: 17)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.orange.opacity(0.08))
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(Color.orange.opacity(0.15), lineWidth: 0.5)
            }
    }

    private var isPrivateUsageUploadActive: Bool {
        PrivateUsageUploadFeatureAvailability.isEnabledInCurrentBuild
            && settings.privateUsageUploadEnabled
    }

    private var syncStateBadgeText: String {
        isPrivateUsageUploadActive ? t(.webSyncEnabled) : t(.localOnly)
    }

    private var syncStateBadgeColor: Color {
        isPrivateUsageUploadActive ? .blue : .green
    }

}

extension TokenMeteringDashboardView {
    private var syncStateBadge: some View {
        Text(syncStateBadgeText.uppercased())
            .font(.system(size: 8, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(syncStateBadgeColor.opacity(0.85))
            .padding(.horizontal, 6)
            .frame(height: 17)
            .background(
                Capsule(style: .continuous)
                    .fill(syncStateBadgeColor.opacity(0.08))
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(syncStateBadgeColor.opacity(0.15), lineWidth: 0.5)
            }
    }

    private func headerActionButton(
        systemImage: String,
        accessibilityLabel: String,
        helpText: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
        }
        .buttonStyle(HeaderActionButtonStyle(isEnabled: isEnabled))
        .disabled(!isEnabled)
        .help(helpText)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityHint(Text(helpText))
    }

    private var dashboardCardBackground: some ShapeStyle {
        .regularMaterial
    }
}

private struct HeaderActionButtonStyle: ButtonStyle {
    let isEnabled: Bool
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isEnabled ? Color.primary.opacity(0.72) : Color.primary.opacity(0.28))
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        configuration.isPressed
                            ? Color.primary.opacity(0.12)
                            : (isHovered && isEnabled ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04))
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        isHovered && isEnabled
                            ? Color.primary.opacity(0.14)
                            : Color.primary.opacity(0.08),
                        lineWidth: 0.5
                    )
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
