import Foundation

extension PrivateUsageUploadCoordinator {
    func acknowledge(
        buckets: [PrivateUsageEncryptedBucket],
        sharedSummaries: [PrivateUsageSharedSummary],
        plan: PrivateUsageUploadPlan,
        uploadedAt: Date
    ) {
        lock.withLock {
            var state = stateStore.load()
            for bucket in buckets {
                state.acknowledgedCiphertextHashesByBucketKey[bucket.bucketKey] = bucket.ciphertextHash
            }
            for summary in sharedSummaries {
                if let summaryHash = try? summary.canonicalHash() {
                    state.acknowledgedSharedSummaryHashesByBucketKey[summary.bucketKey] = summaryHash
                }
            }
            state.lastSuccessfulUploadAt = ISO8601DateFormatter.tokenUsage.string(from: uploadedAt)
            state.lastFailedUploadAt = nil
            state.lastFailureReason = nil
            state.lastAckedBucketKey = buckets.last?.bucketKey ?? sharedSummaries.last?.bucketKey ?? state.lastAckedBucketKey
            applyChangeTracking(plan, to: &state)
            stateStore.save(state)
        }
    }

    func advanceChangeTracking(_ plan: PrivateUsageUploadPlan) {
        lock.withLock {
            var state = stateStore.load()
            applyChangeTracking(plan, to: &state)
            stateStore.save(state)
        }
    }

    private func applyChangeTracking(
        _ plan: PrivateUsageUploadPlan,
        to state: inout PrivateUsageUploadPersistence
    ) {
        state.lastProcessedEventChangeID = max(
            state.lastProcessedEventChangeID ?? 0,
            plan.maxChangeID
        )
        state.pendingDirtyDayIDs = plan.remainingPendingDayIDs
    }

    func markAutomaticAttempt(dayID: String) {
        lock.withLock {
            var state = stateStore.load()
            state.lastAutomaticAttemptDayID = dayID
            stateStore.save(state)
        }
    }

    func markSavedConnection(_ hasSavedConnection: Bool) {
        lock.withLock {
            var state = stateStore.load()
            state.hasSavedConnection = hasSavedConnection
            stateStore.save(state)
        }
    }

    func automaticUploadIsDue(
        isEnabled: Bool,
        now: Date
    ) -> Bool {
        guard isEnabled else {
            return false
        }

        let attemptDayID = PrivateUsageDailyBucketBuilder.localDayID(for: now)
        let state = stateStore.load()
        return state.lastAutomaticAttemptDayID != attemptDayID
    }

    func recordFailure(_ error: Error, at date: Date) {
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

    func nextAutomaticAttemptAfter(
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
