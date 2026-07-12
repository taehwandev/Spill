import Foundation

struct PrivateUsageUploadPlan: Sendable {
    let buckets: [PrivateUsageEncryptedBucket]
    let sharedSummaries: [PrivateUsageSharedSummary]
    let processedDayIDs: [String]
    let remainingPendingDayIDs: [String]
    let maxChangeID: Int64
}

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
        let plan = try makeUploadPlan(
            state: state,
            now: now,
            limit: Self.uploadBatchLimit,
            earliestBucketStart: earliestBucketStart,
            includeCurrentDay: includeCurrentDay
        )
        let buckets = plan.buckets
        let sharedSummaries = plan.sharedSummaries
        guard !buckets.isEmpty || !sharedSummaries.isEmpty else {
            advanceChangeTracking(plan)
            return PrivateUsageUploadRunResult(
                accepted: 0,
                attemptedBucketCount: 0,
                attemptedSharedSummaryCount: 0,
                uploadedAt: nil,
                processedDayCount: plan.processedDayIDs.count
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
            acknowledge(
                buckets: buckets,
                sharedSummaries: sharedSummaries,
                plan: plan,
                uploadedAt: uploadedAt
            )
            return PrivateUsageUploadRunResult(
                accepted: response.accepted,
                acceptedSharedSummaryCount: response.acceptedSharedSummaries,
                attemptedBucketCount: buckets.count,
                attemptedSharedSummaryCount: sharedSummaries.count,
                uploadedAt: uploadedAt,
                processedDayCount: plan.processedDayIDs.count
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

    func makeUploadPlan(
        state: PrivateUsageUploadPersistence,
        now: Date,
        limit: Int,
        earliestBucketStart: Date? = nil,
        includeCurrentDay: Bool = false
    ) throws -> PrivateUsageUploadPlan {
        guard limit > 0 else {
            return PrivateUsageUploadPlan(
                buckets: [],
                sharedSummaries: [],
                processedDayIDs: [],
                remainingPendingDayIDs: state.pendingDirtyDayIDs ?? [],
                maxChangeID: state.lastProcessedEventChangeID ?? 0
            )
        }

        let cursor = state.lastProcessedEventChangeID ?? 0
        let changes = usageStore.loadPrivateUsageEventChanges(afterChangeID: cursor)
        var pendingDayIDs = Set(state.pendingDirtyDayIDs ?? [])
        for change in changes.changes {
            guard let eventDate = ISO8601DateFormatter.parseTokenUsageDate(from: change.eventCreatedAt) else {
                continue
            }
            pendingDayIDs.insert(bucketBuilder.localDayID(for: eventDate))
        }

        let todayID = bucketBuilder.localDayID(for: now)
        let earliestDayID = earliestBucketStart.map { bucketBuilder.localDayID(for: $0) }
        let eligibleDayIDs = pendingDayIDs.filter { dayID in
            guard dayID < todayID || (includeCurrentDay && dayID == todayID) else {
                return false
            }
            if let earliestDayID, dayID < earliestDayID {
                return false
            }
            return true
        }.sorted()
        let processedDayIDs = Array(eligibleDayIDs.prefix(limit))

        var events = [TokenUsageEvent]()
        for dayID in processedDayIDs {
            guard let interval = bucketBuilder.localDayInterval(for: dayID) else {
                continue
            }
            events.append(contentsOf: usageStore.loadEvents(
                startingAt: interval.start,
                endingBefore: interval.end
            ))
        }

        let buckets = try bucketBuilder.makeDirtyDailyBuckets(
            events: events,
            acknowledgedHashesByBucketKey: state.acknowledgedCiphertextHashesByBucketKey,
            now: now,
            limit: limit,
            includeCurrentDay: includeCurrentDay,
            requiredDayIDs: processedDayIDs
        )
        let sharedSummaries = try bucketBuilder.makeDirtySharedSummaries(
            events: events,
            acknowledgedHashesByBucketKey: state.acknowledgedSharedSummaryHashesByBucketKey,
            now: now,
            limit: limit,
            includeCurrentDay: includeCurrentDay,
            requiredDayIDs: processedDayIDs
        )
        pendingDayIDs.subtract(processedDayIDs)

        return PrivateUsageUploadPlan(
            buckets: buckets,
            sharedSummaries: sharedSummaries,
            processedDayIDs: processedDayIDs,
            remainingPendingDayIDs: pendingDayIDs.sorted(),
            maxChangeID: changes.maxChangeID
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
        var processedDayCount = 0
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
            processedDayCount += result.processedDayCount
            uploadedAt = result.uploadedAt ?? uploadedAt

            if result.processedDayCount < Self.uploadBatchLimit {
                break
            }
        }

        return PrivateUsageUploadRunResult(
            accepted: accepted,
            acceptedSharedSummaryCount: acceptedSharedSummaryCount,
            attemptedBucketCount: attemptedBucketCount,
            attemptedSharedSummaryCount: attemptedSharedSummaryCount,
            uploadedAt: uploadedAt,
            processedDayCount: processedDayCount
        )
    }

}
