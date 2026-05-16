import SwiftUI

@MainActor
final class SystemStatusStore: ObservableObject {
    typealias CPUReader = () async -> SystemCPUStatus
    typealias MemoryReader = () -> SystemMemoryStatus
    typealias GPUReader = () -> SystemGPUStatus
    typealias NetworkReader = () -> SystemNetworkStatus
    typealias PowerReader = () -> SystemPowerStatus

    @Published private(set) var cpu: SystemCPUStatus
    @Published private(set) var memory: SystemMemoryStatus
    @Published private(set) var gpu: SystemGPUStatus
    @Published private(set) var network: SystemNetworkStatus
    @Published private(set) var power: SystemPowerStatus

    private let cpuReader: CPUReader
    private let memoryReader: MemoryReader
    private let gpuReader: GPUReader
    private let networkReader: NetworkReader
    private let powerReader: PowerReader

    init(
        cpu: SystemCPUStatus = SystemCPUProvider.status(previous: nil, current: nil),
        memory: SystemMemoryStatus = SystemMemoryProvider.status(from: nil),
        gpu: SystemGPUStatus = SystemGPUProvider.status(from: nil),
        network: SystemNetworkStatus = SystemNetworkProvider.status(from: nil),
        power: SystemPowerStatus = SystemPowerProvider.status(from: nil),
        cpuReader: @escaping CPUReader = { await SystemCPUProvider.status() },
        memoryReader: @escaping MemoryReader = { SystemMemoryProvider.status() },
        gpuReader: @escaping GPUReader = { SystemGPUProvider.status() },
        networkReader: @escaping NetworkReader = { SystemNetworkProvider.status() },
        powerReader: @escaping PowerReader = { SystemPowerProvider.status() }
    ) {
        self.cpu = cpu
        self.memory = memory
        self.gpu = gpu
        self.network = network
        self.power = power
        self.cpuReader = cpuReader
        self.memoryReader = memoryReader
        self.gpuReader = gpuReader
        self.networkReader = networkReader
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

        if enabledModules.contains(.network) {
            network = networkReader()
        } else {
            network = SystemNetworkProvider.status(from: nil)
        }

        if enabledModules.contains(.gpu) {
            gpu = gpuReader()
        } else {
            gpu = SystemGPUProvider.status(from: nil)
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
