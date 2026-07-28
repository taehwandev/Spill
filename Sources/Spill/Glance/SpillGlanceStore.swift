import Combine
import Foundation

@MainActor
final class SpillGlanceStore: ObservableObject {
    @Published private(set) var presentation: SpillGlancePresentation

    private let now: () -> Date
    private var workRotationIdentity: SpillGlanceWorkRotationIdentity
    private var workRotationEpoch: Date
    private var cancellables = Set<AnyCancellable>()

    init(
        settings: SpillSettings,
        tokenUsageDashboardStore: TokenUsageDashboardStore,
        now: @escaping () -> Date = Date.init
    ) {
        let glanceSummary = tokenUsageDashboardStore.glanceSummary
        let workRotationEnabled = settings.glanceWorkRotationEnabled
        let rotationIdentity = Self.workRotationIdentity(
            panelSummary: glanceSummary,
            rotationEnabled: workRotationEnabled,
            surfaceEnabled: settings.glanceEnabled
        )
        let rotationEpoch = now()
        self.now = now
        workRotationIdentity = rotationIdentity
        workRotationEpoch = rotationEpoch
        presentation = Self.makePresentation(
            enabled: settings.glanceEnabled,
            modules: settings.visibleGlanceModules,
            panelSummary: glanceSummary,
            inputScope: settings.tokenUsageInputScope,
            workRotationEnabled: workRotationEnabled,
            workRotationEpoch: rotationEpoch
        )

        Publishers.CombineLatest4(
            settings.$glanceEnabled,
            settings.$enabledGlanceModules,
            settings.$tokenUsageInputScope,
            settings.$glanceWorkRotationEnabled
        )
        .combineLatest(tokenUsageDashboardStore.$glanceSummary)
        .sink { [weak self] configuration, glanceSummary in
            guard let self else {
                return
            }
            let (enabled, enabledModules, inputScope, workRotationEnabled) = configuration
            let nextRotationIdentity = Self.workRotationIdentity(
                panelSummary: glanceSummary,
                rotationEnabled: workRotationEnabled,
                surfaceEnabled: enabled
            )
            if nextRotationIdentity != workRotationIdentity {
                workRotationIdentity = nextRotationIdentity
                workRotationEpoch = now()
            }

            presentation = Self.makePresentation(
                enabled: enabled,
                modules: SpillGlanceModule.defaultOrder.filter {
                    SpillGlanceModule.fixedModules.contains($0)
                        || enabledModules.contains($0)
                },
                panelSummary: glanceSummary,
                inputScope: inputScope,
                workRotationEnabled: workRotationEnabled,
                workRotationEpoch: workRotationEpoch
            )
        }
        .store(in: &cancellables)
    }

    static func makePresentation(
        enabled: Bool,
        modules: [SpillGlanceModule],
        panelSummary: TokenUsagePanelSummarySnapshot,
        inputScope: TokenUsageInputScope,
        workRotationEnabled: Bool = true,
        workRotationEpoch: Date = Date()
    ) -> SpillGlancePresentation {
        guard enabled, !modules.isEmpty else {
            return .hidden
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
                    rotationEnabled: workRotationEnabled,
                    rotationEpoch: workRotationEpoch
                )
            }
        }

        return SpillGlancePresentation(isVisible: !items.isEmpty, items: items)
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
        let orderedRows = orderedWorkRows(panelSummary: panelSummary)
        let rows = rotationEnabled
            ? orderedRows
            : Array(orderedRows.prefix(1))
        let displayValues = rows.map {
            [
                compactTaskTitle(id: $0.id, title: $0.title),
                compactTokenValue(from: $0.value),
            ].joined(separator: " ")
        }
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
        let knownTitles = [
            "prd_drafting": "PRD",
            "code_generation": "Code",
            "ui_design": "UI",
            "prompt_design": "Prompt",
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
        if let knownTitle = knownTitles[id] {
            return knownTitle
        }
        if title.count <= 12 {
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

    static func workRotationIdentity(
        panelSummary: TokenUsagePanelSummarySnapshot,
        rotationEnabled: Bool,
        surfaceEnabled: Bool = true
    ) -> SpillGlanceWorkRotationIdentity {
        SpillGlanceWorkRotationIdentity(
            orderedWorkIDs: orderedWorkRows(panelSummary: panelSummary).map(\.id),
            rotationEnabled: rotationEnabled,
            surfaceEnabled: surfaceEnabled
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
}
