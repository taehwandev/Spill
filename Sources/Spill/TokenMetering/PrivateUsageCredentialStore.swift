import Foundation
import Security

protocol PrivateUsageCredentialStoring: Sendable {
    func loadCredential() throws -> PrivateUsageDeviceCredential?
    func saveCredential(_ credential: PrivateUsageDeviceCredential) throws
    func clearCredential() throws
    func loadKeyWrappingSecret() throws -> PrivateUsageKeyWrappingSecret?
    func saveKeyWrappingSecret(_ secret: PrivateUsageKeyWrappingSecret) throws
    func clearKeyWrappingSecret() throws
    func saveConnection(credential: PrivateUsageDeviceCredential, keyWrappingSecret: PrivateUsageKeyWrappingSecret) throws
    func clearConnection() throws
    func loadSealingKeyData() throws -> Data?
    func saveSealingKeyData(_ data: Data) throws
}

extension PrivateUsageCredentialStoring {
    func saveConnection(credential: PrivateUsageDeviceCredential, keyWrappingSecret: PrivateUsageKeyWrappingSecret) throws {
        try saveKeyWrappingSecret(keyWrappingSecret)
        try saveCredential(credential)
    }

    func clearConnection() throws {
        try clearCredential()
        try clearKeyWrappingSecret()
    }
}

final class PrivateUsageKeychainCredentialStore: PrivateUsageCredentialStoring, @unchecked Sendable {
    private enum Account {
        static let bundle = "private-usage-credential-bundle-v1"
        static let legacyCredential = "device-credential"
        static let legacyKeyWrappingSecret = "browser-key-wrap-secret"
        static let legacySealingKey = "bucket-sealing-key"
    }

    private struct StoredBundle: Codable {
        var credential: PrivateUsageDeviceCredential?
        var keyWrappingSecret: PrivateUsageKeyWrappingSecret?
        var sealingKeyData: Data?

        var isEmpty: Bool {
            credential == nil && keyWrappingSecret == nil && sealingKeyData == nil
        }
    }

    private let service: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let lock = NSLock()

    init(service: String = "dev.spill.private-usage") {
        self.service = service
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func loadCredential() throws -> PrivateUsageDeviceCredential? {
        try lock.withLock {
            try loadBundle().credential
        }
    }

    func saveCredential(_ credential: PrivateUsageDeviceCredential) throws {
        try lock.withLock {
            var bundle = try loadBundle()
            bundle.credential = credential
            try saveBundle(bundle)
        }
    }

    func clearCredential() throws {
        try lock.withLock {
            var bundle = try loadBundle()
            bundle.credential = nil
            try saveBundle(bundle)
        }
    }

    func loadKeyWrappingSecret() throws -> PrivateUsageKeyWrappingSecret? {
        try lock.withLock {
            try loadBundle().keyWrappingSecret
        }
    }

    func saveKeyWrappingSecret(_ secret: PrivateUsageKeyWrappingSecret) throws {
        try lock.withLock {
            var bundle = try loadBundle()
            bundle.keyWrappingSecret = secret
            try saveBundle(bundle)
        }
    }

    func clearKeyWrappingSecret() throws {
        try lock.withLock {
            var bundle = try loadBundle()
            bundle.keyWrappingSecret = nil
            try saveBundle(bundle)
        }
    }

    func saveConnection(credential: PrivateUsageDeviceCredential, keyWrappingSecret: PrivateUsageKeyWrappingSecret) throws {
        try lock.withLock {
            var bundle = try loadBundle()
            bundle.credential = credential
            bundle.keyWrappingSecret = keyWrappingSecret
            try saveBundle(bundle)
        }
    }

    func clearConnection() throws {
        try lock.withLock {
            var bundle = try loadBundle()
            bundle.credential = nil
            bundle.keyWrappingSecret = nil
            try saveBundle(bundle)
        }
    }

    func loadSealingKeyData() throws -> Data? {
        try lock.withLock {
            try loadBundle().sealingKeyData
        }
    }

    func saveSealingKeyData(_ data: Data) throws {
        try lock.withLock {
            var bundle = try loadBundle()
            bundle.sealingKeyData = data
            try saveBundle(bundle)
        }
    }
}

private extension PrivateUsageKeychainCredentialStore {
    private func loadBundle() throws -> StoredBundle {
        guard let data = try loadData(account: Account.bundle) else {
            return try migrateLegacyBundle()
        }

        do {
            return try decoder.decode(StoredBundle.self, from: data)
        } catch {
            throw PrivateUsageUploadError.keychainReadFailed
        }
    }

