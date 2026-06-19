struct PrivateUsageUploadBucketsRequest: Codable, Equatable, Sendable {
    let keyEnvelopes: [PrivateUsageKeyEnvelope]
    let buckets: [PrivateUsageEncryptedBucket]

    enum CodingKeys: String, CodingKey {
        case keyEnvelopes = "key_envelopes"
        case buckets
    }
}
