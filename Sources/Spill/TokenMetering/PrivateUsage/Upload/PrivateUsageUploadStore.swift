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
    var coordinator: PrivateUsageUploadCoordinator
    var coordinatorEnvironment: PrivateUsageUploadEnvironment
    var refreshTask: Task<Void, Never>?
    var webConnectionWaitTask: Task<Void, Never>?
    var refreshGeneration = 0

    init(
        settings: SpillSettings,
        usageStore: TokenUsageStore,
        coordinator: PrivateUsageUploadCoordinator? = nil
    ) {
        self.settings = settings
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
        refresh()
    }

    deinit {
        refreshTask?.cancel()
        webConnectionWaitTask?.cancel()
    }

}
