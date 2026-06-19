struct PrivateUsageGrantExchangeResponse: Codable, Equatable, Sendable {
    let deviceID: String
    let credential: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case credential
        case tokenType = "token_type"
    }
}
