import XCTest
@testable import Spill

final class PrivateUsageUploadTests: XCTestCase {
    private let testWrappingSecret = String(repeating: "A", count: 43)

    func testPrivateUsageFeatureAvailabilityReadsExplicitBuildFlag() {
        XCTAssertFalse(
            PrivateUsageUploadFeatureAvailability.isEnabled(
                processEnvironment: [:],
                bundleInfo: [:]
            )
        )
        XCTAssertTrue(
            PrivateUsageUploadFeatureAvailability.isEnabled(
                processEnvironment: [
                    PrivateUsageUploadFeatureAvailability.featureEnabledEnvironmentKey: "1"
                ],
                bundleInfo: [:]
            )
        )
        XCTAssertTrue(
            PrivateUsageUploadFeatureAvailability.isEnabled(
                processEnvironment: [:],
                bundleInfo: [
                    PrivateUsageUploadFeatureAvailability.featureEnabledInfoDictionaryKey: true
                ]
            )
        )
        XCTAssertFalse(
            PrivateUsageUploadFeatureAvailability.isEnabled(
                processEnvironment: [
                    PrivateUsageUploadFeatureAvailability.featureEnabledEnvironmentKey: "0"
                ],
                bundleInfo: [
                    PrivateUsageUploadFeatureAvailability.featureEnabledInfoDictionaryKey: true
                ]
            )
        )
    }

    func testConnectionDeepLinkExtractsConnectionCode() throws {
        let url = try XCTUnwrap(URL(string: "spill://private-usage/connect?code=spill-v1%3Agrant_opaque%3A\(testWrappingSecret)"))

        XCTAssertEqual(
            PrivateUsageConnectionDeepLink.connectionCode(from: url),
            "spill-v1:grant_opaque:\(testWrappingSecret)"
        )
    }

    func testConnectionDeepLinkExtractsConnectionCodeFromFragment() throws {
        let fragmentURL = try XCTUnwrap(URL(string: "spill://private-usage/connect#code=spill-v1%3Agrant_opaque%3A\(testWrappingSecret)"))
        let routedFragmentURL = try XCTUnwrap(URL(string: "spill://private-usage/connect#/done?connection_code=spill-v1%3Agrant_opaque%3A\(testWrappingSecret)"))

        XCTAssertEqual(
            PrivateUsageConnectionDeepLink.connectionCode(from: fragmentURL),
            "spill-v1:grant_opaque:\(testWrappingSecret)"
        )
        XCTAssertEqual(
            PrivateUsageConnectionDeepLink.connectionCode(from: routedFragmentURL),
            "spill-v1:grant_opaque:\(testWrappingSecret)"
        )
    }

    func testConnectionDeepLinkRejectsUnrelatedURLs() throws {
        XCTAssertNil(PrivateUsageConnectionDeepLink.connectionCode(from: URL(string: "spill://private-usage/other?code=value")!))
        XCTAssertNil(PrivateUsageConnectionDeepLink.connectionCode(from: URL(string: "https://spill.thdev.app/settings?code=value")!))
    }

