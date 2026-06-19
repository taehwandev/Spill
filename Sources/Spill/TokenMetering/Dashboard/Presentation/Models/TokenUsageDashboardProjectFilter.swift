import Foundation

struct TokenUsageDashboardProjectFilter: Identifiable, Equatable {
    let projectID: String?
    let title: String
    let detail: String
    let isSelected: Bool

    var id: String {
        projectID ?? "all"
    }
}
