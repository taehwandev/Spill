import Combine
import Foundation

final class PrivateUsageUploadCoordinator: @unchecked Sendable {
    let usageStore: TokenUsageStore
    let credentialStore: PrivateUsageCredentialStoring
    let stateStore: PrivateUsageUploadStateStore
    let relayClient: PrivateUsageRelayClienting
    let bucketBuilder: PrivateUsageDailyBucketBuilder
    let sealer: PrivateUsageBucketSealing
    let lock = NSLock()

    init(
        usageStore: TokenUsageStore,
        credentialStore: PrivateUsageCredentialStoring,
        stateStore: PrivateUsageUploadStateStore,
        relayClient: PrivateUsageRelayClienting,
        bucketBuilder: PrivateUsageDailyBucketBuilder,
        sealer: PrivateUsageBucketSealing
    ) {
        self.usageStore = usageStore
        self.credentialStore = credentialStore
        self.stateStore = stateStore
        self.relayClient = relayClient
        self.bucketBuilder = bucketBuilder
        self.sealer = sealer
    }

    static func live(
        usageStore: TokenUsageStore,
        environment: PrivateUsageUploadEnvironment = .defaultValue
    ) -> PrivateUsageUploadCoordinator {
        let resolvedEnvironment = PrivateUsageUploadEnvironment.resolvedFromConfiguration() ?? environment
        let credentialStore = PrivateUsageKeychainCredentialStore(
            service: resolvedEnvironment.keychainService
        )
        let sealer = PrivateUsageAESGCMBucketSealer(credentialStore: credentialStore)
        let relayClient: PrivateUsageRelayClienting
        if let relayURL = PrivateUsageRelayEndpoint.relayURL(environment: resolvedEnvironment) {
            relayClient = PrivateUsageRelayClient(relayURL: relayURL)
        } else {
            relayClient = PrivateUsageUnavailableRelayClient()
        }
        return PrivateUsageUploadCoordinator(
            usageStore: usageStore,
            credentialStore: credentialStore,
            stateStore: PrivateUsageUploadStateStore(environment: resolvedEnvironment),
            relayClient: relayClient,
            bucketBuilder: PrivateUsageDailyBucketBuilder(sealer: sealer),
            sealer: sealer
        )
    }

}
