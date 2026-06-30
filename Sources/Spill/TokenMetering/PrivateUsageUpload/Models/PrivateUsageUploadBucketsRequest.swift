struct PrivateUsageUploadBucketsRequest: Codable, Equatable, Sendable {
    let keyEnvelopes: [PrivateUsageKeyEnvelope]
    let buckets: [PrivateUsageEncryptedBucket]
    let sharedSummaries: [PrivateUsageSharedSummary]

    enum CodingKeys: String, CodingKey {
        case keyEnvelopes = "key_envelopes"
        case buckets
        case sharedSummaries = "shared_summaries"
    }
}
