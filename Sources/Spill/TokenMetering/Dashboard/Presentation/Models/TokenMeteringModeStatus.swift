import Foundation

struct TokenMeteringModeStatus: Identifiable, Equatable {
    let id: String
    let title: String
    let state: String
    let detail: String
    let isActive: Bool
}
