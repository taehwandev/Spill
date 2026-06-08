import Combine
import Foundation

final class PrivateUsageUploadCoordinator: @unchecked Sendable {
    private let usageStore: TokenUsageStore
    private let credentialStore: PrivateUsageCredentialStoring
    private let stateStore: PrivateUsageUploadStateStore
    private let relayClient: PrivateUsageRelayClienting
    private let bucketBuilder: PrivateUsageDailyBucketBuilder
    private let sealer: PrivateUsageBucketSealing
    private let lock = NSLock()

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

    func exchangeGrantCode(_ grantCode: String) async throws -> PrivateUsageDeviceCredential {
        let trimmedGrantCode = grantCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGrantCode.isEmpty else {
            throw PrivateUsageUploadError.invalidGrantCode
        }
        let connectionCode = try PrivateUsageConnectionCode(rawValue: trimmedGrantCode)

        let credential = try await relayClient.exchangeDeviceGrant(
            grantCode: connectionCode.grantCode,
            installID: stateStore.installID(),
            deviceName: PrivateUsageDeviceName.current(),
            deviceKeyFingerprint: connectionCode.keyWrappingSecret.keyID
        )
        try credentialStore.saveKeyWrappingSecret(connectionCode.keyWrappingSecret)
        try credentialStore.saveCredential(credential)
        return credential
    }

    func clearConnection() throws {
        try credentialStore.clearCredential()
        try credentialStore.clearKeyWrappingSecret()
    }

    func status(
        isEnabled: Bool,
        now: Date = Date()
    ) -> PrivateUsageUploadStatus {
        let credential = try? credentialStore.loadCredential()
        let state = stateStore.load()
        let queuedCount = credential == nil
            ? 0
            : ((try? dirtyBuckets(state: state, now: now, limit: 31).count) ?? 0)

        return PrivateUsageUploadStatus(
            isConnected: credential != nil,
            isEnabled: isEnabled,
            queuedBucketCount: queuedCount,
            lastSuccessfulUploadAt: state.lastSuccessfulUploadAt.flatMap(ISO8601DateFormatter.parseTokenUsageDate(from:)),
            lastFailedUploadAt: state.lastFailedUploadAt.flatMap(ISO8601DateFormatter.parseTokenUsageDate(from:)),
            lastFailureReason: state.lastFailureReason,
            lastAckedBucketKey: state.lastAckedBucketKey,
            nextAutomaticAttemptAfter: nextAutomaticAttemptAfter(
                lastAttemptDayID: state.lastAutomaticAttemptDayID,
                now: now
            )
        )
    }

    func statusAsync(
        isEnabled: Bool,
        now: Date = Date()
    ) async -> PrivateUsageUploadStatus {
        let localStatus = await Task.detached(priority: .utility) {
            self.status(isEnabled: isEnabled, now: now)
        }.value

        guard localStatus.isConnected,
              let credential = try? credentialStore.loadCredential()
        else {
            return localStatus
        }

        do {
            try await verifyDeviceConnection(credential)
            return localStatus
        } catch let error as PrivateUsageUploadError where error.isRevokedConnection {
            return .disconnected
        } catch {
            return localStatus
        }
    }

    func syncNow(
        isEnabled: Bool,
        now: Date = Date()
    ) async throws -> PrivateUsageUploadRunResult {
        guard isEnabled else {
            throw PrivateUsageUploadError.uploadDisabled
        }

        guard let credential = try credentialStore.loadCredential() else {
            throw PrivateUsageUploadError.missingCredential
        }

        try await verifyDeviceConnection(credential)
        return try await performUpload(isEnabled: isEnabled, now: now)
    }

    func runAutomaticUploadIfNeeded(
        isEnabled: Bool,
        now: Date = Date()
    ) async -> PrivateUsageUploadRunResult? {
        guard isEnabled else {
            return nil
        }

        let attemptDayID = PrivateUsageDailyBucketBuilder.localDayID(for: now)
        let state = stateStore.load()
        guard state.lastAutomaticAttemptDayID != attemptDayID else {
            return nil
        }

        do {
            let result = try await performUpload(isEnabled: isEnabled, now: now)
            markAutomaticAttempt(dayID: attemptDayID)
            return result
        } catch {
            return nil
        }
    }

