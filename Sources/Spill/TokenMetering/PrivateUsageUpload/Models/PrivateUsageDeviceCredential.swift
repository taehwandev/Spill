import Foundation

struct PrivateUsageDeviceCredential: Codable, Equatable, Sendable {
    let deviceID: String
    let credential: String
    let tokenType: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case credential
        case tokenType = "token_type"
        case createdAt = "created_at"
    }

    var authorizationToken: String {
        if credential.hasPrefix("spill_device_v1_") {
            return credential
        }

        if tokenType == "spill_device_v1" {
            return "spill_device_v1_\(credential)"
        }

        return credential
    }
}
