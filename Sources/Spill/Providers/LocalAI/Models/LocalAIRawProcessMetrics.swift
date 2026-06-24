import Foundation

struct LocalAIRawProcessMetrics: Hashable, Sendable {
    let sample: LocalAIProcessMetricSample
    let memoryBytes: UInt64
}
