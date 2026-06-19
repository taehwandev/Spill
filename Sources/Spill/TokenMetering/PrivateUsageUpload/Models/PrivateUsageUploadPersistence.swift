struct PrivateUsageUploadPersistence: Codable, Equatable, Sendable {
    var acknowledgedCiphertextHashesByBucketKey: [String: String] = [:]
    var lastSuccessfulUploadAt: String?
    var lastFailedUploadAt: String?
    var lastFailureReason: String?
    var lastAutomaticAttemptDayID: String?
    var lastAckedBucketKey: String?

    static let empty = PrivateUsageUploadPersistence()
}