    func testDailyBucketBuilderCreatesPreviousDayAggregateWithoutRawEventIDs() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Seoul"))
        let calendar = fixedCalendar(timeZone: timeZone)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 9)))
        let yesterdayNoon = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 12)))
        let todayNoon = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 12)))
        let sealer = RecordingPrivateUsageSealer()
        let builder = PrivateUsageDailyBucketBuilder(
            calendar: calendar,
            timeZone: timeZone,
            sealer: sealer
        )

        let buckets = try builder.makeDirtyDailyBuckets(
            events: [
                makeEvent(
                    spanID: "span_a1",
                    runID: "run_a1",
                    aiTool: .codex,
                    taskType: "code_generation",
                    stage: "implement",
                    model: "gpt-5",
                    input: 120,
                    output: 80,
                    createdAt: yesterdayNoon
                ),
                makeEvent(
                    spanID: "span_b1",
                    runID: "run_b1",
                    aiTool: .claude,
                    taskType: "testing",
                    stage: "verify",
                    model: "claude-opus-4",
                    input: 50,
                    output: 25,
                    createdAt: yesterdayNoon
                ),
                makeEvent(
                    spanID: "span_c1",
                    runID: "run_c1",
                    aiTool: .codex,
                    taskType: .uncategorized,
                    stage: .summarize,
                    model: "gpt-5",
                    input: 9,
                    output: 1,
                    createdAt: yesterdayNoon
                ),
                makeEvent(
                    spanID: "span_today",
                    runID: "run_today",
                    aiTool: .codex,
                    taskType: "analysis",
                    stage: "plan",
                    model: "gpt-5",
                    input: 10,
                    output: 10,
                    createdAt: todayNoon
                )
            ],
            acknowledgedHashesByBucketKey: [:],
            now: now
        )

        XCTAssertEqual(buckets.count, 1)
        XCTAssertEqual(buckets[0].bucketKey, "2026-06-07:daily")
        XCTAssertEqual(buckets[0].bucketStartAt, "2026-06-07T00:00:00.000+09:00")
        XCTAssertEqual(buckets[0].bucketEndAt, "2026-06-08T00:00:00.000+09:00")
        XCTAssertEqual(buckets[0].timezone, "Asia/Seoul")

        let plaintext = try XCTUnwrap(sealer.plaintexts.first)
        let aggregate = try JSONDecoder().decode(PrivateUsageDailyAggregate.self, from: plaintext)
        XCTAssertEqual(aggregate.totals.eventCount, 3)
        XCTAssertEqual(aggregate.totals.totalTokens, 285)
        XCTAssertEqual(aggregate.toolTotals["codex"]?.totalTokens, 210)
        XCTAssertEqual(aggregate.toolTotals["claude"]?.totalTokens, 75)
        XCTAssertEqual(aggregate.modelTotals["gpt-5"]?.totalTokens, 210)
        XCTAssertEqual(aggregate.taskTypeTotals["testing"]?.totalTokens, 75)
        XCTAssertEqual(aggregate.stageTotals["implement"]?.totalTokens, 200)
        XCTAssertEqual(aggregate.workflowUsageTotals.assisted.eventCount, 2)
        XCTAssertEqual(aggregate.workflowUsageTotals.assisted.totalTokens, 275)
        XCTAssertEqual(aggregate.workflowUsageTotals.untracked.eventCount, 1)
        XCTAssertEqual(aggregate.workflowUsageTotals.untracked.totalTokens, 10)
        XCTAssertEqual(aggregate.sourceTotals["unknown"], 285)

        let plaintextString = try XCTUnwrap(String(data: plaintext, encoding: .utf8))
        XCTAssertFalse(plaintextString.contains("span_a1"))
        XCTAssertFalse(plaintextString.contains("run_a1"))
        XCTAssertFalse(plaintextString.contains("span_c1"))
        XCTAssertFalse(plaintextString.contains("span_today"))
    }

    func testDailyAggregateDecodesLegacyPayloadWithoutWorkflowUsageTotals() throws {
        let payload = Data("""
        {
          "schema_version": 1,
          "bucket_kind": "daily",
          "bucket_key": "2026-06-07:daily",
          "bucket_start_at": "2026-06-07T00:00:00.000Z",
          "bucket_end_at": "2026-06-08T00:00:00.000Z",
          "timezone": "UTC",
          "generated_at": "2026-06-08T00:00:00.000Z",
          "totals": {
            "event_count": 0,
            "input_tokens": 0,
            "output_tokens": 0,
            "total_tokens": 0,
            "latency_ms": 0
          },
          "source_totals": {},
          "tool_totals": {},
          "model_totals": {},
          "task_type_totals": {},
          "stage_totals": {}
        }
        """.utf8)

        let aggregate = try JSONDecoder().decode(PrivateUsageDailyAggregate.self, from: payload)

        XCTAssertEqual(aggregate.workflowUsageTotals, .zero)
    }

    func testDailyBucketBuilderSkipsAcknowledgedUnchangedBucket() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let calendar = fixedCalendar(timeZone: timeZone)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 9)))
        let yesterday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 12)))
        let sealer = RecordingPrivateUsageSealer()
        let builder = PrivateUsageDailyBucketBuilder(
            calendar: calendar,
            timeZone: timeZone,
            sealer: sealer
        )
        let event = makeEvent(
            spanID: "span_ack",
            runID: "run_ack",
            aiTool: .codex,
            taskType: "code_generation",
            stage: "implement",
            model: "gpt-5",
            input: 1,
            output: 2,
            createdAt: yesterday
        )

        let firstBuckets = try builder.makeDirtyDailyBuckets(
            events: [event],
            acknowledgedHashesByBucketKey: [:],
            now: now
        )
        let firstBucket = try XCTUnwrap(firstBuckets.first)

        let secondBuckets = try builder.makeDirtyDailyBuckets(
            events: [event],
            acknowledgedHashesByBucketKey: [firstBucket.bucketKey: firstBucket.ciphertextHash],
            now: now
        )

        XCTAssertTrue(secondBuckets.isEmpty)
    }

    func testRelayClientExchangesGrantAndUploadsWithDeviceBearer() async throws {
        let requestRecorder = PrivateUsageRequestRecorder()
        let wrappingSecret = try PrivateUsageKeyWrappingSecret(rawValue: testWrappingSecret)
        let transport = PrivateUsageRelayTransport { request in
            requestRecorder.append(request)
            let path = request.url?.path ?? ""
            let body: String
            if path.hasSuffix("/exchange-device-grant") {
                body = #"{"device_id":"device_server","credential":"spill_device_v1_secret","token_type":"spill_device_v1"}"#
            } else {
                body = #"{"accepted":1,"uploaded_at":"2026-06-08T00:00:00.000Z"}"#
            }
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(body.utf8), response)
        }
        let client = PrivateUsageRelayClient(
            relayURL: URL(string: "http://localhost:54321/functions/v1/private-usage-relay")!,
            transport: transport
        )

        let credential = try await client.exchangeDeviceGrant(
            grantCode: "grant_secret",
            installID: "install-safe",
            deviceName: "Work MacBook",
            deviceKeyFingerprint: "fingerprint"
        )
        let upload = try await client.uploadBuckets(
            credential: credential,
            buckets: [
                PrivateUsageEncryptedBucket(
                    bucketKey: "2026-06-07:daily",
                    bucketKind: "daily",
                    bucketStartAt: "2026-06-07T00:00:00.000Z",
                    bucketEndAt: "2026-06-08T00:00:00.000Z",
                    timezone: "UTC",
                    schemaVersion: 1,
                    keyVersion: 1,
                    ciphertext: "sealed",
                    ciphertextHash: String(repeating: "a", count: 64)
                )
            ],
            keyEnvelopes: [
                PrivateUsageKeyEnvelope(
                    keyVersion: 1,
                    wrappingKeyID: wrappingSecret.keyID,
                    algorithm: PrivateUsageKeyEnvelope.algorithm,
                    wrappedKey: "wrapped"
                )
            ]
        )

        let requests = requestRecorder.requests
        XCTAssertEqual(credential.authorizationToken, "spill_device_v1_secret")
        XCTAssertEqual(upload.accepted, 1)
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests[0].url?.path, "/functions/v1/private-usage-relay/exchange-device-grant")
        XCTAssertEqual(requests[1].value(forHTTPHeaderField: "Authorization"), "Bearer spill_device_v1_secret")

        let exchangeBody = try XCTUnwrap(requests[0].httpBody)
        let exchangeJSON = try JSONSerialization.jsonObject(with: exchangeBody) as? [String: Any]
        XCTAssertEqual(exchangeJSON?["grant_code"] as? String, "grant_secret")
        XCTAssertEqual(exchangeJSON?["install_id"] as? String, "install-safe")
        XCTAssertEqual(exchangeJSON?["device_name"] as? String, "Work MacBook")
        XCTAssertEqual(exchangeJSON?["device_key_fingerprint"] as? String, "fingerprint")

        let uploadBody = try XCTUnwrap(requests[1].httpBody)
        let uploadBodyString = try XCTUnwrap(String(data: uploadBody, encoding: .utf8))
        XCTAssertFalse(uploadBodyString.contains(testWrappingSecret))
        let uploadJSON = try JSONSerialization.jsonObject(with: uploadBody) as? [String: Any]
        XCTAssertEqual((uploadJSON?["key_envelopes"] as? [[String: Any]])?.count, 1)
    }

    func testConnectionCodeRequiresLocalWrappingSecret() {
        XCTAssertThrowsError(try PrivateUsageConnectionCode(rawValue: "grant_secret")) { error in
            XCTAssertEqual(error as? PrivateUsageUploadError, .invalidConnectionCode)
        }
    }

    func testCoordinatorSplitsConnectionCodeAndStoresWrappingSecretLocally() async throws {
        let usageStore = makeUsageStore()
        let credentialStore = InMemoryPrivateUsageCredentialStore()
        let relayClient = FakePrivateUsageRelayClient()
        let sealer = RecordingPrivateUsageSealer()
        let coordinator = PrivateUsageUploadCoordinator(
            usageStore: usageStore,
            credentialStore: credentialStore,
            stateStore: PrivateUsageUploadStateStore(defaults: makeDefaults()),
            relayClient: relayClient,
            bucketBuilder: PrivateUsageDailyBucketBuilder(sealer: sealer),
            sealer: sealer
        )
        let code = "spill-v1:grant_secret:\(testWrappingSecret)"

        _ = try await coordinator.exchangeGrantCode(code)

        let storedSecret = try XCTUnwrap(credentialStore.loadKeyWrappingSecret())
        XCTAssertEqual(storedSecret.rawValue, testWrappingSecret)
        XCTAssertEqual(relayClient.exchangedGrantCodes, ["grant_secret"])
        XCTAssertEqual(relayClient.exchangedKeyFingerprints, [storedSecret.keyID])
        XCTAssertFalse(relayClient.exchangedGrantCodes.contains { $0.contains(testWrappingSecret) })
    }

    func testCoordinatorAcksUploadedBucketsAndAvoidsReupload() async throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let calendar = fixedCalendar(timeZone: timeZone)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 9)))
        let yesterday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 12)))
        let usageStore = makeUsageStore()
        try usageStore.replaceEvents([
            makeEvent(
                spanID: "span_sync",
                runID: "run_sync",
                aiTool: .codex,
                taskType: "code_generation",
                stage: "implement",
                model: "gpt-5",
                input: 11,
                output: 13,
                createdAt: yesterday
            )
        ])
        let credentialStore = InMemoryPrivateUsageCredentialStore()
        let credential = PrivateUsageDeviceCredential(
            deviceID: "device_server",
            credential: "spill_device_v1_secret",
            tokenType: "spill_device_v1",
            createdAt: now
        )
        try credentialStore.saveCredential(credential)
        try credentialStore.saveKeyWrappingSecret(
            PrivateUsageKeyWrappingSecret(rawValue: testWrappingSecret)
        )
        let relayClient = FakePrivateUsageRelayClient()
        let sealer = RecordingPrivateUsageSealer()
        let stateStore = PrivateUsageUploadStateStore(defaults: makeDefaults())
        let coordinator = PrivateUsageUploadCoordinator(
            usageStore: usageStore,
            credentialStore: credentialStore,
            stateStore: stateStore,
            relayClient: relayClient,
            bucketBuilder: PrivateUsageDailyBucketBuilder(
                calendar: calendar,
                timeZone: timeZone,
                sealer: sealer
            ),
            sealer: sealer
        )

        let firstResult = try await coordinator.syncNow(isEnabled: true, now: now)
        let secondResult = try await coordinator.syncNow(isEnabled: true, now: now)

        XCTAssertEqual(firstResult.accepted, 1)
        XCTAssertEqual(firstResult.attemptedBucketCount, 1)
        XCTAssertEqual(secondResult.accepted, 0)
        XCTAssertEqual(relayClient.uploadedBucketCounts, [1])
        XCTAssertEqual(relayClient.uploadedKeyEnvelopeCounts, [1])
        XCTAssertEqual(coordinator.status(isEnabled: true, now: now).queuedBucketCount, 0)
    }

    func testCoordinatorRejectsPartialRelayAcceptanceWithoutAcknowledgingBuckets() async throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let calendar = fixedCalendar(timeZone: timeZone)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 9)))
        let yesterday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 12)))
        let usageStore = makeUsageStore()
        try usageStore.replaceEvents([
            makeEvent(
                spanID: "span_partial",
                runID: "run_partial",
                aiTool: .codex,
                taskType: "code_generation",
                stage: "implement",
                model: "gpt-5",
                input: 11,
                output: 13,
                createdAt: yesterday
            )
        ])
        let credentialStore = InMemoryPrivateUsageCredentialStore()
        try credentialStore.saveCredential(
            PrivateUsageDeviceCredential(
                deviceID: "device_server",
                credential: "spill_device_v1_secret",
                tokenType: "spill_device_v1",
                createdAt: now
            )
        )
        try credentialStore.saveKeyWrappingSecret(
            PrivateUsageKeyWrappingSecret(rawValue: testWrappingSecret)
        )
        let relayClient = FakePrivateUsageRelayClient()
        relayClient.acceptedOverride = 0
        let sealer = RecordingPrivateUsageSealer()
        let stateStore = PrivateUsageUploadStateStore(defaults: makeDefaults())
        let coordinator = PrivateUsageUploadCoordinator(
            usageStore: usageStore,
            credentialStore: credentialStore,
            stateStore: stateStore,
            relayClient: relayClient,
            bucketBuilder: PrivateUsageDailyBucketBuilder(
                calendar: calendar,
                timeZone: timeZone,
                sealer: sealer
            ),
            sealer: sealer
        )

        do {
            _ = try await coordinator.syncNow(isEnabled: true, now: now)
            XCTFail("Expected partial relay acceptance to fail")
        } catch {
            XCTAssertEqual(error as? PrivateUsageUploadError, .invalidRelayResponse)
        }

        XCTAssertTrue(stateStore.load().acknowledgedCiphertextHashesByBucketKey.isEmpty)
        XCTAssertEqual(coordinator.status(isEnabled: true, now: now).queuedBucketCount, 1)
        XCTAssertNotNil(stateStore.load().lastFailedUploadAt)
    }

    func testAutomaticUploadAttemptsOnlyOncePerLocalDay() async throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let calendar = fixedCalendar(timeZone: timeZone)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 9)))
        let yesterday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 12)))
        let usageStore = makeUsageStore()
        try usageStore.replaceEvents([
            makeEvent(
                spanID: "span_auto",
                runID: "run_auto",
                aiTool: .codex,
                taskType: "testing",
                stage: "verify",
                model: "gpt-5",
                input: 3,
                output: 4,
                createdAt: yesterday
            )
        ])
        let credentialStore = InMemoryPrivateUsageCredentialStore()
        try credentialStore.saveCredential(
            PrivateUsageDeviceCredential(
                deviceID: "device_server",
                credential: "spill_device_v1_secret",
                tokenType: "spill_device_v1",
                createdAt: yesterday
            )
        )
        try credentialStore.saveKeyWrappingSecret(
            PrivateUsageKeyWrappingSecret(rawValue: testWrappingSecret)
        )
        let relayClient = FakePrivateUsageRelayClient()
        let sealer = RecordingPrivateUsageSealer()
        let coordinator = PrivateUsageUploadCoordinator(
            usageStore: usageStore,
            credentialStore: credentialStore,
            stateStore: PrivateUsageUploadStateStore(defaults: makeDefaults()),
            relayClient: relayClient,
            bucketBuilder: PrivateUsageDailyBucketBuilder(
                calendar: calendar,
                timeZone: timeZone,
                sealer: sealer
            ),
            sealer: sealer
        )

        let firstResult = await coordinator.runAutomaticUploadIfNeeded(isEnabled: true, now: now)
        let secondResult = await coordinator.runAutomaticUploadIfNeeded(isEnabled: true, now: now)

        XCTAssertEqual(firstResult?.accepted, 1)
        XCTAssertNil(secondResult)
        XCTAssertEqual(relayClient.uploadedBucketCounts, [1])
        XCTAssertEqual(relayClient.uploadedKeyEnvelopeCounts, [1])
    }

    func testAutomaticUploadDoesNotDrainHistoryFromBeforeDeviceConnection() async throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let calendar = fixedCalendar(timeZone: timeZone)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 9)))
        let historicalDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 12)))
        let connectedDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 9, hour: 12)))
        let connectedAt = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 9, hour: 9)))
        let usageStore = makeUsageStore()
        try usageStore.replaceEvents([
            makeEvent(
                spanID: "span_history",
                runID: "run_history",
                aiTool: .codex,
                taskType: "code_generation",
                stage: "implement",
                model: "gpt-5",
                input: 30,
                output: 10,
                createdAt: historicalDay
            ),
            makeEvent(
                spanID: "span_connected",
                runID: "run_connected",
                aiTool: .claude,
                taskType: "testing",
                stage: "verify",
                model: "claude-opus-4",
                input: 3,
                output: 4,
                createdAt: connectedDay
            )
        ])
        let credentialStore = InMemoryPrivateUsageCredentialStore()
        try credentialStore.saveCredential(
            PrivateUsageDeviceCredential(
                deviceID: "device_server",
                credential: "spill_device_v1_secret",
                tokenType: "spill_device_v1",
                createdAt: connectedAt
            )
        )
        try credentialStore.saveKeyWrappingSecret(
            PrivateUsageKeyWrappingSecret(rawValue: testWrappingSecret)
        )
        let relayClient = FakePrivateUsageRelayClient()
        let sealer = RecordingPrivateUsageSealer()
        let coordinator = PrivateUsageUploadCoordinator(
            usageStore: usageStore,
            credentialStore: credentialStore,
            stateStore: PrivateUsageUploadStateStore(defaults: makeDefaults()),
            relayClient: relayClient,
            bucketBuilder: PrivateUsageDailyBucketBuilder(
                calendar: calendar,
                timeZone: timeZone,
                sealer: sealer
            ),
            sealer: sealer
        )

        let result = await coordinator.runAutomaticUploadIfNeeded(isEnabled: true, now: now)

        XCTAssertEqual(result?.accepted, 1)
        XCTAssertEqual(relayClient.uploadedBucketKeys, [["2026-06-09:daily"]])
    }

    func testManualSyncDrainsMultipleUploadBatchesBehindOneUserAction() async throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let calendar = fixedCalendar(timeZone: timeZone)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 9)))
        let usageStore = makeUsageStore()
        let events = try (1...35).map { offset in
            makeEvent(
                spanID: "span_manual_\(offset)",
                runID: "run_manual_\(offset)",
                aiTool: .codex,
                taskType: "code_generation",
                stage: "implement",
                model: "gpt-5",
                input: 1,
                output: 1,
                createdAt: try XCTUnwrap(calendar.date(byAdding: .day, value: -offset, to: now))
            )
        }
        try usageStore.replaceEvents(events)
        let credentialStore = InMemoryPrivateUsageCredentialStore()
        try credentialStore.saveCredential(
            PrivateUsageDeviceCredential(
                deviceID: "device_server",
                credential: "spill_device_v1_secret",
                tokenType: "spill_device_v1",
                createdAt: now
            )
        )
        try credentialStore.saveKeyWrappingSecret(
            PrivateUsageKeyWrappingSecret(rawValue: testWrappingSecret)
        )
        let relayClient = FakePrivateUsageRelayClient()
        let sealer = RecordingPrivateUsageSealer()
        let coordinator = PrivateUsageUploadCoordinator(
            usageStore: usageStore,
            credentialStore: credentialStore,
            stateStore: PrivateUsageUploadStateStore(defaults: makeDefaults()),
            relayClient: relayClient,
            bucketBuilder: PrivateUsageDailyBucketBuilder(
                calendar: calendar,
                timeZone: timeZone,
                sealer: sealer
            ),
            sealer: sealer
        )

        let result = try await coordinator.syncNow(isEnabled: true, now: now)

        XCTAssertEqual(result.accepted, 35)
        XCTAssertEqual(result.attemptedBucketCount, 35)
        XCTAssertEqual(relayClient.uploadedBucketCounts, [31, 4])
    }

    func testAutomaticUploadCanRetrySameDayAfterFailure() async throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let calendar = fixedCalendar(timeZone: timeZone)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 9)))
        let yesterday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 12)))
        let usageStore = makeUsageStore()
        try usageStore.replaceEvents([
            makeEvent(
                spanID: "span_retry",
                runID: "run_retry",
                aiTool: .codex,
                taskType: "testing",
                stage: "verify",
                model: "gpt-5",
                input: 3,
                output: 4,
                createdAt: yesterday
            )
        ])
        let credentialStore = InMemoryPrivateUsageCredentialStore()
        try credentialStore.saveCredential(
            PrivateUsageDeviceCredential(
                deviceID: "device_server",
                credential: "spill_device_v1_secret",
                tokenType: "spill_device_v1",
                createdAt: yesterday
            )
        )
        try credentialStore.saveKeyWrappingSecret(
            PrivateUsageKeyWrappingSecret(rawValue: testWrappingSecret)
        )
        let relayClient = FakePrivateUsageRelayClient()
        relayClient.uploadError = PrivateUsageUploadError.relay(status: 503, reason: nil)
        let sealer = RecordingPrivateUsageSealer()
        let stateStore = PrivateUsageUploadStateStore(defaults: makeDefaults())
        let coordinator = PrivateUsageUploadCoordinator(
            usageStore: usageStore,
            credentialStore: credentialStore,
            stateStore: stateStore,
            relayClient: relayClient,
            bucketBuilder: PrivateUsageDailyBucketBuilder(
                calendar: calendar,
                timeZone: timeZone,
                sealer: sealer
            ),
            sealer: sealer
        )

        let failedResult = await coordinator.runAutomaticUploadIfNeeded(isEnabled: true, now: now)
        relayClient.uploadError = nil
        let retryResult = await coordinator.runAutomaticUploadIfNeeded(isEnabled: true, now: now)

        XCTAssertNil(failedResult)
        XCTAssertEqual(retryResult?.accepted, 1)
        XCTAssertEqual(relayClient.uploadedBucketCounts, [1])
        XCTAssertNil(stateStore.load().lastFailedUploadAt)
        XCTAssertEqual(stateStore.load().lastAutomaticAttemptDayID, "2026-06-08")
    }

    func testEnvironmentSeparatesRelayKeychainAndLocalUploadState() {
        let defaults = makeDefaults()
        let productionState = PrivateUsageUploadStateStore(
            defaults: defaults,
            environment: .production
        )
        let developmentState = PrivateUsageUploadStateStore(
            defaults: defaults,
            environment: .development
        )
        var state = PrivateUsageUploadPersistence.empty
        state.acknowledgedCiphertextHashesByBucketKey = ["2026-06-07:daily": String(repeating: "a", count: 64)]

        productionState.save(state)

        XCTAssertEqual(
            productionState.load().acknowledgedCiphertextHashesByBucketKey["2026-06-07:daily"],
            String(repeating: "a", count: 64)
        )
        XCTAssertTrue(developmentState.load().acknowledgedCiphertextHashesByBucketKey.isEmpty)
        XCTAssertNotEqual(productionState.installID(), developmentState.installID())
        XCTAssertNotEqual(
            PrivateUsageUploadEnvironment.production.keychainService,
            PrivateUsageUploadEnvironment.development.keychainService
        )
    }

    func testStatusCheckClearsRevokedDeviceCredential() async throws {
        let now = try XCTUnwrap(ISO8601DateFormatter.parseTokenUsageDate(from: "2026-06-08T10:00:00.000Z"))
        let credentialStore = InMemoryPrivateUsageCredentialStore()
        try credentialStore.saveCredential(
            PrivateUsageDeviceCredential(
                deviceID: "device_server",
                credential: "spill_device_v1_secret",
                tokenType: "spill_device_v1",
                createdAt: now
            )
        )
        try credentialStore.saveKeyWrappingSecret(
            PrivateUsageKeyWrappingSecret(rawValue: testWrappingSecret)
        )
        let relayClient = FakePrivateUsageRelayClient()
        relayClient.connectionCheckError = PrivateUsageUploadError.relay(
            status: 403,
            reason: "device_forbidden"
        )
        let sealer = RecordingPrivateUsageSealer()
        let coordinator = PrivateUsageUploadCoordinator(
            usageStore: makeUsageStore(),
            credentialStore: credentialStore,
            stateStore: PrivateUsageUploadStateStore(defaults: makeDefaults()),
            relayClient: relayClient,
            bucketBuilder: PrivateUsageDailyBucketBuilder(sealer: sealer),
            sealer: sealer
        )

        let status = await coordinator.statusAsync(isEnabled: true, now: now)

        XCTAssertFalse(status.isConnected)
        XCTAssertNil(try credentialStore.loadCredential())
        XCTAssertNil(try credentialStore.loadKeyWrappingSecret())
    }

    func testSyncNowChecksRevokedDeviceEvenWhenNoBucketsAreQueued() async throws {
        let now = try XCTUnwrap(ISO8601DateFormatter.parseTokenUsageDate(from: "2026-06-08T10:00:00.000Z"))
        let credentialStore = InMemoryPrivateUsageCredentialStore()
        try credentialStore.saveCredential(
            PrivateUsageDeviceCredential(
                deviceID: "device_server",
                credential: "spill_device_v1_secret",
                tokenType: "spill_device_v1",
                createdAt: now
            )
        )
        try credentialStore.saveKeyWrappingSecret(
            PrivateUsageKeyWrappingSecret(rawValue: testWrappingSecret)
        )
        let relayClient = FakePrivateUsageRelayClient()
        relayClient.connectionCheckError = PrivateUsageUploadError.relay(
            status: 403,
            reason: "device_forbidden"
        )
        let sealer = RecordingPrivateUsageSealer()
        let coordinator = PrivateUsageUploadCoordinator(
            usageStore: makeUsageStore(),
            credentialStore: credentialStore,
            stateStore: PrivateUsageUploadStateStore(defaults: makeDefaults()),
            relayClient: relayClient,
            bucketBuilder: PrivateUsageDailyBucketBuilder(sealer: sealer),
            sealer: sealer
        )

        do {
            _ = try await coordinator.syncNow(isEnabled: true, now: now)
            XCTFail("Expected revoked device check to fail")
        } catch {
            XCTAssertEqual(error as? PrivateUsageUploadError, .relay(status: 403, reason: "device_forbidden"))
        }

        XCTAssertEqual(relayClient.checkedConnectionDeviceIDs, ["device_server"])
        XCTAssertTrue(relayClient.uploadedBucketCounts.isEmpty)
        XCTAssertNil(try credentialStore.loadCredential())
        XCTAssertNil(try credentialStore.loadKeyWrappingSecret())
    }

    func testWebConnectionURLRequiresConfiguredSafeURL() {
        XCTAssertNil(PrivateUsageWebConnection.connectDeviceURL(processEnvironment: [:], bundleInfo: nil))
        XCTAssertEqual(
            PrivateUsageWebConnection.connectDeviceURL(
                processEnvironment: [
                    PrivateUsageWebConnection.webURLOverrideEnvironmentKey: "http://localhost/#/connect-device"
                ]
            )?.absoluteString,
            Optional("http://localhost/#/connect-device?source=macos&callback_url=spill://private-usage/connect")
        )
        XCTAssertEqual(
            PrivateUsageWebConnection.connectDeviceURL(
                processEnvironment: [:],
                bundleInfo: [
                    PrivateUsageWebConnection.webURLInfoDictionaryKey: "https://web.example.test/#/connect-device"
                ]
            )?.absoluteString,
            Optional("https://web.example.test/#/connect-device?source=macos&callback_url=spill://private-usage/connect")
        )
        XCTAssertNil(
            PrivateUsageWebConnection.connectDeviceURL(
                processEnvironment: [
                    PrivateUsageWebConnection.webURLOverrideEnvironmentKey: "file:///tmp/unsafe"
                ]
            )
        )
        XCTAssertNil(
            PrivateUsageWebConnection.connectDeviceURL(
                processEnvironment: [
                    PrivateUsageWebConnection.webURLOverrideEnvironmentKey: "http://example.com/#/connect-device"
                ]
            )
        )
        XCTAssertNil(
            PrivateUsageWebConnection.connectDeviceURL(
                processEnvironment: [
                    PrivateUsageWebConnection.webURLOverrideEnvironmentKey: "ftp://localhost/#/connect-device"
                ]
            )
        )
    }

    func testWebConnectionURLUsesAppCallbackOverConfiguredCallback() {
        XCTAssertEqual(
            PrivateUsageWebConnection.connectDeviceURL(
                processEnvironment: [
                    PrivateUsageWebConnection.webURLOverrideEnvironmentKey: "https://web.example.test/#/connect-device?source=browser&callback_url=https%3A%2F%2Fexample.test%2Fdone"
                ]
            )?.absoluteString,
            Optional("https://web.example.test/#/connect-device?source=macos&callback_url=spill://private-usage/connect")
        )
    }

    func testPrivateUsageEnvironmentUsesRuntimeEnvBeforeBundleInfo() {
        XCTAssertEqual(
            PrivateUsageUploadEnvironment.resolvedFromConfiguration(
                processEnvironment: [
                    PrivateUsageUploadEnvironment.environmentOverrideEnvironmentKey: "development"
                ],
                bundleInfo: [
                    PrivateUsageUploadEnvironment.environmentInfoDictionaryKey: "production"
                ]
            ),
            .development
        )
        XCTAssertEqual(
            PrivateUsageUploadEnvironment.resolvedFromConfiguration(
                processEnvironment: [:],
                bundleInfo: [
                    PrivateUsageUploadEnvironment.environmentInfoDictionaryKey: "production"
                ]
            ),
            .production
        )
        XCTAssertNil(
            PrivateUsageUploadEnvironment.resolvedFromConfiguration(
                processEnvironment: [:],
                bundleInfo: [
                    PrivateUsageUploadEnvironment.environmentInfoDictionaryKey: "preview"
                ]
            )
        )
    }

    func testPrivateUsageURLsUseBundleInfoAfterRuntimeEnv() {
        let bundleInfo: [String: Any] = [
            PrivateUsageWebConnection.webURLInfoDictionaryKey: "https://preview.example.com/#/connect-device",
            PrivateUsageRelayEndpoint.relayURLInfoDictionaryKey: "https://relay.example.com/functions/v1/private-usage-relay"
        ]

        XCTAssertEqual(
            PrivateUsageWebConnection.connectDeviceURL(
                processEnvironment: [:],
                bundleInfo: bundleInfo
            )?.absoluteString,
            Optional("https://preview.example.com/#/connect-device?source=macos&callback_url=spill://private-usage/connect")
        )
        XCTAssertEqual(
            PrivateUsageRelayEndpoint.relayURL(
                environment: .production,
                processEnvironment: [:],
                bundleInfo: bundleInfo
            )?.absoluteString,
            Optional("https://relay.example.com/functions/v1/private-usage-relay")
        )
        XCTAssertEqual(
            PrivateUsageWebConnection.connectDeviceURL(
                processEnvironment: [
                    PrivateUsageWebConnection.webURLOverrideEnvironmentKey: "http://localhost/#/connect-device"
                ],
                bundleInfo: bundleInfo
            )?.absoluteString,
            Optional("http://localhost/#/connect-device?source=macos&callback_url=spill://private-usage/connect")
        )
        XCTAssertEqual(
            PrivateUsageRelayEndpoint.relayURL(
                environment: .production,
                processEnvironment: [
                    PrivateUsageRelayEndpoint.relayURLOverrideEnvironmentKey: "http://localhost:54321/functions/v1/private-usage-relay"
                ],
                bundleInfo: bundleInfo
            )?.absoluteString,
            Optional("http://localhost:54321/functions/v1/private-usage-relay")
        )
    }

    func testPrivateUsageDeviceNameUsesComputerNameWhenSafe() {
        XCTAssertEqual(
            PrivateUsageDeviceName.current(
                copyComputerName: { "Work MacBook" },
                fallbackHostName: "fallback"
            ),
            "Work MacBook"
        )
        XCTAssertEqual(
            PrivateUsageDeviceName.current(
                copyComputerName: { "  " },
                fallbackHostName: "Fallback Mac"
            ),
            "Fallback Mac"
        )
        XCTAssertNil(
            PrivateUsageDeviceName.current(
                copyComputerName: { "Bad\nName" },
                fallbackHostName: nil
            )
        )
    }

    func testPrivateUsageRelayURLRejectsUnsafeOverrides() {
        XCTAssertNil(
            PrivateUsageRelayEndpoint.relayURL(
                environment: .production,
                processEnvironment: [
                    PrivateUsageRelayEndpoint.relayURLOverrideEnvironmentKey: "http://example.com/functions/v1/private-usage-relay"
                ],
                bundleInfo: [
                    PrivateUsageRelayEndpoint.relayURLInfoDictionaryKey: "ftp://localhost/functions/v1/private-usage-relay"
                ]
            )
        )
    }

    func testAESGCMSealerRotatesKeyVersionsAndRetainsKeyRing() throws {
        let credentialStore = InMemoryPrivateUsageCredentialStore()
        let clock = MutableClock(
            date: Date(timeIntervalSince1970: 1_000)
        )
        let sealer = PrivateUsageAESGCMBucketSealer(
            credentialStore: credentialStore,
            rotationInterval: 10,
            now: { clock.date }
        )

        let first = try sealer.seal(Data("first".utf8), bucketKey: "2026-06-07:daily")
        clock.date = Date(timeIntervalSince1970: 1_005)
        let second = try sealer.seal(Data("second".utf8), bucketKey: "2026-06-08:daily")
        clock.date = Date(timeIntervalSince1970: 1_011)
        let third = try sealer.seal(Data("third".utf8), bucketKey: "2026-06-09:daily")

        XCTAssertEqual(first.keyVersion, 1)
        XCTAssertEqual(second.keyVersion, 1)
        XCTAssertEqual(third.keyVersion, 2)

        let keyRing = try XCTUnwrap(credentialStore.storedKeyRing())
        XCTAssertEqual(keyRing["current_version"] as? Int, 2)
        XCTAssertEqual((keyRing["keys"] as? [[String: Any]])?.count, 2)
    }

    func testAESGCMSealerMigratesLegacySingleKeyToVersionOneKeyRing() throws {
        let credentialStore = InMemoryPrivateUsageCredentialStore()
        try credentialStore.saveSealingKeyData(Data(repeating: 7, count: 32))
        let sealer = PrivateUsageAESGCMBucketSealer(
            credentialStore: credentialStore,
            rotationInterval: 60,
            now: { Date(timeIntervalSince1970: 1_000) }
        )

        let sealed = try sealer.seal(Data("legacy".utf8), bucketKey: "2026-06-07:daily")

        XCTAssertEqual(sealed.keyVersion, 1)
        let keyRing = try XCTUnwrap(credentialStore.storedKeyRing())
        XCTAssertEqual(keyRing["current_version"] as? Int, 1)
        XCTAssertEqual((keyRing["keys"] as? [[String: Any]])?.count, 1)
    }

    func testAESGCMSealerWrapsSealingKeysForBrowserOnlySecret() throws {
        let credentialStore = InMemoryPrivateUsageCredentialStore()
        try credentialStore.saveSealingKeyData(Data(repeating: 9, count: 32))
        let wrappingSecret = try PrivateUsageKeyWrappingSecret(rawValue: testWrappingSecret)
        let sealer = PrivateUsageAESGCMBucketSealer(
            credentialStore: credentialStore,
            rotationInterval: 60,
            now: { Date(timeIntervalSince1970: 1_000) }
        )

        _ = try sealer.seal(Data("daily aggregate".utf8), bucketKey: "2026-06-07:daily")
        let envelopes = try sealer.keyEnvelopes(for: wrappingSecret)

        XCTAssertEqual(envelopes.count, 1)
        XCTAssertEqual(envelopes[0].keyVersion, 1)
        XCTAssertEqual(envelopes[0].wrappingKeyID, wrappingSecret.keyID)
        XCTAssertEqual(envelopes[0].algorithm, PrivateUsageKeyEnvelope.algorithm)
        XCTAssertFalse(envelopes[0].wrappedKey.contains(testWrappingSecret))

        let unwrappedKey = try PrivateUsageAESGCMBucketSealer.unwrapKeyEnvelope(
            envelopes[0],
            using: wrappingSecret
        )
        XCTAssertEqual(unwrappedKey, Data(repeating: 9, count: 32))
    }

    private func fixedCalendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private func makeUsageStore() -> TokenUsageStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpillPrivateUsageUploadTests-\(UUID().uuidString)", isDirectory: true)
        return TokenUsageStore(
            fileURL: directory.appendingPathComponent("events.json"),
            inboxURL: directory.appendingPathComponent("inbox", isDirectory: true)
        )
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "PrivateUsageUploadTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeEvent(
        spanID: String,
        runID: String,
        aiTool: TokenUsageAITool,
        taskType: TokenUsageTaskType,
        stage: TokenUsageStage,
        model: String,
        input: Int,
        output: Int,
        createdAt: Date
    ) -> TokenUsageEvent {
        TokenUsageEvent(
            schemaVersion: 1,
            deviceID: "device_local",
            projectID: "project_global",
            artifactID: "artifact_global",
            runID: runID,
            spanID: spanID,
            aiTool: aiTool,
            taskType: taskType,
            stage: stage,
            model: model,
            inputTokens: input,
            outputTokens: output,
            totalTokens: input + output,
            tokenBreakdown: TokenUsageBreakdown(
                system: 0,
                user: 0,
                history: 0,
                repoContext: 0,
                toolOutput: 0,
                generatedOutput: 0,
                unknown: input + output
            ),
            latencyMS: 0,
            createdAt: ISO8601DateFormatter.tokenUsage.string(from: createdAt)
        )
    }
}

