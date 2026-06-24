import Foundation

struct LocalAIProcessMetricSample: Hashable, Sendable {
    let processID: Int
    let timestamp: Date
    let cpuTimeNanoseconds: UInt64
    let processStartTimeNanoseconds: UInt64?
}
