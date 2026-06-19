import Foundation

struct PrivateUsageUploadRunResult: Equatable, Sendable {
    let accepted: Int
    let attemptedBucketCount: Int
    let uploadedAt: Date?

    var didUpload: Bool {
        accepted > 0
    }
}