private final class RecordingPrivateUsageSealer: PrivateUsageBucketSealing, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var plaintexts = [Data]()

    func seal(_ plaintext: Data, bucketKey: String) throws -> PrivateUsageSealedPayload {
        lock.withLock {
            plaintexts.append(plaintext)
        }
        let digest = PrivateUsageDailyBucketBuilder.sha256Hex(plaintext)
        return PrivateUsageSealedPayload(
            ciphertext: "sealed-\(bucketKey)-\(digest)",
            keyVersion: 1
        )
    }

    func keyEnvelopes(for wrappingSecret: PrivateUsageKeyWrappingSecret) throws -> [PrivateUsageKeyEnvelope] {
        [
            PrivateUsageKeyEnvelope(
                keyVersion: 1,
                wrappingKeyID: wrappingSecret.keyID,
                algorithm: PrivateUsageKeyEnvelope.algorithm,
                wrappedKey: "wrapped"
            )
        ]
    }
}

private final class MutableClock: @unchecked Sendable {
    private let lock = NSLock()
    private var storedDate: Date

    init(date: Date) {
        storedDate = date
    }

    var date: Date {
        get {
            lock.withLock { storedDate }
        }
        set {
            lock.withLock {
                storedDate = newValue
            }
        }
    }
}

private final class PrivateUsageRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedRequests = [URLRequest]()

    var requests: [URLRequest] {
        lock.withLock { recordedRequests }
    }

    func append(_ request: URLRequest) {
        lock.withLock {
            recordedRequests.append(request)
        }
    }
}

