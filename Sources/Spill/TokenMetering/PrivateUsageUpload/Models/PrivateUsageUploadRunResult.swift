import Foundation

struct PrivateUsageUploadRunResult: Equatable, Sendable {
    let accepted: Int
    let acceptedSharedSummaryCount: Int
    let attemptedBucketCount: Int
    let attemptedSharedSummaryCount: Int
    let uploadedAt: Date?

    init(
        accepted: Int,
        acceptedSharedSummaryCount: Int = 0,
        attemptedBucketCount: Int,
        attemptedSharedSummaryCount: Int = 0,
        uploadedAt: Date?
    ) {
        self.accepted = accepted
        self.acceptedSharedSummaryCount = acceptedSharedSummaryCount
        self.attemptedBucketCount = attemptedBucketCount
        self.attemptedSharedSummaryCount = attemptedSharedSummaryCount
        self.uploadedAt = uploadedAt
    }

    var didUpload: Bool {
        accepted > 0 || acceptedSharedSummaryCount > 0
    }
}
