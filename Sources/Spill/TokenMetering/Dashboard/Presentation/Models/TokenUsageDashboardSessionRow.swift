import Foundation

struct TokenUsageDashboardSessionRow: Identifiable, Equatable {
    let id: String
    let runID: String
    let projectID: String
    let projectTitle: String
    let title: String
    let value: String
    let detail: String
    let eventCount: Int
}
