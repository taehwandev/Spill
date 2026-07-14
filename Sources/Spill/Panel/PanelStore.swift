import Combine
import Foundation

struct PanelState: Equatable {
    let displayItems: [MenuBarItemSnapshot]
    let selectedItemKeys: Set<String>
    let visibleStatusModules: [SpillStatusModule]
    let readiness: SpillPanelState
    let actionFeedback: SpillActionFeedback?
    let statusDetailTarget: SpillStatusDetailTarget?
    let pendingDismiss: Bool
    let onboardingPreviewEnabled: Bool
}

extension PanelState {
    var itemCount: Int {
        displayItems.count
    }

    var pinnedItemCount: Int {
        pinnedItems.count
    }

    var pinnedItems: [MenuBarItemSnapshot] {
        displayItems.filter { selectedItemKeys.contains($0.stableKey) }
    }

    var displayActionItems: [MenuBarItemSnapshot] {
        displayItems.filter { !selectedItemKeys.contains($0.stableKey) }
    }

    var actionItems: [SpillDisplayedActionItem] {
        var pinnedActionItems: [SpillDisplayedActionItem] = []
        var displayActionItems: [SpillDisplayedActionItem] = []

        for item in displayItems {
            let actionItem = Self.displayedActionItem(from: item, selectedItemKeys: selectedItemKeys)
            if actionItem.isPinned {
                pinnedActionItems.append(actionItem)
            } else {
                displayActionItems.append(actionItem)
            }
        }

        return pinnedActionItems + displayActionItems
    }
}

extension PanelState {
    @MainActor
    static func derived(
        settings: SpillSettings,
        scanner: AXMenuBarItemScanner,
        isAccessibilityTrusted: Bool
    ) -> PanelState {
        if settings.panelOnboardingPreviewEnabled {
            return onboardingPreview(visibleStatusModules: settings.visiblePanelStatusModules)
        }

        let displayItems = settings.displayMode.items(from: scanner, settings: settings)

        return derived(
            displayItems: displayItems,
            selectedItemKeys: settings.selectedItemKeys,
            visibleStatusModules: settings.visiblePanelStatusModules,
            isScanning: scanner.isScanning,
            isAccessibilityTrusted: isAccessibilityTrusted
        )
    }

    static func derived(
        notchCandidates: [MenuBarItemSnapshot],
        selectedItemKeys: Set<String>,
        hiddenItemKeys: Set<String>,
        visibleStatusModules: [SpillStatusModule] = SpillStatusModule.primaryPanelModules,
        isScanning: Bool,
        isAccessibilityTrusted: Bool
    ) -> PanelState {
        let displayItems = notchCandidates.filter { !hiddenItemKeys.contains($0.stableKey) }

        return derived(
            displayItems: displayItems,
            selectedItemKeys: selectedItemKeys,
            visibleStatusModules: visibleStatusModules,
            isScanning: isScanning,
            isAccessibilityTrusted: isAccessibilityTrusted
        )
    }

    static func derived(
        displayItems: [MenuBarItemSnapshot],
        selectedItemKeys: Set<String>,
        visibleStatusModules: [SpillStatusModule] = SpillStatusModule.primaryPanelModules,
        isScanning: Bool,
        isAccessibilityTrusted: Bool
    ) -> PanelState {
        return PanelState(
            displayItems: displayItems,
            selectedItemKeys: selectedItemKeys,
            visibleStatusModules: visibleStatusModules,
            readiness: SpillPanelState.current(
                isAccessibilityTrusted: isAccessibilityTrusted,
                isScanning: isScanning,
                isEmpty: displayItems.isEmpty
            ),
            actionFeedback: nil,
            statusDetailTarget: nil,
            pendingDismiss: false,
            onboardingPreviewEnabled: false
        )
    }

    static func onboardingPreview(
        visibleStatusModules: [SpillStatusModule] = SpillStatusModule.primaryPanelModules
    ) -> PanelState {
        PanelState(
            displayItems: [],
            selectedItemKeys: [],
            visibleStatusModules: visibleStatusModules,
            readiness: .empty,
            actionFeedback: nil,
            statusDetailTarget: nil,
            pendingDismiss: false,
            onboardingPreviewEnabled: true
        )
    }
}

