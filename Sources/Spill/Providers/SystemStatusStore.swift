import SwiftUI

@MainActor
final class SystemStatusStore: ObservableObject {
    typealias MemoryReader = () -> SystemMemoryStatus
    typealias PowerReader = () -> SystemPowerStatus

    @Published private(set) var memory: SystemMemoryStatus
    @Published private(set) var power: SystemPowerStatus

    private let memoryReader: MemoryReader
    private let powerReader: PowerReader

    init(
        memory: SystemMemoryStatus = SystemMemoryProvider.status(from: nil),
        power: SystemPowerStatus = SystemPowerProvider.status(from: nil),
        memoryReader: @escaping MemoryReader = { SystemMemoryProvider.status() },
        powerReader: @escaping PowerReader = { SystemPowerProvider.status() }
    ) {
        self.memory = memory
        self.power = power
        self.memoryReader = memoryReader
        self.powerReader = powerReader
    }

    func refresh() {
        memory = memoryReader()
        power = powerReader()
    }
}
