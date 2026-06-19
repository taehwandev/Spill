struct PrivateUsageWorkflowUsageTotals: Codable, Equatable, Sendable {
    var assisted: PrivateUsageTokenTotals
    var untracked: PrivateUsageTokenTotals

    enum CodingKeys: String, CodingKey {
        case assisted
        case untracked
    }

    static let zero = PrivateUsageWorkflowUsageTotals(
        assisted: .zero,
        untracked: .zero
    )

    mutating func add(_ event: TokenUsageEvent) {
        if TokenUsageWorkflowAssistance.isAssisted(event) {
            assisted.add(event)
        } else {
            untracked.add(event)
        }
    }
}
