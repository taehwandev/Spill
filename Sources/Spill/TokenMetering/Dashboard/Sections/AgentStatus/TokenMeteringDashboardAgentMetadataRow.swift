import Foundation

struct TokenMeteringDashboardAgentMetadataRow: Identifiable, Equatable {
    let label: String
    let value: String

    var id: String {
        "\(label):\(value)"
    }
}
