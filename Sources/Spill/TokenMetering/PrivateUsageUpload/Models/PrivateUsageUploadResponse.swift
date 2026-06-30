struct PrivateUsageUploadResponse: Codable, Equatable, Sendable {
    let accepted: Int
    let acceptedSharedSummaries: Int
    let uploadedAt: String?

    enum CodingKeys: String, CodingKey {
        case accepted
        case acceptedSharedSummaries = "accepted_shared_summaries"
        case uploadedAt = "uploaded_at"
    }

    init(
        accepted: Int,
        acceptedSharedSummaries: Int = 0,
        uploadedAt: String?
    ) {
        self.accepted = accepted
        self.acceptedSharedSummaries = acceptedSharedSummaries
        self.uploadedAt = uploadedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accepted = try container.decode(Int.self, forKey: .accepted)
        acceptedSharedSummaries = try container.decodeIfPresent(Int.self, forKey: .acceptedSharedSummaries) ?? 0
        uploadedAt = try container.decodeIfPresent(String.self, forKey: .uploadedAt)
    }
}
