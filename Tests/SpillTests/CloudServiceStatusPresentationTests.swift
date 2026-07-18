import XCTest
@testable import Spill

final class CloudServiceStatusPresentationTests: XCTestCase {
    func testCloudServiceKindsExposeStatusPageURLs() {
        XCTAssertEqual(CloudServiceKind.codex.statusPageURL.absoluteString, "https://status.openai.com/")
        XCTAssertEqual(CloudServiceKind.openAI.statusPageURL.absoluteString, "https://status.openai.com/")
        XCTAssertEqual(CloudServiceKind.claudeCode.statusPageURL.absoluteString, "https://status.claude.com/")
        XCTAssertEqual(CloudServiceKind.claudeAPI.statusPageURL.absoluteString, "https://status.claude.com/")
        XCTAssertEqual(CloudServiceKind.geminiAPI.statusPageURL.absoluteString, "https://status.cloud.google.com/")
        XCTAssertEqual(CloudServiceKind.antigravity.statusPageURL.absoluteString, "https://status.cloud.google.com/")
    }

    func testAggregateHealthIgnoresAntigravityUnknownWhenOfficialSourcesAreHealthy() {
        let health = CloudServiceStatusPresentation.aggregateHealth(for: [
            item(kind: .openAI, health: .operational),
            item(kind: .claudeCode, health: .operational),
            item(kind: .antigravity, health: .unknown)
        ])

        XCTAssertEqual(health, .operational)
    }

    func testAggregateHealthKeepsUnknownForOfficialStatusFailures() {
        let health = CloudServiceStatusPresentation.aggregateHealth(for: [
            item(kind: .openAI, health: .unknown),
            item(kind: .claudeCode, health: .operational),
            item(kind: .antigravity, health: .unknown)
        ])

        XCTAssertEqual(health, .unknown)
    }

    func testAggregateHealthPrioritizesServerIssuesOverUnknowns() {
        let health = CloudServiceStatusPresentation.aggregateHealth(for: [
            item(kind: .openAI, health: .unknown),
            item(kind: .claudeAPI, health: .degraded),
            item(kind: .geminiAPI, health: .operational)
        ])

        XCTAssertEqual(health, .degraded)
    }

    func testServerStatusBadgeTitlesExposeHealthDirectly() {
        XCTAssertEqual(CloudServiceHealth.operational.serverStatusBadgeTitle, "Server OK")
        XCTAssertEqual(CloudServiceHealth.degraded.serverStatusBadgeTitle, "Degraded")
        XCTAssertEqual(CloudServiceHealth.outage.serverStatusBadgeTitle, "Outage")
        XCTAssertEqual(CloudServiceHealth.maintenance.serverStatusBadgeTitle, "Maint")
        XCTAssertEqual(CloudServiceHealth.unknown.serverStatusBadgeTitle, "Unknown")
    }

    func testControlStateUsesSharedServerIssuePresentation() {
        let now = Date(timeIntervalSince1970: 10_000)
        let snapshot = CloudServiceStatusSnapshot(
            fetchedAt: now.addingTimeInterval(-600),
            items: [
                item(kind: .codex, health: .operational),
                item(kind: .claudeCode, health: .degraded)
            ]
        )

        let state = CloudServiceStatusPresentation.controlState(
            snapshot: snapshot,
            isLoading: false,
            appLanguage: .english,
            now: now
        )

        XCTAssertEqual(state.title, "Degraded")
        XCTAssertEqual(state.symbolName, "exclamationmark.circle.fill")
        XCTAssertEqual(state.issueCount, 1)
        XCTAssertTrue(state.hasServerIssue)
        XCTAssertTrue(state.helpText.contains("with 1 issue"))
    }

    func testControlStateKeepsLoadingVisualStateShared() {
        let state = CloudServiceStatusPresentation.controlState(
            snapshot: nil,
            isLoading: true,
            appLanguage: .english
        )

        XCTAssertEqual(state.title, "Checking")
        XCTAssertEqual(state.symbolName, "arrow.triangle.2.circlepath")
        XCTAssertEqual(state.issueCount, 0)
        XCTAssertFalse(state.hasServerIssue)
    }

    func testOnlyActionableHealthStatesCountAsServerIssues() {
        XCTAssertFalse(CloudServiceHealth.operational.isServerIssue)
        XCTAssertTrue(CloudServiceHealth.degraded.isServerIssue)
        XCTAssertTrue(CloudServiceHealth.outage.isServerIssue)
        XCTAssertTrue(CloudServiceHealth.maintenance.isServerIssue)
        XCTAssertFalse(CloudServiceHealth.unknown.isServerIssue)
    }