extension PanelState {
    func replacingTransientState(
        actionFeedback: SpillActionFeedback?,
        statusDetailTarget: SpillStatusDetailTarget?,
        pendingDismiss: Bool
    ) -> PanelState {
        PanelState(
            displayItems: displayItems,
            selectedItemKeys: selectedItemKeys,
            visibleStatusModules: visibleStatusModules,
            readiness: readiness,
            actionFeedback: actionFeedback,
            statusDetailTarget: statusDetailTarget,
            pendingDismiss: pendingDismiss,
            onboardingPreviewEnabled: onboardingPreviewEnabled
        )
    }

    private static func displayedActionItem(
        from item: MenuBarItemSnapshot,
        selectedItemKeys: Set<String>
    ) -> SpillDisplayedActionItem {
        SpillDisplayedActionItem(
            sourceItem: item,
            action: MenuBarActionAdapter.action(from: item),
            isPinned: selectedItemKeys.contains(item.stableKey)
        )
    }
}

enum PanelAction: Equatable {
    case refreshDerivedState
    case setStatusDetailTarget(SpillStatusDetailTarget?)
    case dismissRequestHandled
    case togglePinned(MenuBarItemSnapshot)
    case performMenuBarAction(SpillDisplayedActionItem)
    case performWindowAction(SpillAction)
}

private enum TransientUpdate<Value> {
    case preserve
    case replace(Value)

    func resolve(current: Value) -> Value {
        switch self {
        case .preserve:
            return current
        case let .replace(value):
            return value
        }
    }
}

@MainActor
final class PanelStore: ObservableObject {
    typealias AccessibilityTrustReader = () -> Bool
    typealias ActionPerformer = @MainActor (SpillAction) -> SpillActionResult
    typealias StateBuilder = @MainActor (SpillSettings, AXMenuBarItemScanner, Bool) -> PanelState

    @Published private(set) var state: PanelState

    private let settings: SpillSettings
    private let scanner: AXMenuBarItemScanner
    private let isAccessibilityTrusted: AccessibilityTrustReader
    private let menuBarActionPerformer: ActionPerformer
    private let windowActionPerformer: ActionPerformer
    private let stateBuilder: StateBuilder
    private var refreshScheduled = false
    private var cancellables = Set<AnyCancellable>()

    init(
        settings: SpillSettings,
        scanner: AXMenuBarItemScanner,
        isAccessibilityTrusted: @escaping AccessibilityTrustReader = { AccessibilityPermission.isTrusted },
        menuBarActionPerformer: ActionPerformer? = nil,
        windowActionPerformer: @escaping ActionPerformer = { _ in .unsupported },
        stateBuilder: @escaping StateBuilder = PanelState.derived(settings:scanner:isAccessibilityTrusted:)
    ) {
        self.settings = settings
        self.scanner = scanner
        self.isAccessibilityTrusted = isAccessibilityTrusted
        self.menuBarActionPerformer = menuBarActionPerformer ?? { action in
            MenuBarActionExecutor(scanner: scanner).perform(action)
        }
        self.windowActionPerformer = windowActionPerformer
        self.stateBuilder = stateBuilder
        state = stateBuilder(settings, scanner, isAccessibilityTrusted())
        observeInputs()
    }
}

extension PanelStore {
    func send(_ action: PanelAction) {
        switch action {
        case .refreshDerivedState:
            refreshDerivedState()
        case let .setStatusDetailTarget(target):
            if let target {
                SpillTelemetry.shared.track("status_detail_opened", props: telemetryProps(for: target))
            }
            updateTransientState(statusDetailTarget: .replace(target), pendingDismiss: .replace(false))
        case .dismissRequestHandled:
            updateTransientState(pendingDismiss: .replace(false))
        case let .togglePinned(item):
            togglePinned(item)
        case let .performMenuBarAction(item):
            perform(item)
        case let .performWindowAction(action):
            performWindowAction(action)
        }
    }

