import Foundation

enum CloudServiceKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case codex
    case openAI
    case claudeCode
    case claudeAPI
    case geminiAPI
    case antigravity

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .codex:
            return "Codex"
        case .openAI:
            return "OpenAI API"
        case .claudeCode:
            return "Claude Code"
        case .claudeAPI:
            return "Claude API"
        case .geminiAPI:
            return "Gemini API"
        case .antigravity:
            return "Antigravity"
        }
    }

    var symbolName: String {
        switch self {
        case .codex:
            return "terminal.fill"
        case .openAI:
            return "key.fill"
        case .claudeCode:
            return "curlybraces.square.fill"
        case .claudeAPI:
            return "network"
        case .geminiAPI:
            return "sparkles"
        case .antigravity:
            return "app.dashed"
        }
    }
}

enum CloudServiceHealth: String, Codable, Sendable {
    case operational
    case degraded
    case outage
    case maintenance
    case unknown

    var title: String {
        switch self {
        case .operational:
            return "Operational"
        case .degraded:
            return "Degraded"
        case .outage:
            return "Outage"
        case .maintenance:
            return "Maintenance"
        case .unknown:
            return "Unknown"
        }
    }
}

struct CloudServiceStatusItem: Identifiable, Codable, Equatable, Sendable {
    let kind: CloudServiceKind
    let health: CloudServiceHealth
    let detail: String
    let source: String

    var id: String {
        kind.rawValue
    }

    var title: String {
        kind.title
    }

    var symbolName: String {
        kind.symbolName
    }
}

struct CloudServiceStatusSnapshot: Codable, Equatable, Sendable {
    let fetchedAt: Date
    let items: [CloudServiceStatusItem]

    func isFresh(now: Date = Date(), ttl: TimeInterval) -> Bool {
        now.timeIntervalSince(fetchedAt) < ttl
    }

    func isFresh(
        now: Date = Date(),
        healthyTTL: TimeInterval,
        issueTTL: TimeInterval
    ) -> Bool {
        now.timeIntervalSince(fetchedAt) < (usesIssueRefreshInterval ? issueTTL : healthyTTL)
    }

    var usesIssueRefreshInterval: Bool {
        items.isEmpty || items.contains { $0.health != .operational }
    }
}

struct CloudServiceStatusProvider: Sendable {
    static let defaultCacheTTL: TimeInterval = 15 * 60
    static let issueCacheTTL: TimeInterval = 5 * 60
    static let openAIStatusURL = URL(string: "https://status.openai.com/api/v2/summary.json")!
    static let claudeStatusURL = URL(string: "https://status.claude.com/api/v2/summary.json")!
    static let googleCloudIncidentsURL = URL(string: "https://status.cloud.google.com/incidents.json")!

    let dataLoader: @Sendable (URL) async throws -> Data

    init(dataLoader: @escaping @Sendable (URL) async throws -> Data = Self.liveData(from:)) {
        self.dataLoader = dataLoader
    }

    func snapshot(now: Date = Date()) async -> CloudServiceStatusSnapshot {
        var items = [CloudServiceStatusItem]()
        items.append(contentsOf: await openAIItems())
        items.append(contentsOf: await claudeItems())
        let googleStatusItems = await googleItems()
        items.append(contentsOf: googleStatusItems)
        items.append(antigravityItem(from: googleStatusItems.first { $0.kind == .geminiAPI }))

        return CloudServiceStatusSnapshot(fetchedAt: now, items: items)
    }

    private func openAIItems() async -> [CloudServiceStatusItem] {
        do {
            let summary = try await statusPageSummary(from: Self.openAIStatusURL)
            return [
                item(
                    kind: .codex,
                    source: "OpenAI Status",
                    components: components(
                        named: ["CLI", "Codex API", "VS Code extension"],
                        in: summary
                    ),
                    fallback: summary.status
                ),
                item(
                    kind: .openAI,
                    source: "OpenAI Status",
                    components: components(
                        named: ["Responses", "Realtime", "Images", "Embeddings", "Files"],
                        in: summary
                    ),
                    fallback: summary.status
                )
            ]
        } catch {
            return [
                unavailableItem(kind: .codex, source: "OpenAI Status", error: error),
                unavailableItem(kind: .openAI, source: "OpenAI Status", error: error)
            ]
        }
    }

    private func claudeItems() async -> [CloudServiceStatusItem] {
        do {
            let summary = try await statusPageSummary(from: Self.claudeStatusURL)
            return [
                item(
                    kind: .claudeCode,
                    source: "Claude Status",
                    components: components(named: ["Claude Code"], in: summary),
                    fallback: summary.status
                ),
                item(
                    kind: .claudeAPI,
                    source: "Claude Status",
                    components: components(named: ["Claude API"], in: summary),
                    fallback: summary.status
                )
            ]
        } catch {
            return [
                unavailableItem(kind: .claudeCode, source: "Claude Status", error: error),
                unavailableItem(kind: .claudeAPI, source: "Claude Status", error: error)
            ]
        }
    }

