import Combine
import Foundation

@MainActor
final class SpillGlanceStore: ObservableObject {
    @Published private(set) var presentation: SpillGlancePresentation
    /// True while the panel window is fully occluded (covered, or on another
    /// Space). The surface stops its rotation schedule then: redrawing a strip
    /// nobody can see is pure wasted layout. Values keep updating through
    /// `presentation`, so the strip is current the moment it becomes visible.
    @Published private(set) var isRotationPaused = false

    private let now: () -> Date
    private var rotationIdentity: SpillGlanceRotationIdentity
    private var rotationEpoch: Date
    private var changeQueue: SpillGlanceChangeQueue
    private var changeBaseline: ChangeBaseline
    private var cancellables = Set<AnyCancellable>()

    init(
        settings: SpillSettings,
        tokenUsageDashboardStore: TokenUsageDashboardStore,
        now: @escaping () -> Date = Date.init
    ) {
        let glanceSummary = tokenUsageDashboardStore.glanceSummary
        let workRotationEnabled = settings.glanceWorkRotationEnabled
        let reactiveRotationEnabled = settings.glanceReactiveRotationEnabled
        let modules = settings.visibleGlanceModules
        let initialRotationIdentity = Self.rotationIdentity(
            panelSummary: glanceSummary,
            modules: modules,
            workRotationEnabled: workRotationEnabled,
            reactiveRotationEnabled: reactiveRotationEnabled,
            displayStyle: settings.glanceDisplayStyle,
            surfaceEnabled: settings.glanceEnabled
        )
        let initialRotationEpoch = now()
        let initialPresentation = Self.makePresentation(
            enabled: settings.glanceEnabled,
            modules: modules,
            panelSummary: glanceSummary,
            inputScope: settings.tokenUsageInputScope,
            displayStyle: settings.glanceDisplayStyle,
            showInFullScreen: settings.glanceShowInFullScreen,
            reactiveRotationEnabled: reactiveRotationEnabled,
            workRotationEnabled: workRotationEnabled,
            rotationEpoch: initialRotationEpoch
        )
        self.now = now
        rotationIdentity = initialRotationIdentity
        rotationEpoch = initialRotationEpoch
        changeQueue = SpillGlanceChangeQueue()
        changeBaseline = Self.changeBaseline(
            items: initialPresentation.items,
            panelSummary: glanceSummary
        )
        presentation = initialPresentation

        let configuration = Publishers.CombineLatest4(
            settings.$glanceEnabled,
            settings.$enabledGlanceModules,
            settings.$tokenUsageInputScope,
            settings.$glanceWorkRotationEnabled
        )
        let surface = Publishers.CombineLatest3(
            settings.$glanceDisplayStyle,
            settings.$glanceShowInFullScreen,
            settings.$glanceReactiveRotationEnabled
        )

        configuration
            .combineLatest(surface, tokenUsageDashboardStore.$glanceSummary)
            .sink { [weak self] configuration, surface, glanceSummary in
                let (enabled, enabledModules, inputScope, workRotationEnabled) = configuration
                let (displayStyle, showInFullScreen, reactiveRotationEnabled) = surface
                self?.apply(
                    enabled: enabled,
                    enabledModules: enabledModules,
                    inputScope: inputScope,
                    workRotationEnabled: workRotationEnabled,
                    displayStyle: displayStyle,
                    showInFullScreen: showInFullScreen,
                    reactiveRotationEnabled: reactiveRotationEnabled,
                    panelSummary: glanceSummary
                )
            }
            .store(in: &cancellables)
    }

    func setRotationPaused(_ paused: Bool) {
        guard isRotationPaused != paused else {
            return
        }
        isRotationPaused = paused
    }