    private func observeInputs() {
        let publishers: [AnyPublisher<Void, Never>] = [
            scanner.$items.map { _ in () }.eraseToAnyPublisher(),
            scanner.$isScanning.map { _ in () }.eraseToAnyPublisher(),
            settings.$displayMode.map { _ in () }.eraseToAnyPublisher(),
            settings.$selectedItemKeys.map { _ in () }.eraseToAnyPublisher(),
            settings.$hiddenItemKeys.map { _ in () }.eraseToAnyPublisher(),
            settings.$statusModuleOrder.map { _ in () }.eraseToAnyPublisher(),
            settings.$enabledStatusModules.map { _ in () }.eraseToAnyPublisher(),
            settings.$panelOnboardingPreviewEnabled.map { _ in () }.eraseToAnyPublisher()
        ]

        Publishers.MergeMany(publishers)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.scheduleCoalescedRefresh()
                }
            }
            .store(in: &cancellables)
    }

    private func scheduleCoalescedRefresh() {
        guard !refreshScheduled else {
            return
        }

        refreshScheduled = true
        Task { @MainActor [weak self] in
            // Let sibling @Published updates in the current main-actor turn settle before deriving state.
            await Task.yield()
            self?.refreshScheduled = false
            self?.refreshDerivedState()
        }
    }
}

private extension PanelStore {
    private func refreshDerivedState() {
        let currentState = state
        state = stateBuilder(settings, scanner, isAccessibilityTrusted())
            .replacingTransientState(
                actionFeedback: currentState.actionFeedback,
                statusDetailTarget: currentState.statusDetailTarget,
                pendingDismiss: currentState.pendingDismiss
            )
    }

    private func updateTransientState(
        actionFeedback: TransientUpdate<SpillActionFeedback?> = .preserve,
        statusDetailTarget: TransientUpdate<SpillStatusDetailTarget?> = .preserve,
        pendingDismiss: TransientUpdate<Bool> = .preserve
    ) {
        let currentState = state
        state = state.replacingTransientState(
            actionFeedback: actionFeedback.resolve(current: currentState.actionFeedback),
            statusDetailTarget: statusDetailTarget.resolve(current: currentState.statusDetailTarget),
            pendingDismiss: pendingDismiss.resolve(current: currentState.pendingDismiss)
        )
    }

    private func togglePinned(_ item: MenuBarItemSnapshot) {
        let isPinned = settings.selectedItemKeys.contains(item.stableKey)
        settings.setItem(item, selected: !isPinned)
        SpillTelemetry.shared.track(
            "pinned_item_toggled",
            props: ["state": isPinned ? "unpinned" : "pinned"]
        )
        refreshDerivedState()
        updateTransientState(
            actionFeedback: .replace(SpillActionFeedback(
                result: .success,
                title: item.displayTitle,
                overrideMessage: isPinned
                    ? AppL10n.unpinned(item.displayTitle, appLanguage: settings.appLanguage)
                    : AppL10n.pinned(item.displayTitle, appLanguage: settings.appLanguage)
            )),
            pendingDismiss: .replace(false)
        )
    }
}

private extension PanelStore {
    private func perform(_ item: SpillDisplayedActionItem) {
        let result = menuBarActionPerformer(item.action)
        SpillTelemetry.shared.track(
            "menu_bar_action_performed",
            props: [
                "source": "panel",
                "result": telemetryResult(result)
            ]
        )
        updateTransientState(
            actionFeedback: .replace(SpillActionFeedback(result: result, title: item.action.title)),
            pendingDismiss: .replace(result == .success)
        )
    }

    private func performWindowAction(_ action: SpillAction) {
        let result = windowActionPerformer(action)
        if case let .window(kind) = action.kind {
            SpillTelemetry.shared.track(
                "window_action_performed",
                props: [
                    "source": "panel",
                    "kind": kind.rawValue,
                    "result": telemetryResult(result)
                ]
            )
        }
        updateTransientState(
            actionFeedback: .replace(SpillActionFeedback(result: result, title: action.title)),
            pendingDismiss: .replace(false)
        )
    }

    private func telemetryProps(for target: SpillStatusDetailTarget) -> [String: String] {
        switch target {
        case let .system(module):
            return ["target": "system", "module": module.rawValue]
        case .ai:
            return ["target": "ai"]
        }
    }

    private func telemetryResult(_ result: SpillActionResult) -> String {
        switch result {
        case .success:
            return "success"
        case .unavailable:
            return "unavailable"
        case .permissionRequired:
            return "permission_required"
        case .unsupported:
            return "unsupported"
        case .failed:
            return "failed"
        }
    }
}