    private func googleItems() async -> [CloudServiceStatusItem] {
        do {
            let data = try await dataLoader(Self.googleCloudIncidentsURL)
            let incidents = try JSONDecoder().decode([GoogleCloudIncident].self, from: data)
            let relevantIncidents = incidents.filter { incident in
                incident.isOpen
                    && incident.affectedProducts.contains { product in
                        ["Vertex Gemini API", "Gemini Code Assist", "Gemini Enterprise"].contains(product.title)
                    }
            }
            let health = relevantIncidents.map(\.health).worst ?? .operational
            let detail = relevantIncidents.first?.externalDescription ?? "No open Google Cloud incident found"

            return [
                CloudServiceStatusItem(
                    kind: .geminiAPI,
                    health: health,
                    detail: detail,
                    source: "Google Cloud Status"
                )
            ]
        } catch {
            return [
                unavailableItem(kind: .geminiAPI, source: "Google Cloud Status", error: error)
            ]
        }
    }

    private func antigravityItem(from geminiItem: CloudServiceStatusItem?) -> CloudServiceStatusItem {
        guard let geminiItem else {
            return CloudServiceStatusItem(
                kind: .antigravity,
                health: .unknown,
                detail: "Gemini service status unavailable",
                source: "Google Cloud Status"
            )
        }

        return CloudServiceStatusItem(
            kind: .antigravity,
            health: geminiItem.health,
            detail: "Using Gemini API status: \(geminiItem.detail)",
            source: geminiItem.source
        )
    }

    private func statusPageSummary(from url: URL) async throws -> StatusPageSummary {
        let data = try await dataLoader(url)
        return try JSONDecoder().decode(StatusPageSummary.self, from: data)
    }

    private func components(named names: Set<String>, in summary: StatusPageSummary) -> [StatusPageComponent] {
        summary.components.filter { names.contains($0.name) }
    }

    private func components(named names: [String], in summary: StatusPageSummary) -> [StatusPageComponent] {
        components(named: Set(names), in: summary)
    }

    private func item(
        kind: CloudServiceKind,
        source: String,
        components: [StatusPageComponent],
        fallback: StatusPageRollup
    ) -> CloudServiceStatusItem {
        let componentHealth = components.map { CloudServiceHealth(statusPageComponentStatus: $0.status) }
        let health = componentHealth.worst ?? CloudServiceHealth(statusPageIndicator: fallback.indicator)
        let detail: String

        if components.isEmpty {
            detail = fallback.description
        } else {
            detail = components
                .map { "\($0.name): \(CloudServiceHealth(statusPageComponentStatus: $0.status).title)" }
                .joined(separator: ", ")
        }

        return CloudServiceStatusItem(kind: kind, health: health, detail: detail, source: source)
    }

    private func unavailableItem(kind: CloudServiceKind, source: String, error: Error) -> CloudServiceStatusItem {
        CloudServiceStatusItem(
            kind: kind,
            health: .unknown,
            detail: "Status unavailable: \(error.localizedDescription)",
            source: source
        )
    }

    private static func liveData(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw CloudServiceStatusError.invalidHTTPStatus(httpResponse.statusCode)
        }

        return data
    }
}

enum CloudServiceStatusError: LocalizedError, Equatable {
    case invalidHTTPStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidHTTPStatus(let statusCode):
            return "Status request failed with HTTP \(statusCode)."
        }
    }
}

private struct StatusPageSummary: Decodable {
    let status: StatusPageRollup
    let components: [StatusPageComponent]
}

private struct StatusPageRollup: Decodable {
    let description: String
    let indicator: String
}

private struct StatusPageComponent: Decodable {
    let name: String
    let status: String
}

private struct GoogleCloudIncident: Decodable {
    let externalDescription: String
    let statusImpact: String?
    let severity: String?
    let end: String?
    let affectedProducts: [GoogleCloudAffectedProduct]

    private enum CodingKeys: String, CodingKey {
        case externalDescription = "external_desc"
        case statusImpact = "status_impact"
        case severity
        case end
        case affectedProducts = "affected_products"
    }

    var isOpen: Bool {
        end == nil
    }

    var health: CloudServiceHealth {
        let normalizedImpact = statusImpact?.lowercased() ?? ""
        let normalizedSeverity = severity?.lowercased() ?? ""

        if normalizedImpact.contains("outage") || normalizedSeverity == "high" {
            return .outage
        }

        if normalizedImpact.contains("disruption")
            || normalizedImpact.contains("information")
            || normalizedSeverity == "medium"
            || normalizedSeverity == "low" {
            return .degraded
        }

        return .unknown
    }
}

private struct GoogleCloudAffectedProduct: Decodable {
    let title: String
}

private extension CloudServiceHealth {
    init(statusPageIndicator: String) {
        switch statusPageIndicator {
        case "none":
            self = .operational
        case "minor":
            self = .degraded
        case "major", "critical":
            self = .outage
        default:
            self = .unknown
        }
    }

    init(statusPageComponentStatus: String) {
        switch statusPageComponentStatus {
        case "operational":
            self = .operational
        case "degraded_performance":
            self = .degraded
        case "partial_outage", "major_outage":
            self = .outage
        case "under_maintenance":
            self = .maintenance
        default:
            self = .unknown
        }
    }
}

private extension Array where Element == CloudServiceHealth {
    var worst: CloudServiceHealth? {
        sorted { lhs, rhs in
            lhs.severityRank > rhs.severityRank
        }
        .first
    }
}

private extension CloudServiceHealth {
    var severityRank: Int {
        switch self {
        case .outage:
            return 5
        case .degraded:
            return 4
        case .maintenance:
            return 3
        case .unknown:
            return 2
        case .operational:
            return 1
        }
    }
}