    static func makePresentation(
        enabled: Bool,
        modules: [SpillGlanceModule],
        panelSummary: TokenUsagePanelSummarySnapshot,
        inputScope: TokenUsageInputScope,
        displayStyle: SpillGlanceDisplayStyle = .all,
        showInFullScreen: Bool = false,
        reactiveRotationEnabled: Bool = false,
        workRotationEnabled: Bool = true,
        rotationEpoch: Date = Date(),
        changeQueue: SpillGlanceChangeQueue = SpillGlanceChangeQueue()
    ) -> SpillGlancePresentation {
        guard enabled, !modules.isEmpty else {
            return .hidden(
                displayStyle: displayStyle,
                showInFullScreen: showInFullScreen,
                reactiveRotationEnabled: reactiveRotationEnabled,
                rotationEpoch: rotationEpoch
            )
        }

        var seenModules = Set<SpillGlanceModule>()
        let items = modules.compactMap { module -> SpillGlanceItem? in
            guard seenModules.insert(module).inserted else {
                return nil
            }

            switch module {
            case .allToday:
                return allTodayItem(
                    panelSummary: panelSummary,
                    inputScope: inputScope
                )
            case .codexToday:
                return toolItem(
                    module: module,
                    title: "Codex",
                    symbolName: "terminal.fill",
                    tool: .codex,
                    tint: .codex,
                    panelSummary: panelSummary
                )
            case .claudeToday:
                return toolItem(
                    module: module,
                    title: "Claude",
                    symbolName: "command",
                    tool: .claude,
                    tint: .claude,
                    panelSummary: panelSummary
                )
            case .antigravityToday:
                return toolItem(
                    module: module,
                    title: "AGY",
                    symbolName: "sparkles",
                    tool: .antigravity,
                    tint: .antigravity,
                    panelSummary: panelSummary
                )
            case .workType:
                return workTypeItem(
                    panelSummary: panelSummary,
                    rotationEnabled: workRotationEnabled && !reactiveRotationEnabled,
                    rotationEpoch: rotationEpoch
                )
            }
        }

        return SpillGlancePresentation(
            isVisible: !items.isEmpty,
            items: items,
            displayStyle: displayStyle,
            showInFullScreen: showInFullScreen,
            reactiveRotationEnabled: reactiveRotationEnabled,
            rotationEpoch: rotationEpoch,
            changeQueue: changeQueue
        )
    }
}

private extension SpillGlanceStore {
    func apply(
        enabled: Bool,
        enabledModules: Set<SpillGlanceModule>,
        inputScope: TokenUsageInputScope,
        workRotationEnabled: Bool,
        displayStyle: SpillGlanceDisplayStyle,
        showInFullScreen: Bool,
        reactiveRotationEnabled: Bool,
        panelSummary: TokenUsagePanelSummarySnapshot
    ) {
        let modules = SpillGlanceModule.defaultOrder.filter {
            SpillGlanceModule.fixedModules.contains($0)
                || enabledModules.contains($0)
        }
        let nextRotationIdentity = Self.rotationIdentity(
            panelSummary: panelSummary,
            modules: modules,
            workRotationEnabled: workRotationEnabled,
            reactiveRotationEnabled: reactiveRotationEnabled,
            displayStyle: displayStyle,
            surfaceEnabled: enabled
        )
        let didReconfigure = nextRotationIdentity.configuration != rotationIdentity.configuration
        if nextRotationIdentity != rotationIdentity {
            rotationIdentity = nextRotationIdentity
            rotationEpoch = now()
        }

        let basePresentation = Self.makePresentation(
            enabled: enabled,
            modules: modules,
            panelSummary: panelSummary,
            inputScope: inputScope,
            displayStyle: displayStyle,
            showInFullScreen: showInFullScreen,
            reactiveRotationEnabled: reactiveRotationEnabled,
            workRotationEnabled: workRotationEnabled,
            rotationEpoch: rotationEpoch
        )
        let items = basePresentation.items

        let nextBaseline = Self.changeBaseline(items: items, panelSummary: panelSummary)
        changeQueue = Self.advancedQueue(
            changeQueue,
            reactiveRotationEnabled: reactiveRotationEnabled,
            didReconfigure: didReconfigure,
            displayStyle: displayStyle,
            workRotationEnabled: workRotationEnabled,
            items: items,
            previous: changeBaseline,
            next: nextBaseline,
            at: now()
        )
        changeBaseline = nextBaseline

        presentation = SpillGlancePresentation(
            isVisible: basePresentation.isVisible,
            items: items,
            displayStyle: displayStyle,
            showInFullScreen: showInFullScreen,
            reactiveRotationEnabled: reactiveRotationEnabled,
            rotationEpoch: rotationEpoch,
            changeQueue: changeQueue
        )
    }
}

extension SpillGlanceStore {
    static func allTodayItem(
        panelSummary: TokenUsagePanelSummarySnapshot,
        inputScope: TokenUsageInputScope
    ) -> SpillGlanceItem {
        let totalTokens = panelSummary.usageTotal(for: inputScope)
        return SpillGlanceItem(
            module: .allToday,
            title: "All",
            value: TokenUsageDashboardSnapshot.formatTokens(totalTokens),
            symbolName: "chart.bar.fill",
            tint: totalTokens > 0 ? .active : .muted
        )
    }

