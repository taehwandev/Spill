struct PrivateUsageKeyEnvelope: Codable, Equatable, Sendable {
    static let algorithm = "aes-256-gcm-hkdf-sha256"

    let keyVersion: Int
    let wrappingKeyID: String
    let algorithm: String
    let wrappedKey: String

    enum CodingKeys: String, CodingKey {
        case keyVersion = "key_version"
        case wrappingKeyID = "wrapping_key_id"
        case algorithm
        case wrappedKey = "wrapped_key"
    }
}
