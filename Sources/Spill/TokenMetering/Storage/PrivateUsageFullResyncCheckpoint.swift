struct PrivateUsageFullResyncCheckpoint: Equatable, Sendable {
    let eventCreatedAts: [String]
    let maxChangeID: Int64
}
