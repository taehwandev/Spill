import Combine
import Foundation

@MainActor
final class PanelStore: ObservableObject {
    typealias ActionPerformer = @MainActor (SpillAction) -> SpillActionResult
    @Published private(set) var state: PanelState
    private let settings: SpillSettings
    private let windowActionPerformer: ActionPerformer
    private var refreshScheduled = false
    private var cancellables = Set<AnyCancellable>()

    init(settings: SpillSettings, windowActionPerformer: @escaping ActionPerformer = { _ in .unsupported }) {
        self.settings = settings
        self.windowActionPerformer = windowActionPerformer
        state = PanelState(visibleStatusModules: settings.visiblePanelStatusModules)
        let publishers: [AnyPublisher<Void, Never>] = [
            settings.$statusModuleOrder.map { _ in () }.eraseToAnyPublisher(),
            settings.$enabledStatusModules.map { _ in () }.eraseToAnyPublisher()
        ]
        Publishers.MergeMany(publishers)
            .sink { [weak self] _ in
                Task { @MainActor in self?.scheduleCoalescedRefresh() }
            }
            .store(in: &cancellables)
    }

    func send(_ action: PanelAction) {
        switch action {
        case .refreshDerivedState:
            refreshDerivedState()
        case let .setStatusDetailTarget(target):
            if let target {
                SpillTelemetry.shared.track("status_detail_opened", props: telemetryProps(for: target))
            }
            state.statusDetailTarget = target
        case let .performWindowAction(action):
            let result = windowActionPerformer(action)
            if case let .window(kind) = action.kind {
                SpillTelemetry.shared.track("window_action_performed",
                    props: ["source": "panel", "kind": kind.rawValue, "result": telemetryResult(result)])
            }
            state.actionFeedback = SpillActionFeedback(result: result, title: action.title)
        }
    }

    private func scheduleCoalescedRefresh() {
        guard !refreshScheduled else { return }
        refreshScheduled = true
        Task { @MainActor [weak self] in
            await Task.yield()
            self?.refreshScheduled = false
            self?.refreshDerivedState()
        }
    }

    private func refreshDerivedState() {
        state = PanelState(visibleStatusModules: settings.visiblePanelStatusModules,
            actionFeedback: state.actionFeedback, statusDetailTarget: state.statusDetailTarget)
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
