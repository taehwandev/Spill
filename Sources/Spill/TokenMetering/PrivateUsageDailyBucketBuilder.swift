import CryptoKit
import Foundation
import Security

protocol PrivateUsageBucketSealing: Sendable {
    func seal(_ plaintext: Data, bucketKey: String) throws -> PrivateUsageSealedPayload
    func keyEnvelopes(for wrappingSecret: PrivateUsageKeyWrappingSecret) throws -> [PrivateUsageKeyEnvelope]
}

struct PrivateUsageSealedPayload: Equatable, Sendable {
    let ciphertext: String
    let keyVersion: Int
}

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

struct PrivateUsageTokenTotals: Codable, Equatable, Sendable {
    var eventCount: Int
    var inputTokens: Int
    var outputTokens: Int
    var totalTokens: Int
    var latencyMS: Int

    enum CodingKeys: String, CodingKey {
        case eventCount = "event_count"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case totalTokens = "total_tokens"
        case latencyMS = "latency_ms"
    }

    static let zero = PrivateUsageTokenTotals(
        eventCount: 0,
        inputTokens: 0,
        outputTokens: 0,
        totalTokens: 0,
        latencyMS: 0
    )

    mutating func add(_ event: TokenUsageEvent) {
        eventCount += 1
        inputTokens += event.inputTokens
        outputTokens += event.outputTokens
        totalTokens += event.totalTokens
        latencyMS += event.latencyMS
    }
}

struct PrivateUsageDailyAggregate: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let bucketKind: String
    let bucketKey: String
    let bucketStartAt: String
    let bucketEndAt: String
    let timezone: String
    let generatedAt: String
    let totals: PrivateUsageTokenTotals
    let sourceTotals: [String: Int]
    let toolTotals: [String: PrivateUsageTokenTotals]
    let modelTotals: [String: PrivateUsageTokenTotals]
    let taskTypeTotals: [String: PrivateUsageTokenTotals]
    let stageTotals: [String: PrivateUsageTokenTotals]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case bucketKind = "bucket_kind"
        case bucketKey = "bucket_key"
        case bucketStartAt = "bucket_start_at"
        case bucketEndAt = "bucket_end_at"
        case timezone
        case generatedAt = "generated_at"
        case totals
        case sourceTotals = "source_totals"
        case toolTotals = "tool_totals"
        case modelTotals = "model_totals"
        case taskTypeTotals = "task_type_totals"
        case stageTotals = "stage_totals"
    }
}

struct PrivateUsageDailyBucketBuilder: Sendable {
    private let calendar: Calendar
    private let timeZone: TimeZone
    private let sealer: PrivateUsageBucketSealing
    private let encoder: JSONEncoder

    init(
        calendar: Calendar = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent,
        sealer: PrivateUsageBucketSealing
    ) {
        var calendar = calendar
        calendar.timeZone = timeZone
        self.calendar = calendar
        self.timeZone = timeZone
        self.sealer = sealer

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder
    }

    func makeDirtyDailyBuckets(
        events: [TokenUsageEvent],
        acknowledgedHashesByBucketKey: [String: String],
        now: Date = Date(),
        limit: Int = 31
    ) throws -> [PrivateUsageEncryptedBucket] {
        guard limit > 0 else {
            return []
        }

        let aggregates = makeDailyAggregates(events: events, now: now)
        var buckets = [PrivateUsageEncryptedBucket]()
        buckets.reserveCapacity(min(aggregates.count, limit))

        for aggregate in aggregates {
            let plaintext = try encoder.encode(aggregate)
            let sealed = try sealer.seal(plaintext, bucketKey: aggregate.bucketKey)
            let ciphertextHash = Self.sha256Hex(Data(sealed.ciphertext.utf8))

            if acknowledgedHashesByBucketKey[aggregate.bucketKey] == ciphertextHash {
                continue
            }

            buckets.append(
                PrivateUsageEncryptedBucket(
                    bucketKey: aggregate.bucketKey,
                    bucketKind: aggregate.bucketKind,
                    bucketStartAt: aggregate.bucketStartAt,
                    bucketEndAt: aggregate.bucketEndAt,
                    timezone: aggregate.timezone,
                    schemaVersion: aggregate.schemaVersion,
                    keyVersion: sealed.keyVersion,
                    ciphertext: sealed.ciphertext,
                    ciphertextHash: ciphertextHash
                )
            )

            if buckets.count >= limit {
                break
            }
        }

        return buckets
    }