    static func toolItem(
        module: SpillGlanceModule,
        title: String,
        symbolName: String,
        tool: TokenUsageAITool,
        tint: SpillGlanceTint,
        panelSummary: TokenUsagePanelSummarySnapshot
    ) -> SpillGlanceItem {
        guard let row = panelSummary.toolRows.first(where: { $0.id == tool.rawValue }) else {
            return SpillGlanceItem(
                module: module,
                title: title,
                value: "—",
                symbolName: symbolName,
                tint: tint
            )
        }

        return SpillGlanceItem(
            module: module,
            title: title,
            value: compactTokenValue(from: row.value),
            symbolName: symbolName,
            tint: tint
        )
    }

    static func workTypeItem(
        panelSummary: TokenUsagePanelSummarySnapshot,
        rotationEnabled: Bool,
        rotationEpoch: Date
    ) -> SpillGlanceItem {
        let orderedValues = orderedWorkValues(panelSummary: panelSummary)
        let displayValues = (rotationEnabled ? orderedValues : Array(orderedValues.prefix(1)))
            .map(\.value)
        guard !displayValues.isEmpty else {
            return SpillGlanceItem(
                module: .workType,
                title: "Work",
                value: "—",
                symbolName: "tag",
                tint: .muted
            )
        }

        return SpillGlanceItem(
            module: .workType,
            title: "Work",
            displayValues: displayValues,
            rotationEpoch: rotationEnabled && displayValues.count > 1 ? rotationEpoch : nil,
            symbolName: "tag.fill",
            tint: .normal
        )
    }

    static func compactTokenValue(from rowValue: String) -> String {
        rowValue.split(separator: " ", maxSplits: 1).first.map(String.init) ?? rowValue
    }

    static func compactTaskTitle(id: String, title: String) -> String {
        if let knownTitle = knownWorkTitles[id] {
            return knownTitle
        }
        if title.count <= maximumWorkTitleLength {
            return title
        }

        let initials = id
            .split(separator: "_")
            .prefix(4)
            .compactMap(\.first)
            .map { String($0).uppercased() }
            .joined()
        return initials.isEmpty ? "Work" : initials
    }

    static func rotationIdentity(
        panelSummary: TokenUsagePanelSummarySnapshot,
        modules: [SpillGlanceModule],
        workRotationEnabled: Bool,
        reactiveRotationEnabled: Bool = false,
        displayStyle: SpillGlanceDisplayStyle,
        surfaceEnabled: Bool = true
    ) -> SpillGlanceRotationIdentity {
        SpillGlanceRotationIdentity(
            configuration: SpillGlanceRotationIdentity.Configuration(
                orderedModules: modules,
                workRotationEnabled: workRotationEnabled,
                reactiveRotationEnabled: reactiveRotationEnabled,
                displayStyle: displayStyle,
                surfaceEnabled: surfaceEnabled
            ),
            orderedWorkIDs: orderedWorkRows(panelSummary: panelSummary).map(\.id)
        )
    }

    static func orderedWorkRows(
        panelSummary: TokenUsagePanelSummarySnapshot
    ) -> [TokenUsageDashboardBarRow] {
        panelSummary.taskRows.sorted { lhs, rhs in
            if lhs.ratio == rhs.ratio {
                return lhs.id < rhs.id
            }
            return lhs.ratio > rhs.ratio
        }
    }

    static func orderedWorkValues(
        panelSummary: TokenUsagePanelSummarySnapshot
    ) -> [WorkValue] {
        orderedWorkRows(panelSummary: panelSummary).map { row in
            WorkValue(
                id: row.id,
                value: [
                    compactTaskTitle(id: row.id, title: row.title),
                    compactTokenValue(from: row.value),
                ].joined(separator: " ")
            )
        }
    }

    /// Titles long enough to overflow the fixed Work cell fall back to initials.
    static let maximumWorkTitleLength = 12

    static let knownWorkTitles: [String: String] = [
        "prd_drafting": "PRD",
        "architecture": "Arch",
        "code_generation": "Code",
        "ui_design": "UI",
        "prompt_design": "Prompt",
        "refactoring": "Refactor",
        "code_review": "Review",
        "review_response": "Review",
        "test_generation": "Tests",
        "build_verification": "Build",
        "bug_reproduction": "Repro",
        "release_notes": "Notes",
        "release_packaging": "Release",
        "git_commit": "Commit",
        "commit_message": "Commit",
        "pull_request": "PR",
        "workflow_setup": "Workflow",
        "uncategorized": "Other",
    ]
}
