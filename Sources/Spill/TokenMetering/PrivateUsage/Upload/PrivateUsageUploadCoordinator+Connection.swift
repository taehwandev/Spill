import Foundation

extension PrivateUsageUploadCoordinator {
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
        try credentialStore.saveConnection(credential: credential, keyWrappingSecret: connectionCode.keyWrappingSecret)
        markSavedConnection(true)
        return credential
    }

    func clearConnection() throws {
        try credentialStore.clearConnection()
        markSavedConnection(false)
    }

    func locallySavedConnectionStatus(
        isEnabled: Bool,
        now: Date = Date()
    ) -> PrivateUsageUploadStatus {
        let state = stateStore.load()
        let shouldShowSavedConnection = state.hasSavedConnection == true ||
            (state.hasSavedConnection == nil && isEnabled)
        return status(
            isConnected: shouldShowSavedConnection,
            isEnabled: isEnabled,
            queuedBucketCount: 0,
            state: state,
            now: now
        )
    }

    func status(
        isEnabled: Bool,
        now: Date = Date()
    ) -> PrivateUsageUploadStatus {
        let credential = try? credentialStore.loadCredential()
        let state = stateStore.load()
        let queuedCount: Int
        if credential == nil {
            queuedCount = 0
        } else {
            let dirtyBucketCount = (try? dirtyBuckets(state: state, now: now, limit: 31).count) ?? 0
            let dirtySummaryCount = (try? dirtySharedSummaries(state: state, now: now, limit: 31).count) ?? 0
            queuedCount = max(dirtyBucketCount, dirtySummaryCount)
        }

        return status(
            isConnected: credential != nil,
            isEnabled: isEnabled,
            queuedBucketCount: queuedCount,
            state: state,
            now: now
        )
    }

    private func status(
        isConnected: Bool,
        isEnabled: Bool,
        queuedBucketCount: Int,
        state: PrivateUsageUploadPersistence,
        now: Date
    ) -> PrivateUsageUploadStatus {
        return PrivateUsageUploadStatus(
            isConnected: isConnected,
            isEnabled: isEnabled,
            queuedBucketCount: queuedBucketCount,
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
            markSavedConnection(true)
            return localStatus
        } catch let error as PrivateUsageUploadError where error.isRevokedConnection {
            return .disconnected
        } catch {
            markSavedConnection(true)
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
        return try await performManualSync(isEnabled: isEnabled, now: now)
    }

    func runAutomaticUploadIfNeeded(
        isEnabled: Bool,
        now: Date = Date()
    ) async -> PrivateUsageUploadRunResult? {
        let attemptDayID = PrivateUsageDailyBucketBuilder.localDayID(for: now)
        guard automaticUploadIsDue(isEnabled: isEnabled, now: now) else {
            return nil
        }

        do {
            guard let credential = try credentialStore.loadCredential() else {
                return nil
            }
            let result = try await performUpload(
                isEnabled: isEnabled,
                now: now,
                earliestBucketStart: credential.createdAt
            )
            markAutomaticAttempt(dayID: attemptDayID)
            return result
        } catch {
            if let uploadError = error as? PrivateUsageUploadError,
               uploadError.isRevokedConnection {
                try? clearConnection()
            }
            if error is CancellationError || (error as? URLError)?.code == .cancelled {
                return nil
            }
            SpillCrashReporter.capturePrivateUsageUploadFailure(operation: .automaticUpload, error: error)
            return nil
        }
    }

}
