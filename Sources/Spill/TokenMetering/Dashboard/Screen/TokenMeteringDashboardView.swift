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
    @State private var aiToolVisibilityObserver: NSObjectProtocol?
    @State private var visibleAIToolsSyncTask: Task<Void, Never>?
    @StateObject private var limitStore = TokenUsageDashboardLimitStore()
    private var limitSnapshots: [TokenUsageLimitSnapshot] { limitStore.snapshots }
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

            dashboardBody
        }
        .background(VisualEffectView(material: .sidebar, blendingMode: .withinWindow))
        .frame(
            minWidth: TokenMeteringDashboardWindowMetrics.minimumContentSize.width,
            minHeight: TokenMeteringDashboardWindowMetrics.minimumContentSize.height
        )
        .focusEffectDisabled()
        // Limit snapshots refresh whenever the panel summary does — the same
        // cadence that already tracks collection cycles — so the strip needs
        // no timer of its own. File reads run off the main thread and coalesce.
        .onReceive(
            NotificationCenter.default.publisher(
                for: TokenUsageLimitInboxMonitor.limitsDidChangeNotification
            )
        ) { _ in
            // Limits change on their own cadence, so they cannot wait for the
            // panel summary to publish for some unrelated reason.
            limitStore.refresh()
        }
        .onReceive(store.$panelSummary) { _ in
            limitStore.refresh()
        }
        .onAppear {
            limitStore.refresh()
            let language = TokenMeteringLanguage.current(appLanguage: settings.appLanguage)
            resolvedLanguage = language
            titleDidChange()
            store.setLanguage(language)
            store.setUsageInputScope(settings.tokenUsageInputScope)
            syncOnboardingPreviewFromSettings()
            if syncsVisibleAITools {
                installAIToolVisibilityObserver()
            }
            if syncsVisibleAITools {
                syncVisibleAITools()
            }
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

    /// Two columns under the header. The left column is the analysis: tool
    /// tabs (with each tool's limits) and periods stay pinned, and the usage
    /// sections scroll beneath them. The right column runs from the top as
    /// its own scrolling sidebar, so status and setup never read as part of
    /// the analysis flow.
    private var dashboardBody: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                topFilterBar

                Divider()
                    .background(Color.primary.opacity(0.05))

                ZStack(alignment: .top) {
                    analysisScroll
                        .modifier(EmptyDashboardDimming(isActive: showsEmptyDashboardOverlay))

                    if showsEmptyDashboardOverlay {
                        emptyDashboardGuide
                            .frame(maxWidth: 680)
                            .padding(.top, 42)
                            .padding(.horizontal, 32)
                            .shadow(color: Color.black.opacity(0.18), radius: 20, x: 0, y: 12)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }
                }
            }
            .padding(.leading, 18)
            .padding(.trailing, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            Divider()
                .background(Color.primary.opacity(0.05))

            sideColumn
                .padding(.leading, 16)
                .padding(.trailing, 18)
                .modifier(EmptyDashboardDimming(isActive: showsEmptyDashboardOverlay))
        }
        .animation(.easeOut(duration: 0.18), value: store.selectedSessionID)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// Reading order: how much was used (totals, trend), where the tokens
    /// went, which work dominated, then Work Items. Limits are not repeated
    /// here; they sit pinned inside each tool tab.
    private var analysisScroll: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 16) {
                kpiStrip

                if showsDashboardPlaceholder || hasAnyDashboardEvents {
                    TokenMeteringDashboardTrendSection(
                        store: store,
                        language: currentLanguage,
                        showsPlaceholder: showsDashboardPlaceholder
                    )

                    TokenMeteringDashboardAttributionSection(
                        store: store,
                        language: currentLanguage,
                        showsPlaceholder: showsDashboardPlaceholder
                    )

                    TokenMeteringDashboardWorkBreakdownSection(
                        store: store,
                        language: currentLanguage,
                        showsPlaceholder: showsDashboardPlaceholder
                    )
                } else {
                    emptyDashboardGuide
                }

                sessionsTable
            }
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var sideColumn: some View {
        if let selectedSession = store.snapshot.selectedSession,
           !showsDashboardPlaceholder {
            receiverPanel(selectedSession)
                .padding(.vertical, 12)
                .transition(.opacity)
        } else {
            TokenMeteringDashboardRightRail(
                store: store,
                aiStatusStore: aiStatusStore,
                settings: settings,
                language: currentLanguage,
                showsPlaceholder: showsDashboardPlaceholder
            )
            .frame(width: 286)
            .transition(.opacity)
        }
    }

}