private final class InMemoryPrivateUsageCredentialStore: PrivateUsageCredentialStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var credential: PrivateUsageDeviceCredential?
    private var keyWrappingSecret: PrivateUsageKeyWrappingSecret?
    private var sealingKeyData: Data? = Data(repeating: 1, count: 32)

    func loadCredential() throws -> PrivateUsageDeviceCredential? {
        lock.withLock { credential }
    }

    func saveCredential(_ credential: PrivateUsageDeviceCredential) throws {
        lock.withLock {
            self.credential = credential
        }
    }

    func clearCredential() throws {
        lock.withLock {
            credential = nil
        }
    }

    func loadKeyWrappingSecret() throws -> PrivateUsageKeyWrappingSecret? {
        lock.withLock { keyWrappingSecret }
    }

    func saveKeyWrappingSecret(_ secret: PrivateUsageKeyWrappingSecret) throws {
        lock.withLock {
            keyWrappingSecret = secret
        }
    }

    func clearKeyWrappingSecret() throws {
        lock.withLock {
            keyWrappingSecret = nil
        }
    }

    func loadSealingKeyData() throws -> Data? {
        lock.withLock { sealingKeyData }
    }

    func saveSealingKeyData(_ data: Data) throws {
        lock.withLock {
            sealingKeyData = data
        }
    }

    func storedKeyRing() throws -> [String: Any]? {
        guard let data = lock.withLock({ sealingKeyData }) else {
            return nil
        }

        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}