    func testLocalAIToolKindsMapToCloudServiceKinds() {
        XCTAssertEqual(CloudServiceStatusPresentation.serviceKinds(for: LocalAIToolKind.codex), [.codex])
        XCTAssertEqual(CloudServiceStatusPresentation.serviceKinds(for: LocalAIToolKind.claude), [.claudeCode])
        XCTAssertEqual(CloudServiceStatusPresentation.serviceKinds(for: LocalAIToolKind.antigravity), [.antigravity])
        XCTAssertEqual(CloudServiceStatusPresentation.serviceKinds(for: LocalAIToolKind.openAI), [.openAI])
        XCTAssertEqual(CloudServiceStatusPresentation.serviceKinds(for: LocalAIToolKind.ollama), [])
    }

    func testTokenAIToolsMapToCloudServiceKinds() {
        XCTAssertEqual(CloudServiceStatusPresentation.serviceKinds(for: TokenUsageAITool.codex), [.codex])
        XCTAssertEqual(CloudServiceStatusPresentation.serviceKinds(for: TokenUsageAITool.claude), [.claudeCode])
        XCTAssertEqual(CloudServiceStatusPresentation.serviceKinds(for: TokenUsageAITool.antigravity), [.antigravity])
        XCTAssertEqual(CloudServiceStatusPresentation.serviceKinds(for: TokenUsageAITool.openAI), [.openAI])
        XCTAssertEqual(CloudServiceStatusPresentation.serviceKinds(for: TokenUsageAITool.unknown), [])
    }

    func testServiceStatusUsesWorstMappedHealth() {
        let snapshot = CloudServiceStatusSnapshot(
            fetchedAt: Date(),
            items: [
                item(kind: .claudeAPI, health: .outage),
                item(kind: .claudeCode, health: .degraded),
                item(kind: .openAI, health: .operational)
            ]
        )

        XCTAssertEqual(
            CloudServiceStatusPresentation.serviceStatus(for: TokenUsageAITool.claude, in: snapshot)?.kind,
            .claudeCode
        )
        XCTAssertEqual(
            CloudServiceStatusPresentation.serviceStatus(for: TokenUsageAITool.claude, in: snapshot)?.health,
            .degraded
        )
    }

    func testGuidanceDirectsHealthyOfficialStatusToLocalChecks() {
        let snapshot = CloudServiceStatusSnapshot(
            fetchedAt: Date(),
            items: [
                item(kind: .codex, health: .operational),
                item(kind: .claudeCode, health: .operational),
                item(kind: .geminiAPI, health: .operational)
            ]
        )

        let guidance = CloudServiceStatusGuidance.make(
            snapshot: snapshot,
            isLoading: false,
            appLanguage: .english
        )

        XCTAssertEqual(guidance.title, "Official services look healthy")
        XCTAssertEqual(guidance.symbolName, "checkmark.circle.fill")
        XCTAssertEqual(guidance.health, .operational)
        XCTAssertTrue(guidance.detail.contains("local process and setup"))
    }

    func testGuidancePrioritizesOfficialIncidents() {
        let snapshot = CloudServiceStatusSnapshot(
            fetchedAt: Date(),
            items: [
                item(kind: .codex, health: .operational),
                item(kind: .claudeCode, health: .outage)
            ]
        )

        let guidance = CloudServiceStatusGuidance.make(
            snapshot: snapshot,
            isLoading: false,
            appLanguage: .english
        )

        XCTAssertEqual(guidance.title, "1 official service issue")
        XCTAssertEqual(guidance.symbolName, "exclamationmark.triangle.fill")
        XCTAssertEqual(guidance.health, .outage)
        XCTAssertTrue(guidance.detail.contains("affected service"))
    }

    func testGuidanceExplainsUnavailableOfficialStatus() {
        let snapshot = CloudServiceStatusSnapshot(
            fetchedAt: Date(),
            items: [item(kind: .openAI, health: .unknown)]
        )

        let guidance = CloudServiceStatusGuidance.make(
            snapshot: snapshot,
            isLoading: false,
            appLanguage: .english
        )

        XCTAssertEqual(guidance.title, "Official status is incomplete")
        XCTAssertEqual(guidance.symbolName, "questionmark.circle.fill")
        XCTAssertEqual(guidance.health, .unknown)
        XCTAssertTrue(guidance.detail.contains("Refresh or open"))
    }

    private func item(kind: CloudServiceKind, health: CloudServiceHealth) -> CloudServiceStatusItem {
        CloudServiceStatusItem(
            kind: kind,
            health: health,
            detail: "test",
            source: "test"
        )
    }
}
