struct PrivateUsageGrantExchangeRequest: Codable, Equatable, Sendable {
    let grantCode: String
    let installID: String
    let deviceName: String?
    let deviceKeyFingerprint: String?

    enum CodingKeys: String, CodingKey {
        case grantCode = "grant_code"
        case installID = "install_id"
        case deviceName = "device_name"
        case deviceKeyFingerprint = "device_key_fingerprint"
    }
}
