struct PrivateUsageUploadPersistence: Codable, Equatable, Sendable {
    var acknowledgedCiphertextHashesByBucketKey: [String: String] = [:]
    var acknowledgedSharedSummaryHashesByBucketKey: [String: String] = [:]
    var lastSuccessfulUploadAt: String?
    var lastFailedUploadAt: String?
    var lastFailureReason: String?
    var lastAutomaticAttemptDayID: String?
    var lastAckedBucketKey: String?
    var hasSavedConnection: Bool?
    var syncTargetFingerprint: String?
    var lastProcessedEventChangeID: Int64?
    var pendingDirtyDayIDs: [String]?

    static let empty = PrivateUsageUploadPersistence()
}