private final class FakePrivateUsageRelayClient: PrivateUsageRelayClienting, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var uploadedBucketCounts = [Int]()
    private(set) var uploadedBucketKeys = [[String]]()
    private(set) var uploadedKeyEnvelopeCounts = [Int]()
    private(set) var exchangedGrantCodes = [String]()
    private(set) var exchangedDeviceNames = [String?]()
    private(set) var exchangedKeyFingerprints = [String?]()
    private(set) var checkedConnectionDeviceIDs = [String]()
    var uploadError: Error?
    var connectionCheckError: Error?
    var acceptedOverride: Int?

    func exchangeDeviceGrant(
        grantCode: String,
        installID: String,
        deviceName: String?,
        deviceKeyFingerprint: String?
    ) async throws -> PrivateUsageDeviceCredential {
        lock.withLock {
            exchangedGrantCodes.append(grantCode)
            exchangedDeviceNames.append(deviceName)
            exchangedKeyFingerprints.append(deviceKeyFingerprint)
        }
        return PrivateUsageDeviceCredential(
            deviceID: "device_server",
            credential: "spill_device_v1_secret",
            tokenType: "spill_device_v1",
            createdAt: Date()
        )
    }

    func uploadBuckets(
        credential: PrivateUsageDeviceCredential,
        buckets: [PrivateUsageEncryptedBucket],
        keyEnvelopes: [PrivateUsageKeyEnvelope]
    ) async throws -> PrivateUsageUploadResponse {
        if let uploadError {
            throw uploadError
        }
        lock.withLock {
            uploadedBucketCounts.append(buckets.count)
            uploadedBucketKeys.append(buckets.map(\.bucketKey))
            uploadedKeyEnvelopeCounts.append(keyEnvelopes.count)
        }
        return PrivateUsageUploadResponse(
            accepted: acceptedOverride ?? buckets.count,
            uploadedAt: "2026-06-08T00:00:00.000Z"
        )
    }

    func checkDeviceConnection(
        credential: PrivateUsageDeviceCredential
    ) async throws {
        lock.withLock {
            checkedConnectionDeviceIDs.append(credential.deviceID)
        }
        if let connectionCheckError {
            throw connectionCheckError
        }
    }
}