    private func performUpload(
        isEnabled: Bool,
        now: Date
    ) async throws -> PrivateUsageUploadRunResult {
        guard isEnabled else {
            throw PrivateUsageUploadError.uploadDisabled
        }

        guard let credential = try credentialStore.loadCredential() else {
            throw PrivateUsageUploadError.missingCredential
        }

        let state = stateStore.load()
        let buckets = try dirtyBuckets(state: state, now: now, limit: 31)
        guard !buckets.isEmpty else {
            return PrivateUsageUploadRunResult(
                accepted: 0,
                attemptedBucketCount: 0,
                uploadedAt: nil
            )
        }
        guard let wrappingSecret = try credentialStore.loadKeyWrappingSecret() else {
            throw PrivateUsageUploadError.missingKeyWrappingSecret
        }
        let keyEnvelopes = try sealer.keyEnvelopes(for: wrappingSecret)

        do {
            let response = try await relayClient.uploadBuckets(
                credential: credential,
                buckets: buckets,
                keyEnvelopes: keyEnvelopes
            )
            guard response.accepted == buckets.count else {
                throw PrivateUsageUploadError.invalidRelayResponse
            }
            let uploadedAt = response.uploadedAt
                .flatMap(ISO8601DateFormatter.parseTokenUsageDate(from:))
                ?? now
            acknowledge(buckets: buckets, uploadedAt: uploadedAt)
            return PrivateUsageUploadRunResult(
                accepted: response.accepted,
                attemptedBucketCount: buckets.count,
                uploadedAt: uploadedAt
            )
        } catch {
            if let uploadError = error as? PrivateUsageUploadError,
               uploadError.isRevokedConnection
            {
                try? clearConnection()
            }
            recordFailure(error, at: now)
            throw error
        }
    }

    private func verifyDeviceConnection(_ credential: PrivateUsageDeviceCredential) async throws {
        do {
            try await relayClient.checkDeviceConnection(credential: credential)
        } catch let error as PrivateUsageUploadError where error.isRevokedConnection {
            try? clearConnection()
            throw error
        }
    }

    private func dirtyBuckets(
        state: PrivateUsageUploadPersistence,
        now: Date,
        limit: Int
    ) throws -> [PrivateUsageEncryptedBucket] {
        try bucketBuilder.makeDirtyDailyBuckets(
            events: usageStore.loadEvents(),
            acknowledgedHashesByBucketKey: state.acknowledgedCiphertextHashesByBucketKey,
            now: now,
            limit: limit
        )
    }

    private func acknowledge(
        buckets: [PrivateUsageEncryptedBucket],
        uploadedAt: Date
    ) {
        lock.withLock {
            var state = stateStore.load()
            for bucket in buckets {
                state.acknowledgedCiphertextHashesByBucketKey[bucket.bucketKey] = bucket.ciphertextHash
            }
            state.lastSuccessfulUploadAt = ISO8601DateFormatter.tokenUsage.string(from: uploadedAt)
            state.lastFailedUploadAt = nil
            state.lastFailureReason = nil
            state.lastAckedBucketKey = buckets.last?.bucketKey ?? state.lastAckedBucketKey
            stateStore.save(state)
        }
    }

    private func markAutomaticAttempt(dayID: String) {
        lock.withLock {
            var state = stateStore.load()
            state.lastAutomaticAttemptDayID = dayID
            stateStore.save(state)
        }
    }

    private func recordFailure(_ error: Error, at date: Date) {
        lock.withLock {
            var state = stateStore.load()
            state.lastFailedUploadAt = ISO8601DateFormatter.tokenUsage.string(from: date)
            if let uploadError = error as? PrivateUsageUploadError {
                state.lastFailureReason = uploadError.safeUserMessage
            } else {
                state.lastFailureReason = TokenMeteringL10n.text(.privateUsageUploadRelayUnavailableMessage)
            }
            stateStore.save(state)
        }
    }