extension TokenMeteringDashboardView {
    private func receiverPanel(_ selectedSession: TokenUsageDashboardSessionRow) -> some View {
        TokenMeteringDashboardDetailPanel(
            session: selectedSession,
            snapshot: store.snapshot,
            inputScope: store.snapshotInputScope,
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
        TokenMeteringDashboardHeader(
            language: currentLanguage,
            appLanguage: settings.appLanguage,
            lastUpdated: store.snapshot.overallLastUpdatedString,
            isPrivateUsageUploadActive: isPrivateUsageUploadActive,
            isRefreshing: store.loadState == .loading || store.isRefreshing,
            isWebDashboardAvailable: PrivateUsageWebConnection.dashboardURL() != nil,
            onOpenWebDashboard: openWebDashboard,
            onRefresh: refreshLocalTokenData,
            onOpenSettings: settingsAction
        ) {
            serviceStatusButton
        }
    }

    private var kpiStrip: some View {
        TokenMeteringDashboardKPIStrip(
            kpis: store.snapshot.usageKPIs(for: store.snapshotInputScope, language: currentLanguage),
            totalComparison: store.snapshot.usageComparison(for: store.snapshotInputScope),
            comparisonCaption: store.snapshot.comparisonTotalTokens.map {
                "\(comparisonPeriodLabel): \(TokenUsageDashboardSnapshot.formatTokens($0))"
            },
            accent: selectedControlAccent,
            showsPlaceholder: showsDashboardPlaceholder,
            marker: store.liveUpdateMarker,
            isLiveUpdated: { store.isLiveUpdated($0) }
        )
    }

    private var limitsPresentation: TokenMeteringDashboardLimitsPresentation {
        TokenMeteringDashboardLimitsPresentation(
            snapshots: visibleLimitSnapshots,
            tools: visibleLimitTools,
            language: currentLanguage
        )
    }
}

/// While the empty-state guide floats over the dashboard, the content behind
/// it stays visible as a muted preview and cannot be operated.
private struct EmptyDashboardDimming: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isActive ? 0.58 : 1)
            .saturation(isActive ? 0.55 : 1)
            .blur(radius: isActive ? 0.4 : 0)
            .disabled(isActive)
            .accessibilityHidden(isActive)
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

    /// The limits strip honors the same tool-hiding setting as every other
    /// dashboard surface: hidden tools contribute no chips.
    private var visibleLimitSnapshots: [TokenUsageLimitSnapshot] {
        let visibleTools = visibleLimitTools
        return limitSnapshots.filter { visibleTools.contains($0.aiTool) }
    }

    /// Every tool the user has not hidden, whether or not a reading exists for
    /// it. The strip keeps a chip for each one so a tool never blinks out of
    /// the row when its source goes quiet.
    private var visibleLimitTools: Set<TokenUsageAITool> {
        TokenUsageDashboardToolVisibility.visibleTools(
            hiddenTools: settings.hiddenTokenUsageAITools
        )
    }

    private func syncVisibleAITools() {
        refreshLocalAIStatus()
        store.setVisibleAITools(
            TokenUsageDashboardToolVisibility.visibleTools(
                hiddenTools: settings.hiddenTokenUsageAITools
            )
        )
    }

    private func refreshLocalAIStatus() {
        aiStatusStore.setEnabledKinds(
            TokenMeteringToolAvailability.supportedLocalToolKindSet
                .subtracting(settings.hiddenLocalAIToolKinds)
        )
        aiStatusStore.refreshInBackground()
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
            syncVisibleAITools()
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
            aiStatusStore: aiStatusStore,
            isCalendarPickerPresented: $isCalendarPickerPresented,
            language: currentLanguage,
            appLanguage: settings.appLanguage,
            selectedControlAccent: selectedControlAccent,
            selectedControlAccentHighlight: selectedControlAccentHighlight,
            limitsPresentation: limitsPresentation
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
        if syncsVisibleAITools {
            syncVisibleAITools()
        } else {
            refreshLocalAIStatus()
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
    private var hasAnyDashboardEvents: Bool {
        store.hasDashboardEvents
    }

    // Scope toggles keep showing the applied snapshot (whose scope drives every
    // rendered number, including the KPI strip) until the rebuilt snapshot lands,
    // so no placeholder pass is needed for the transition.
    private var isDashboardLoading: Bool {
        store.loadState == .idle || store.loadState == .loading
    }

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

    private var emptyDashboardGuide: some View {
        TokenMeteringDashboardOnboardingGuide(
            language: currentLanguage,
            showsDeveloperOptions: store.isOnboardingPreviewEnabled && SpillBuildOptions.developerOptionsEnabled,
            settingsAction: settingsAction,
            developerOptionsAction: developerOptionsAction
        )
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

    private var isPrivateUsageUploadActive: Bool {
        PrivateUsageUploadFeatureAvailability.isEnabledInCurrentBuild
            && settings.privateUsageUploadEnabled
    }
}
