import Foundation

enum SpillStatusDetailTarget: Equatable {
    case system(SpillStatusModule)
    case ai(LocalAIToolKind)
}

struct SpillStatusDetailRow: Identifiable, Equatable {
    let label: String
    let value: String

    var id: String {
        label
    }
}

enum SpillStatusDetailRows {
    static func rows(for status: SystemCPUStatus) -> [SpillStatusDetailRow] {
        var rows = [
            SpillStatusDetailRow(label: "Usage", value: status.value),
            SpillStatusDetailRow(label: "Available", value: percentText(status.availableRatio)),
            SpillStatusDetailRow(label: "User", value: percentText(status.userRatio)),
            SpillStatusDetailRow(label: "System", value: percentText(status.systemRatio)),
            SpillStatusDetailRow(label: "Nice", value: percentText(status.niceRatio)),
            SpillStatusDetailRow(label: "Idle", value: percentText(status.idleRatio))
        ]

        if status.coreCount > 0 {
            rows.append(SpillStatusDetailRow(label: "Cores", value: "\(status.coreCount)"))
            rows.append(SpillStatusDetailRow(label: "Peak Core", value: percentText(status.peakCoreUsageRatio)))
        }

        rows.append(contentsOf: [
            SpillStatusDetailRow(label: "Sample", value: "\(status.activeTicks) / \(status.totalTicks) active ticks"),
            SpillStatusDetailRow(label: "State", value: status.state.detailTitle)
        ])

        return rows
    }

    static func rows(for status: SystemMemoryStatus) -> [SpillStatusDetailRow] {
        [
            SpillStatusDetailRow(label: "Usage", value: status.value),
            SpillStatusDetailRow(label: "Used", value: SystemMemoryProvider.formatBytes(status.usedBytes)),
            SpillStatusDetailRow(label: "Available", value: SystemMemoryProvider.formatBytes(status.availableBytes)),
            SpillStatusDetailRow(label: "Free", value: SystemMemoryProvider.formatBytes(status.freeBytes)),
            SpillStatusDetailRow(label: "Active", value: SystemMemoryProvider.formatBytes(status.activeBytes)),
            SpillStatusDetailRow(label: "Inactive", value: SystemMemoryProvider.formatBytes(status.inactiveBytes)),
            SpillStatusDetailRow(label: "Wired", value: SystemMemoryProvider.formatBytes(status.wiredBytes)),
            SpillStatusDetailRow(label: "Compressed", value: SystemMemoryProvider.formatBytes(status.compressedBytes)),
            SpillStatusDetailRow(label: "Total", value: SystemMemoryProvider.formatBytes(status.totalBytes))
        ]
    }

    static func rows(for status: SystemStorageStatus) -> [SpillStatusDetailRow] {
        [
            SpillStatusDetailRow(label: "Usage", value: status.value),
            SpillStatusDetailRow(label: "Used", value: SystemMemoryProvider.formatBytes(status.usedBytes)),
            SpillStatusDetailRow(label: "Available", value: SystemMemoryProvider.formatBytes(status.availableBytes)),
            SpillStatusDetailRow(label: "Total", value: SystemMemoryProvider.formatBytes(status.totalBytes)),
            SpillStatusDetailRow(label: "State", value: status.state.detailTitle)
        ]
    }

    static func rows(for status: SystemGPUStatus) -> [SpillStatusDetailRow] {
        let unifiedCount = status.devices.filter(\.hasUnifiedMemory).count
        let lowPowerCount = status.devices.filter(\.isLowPower).count
        let headlessCount = status.devices.filter(\.isHeadless).count
        var rows = [
            SpillStatusDetailRow(label: "Available", value: "\(status.availableDeviceCount) / \(status.totalDeviceCount)"),
            SpillStatusDetailRow(label: "Budget", value: status.totalRecommendedMaxWorkingSetBytes > 0 ? SystemMemoryProvider.formatBytes(status.totalRecommendedMaxWorkingSetBytes) : "N/A"),
            SpillStatusDetailRow(label: "Unified", value: "\(unifiedCount)"),
            SpillStatusDetailRow(label: "Low Power", value: "\(lowPowerCount)"),
            SpillStatusDetailRow(label: "Headless", value: "\(headlessCount)")
        ]

        rows.append(contentsOf: status.devices.prefix(3).map { device in
            let traits = [
                device.hasUnifiedMemory ? "Unified" : nil,
                device.isLowPower ? "Low Power" : nil,
                device.isRemovable ? "Removable" : nil,
                device.isHeadless ? "Headless" : nil
            ].compactMap { $0 }
            let suffix = traits.isEmpty ? "" : " - \(traits.joined(separator: ", "))"
            return SpillStatusDetailRow(
                label: device.name,
                value: "\(device.memoryLabel ?? "N/A")\(suffix)"
            )
        })

        return rows
    }

    static func rows(for status: SystemNetworkStatus) -> [SpillStatusDetailRow] {
        [
            SpillStatusDetailRow(label: "Receive", value: SystemNetworkProvider.formatRate(status.receivedBytesPerSecond)),
            SpillStatusDetailRow(label: "Upload", value: SystemNetworkProvider.formatRate(status.sentBytesPerSecond)),
            SpillStatusDetailRow(label: "Total", value: SystemNetworkProvider.formatRate(status.totalBytesPerSecond)),
            SpillStatusDetailRow(label: "Interfaces", value: "\(status.activeInterfaceCount)"),
            SpillStatusDetailRow(label: "Sample", value: status.sampleInterval > 0 ? String(format: "%.1fs", status.sampleInterval) : "Sampling"),
            SpillStatusDetailRow(label: "Received Total", value: SystemNetworkProvider.formatBytes(status.totalReceivedBytes)),
            SpillStatusDetailRow(label: "Uploaded Total", value: SystemNetworkProvider.formatBytes(status.totalSentBytes))
        ]
    }

    static func rows(for status: LocalAIToolStatus) -> [SpillStatusDetailRow] {
        var rows = [
            SpillStatusDetailRow(label: "Status", value: status.value),
            SpillStatusDetailRow(label: "Detail", value: status.subtitle ?? "N/A")
        ]

        if let model = status.metadata.model, !model.isEmpty {
            rows.append(SpillStatusDetailRow(label: "Model", value: model))
        }

        if let version = status.metadata.version, !version.isEmpty {
            rows.append(SpillStatusDetailRow(label: "Version", value: version))
        }

        if let source = status.metadata.source, !source.isEmpty {
            rows.append(SpillStatusDetailRow(label: "Source", value: source))
        }

        if let serverStatus = status.metadata.serverStatus {
            rows.append(SpillStatusDetailRow(label: "Server", value: serverStatus.state.title))
            rows.append(SpillStatusDetailRow(label: "Check", value: serverStatus.source))

            if !serverStatus.detail.isEmpty {
                rows.append(SpillStatusDetailRow(label: "Evidence", value: serverStatus.detail))
            }
        }

        return rows
    }

    private static func boolText(_ value: Bool) -> String {
        value ? "Yes" : "No"
    }

    private static func percentText(_ ratio: Double) -> String {
        SystemCPUProvider.percentText(ratio)
    }
}

extension SpillStatusState {
    var detailTitle: String {
        switch self {
        case .normal:
            return "Normal"
        case .active:
            return "Active"
        case .warning:
            return "Warning"
        case .unavailable:
            return "Unavailable"
        case .refreshing:
            return "Refreshing"
        }
    }
}
