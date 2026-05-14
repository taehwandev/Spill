import SwiftUI

@MainActor
final class SystemStatusStore: ObservableObject {
    typealias CPUReader = () async -> SystemCPUStatus
    typealias MemoryReader = () -> SystemMemoryStatus
    typealias PowerReader = () -> SystemPowerStatus

    @Published private(set) var cpu: SystemCPUStatus
    @Published private(set) var memory: SystemMemoryStatus
    @Published private(set) var power: SystemPowerStatus

    private let cpuReader: CPUReader
    private let memoryReader: MemoryReader
    private let powerReader: PowerReader

    init(
        cpu: SystemCPUStatus = SystemCPUProvider.status(previous: nil, current: nil),
        memory: SystemMemoryStatus = SystemMemoryProvider.status(from: nil),
        power: SystemPowerStatus = SystemPowerProvider.status(from: nil),
        cpuReader: @escaping CPUReader = { await SystemCPUProvider.status() },
        memoryReader: @escaping MemoryReader = { SystemMemoryProvider.status() },
        powerReader: @escaping PowerReader = { SystemPowerProvider.status() }
    ) {
        self.cpu = cpu
        self.memory = memory
        self.power = power
        self.cpuReader = cpuReader
        self.memoryReader = memoryReader
        self.powerReader = powerReader
    }

    func refresh(
        enabledModules: Set<SpillStatusModule> = SpillStatusModule.defaultEnabled,
        readsPower: Bool = true
    ) async {
        if enabledModules.contains(.memory) {
            memory = memoryReader()
        } else {
            memory = SystemMemoryProvider.status(from: nil)
        }

        if readsPower {
            power = powerReader()
        } else {
            power = SystemPowerProvider.status(from: nil)
        }

        if enabledModules.contains(.cpu) {
            cpu = await cpuReader()
        } else {
            cpu = SystemCPUProvider.status(previous: nil, current: nil)
        }
    }
}
