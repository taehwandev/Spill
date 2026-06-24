import Foundation

extension PrivateUsageUploadCoordinator {
    func performUpload(
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

    func verifyDeviceConnection(_ credential: PrivateUsageDeviceCredential) async throws {
        do {
            try await relayClient.checkDeviceConnection(credential: credential)
        } catch let error as PrivateUsageUploadError where error.isRevokedConnection {
            try? clearConnection()
            throw error
        }
    }

    func dirtyBuckets(
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

}
