import Foundation
import Sentry

extension SpillCrashReporter {
    enum PrivateUsageUploadOperation: String {
        case automaticUpload = "automatic_upload"
        case connect = "connect"
        case connectDeepLink = "connect_deep_link"
        case disconnect = "disconnect"
        case manualSync = "manual_sync"
    }

    static func capturePrivateUsageUploadFailure(
        operation: PrivateUsageUploadOperation,
        error: Error
    ) {
        guard isReportingEnabled,
              shouldCapturePrivateUsageUploadFailure(error)
        else {
            return
        }

        let descriptor = privateUsageUploadErrorDescriptor(error)
        SentrySDK.capture(message: "spill.private_usage_upload_failed") { scope in
            scope.setFingerprint([
                "spill.private_usage_upload_failed",
                operation.rawValue,
                descriptor.kind,
                descriptor.relayStatus,
                descriptor.relayReason
            ])
            scope.setTag(value: "private_usage_upload_failed", key: "spill_failure")
            scope.setTag(value: operation.rawValue, key: "private_usage_operation")
            scope.setTag(value: descriptor.kind, key: "private_usage_error")
            scope.setTag(value: descriptor.relayStatus, key: "private_usage_relay_status")
            scope.setTag(value: descriptor.relayReason, key: "private_usage_relay_reason")
            scope.setTag(value: descriptor.revokedConnection ? "true" : "false", key: "private_usage_revoked")
        }
    }
}

private extension SpillCrashReporter {
    struct PrivateUsageUploadErrorDescriptor {
        let kind: String
        let relayStatus: String
        let relayReason: String
        let revokedConnection: Bool
    }

    static func shouldCapturePrivateUsageUploadFailure(_ error: Error) -> Bool {
        guard let uploadError = error as? PrivateUsageUploadError else {
            return true
        }

        if uploadError.isRevokedConnection {
            return false
        }

        switch uploadError {
        case .invalidConnectionCode,
             .invalidGrantCode,
             .uploadDisabled,
             .missingCredential,
             .relay(status: 401, reason: _):
            return false
        case .missingSealingKey,
             .missingKeyWrappingSecret,
             .invalidRelayURL,
             .invalidRelayResponse,
             .relayTransportFailed,
             .relay,
             .keychainReadFailed,
             .keychainWriteFailed,
             .encryptionFailed,
             .keyWrappingFailed:
            return true
        }
    }

    static func privateUsageUploadErrorDescriptor(_ error: Error) -> PrivateUsageUploadErrorDescriptor {
        guard let uploadError = error as? PrivateUsageUploadError else {
            return PrivateUsageUploadErrorDescriptor(
                kind: "unexpected_error",
                relayStatus: "none",
                relayReason: "none",
                revokedConnection: false
            )
        }

        if case let .relay(status, reason) = uploadError {
            return PrivateUsageUploadErrorDescriptor(
                kind: "relay",
                relayStatus: bucketedRelayStatus(status),
                relayReason: safeRelayReason(reason),
                revokedConnection: uploadError.isRevokedConnection
            )
        }

        return PrivateUsageUploadErrorDescriptor(
            kind: privateUsageUploadErrorKind(uploadError),
            relayStatus: "none",
            relayReason: "none",
            revokedConnection: uploadError.isRevokedConnection
        )
    }

}

private extension SpillCrashReporter {
    static func privateUsageUploadErrorKind(_ error: PrivateUsageUploadError) -> String {
        switch error {
        case .invalidConnectionCode:
            return "invalid_connection_code"
        case .invalidGrantCode:
            return "invalid_grant_code"
        case .uploadDisabled:
            return "upload_disabled"
        case .missingCredential:
            return "missing_credential"
        case .missingSealingKey:
            return "missing_sealing_key"
        case .missingKeyWrappingSecret:
            return "missing_key_wrapping_secret"
        case .invalidRelayURL:
            return "invalid_relay_url"
        case .invalidRelayResponse:
            return "invalid_relay_response"
        case .relayTransportFailed:
            return "relay_transport_failed"
        case .relay:
            return "relay"
        case .keychainReadFailed:
            return "keychain_read_failed"
        case .keychainWriteFailed:
            return "keychain_write_failed"
        case .encryptionFailed:
            return "encryption_failed"
        case .keyWrappingFailed:
            return "key_wrapping_failed"
        }
    }

    static func bucketedRelayStatus(_ status: Int) -> String {
        switch status {
        case 400:
            return "400"
        case 401:
            return "401"
        case 403:
            return "403"
        case 404:
            return "404"
        case 409:
            return "409"
        case 429:
            return "429"
        case 500...599:
            return "5xx"
        default:
            return "other"
        }
    }

    static func safeRelayReason(_ reason: String?) -> String {
        guard let reason else {
            return "none"
        }

        let normalized = reason.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.range(of: #"^[a-z0-9_-]{1,80}$"#, options: .regularExpression) != nil else {
            return "unknown"
        }
        return normalized
    }
}
