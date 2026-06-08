import XCTest
@testable import Spill

final class CloudServiceStatusPresentationTests: XCTestCase {
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

    private func item(kind: CloudServiceKind, health: CloudServiceHealth) -> CloudServiceStatusItem {
        CloudServiceStatusItem(
            kind: kind,
            health: health,
            detail: "test",
            source: "test"
        )
    }
}
