import Foundation
import Metal

struct SystemGPUDeviceStatus: Hashable, Sendable {
    let name: String
    let isLowPower: Bool
    let isHeadless: Bool
    let isRemovable: Bool
    let hasUnifiedMemory: Bool
    let recommendedMaxWorkingSetBytes: UInt64

    var memoryLabel: String? {
        guard recommendedMaxWorkingSetBytes > 0 else {
            return nil
        }

        return SystemMemoryProvider.formatBytes(recommendedMaxWorkingSetBytes)
    }
}

struct SystemGPUStatus: Hashable, Sendable {
    let value: String
    let subtitle: String?
    let devices: [SystemGPUDeviceStatus]
    let availableDeviceCount: Int
    let totalDeviceCount: Int
    let totalRecommendedMaxWorkingSetBytes: UInt64
    let state: SpillStatusState

    var statusItem: SpillStatusItem {
        SpillStatusItem(
            id: "gpu",
            providerID: SystemGPUProvider.providerID,
            title: "GPU",
            value: value,
            subtitle: subtitle,
            symbolName: "display",
            state: state,
            sortPriority: 12
        )
    }
}

struct SystemGPUProvider: SpillStatusProvider {
    static let providerID = SpillProviderID(rawValue: "system")

    let id = "system.gpu"
    let title = "GPU"

    func snapshot() async -> [SpillStatusItem] {
        [Self.status().statusItem]
    }

    static func status() -> SystemGPUStatus {
        status(from: MTLCopyAllDevices().map(deviceStatus))
    }

    static func status(from devices: [SystemGPUDeviceStatus]?) -> SystemGPUStatus {
        guard let devices, !devices.isEmpty else {
            return SystemGPUStatus(
                value: "N/A",
                subtitle: nil,
                devices: [],
                availableDeviceCount: 0,
                totalDeviceCount: 0,
                totalRecommendedMaxWorkingSetBytes: 0,
                state: .unavailable
            )
        }

        let usableDevices = devices.filter { !$0.isHeadless }
        let workingSetBytes = devices.reduce(UInt64(0)) {
            $0.saturatingAdd($1.recommendedMaxWorkingSetBytes)
        }
        let memorySubtitle = workingSetBytes > 0
            ? "\(SystemMemoryProvider.formatBytes(workingSetBytes)) recommended budget"
            : "\(usableDevices.count) usable device\(usableDevices.count == 1 ? "" : "s")"

        return SystemGPUStatus(
            value: "\(usableDevices.count)/\(devices.count)",
            subtitle: memorySubtitle,
            devices: devices,
            availableDeviceCount: usableDevices.count,
            totalDeviceCount: devices.count,
            totalRecommendedMaxWorkingSetBytes: workingSetBytes,
            state: usableDevices.isEmpty ? .warning : .normal
        )
    }

    private static func deviceStatus(from device: MTLDevice) -> SystemGPUDeviceStatus {
        SystemGPUDeviceStatus(
            name: device.name,
            isLowPower: device.isLowPower,
            isHeadless: device.isHeadless,
            isRemovable: device.isRemovable,
            hasUnifiedMemory: device.hasUnifiedMemory,
            recommendedMaxWorkingSetBytes: UInt64(device.recommendedMaxWorkingSetSize)
        )
    }
}

private extension UInt64 {
    func saturatingAdd(_ value: UInt64) -> UInt64 {
        let (result, overflow) = addingReportingOverflow(value)
        return overflow ? UInt64.max : result
    }
}
