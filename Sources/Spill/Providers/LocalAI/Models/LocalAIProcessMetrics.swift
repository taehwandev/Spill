import Foundation

struct LocalAIProcessMetrics: Hashable, Sendable {
    let cpuPercent: Double
    let memoryBytes: UInt64
}
