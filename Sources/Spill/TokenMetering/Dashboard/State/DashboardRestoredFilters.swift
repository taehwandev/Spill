import Foundation

struct DashboardRestoredFilters: Codable, Equatable {
    var tool: String?
    var period: String
    var offset: Int
    var day: String?
    var project: String?
    var session: String?
    var month: Date?
}
