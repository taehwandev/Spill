struct PrivateUsageSealedPayload: Equatable, Sendable {
    let ciphertext: String
    let keyVersion: Int
}
