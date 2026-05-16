import Foundation

struct SpillStatusMeterSnapshot {
    let value: String
    let subtitle: String?
    let state: SpillStatusState
}

extension SystemStatusStore {
    func meterSnapshot(for module: SpillStatusModule) -> SpillStatusMeterSnapshot {
        switch module {
        case .cpu:
            return SpillStatusMeterSnapshot(value: cpu.value, subtitle: cpu.subtitle, state: cpu.state)
        case .memory:
            return SpillStatusMeterSnapshot(value: memory.value, subtitle: memory.subtitle, state: memory.state)
        case .gpu:
            return SpillStatusMeterSnapshot(value: gpu.value, subtitle: gpu.subtitle, state: gpu.state)
        case .network:
            return SpillStatusMeterSnapshot(value: network.value, subtitle: network.subtitle, state: network.state)
        }
    }

    func state(for module: SpillStatusModule) -> SpillStatusState {
        meterSnapshot(for: module).state
    }

    func detailRows(for module: SpillStatusModule) -> [SpillStatusDetailRow] {
        switch module {
        case .cpu:
            return SpillStatusDetailRows.rows(for: cpu)
        case .memory:
            return SpillStatusDetailRows.rows(for: memory)
        case .gpu:
            return SpillStatusDetailRows.rows(for: gpu)
        case .network:
            return SpillStatusDetailRows.rows(for: network)
        }
    }
}
