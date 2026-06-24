import Foundation

extension PrivateUsageUploadCoordinator {
    func acknowledge(
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

    func markAutomaticAttempt(dayID: String) {
        lock.withLock {
            var state = stateStore.load()
            state.lastAutomaticAttemptDayID = dayID
            stateStore.save(state)
        }
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