    func makeDailyAggregates(
        events: [TokenUsageEvent],
        now: Date = Date()
    ) -> [PrivateUsageDailyAggregate] {
        let todayStart = calendar.startOfDay(for: now)
        let groupedEvents = Dictionary(grouping: events.compactMap { event -> (Date, TokenUsageEvent)? in
            guard let date = ISO8601DateFormatter.parseTokenUsageDate(from: event.createdAt),
                  date < todayStart
            else {
                return nil
            }

            return (calendar.startOfDay(for: date), event)
        }) { dayStart, _ in
            dayStart
        }

        return groupedEvents.keys.sorted().compactMap { dayStart -> PrivateUsageDailyAggregate? in
            guard let groupedDayEvents = groupedEvents[dayStart], !groupedDayEvents.isEmpty else {
                return nil
            }

            let dayEvents = groupedDayEvents.map(\.1)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? todayStart
            guard dayEnd <= todayStart else {
                return nil
            }

            return makeAggregate(
                dayStart: dayStart,
                dayEnd: dayEnd,
                events: dayEvents.sorted { lhs, rhs in
                    lhs.createdAt < rhs.createdAt
                },
                generatedAt: now
            )
        }
    }

    private func makeAggregate(
        dayStart: Date,
        dayEnd: Date,
        events: [TokenUsageEvent],
        generatedAt: Date
    ) -> PrivateUsageDailyAggregate {
        var totals = PrivateUsageTokenTotals.zero
        var sourceTotals = [
            "system": 0,
            "user": 0,
            "history": 0,
            "repo_context": 0,
            "tool_output": 0,
            "generated_output": 0,
            "unknown": 0
        ]
        var toolTotals = [String: PrivateUsageTokenTotals]()
        var modelTotals = [String: PrivateUsageTokenTotals]()
        var taskTypeTotals = [String: PrivateUsageTokenTotals]()
        var stageTotals = [String: PrivateUsageTokenTotals]()

        for event in events {
            totals.add(event)
            add(event, to: &toolTotals, key: event.aiTool.rawValue)
            add(event, to: &modelTotals, key: event.model)
            add(event, to: &taskTypeTotals, key: event.taskType.rawValue)
            add(event, to: &stageTotals, key: event.stage.rawValue)
            sourceTotals["system", default: 0] += event.tokenBreakdown.system
            sourceTotals["user", default: 0] += event.tokenBreakdown.user
            sourceTotals["history", default: 0] += event.tokenBreakdown.history
            sourceTotals["repo_context", default: 0] += event.tokenBreakdown.repoContext
            sourceTotals["tool_output", default: 0] += event.tokenBreakdown.toolOutput
            sourceTotals["generated_output", default: 0] += event.tokenBreakdown.generatedOutput
            sourceTotals["unknown", default: 0] += event.tokenBreakdown.unknown
        }

        let bucketDay = Self.localDayID(for: dayStart, timeZone: timeZone)
        return PrivateUsageDailyAggregate(
            schemaVersion: 1,
            bucketKind: "daily",
            bucketKey: "\(bucketDay):daily",
            bucketStartAt: Self.localTimestamp(for: dayStart, timeZone: timeZone),
            bucketEndAt: Self.localTimestamp(for: dayEnd, timeZone: timeZone),
            timezone: timeZone.identifier,
            generatedAt: ISO8601DateFormatter.tokenUsage.string(from: generatedAt),
            totals: totals,
            sourceTotals: sourceTotals,
            toolTotals: toolTotals,
            modelTotals: modelTotals,
            taskTypeTotals: taskTypeTotals,
            stageTotals: stageTotals
        )
    }

    private func add(
        _ event: TokenUsageEvent,
        to totals: inout [String: PrivateUsageTokenTotals],
        key: String
    ) {
        var current = totals[key] ?? .zero
        current.add(event)
        totals[key] = current
    }

    static func localDayID(for date: Date, timeZone: TimeZone = .autoupdatingCurrent) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func localTimestamp(for date: Date, timeZone: TimeZone = .autoupdatingCurrent) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        return formatter.string(from: date)
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
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
