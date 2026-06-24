import Foundation

extension PrivateUsageUploadStore {
    static func isRevokedConnection(_ error: Error) -> Bool {
        (error as? PrivateUsageUploadError)?.isRevokedConnection == true
    }

    static func safeMessage(for error: Error) -> String {
        if let uploadError = error as? PrivateUsageUploadError {
            return uploadError.safeUserMessage
        }

        return TokenMeteringL10n.text(.privateUsageUploadUnavailableMessage)
    }

    func updateCoordinatorIfNeeded() {
        guard coordinatorEnvironment != settings.privateUsageUploadEnvironment else {
            return
        }

        coordinatorEnvironment = settings.privateUsageUploadEnvironment
        coordinator = coordinatorFactory(coordinatorEnvironment)
        message = nil
        errorMessage = nil
    }
}
