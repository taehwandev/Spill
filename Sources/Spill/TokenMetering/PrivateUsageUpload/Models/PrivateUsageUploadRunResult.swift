import Foundation

struct PrivateUsageUploadRunResult: Equatable, Sendable {
    let accepted: Int
    let acceptedSharedSummaryCount: Int
    let attemptedBucketCount: Int
    let attemptedSharedSummaryCount: Int
    let uploadedAt: Date?
    let processedDayCount: Int

    init(
        accepted: Int,
        acceptedSharedSummaryCount: Int = 0,
        attemptedBucketCount: Int,
        attemptedSharedSummaryCount: Int = 0,
        uploadedAt: Date?,
        processedDayCount: Int = 0
    ) {
        self.accepted = accepted
        self.acceptedSharedSummaryCount = acceptedSharedSummaryCount
        self.attemptedBucketCount = attemptedBucketCount
        self.attemptedSharedSummaryCount = attemptedSharedSummaryCount
        self.uploadedAt = uploadedAt
        self.processedDayCount = processedDayCount
    }

    var didUpload: Bool {
        accepted > 0 || acceptedSharedSummaryCount > 0
    }
}
