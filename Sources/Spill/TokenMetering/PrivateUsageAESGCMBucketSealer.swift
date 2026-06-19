import CryptoKit
import Foundation
import Security

private struct PrivateUsageSealingKeyRing: Codable, Equatable {
    var currentVersion: Int
    var keys: [PrivateUsageSealingKey]

    enum CodingKeys: String, CodingKey {
        case currentVersion = "current_version"
        case keys
    }
}

private struct PrivateUsageSealingKey: Codable, Equatable {
    let version: Int
    let createdAt: Date
    let keyData: Data

    enum CodingKeys: String, CodingKey {
        case version
        case createdAt = "created_at"
        case keyData = "key_data"
    }
}

private struct PrivateUsageActiveSealingKey {
    let version: Int
    let keyData: Data
}

final class PrivateUsageAESGCMBucketSealer: PrivateUsageBucketSealing, @unchecked Sendable {
    private static let keyByteCount = 32
    private static let defaultRotationInterval: TimeInterval = 30 * 24 * 60 * 60

    private let credentialStore: PrivateUsageCredentialStoring
    private let rotationInterval: TimeInterval
    private let now: @Sendable () -> Date
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let lock = NSLock()

    init(
        credentialStore: PrivateUsageCredentialStoring,
        rotationInterval: TimeInterval = PrivateUsageAESGCMBucketSealer.defaultRotationInterval,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.credentialStore = credentialStore
        self.rotationInterval = rotationInterval
        self.now = now
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func seal(_ plaintext: Data, bucketKey: String) throws -> PrivateUsageSealedPayload {
        let activeKey = try loadOrCreateActiveKey()
        let key = SymmetricKey(data: activeKey.keyData)
        let nonce = try AES.GCM.Nonce(data: deterministicNonceData(
            keyData: activeKey.keyData,
            bucketKey: bucketKey,
            plaintext: plaintext
        ))

        do {
            let sealed = try AES.GCM.seal(plaintext, using: key, nonce: nonce)
            guard let combined = sealed.combined else {
                throw PrivateUsageUploadError.encryptionFailed
            }

            return PrivateUsageSealedPayload(
                ciphertext: combined.base64EncodedString(),
                keyVersion: activeKey.version
            )
        } catch let error as PrivateUsageUploadError {
            throw error
        } catch {
            throw PrivateUsageUploadError.encryptionFailed
        }
    }

    func keyEnvelopes(for wrappingSecret: PrivateUsageKeyWrappingSecret) throws -> [PrivateUsageKeyEnvelope] {
        _ = try loadOrCreateActiveKey()
        return try lock.withLock {
            let keyRing = try loadOrCreateKeyRing()
            return try keyRing.keys
                .sorted { $0.version < $1.version }
                .map { key in
                    try Self.wrapSealingKey(key, using: wrappingSecret)
                }
        }
    }

    static func unwrapKeyEnvelope(
        _ envelope: PrivateUsageKeyEnvelope,
        using wrappingSecret: PrivateUsageKeyWrappingSecret
    ) throws -> Data {
        guard envelope.algorithm == PrivateUsageKeyEnvelope.algorithm,
              envelope.wrappingKeyID == wrappingSecret.keyID,
              let combined = Data(base64Encoded: envelope.wrappedKey)
        else {
            throw PrivateUsageUploadError.keyWrappingFailed
        }

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: combined)
            return try AES.GCM.open(
                sealedBox,
                using: deriveKeyWrappingKey(
                    wrappingSecret: wrappingSecret,
                    keyVersion: envelope.keyVersion
                )
            )
        } catch let error as PrivateUsageUploadError {
            throw error
        } catch {
            throw PrivateUsageUploadError.keyWrappingFailed
        }
    }

    private func loadOrCreateActiveKey() throws -> PrivateUsageActiveSealingKey {
        try lock.withLock {
            var keyRing = try loadOrCreateKeyRing()
            let currentTime = now()
            if shouldRotate(keyRing: keyRing, now: currentTime) {
                let nextKey = try makeKey(
                    version: (keyRing.keys.map(\.version).max() ?? 0) + 1,
                    createdAt: currentTime
                )
                keyRing.keys.append(nextKey)
                keyRing.currentVersion = nextKey.version
                try saveKeyRing(keyRing)
            }

            guard let activeKey = keyRing.keys.first(where: { $0.version == keyRing.currentVersion }),
                  activeKey.keyData.count == Self.keyByteCount
            else {
                throw PrivateUsageUploadError.missingSealingKey
            }

            return PrivateUsageActiveSealingKey(
                version: activeKey.version,
                keyData: activeKey.keyData
            )
        }
    }

    private func loadOrCreateKeyRing() throws -> PrivateUsageSealingKeyRing {
        guard let storedData = try credentialStore.loadSealingKeyData() else {
            let key = try makeKey(version: 1, createdAt: now())
            let keyRing = PrivateUsageSealingKeyRing(currentVersion: 1, keys: [key])
            try saveKeyRing(keyRing)
            return keyRing
        }

        if let keyRing = try? decoder.decode(PrivateUsageSealingKeyRing.self, from: storedData),
           keyRing.keys.contains(where: { $0.version == keyRing.currentVersion }) {
            return keyRing
        }

        if storedData.count == Self.keyByteCount {
            let migratedKey = PrivateUsageSealingKey(
                version: 1,
                createdAt: now(),
                keyData: storedData
            )
            let keyRing = PrivateUsageSealingKeyRing(currentVersion: 1, keys: [migratedKey])
            try saveKeyRing(keyRing)
            return keyRing
        }

        throw PrivateUsageUploadError.missingSealingKey
    }

    private func shouldRotate(
        keyRing: PrivateUsageSealingKeyRing,
        now: Date
    ) -> Bool {
        guard rotationInterval > 0,
              let currentKey = keyRing.keys.first(where: { $0.version == keyRing.currentVersion })
        else {
            return false
        }

        return now.timeIntervalSince(currentKey.createdAt) >= rotationInterval
    }

    private func makeKey(version: Int, createdAt: Date) throws -> PrivateUsageSealingKey {
        var data = Data(count: Self.keyByteCount)
        let status = data.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, Self.keyByteCount, buffer.baseAddress!)
        }
        guard status == errSecSuccess else {
            throw PrivateUsageUploadError.encryptionFailed
        }

        return PrivateUsageSealingKey(
            version: version,
            createdAt: createdAt,
            keyData: data
        )
    }

    private func saveKeyRing(_ keyRing: PrivateUsageSealingKeyRing) throws {
        try credentialStore.saveSealingKeyData(encoder.encode(keyRing))
    }

    private static func wrapSealingKey(
        _ key: PrivateUsageSealingKey,
        using wrappingSecret: PrivateUsageKeyWrappingSecret
    ) throws -> PrivateUsageKeyEnvelope {
        do {
            let sealed = try AES.GCM.seal(
                key.keyData,
                using: deriveKeyWrappingKey(
                    wrappingSecret: wrappingSecret,
                    keyVersion: key.version
                )
            )
            guard let combined = sealed.combined else {
                throw PrivateUsageUploadError.keyWrappingFailed
            }

            return PrivateUsageKeyEnvelope(
                keyVersion: key.version,
                wrappingKeyID: wrappingSecret.keyID,
                algorithm: PrivateUsageKeyEnvelope.algorithm,
                wrappedKey: combined.base64EncodedString()
            )
        } catch let error as PrivateUsageUploadError {
            throw error
        } catch {
            throw PrivateUsageUploadError.keyWrappingFailed
        }
    }

    private static func deriveKeyWrappingKey(
        wrappingSecret: PrivateUsageKeyWrappingSecret,
        keyVersion: Int
    ) throws -> SymmetricKey {
        var salt = Data("spill-private-usage-key-wrap-v1".utf8)
        salt.append(Data(wrappingSecret.keyID.utf8))
        let info = Data("key-version:\(keyVersion)".utf8)
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: try wrappingSecret.secretData()),
            salt: salt,
            info: info,
            outputByteCount: Self.keyByteCount
        )
    }

    private func deterministicNonceData(
        keyData: Data,
        bucketKey: String,
        plaintext: Data
    ) -> Data {
        var nonceInput = Data()
        nonceInput.append("spill-private-usage-v1".data(using: .utf8) ?? Data())
        nonceInput.append(keyData)
        nonceInput.append(bucketKey.data(using: .utf8) ?? Data())
        nonceInput.append(SHA256.hash(data: plaintext).data)
        return Data(SHA256.hash(data: nonceInput).prefix(12))
    }
}

private extension Digest {
    var data: Data {
        Data(makeIterator())
    }
}
