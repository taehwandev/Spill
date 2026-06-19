import Foundation

protocol PrivateUsageBucketSealing: Sendable {
    func seal(_ plaintext: Data, bucketKey: String) throws -> PrivateUsageSealedPayload
    func keyEnvelopes(for wrappingSecret: PrivateUsageKeyWrappingSecret) throws -> [PrivateUsageKeyEnvelope]
}
