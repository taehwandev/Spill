import Foundation

extension PrivateUsageUploadStore {
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
}
