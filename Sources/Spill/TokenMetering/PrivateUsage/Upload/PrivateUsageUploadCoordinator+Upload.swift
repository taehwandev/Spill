import Foundation

extension PrivateUsageUploadCoordinator {
    private static let uploadBatchLimit = 31
    private static let manualSyncMaxBatches = 12

    func performUpload(
        isEnabled: Bool,
        now: Date,
        earliestBucketStart: Date? = nil,
        includeCurrentDay: Bool = false
    ) async throws -> PrivateUsageUploadRunResult {
        guard isEnabled else {
            throw PrivateUsageUploadError.uploadDisabled
        }

        guard let credential = try credentialStore.loadCredential() else {
            throw PrivateUsageUploadError.missingCredential
        }

        let state = stateStore.load()
        let buckets = try dirtyBuckets(
            state: state,
            now: now,
            limit: Self.uploadBatchLimit,
            earliestBucketStart: earliestBucketStart,
            includeCurrentDay: includeCurrentDay
        )
        let sharedSummaries = try dirtySharedSummaries(
            state: state,
            now: now,
            limit: Self.uploadBatchLimit,
            earliestBucketStart: earliestBucketStart,
            includeCurrentDay: includeCurrentDay
        )
        guard !buckets.isEmpty || !sharedSummaries.isEmpty else {
            return PrivateUsageUploadRunResult(
                accepted: 0,
                attemptedBucketCount: 0,
                attemptedSharedSummaryCount: 0,
                uploadedAt: nil
            )
        }
        let keyEnvelopes: [PrivateUsageKeyEnvelope]
        if buckets.isEmpty {
            keyEnvelopes = []
        } else {
            guard let wrappingSecret = try credentialStore.loadKeyWrappingSecret() else {
                throw PrivateUsageUploadError.missingKeyWrappingSecret
            }
            keyEnvelopes = try sealer.keyEnvelopes(for: wrappingSecret)
        }

        do {
            let response = try await relayClient.uploadBuckets(
                credential: credential,
                buckets: buckets,
                sharedSummaries: sharedSummaries,
                keyEnvelopes: keyEnvelopes
            )
            guard response.accepted == buckets.count,
                  response.acceptedSharedSummaries == sharedSummaries.count
            else {
                throw PrivateUsageUploadError.invalidRelayResponse
            }
            let uploadedAt = response.uploadedAt
                .flatMap(ISO8601DateFormatter.parseTokenUsageDate(from:))
                ?? now
            acknowledge(buckets: buckets, sharedSummaries: sharedSummaries, uploadedAt: uploadedAt)
            return PrivateUsageUploadRunResult(
                accepted: response.accepted,
                acceptedSharedSummaryCount: response.acceptedSharedSummaries,
                attemptedBucketCount: buckets.count,
                attemptedSharedSummaryCount: sharedSummaries.count,
                uploadedAt: uploadedAt
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
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
        limit: Int,
        earliestBucketStart: Date? = nil,
        includeCurrentDay: Bool = false
    ) throws -> [PrivateUsageEncryptedBucket] {
        try bucketBuilder.makeDirtyDailyBuckets(
            events: usageStore.loadEvents(),
            acknowledgedHashesByBucketKey: state.acknowledgedCiphertextHashesByBucketKey,
            now: now,
            limit: limit,
            earliestBucketStart: earliestBucketStart,
            includeCurrentDay: includeCurrentDay
        )
    }

    func dirtySharedSummaries(
        state: PrivateUsageUploadPersistence,
        now: Date,
        limit: Int,
        earliestBucketStart: Date? = nil,
        includeCurrentDay: Bool = false
    ) throws -> [PrivateUsageSharedSummary] {
        try bucketBuilder.makeDirtySharedSummaries(
            events: usageStore.loadEvents(),
            acknowledgedHashesByBucketKey: state.acknowledgedSharedSummaryHashesByBucketKey,
            now: now,
            limit: limit,
            earliestBucketStart: earliestBucketStart,
            includeCurrentDay: includeCurrentDay
        )
    }

    func performManualSync(
        isEnabled: Bool,
        now: Date
    ) async throws -> PrivateUsageUploadRunResult {
        var accepted = 0
        var acceptedSharedSummaryCount = 0
        var attemptedBucketCount = 0
        var attemptedSharedSummaryCount = 0
        var uploadedAt: Date?

        for _ in 0..<Self.manualSyncMaxBatches {
            let result = try await performUpload(
                isEnabled: isEnabled,
                now: now,
                includeCurrentDay: true
            )
            accepted += result.accepted
            acceptedSharedSummaryCount += result.acceptedSharedSummaryCount
            attemptedBucketCount += result.attemptedBucketCount
            attemptedSharedSummaryCount += result.attemptedSharedSummaryCount
            uploadedAt = result.uploadedAt ?? uploadedAt

            if result.attemptedBucketCount < Self.uploadBatchLimit &&
                result.attemptedSharedSummaryCount < Self.uploadBatchLimit
            {
                break
            }
        }

        return PrivateUsageUploadRunResult(
            accepted: accepted,
            acceptedSharedSummaryCount: acceptedSharedSummaryCount,
            attemptedBucketCount: attemptedBucketCount,
            attemptedSharedSummaryCount: attemptedSharedSummaryCount,
            uploadedAt: uploadedAt
        )
    }

}
