enum PrivateUsageUploadError: Error, Equatable {
    case invalidConnectionCode
    case invalidGrantCode
    case uploadDisabled
    case missingCredential
    case missingSealingKey
    case missingKeyWrappingSecret
    case invalidRelayURL
    case invalidRelayResponse
    case relayTransportFailed
    case relay(status: Int, reason: String?)
    case keychainReadFailed
    case keychainWriteFailed
    case encryptionFailed
    case keyWrappingFailed
}

extension PrivateUsageUploadError {
    var isRevokedConnection: Bool {
        if case let .relay(status, reason) = self {
            return status == 403 ||
                reason == "device_forbidden" ||
                reason == "grant_forbidden" ||
                reason == "connection_required"
        }

        return false
    }

    var safeUserMessage: String {
        switch self {
        case .invalidConnectionCode:
            return TokenMeteringL10n.text(.privateUsageUploadInvalidConnectionCodeMessage)
        case .invalidGrantCode:
            return TokenMeteringL10n.text(.privateUsageUploadInvalidGrantCodeMessage)
        case .uploadDisabled:
            return TokenMeteringL10n.text(.privateUsageUploadDisabledMessage)
        case .missingCredential:
            return TokenMeteringL10n.text(.privateUsageUploadMissingCredentialMessage)
        case .missingSealingKey:
            return TokenMeteringL10n.text(.privateUsageUploadMissingSealingKeyMessage)
        case .missingKeyWrappingSecret:
            return TokenMeteringL10n.text(.privateUsageUploadMissingKeyWrappingSecretMessage)
        case .invalidRelayURL:
            return TokenMeteringL10n.text(.privateUsageUploadRelayURLUnavailableMessage)
        case .invalidRelayResponse:
            return TokenMeteringL10n.text(.privateUsageUploadInvalidRelayResponseMessage)
        case .relayTransportFailed:
            return TokenMeteringL10n.text(.privateUsageUploadRelayUnavailableMessage)
        case let .relay(status, reason):
            if status == 403 || reason == "device_forbidden" || reason == "grant_forbidden" {
                return TokenMeteringL10n.text(.privateUsageUploadConnectionExpiredMessage)
            }
            if status == 401 {
                return TokenMeteringL10n.text(.privateUsageUploadConnectionRequiredMessage)
            }
            return TokenMeteringL10n.text(.privateUsageUploadRelayUnavailableMessage)
        case .keychainReadFailed:
            return TokenMeteringL10n.text(.privateUsageUploadKeychainReadFailedMessage)
        case .keychainWriteFailed:
            return TokenMeteringL10n.text(.privateUsageUploadKeychainWriteFailedMessage)
        case .encryptionFailed:
            return TokenMeteringL10n.text(.privateUsageUploadEncryptionFailedMessage)
        case .keyWrappingFailed:
            return TokenMeteringL10n.text(.privateUsageUploadKeyWrappingFailedMessage)
        }
    }
}