    private func saveBundle(_ bundle: StoredBundle) throws {
        do {
            if bundle.isEmpty {
                try deleteData(account: Account.bundle)
            } else {
                try saveData(encoder.encode(bundle), account: Account.bundle)
            }
        } catch let error as PrivateUsageUploadError {
            throw error
        } catch {
            throw PrivateUsageUploadError.keychainWriteFailed
        }
    }

    private func migrateLegacyBundle() throws -> StoredBundle {
        var bundle = StoredBundle()

        if let credentialData = try loadData(account: Account.legacyCredential) {
            do {
                bundle.credential = try decoder.decode(PrivateUsageDeviceCredential.self, from: credentialData)
            } catch {
                throw PrivateUsageUploadError.keychainReadFailed
            }
        }

        if let secretData = try loadData(account: Account.legacyKeyWrappingSecret) {
            do {
                bundle.keyWrappingSecret = try decoder.decode(PrivateUsageKeyWrappingSecret.self, from: secretData)
            } catch {
                throw PrivateUsageUploadError.keychainReadFailed
            }
        }

        bundle.sealingKeyData = try loadData(account: Account.legacySealingKey)

        if !bundle.isEmpty {
            try saveBundle(bundle)
            try? deleteData(account: Account.legacyCredential)
            try? deleteData(account: Account.legacyKeyWrappingSecret)
            try? deleteData(account: Account.legacySealingKey)
        }

        return bundle
    }

    private func loadData(account: String) throws -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess, let data = item as? Data else {
            throw PrivateUsageUploadError.keychainReadFailed
        }

        return data
    }

    private func saveData(_ data: Data, account: String) throws {
        var query = baseQuery(account: account)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            return
        }

        if status == errSecDuplicateItem {
            let update: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]
            let updateStatus = SecItemUpdate(baseQuery(account: account) as CFDictionary, update as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw PrivateUsageUploadError.keychainWriteFailed
            }
            return
        }

        throw PrivateUsageUploadError.keychainWriteFailed
    }

    private func deleteData(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PrivateUsageUploadError.keychainWriteFailed
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

final class PrivateUsageUploadStateStore: @unchecked Sendable {
    private enum Keys {
        static let state = "privateUsageUploadStateV1"
        static let installID = "privateUsageInstallID"
    }

    private let namespace: String
    private let defaults: UserDefaults
    private static let lock = NSLock()

    init(
        defaults: UserDefaults = .standard,
        environment: PrivateUsageUploadEnvironment = .defaultValue
    ) {
        namespace = environment.stateKeyNamespace
        self.defaults = defaults
    }

    func load() -> PrivateUsageUploadPersistence {
        Self.lock.withLock {
            loadUnlocked(namespace: namespace)
        }
    }

    func save(_ state: PrivateUsageUploadPersistence) {
        Self.lock.withLock {
            guard let data = try? JSONEncoder().encode(state) else {
                return
            }

            defaults.set(data, forKey: namespacedKey(Keys.state))
        }
    }

    func minimumPrunableChangeID(including currentChangeID: Int64) -> Int64 {
        Self.lock.withLock {
            let connectedCursors = PrivateUsageUploadEnvironment.allCases.compactMap { environment -> Int64? in
                let state = loadUnlocked(namespace: environment.stateKeyNamespace)
                guard state.hasSavedConnection == true else {
                    return nil
                }
                return state.lastProcessedEventChangeID ?? 0
            }
            return ([currentChangeID] + connectedCursors).min() ?? currentChangeID
        }
    }

    func installID() -> String {
        Self.lock.withLock {
            if let existing = defaults.string(forKey: namespacedKey(Keys.installID)),
               Self.isSafeInstallID(existing) {
                return existing
            }

            let installID = UUID().uuidString.lowercased()
            defaults.set(installID, forKey: namespacedKey(Keys.installID))
            return installID
        }
    }

    private func namespacedKey(_ key: String) -> String {
        "\(namespace).\(key)"
    }

    private func loadUnlocked(namespace: String) -> PrivateUsageUploadPersistence {
        guard let data = defaults.data(forKey: "\(namespace).\(Keys.state)"),
              let state = try? JSONDecoder().decode(PrivateUsageUploadPersistence.self, from: data)
        else {
            return .empty
        }
        return state
    }

    private static func isSafeInstallID(_ value: String) -> Bool {
        value.range(of: #"^[A-Za-z0-9._:-]{1,160}$"#, options: .regularExpression) != nil
    }
}
