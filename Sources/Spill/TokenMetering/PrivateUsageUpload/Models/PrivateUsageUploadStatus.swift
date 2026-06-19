import Foundation

struct PrivateUsageUploadStatus: Equatable, Sendable {
    let isConnected: Bool
    let isEnabled: Bool
    let queuedBucketCount: Int
    let lastSuccessfulUploadAt: Date?
    let lastFailedUploadAt: Date?
    let lastFailureReason: String?
    let lastAckedBucketKey: String?
    let nextAutomaticAttemptAfter: Date?

    static let disconnected = PrivateUsageUploadStatus(
        isConnected: false,
        isEnabled: false,
        queuedBucketCount: 0,
        lastSuccessfulUploadAt: nil,
        lastFailedUploadAt: nil,
        lastFailureReason: nil,
        lastAckedBucketKey: nil,
        nextAutomaticAttemptAfter: nil
    )
}
