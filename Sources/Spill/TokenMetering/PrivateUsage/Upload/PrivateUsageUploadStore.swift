import Combine
import Foundation


@MainActor
final class PrivateUsageUploadStore: ObservableObject {
    @Published var status = PrivateUsageUploadStatus.disconnected
    @Published var isConnecting = false
    @Published var isSyncing = false
    @Published var message: String?
    @Published var errorMessage: String?

    let settings: SpillSettings
    let coordinatorFactory: (PrivateUsageUploadEnvironment) -> PrivateUsageUploadCoordinator
    let prepareForUpload: @MainActor () async -> Void
    var coordinator: PrivateUsageUploadCoordinator
    var coordinatorEnvironment: PrivateUsageUploadEnvironment
    var refreshTask: Task<Void, Never>?
    var webConnectionWaitTask: Task<Void, Never>?
    var refreshGeneration = 0
    private var cancellables = Set<AnyCancellable>()

    init(
        settings: SpillSettings,
        usageStore: TokenUsageStore,
        coordinator: PrivateUsageUploadCoordinator? = nil,
        prepareForUpload: @escaping @MainActor () async -> Void = {}
    ) {
        self.settings = settings
        self.prepareForUpload = prepareForUpload
        coordinatorEnvironment = settings.privateUsageUploadEnvironment
        if let coordinator {
            coordinatorFactory = { _ in coordinator }
            self.coordinator = coordinator
        } else {
            let factory: (PrivateUsageUploadEnvironment) -> PrivateUsageUploadCoordinator = { environment in
                .live(usageStore: usageStore, environment: environment)
            }
            coordinatorFactory = factory
            self.coordinator = factory(coordinatorEnvironment)
        }
        observeConnectionResults()
        refresh()
    }

    deinit {
        refreshTask?.cancel()
        webConnectionWaitTask?.cancel()
    }

}

private extension PrivateUsageUploadStore {
    func observeConnectionResults() {
        NotificationCenter.default.publisher(for: PrivateUsageConnectionResultNotification.didFinish)
            .compactMap(PrivateUsageConnectionResultNotification.payload)
            .receive(on: RunLoop.main)
            .sink { [weak self] payload in
                self?.handleConnectionResult(payload)
            }
            .store(in: &cancellables)
    }

    func handleConnectionResult(_ payload: PrivateUsageConnectionResultNotification.Payload) {
        updateCoordinatorIfNeeded()
        guard payload.environment == coordinatorEnvironment else {
            return
        }

        isConnecting = false
        webConnectionWaitTask?.cancel()
        webConnectionWaitTask = nil
        message = nil
        errorMessage = nil

        if payload.didSucceed {
            settings.privateUsageUploadEnabled = true
            message = TokenMeteringL10n.text(.privateUsageUploadConnectedMessage)
        } else {
            errorMessage = payload.errorMessage
        }

        refresh()
    }
}
