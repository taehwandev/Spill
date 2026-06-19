struct PrivateUsageUploadResponse: Codable, Equatable, Sendable {
    let accepted: Int
    let uploadedAt: String?

    enum CodingKeys: String, CodingKey {
        case accepted
        case uploadedAt = "uploaded_at"
    }
}
