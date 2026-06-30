import Foundation

extension PrivateUsageUploadStore {
    func beginWebConnectionAttempt(timeout: TimeInterval = 180) {
        isConnecting = true
        pendingConnectedMessage = false
        message = nil
        errorMessage = nil
        webConnectionWaitTask?.cancel()
        webConnectionWaitTask = Task { [weak self] in
            let nanoseconds = UInt64(timeout * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            await MainActor.run {
                guard let self,
                      self.isConnecting,
                      !self.status.isConnected
                else {
                    return
                }
                self.isConnecting = false
            }
        }
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
            let hasCredential = (try? coordinator.credentialStore.loadCredential()) != nil
            await MainActor.run {
                guard let self,
                      !Task.isCancelled,
                      self.refreshGeneration == generation
                else {
                    return
                }
                let resolvedStatus = status.isConnected && !hasCredential
                    ? PrivateUsageUploadStatus.disconnected
                    : status
                if !resolvedStatus.isConnected, self.settings.privateUsageUploadEnabled {
                    self.settings.privateUsageUploadEnabled = false
                }
                if !resolvedStatus.isConnected,
                   self.pendingConnectedMessage ||
                   self.message == TokenMeteringL10n.text(.privateUsageUploadConnectedMessage) {
                    self.pendingConnectedMessage = false
                    self.message = nil
                }
                if resolvedStatus.isConnected {
                    if self.pendingConnectedMessage {
                        self.message = TokenMeteringL10n.text(.privateUsageUploadConnectedMessage)
                        self.pendingConnectedMessage = false
                    }
                    self.isConnecting = false
                    self.webConnectionWaitTask?.cancel()
                    self.webConnectionWaitTask = nil
                }
                self.status = resolvedStatus.isConnected ? resolvedStatus : .disconnected
                if !self.status.isConnected,
                   self.message == TokenMeteringL10n.text(.privateUsageUploadConnectedMessage) {
                    self.pendingConnectedMessage = false
                    self.message = nil
                }
            }
        }
    }

    func connect(grantCode: String) async {
        updateCoordinatorIfNeeded()
        isConnecting = true
        pendingConnectedMessage = false
        message = nil
        errorMessage = nil
        defer {
            isConnecting = false
            webConnectionWaitTask?.cancel()
            webConnectionWaitTask = nil
            refresh()
        }

        do {
            _ = try await coordinator.exchangeGrantCode(grantCode)
            settings.privateUsageUploadEnabled = true
            pendingConnectedMessage = false
            message = TokenMeteringL10n.text(.privateUsageUploadConnectedMessage)
        } catch {
            SpillCrashReporter.capturePrivateUsageUploadFailure(operation: .connect, error: error)
            errorMessage = Self.safeMessage(for: error)
        }
    }

    func syncNow() async {
        updateCoordinatorIfNeeded()
        guard !isSyncing else {
            return
        }
        isSyncing = true
        message = nil
        errorMessage = nil
        defer {
            isSyncing = false
            refresh()
        }

        do {
            await prepareForUpload()
            updateCoordinatorIfNeeded()
            let result = try await coordinator.syncNow(
                isEnabled: settings.privateUsageUploadEnabled
            )
            if result.didUpload {
                message = TokenMeteringL10n.text(.privateUsageUploadUploadedMessage)
            } else {
                message = TokenMeteringL10n.text(.privateUsageUploadNoQueuedMessage)
            }
        } catch {
            SpillCrashReporter.capturePrivateUsageUploadFailure(operation: .manualSync, error: error)
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
            SpillCrashReporter.capturePrivateUsageUploadFailure(operation: .disconnect, error: error)
            errorMessage = Self.safeMessage(for: error)
        }
        refresh()
    }
}