    private func nextAutomaticAttemptAfter(
        lastAttemptDayID: String?,
        now: Date
    ) -> Date? {
        guard lastAttemptDayID == PrivateUsageDailyBucketBuilder.localDayID(for: now) else {
            return now
        }

        let calendar = Calendar.autoupdatingCurrent
        let todayStart = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: 1, to: todayStart)
    }
}

@MainActor
final class PrivateUsageUploadStore: ObservableObject {
    @Published private(set) var status = PrivateUsageUploadStatus.disconnected
    @Published private(set) var isConnecting = false
    @Published private(set) var isSyncing = false
    @Published private(set) var message: String?
    @Published private(set) var errorMessage: String?

    private let settings: SpillSettings
    private let coordinatorFactory: (PrivateUsageUploadEnvironment) -> PrivateUsageUploadCoordinator
    private var coordinator: PrivateUsageUploadCoordinator
    private var coordinatorEnvironment: PrivateUsageUploadEnvironment
    private var refreshTask: Task<Void, Never>?
    private var refreshGeneration = 0

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
    }

    func refresh() {
        updateCoordinatorIfNeeded()
        refreshGeneration += 1
        let generation = refreshGeneration
        let coordinator = coordinator
        let isEnabled = settings.privateUsageUploadEnabled
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            let status = await coordinator.statusAsync(isEnabled: isEnabled)
            await MainActor.run {
                guard let self,
                      !Task.isCancelled,
                      self.refreshGeneration == generation
                else {
                    return
                }
                if !status.isConnected, self.settings.privateUsageUploadEnabled {
                    self.settings.privateUsageUploadEnabled = false
                }
                self.status = status.isConnected ? status : .disconnected
            }
        }
    }

    func connect(grantCode: String) async {
        updateCoordinatorIfNeeded()
        isConnecting = true
        message = nil
        errorMessage = nil
        defer {
            isConnecting = false
            refresh()
        }

        do {
            _ = try await coordinator.exchangeGrantCode(grantCode)
            settings.privateUsageUploadEnabled = true
            message = TokenMeteringL10n.text(.privateUsageUploadConnectedMessage)
        } catch {
            errorMessage = Self.safeMessage(for: error)
        }
    }

    func syncNow() async {
        updateCoordinatorIfNeeded()
        isSyncing = true
        message = nil
        errorMessage = nil
        defer {
            isSyncing = false
            refresh()
        }

        do {
            let result = try await coordinator.syncNow(
                isEnabled: settings.privateUsageUploadEnabled
            )
            if result.didUpload {
                message = TokenMeteringL10n.text(.privateUsageUploadUploadedMessage)
            } else {
                message = TokenMeteringL10n.text(.privateUsageUploadNoQueuedMessage)
            }
        } catch {
            if Self.isRevokedConnection(error) {
                settings.privateUsageUploadEnabled = false
            }
            errorMessage = Self.safeMessage(for: error)
        }
    }

    func disconnect() {
        updateCoordinatorIfNeeded()
        do {
            try coordinator.clearConnection()
            settings.privateUsageUploadEnabled = false
            message = TokenMeteringL10n.text(.privateUsageUploadDisconnectedMessage)
            errorMessage = nil
        } catch {
            errorMessage = Self.safeMessage(for: error)
        }
        refresh()
    }

    private static func isRevokedConnection(_ error: Error) -> Bool {
        (error as? PrivateUsageUploadError)?.isRevokedConnection == true
    }

    private static func safeMessage(for error: Error) -> String {
        if let uploadError = error as? PrivateUsageUploadError {
            return uploadError.safeUserMessage
        }

        return TokenMeteringL10n.text(.privateUsageUploadUnavailableMessage)
    }

    private func updateCoordinatorIfNeeded() {
        guard coordinatorEnvironment != settings.privateUsageUploadEnvironment else {
            return
        }

        coordinatorEnvironment = settings.privateUsageUploadEnvironment
        coordinator = coordinatorFactory(coordinatorEnvironment)
        message = nil
        errorMessage = nil
    }
}
