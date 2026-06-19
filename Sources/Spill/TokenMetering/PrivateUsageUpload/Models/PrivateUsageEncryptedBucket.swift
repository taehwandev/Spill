struct PrivateUsageEncryptedBucket: Codable, Equatable, Sendable {
    let bucketKey: String
    let bucketKind: String
    let bucketStartAt: String
    let bucketEndAt: String
    let timezone: String
    let schemaVersion: Int
    let keyVersion: Int
    let ciphertext: String
    let ciphertextHash: String

    enum CodingKeys: String, CodingKey {
        case bucketKey = "bucket_key"
        case bucketKind = "bucket_kind"
        case bucketStartAt = "bucket_start_at"
        case bucketEndAt = "bucket_end_at"
        case timezone
        case schemaVersion = "schema_version"
        case keyVersion = "key_version"
        case ciphertext
        case ciphertextHash = "ciphertext_hash"
    }
}
