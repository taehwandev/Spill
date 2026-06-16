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
            SpillStatusDetailRow(label: AppL10n.text(.usage), value: status.value),
            SpillStatusDetailRow(label: AppL10n.text(.available), value: percentText(status.availableRatio)),
            SpillStatusDetailRow(label: AppL10n.text(.user), value: percentText(status.userRatio)),
            SpillStatusDetailRow(label: AppL10n.text(.system), value: percentText(status.systemRatio)),
            SpillStatusDetailRow(label: AppL10n.text(.nice), value: percentText(status.niceRatio)),
            SpillStatusDetailRow(label: AppL10n.text(.idleLabel), value: percentText(status.idleRatio))
        ]

        if status.coreCount > 0 {
            rows.append(SpillStatusDetailRow(label: AppL10n.text(.cores), value: "\(status.coreCount)"))
            rows.append(SpillStatusDetailRow(label: AppL10n.text(.peakCore), value: percentText(status.peakCoreUsageRatio)))
        }

        rows.append(contentsOf: [
            SpillStatusDetailRow(label: AppL10n.text(.sample), value: "\(status.activeTicks) / \(status.totalTicks) active ticks"),
            SpillStatusDetailRow(label: AppL10n.text(.state), value: status.state.detailTitle)
        ])

        return rows
    }

    static func rows(for status: SystemMemoryStatus) -> [SpillStatusDetailRow] {
        [
            SpillStatusDetailRow(label: AppL10n.text(.usage), value: status.value),
            SpillStatusDetailRow(label: AppL10n.text(.used), value: SystemMemoryProvider.formatBytes(status.usedBytes)),
            SpillStatusDetailRow(label: AppL10n.text(.available), value: SystemMemoryProvider.formatBytes(status.availableBytes)),
            SpillStatusDetailRow(label: AppL10n.text(.free), value: SystemMemoryProvider.formatBytes(status.freeBytes)),
            SpillStatusDetailRow(label: AppL10n.text(.active), value: SystemMemoryProvider.formatBytes(status.activeBytes)),
            SpillStatusDetailRow(label: AppL10n.text(.inactive), value: SystemMemoryProvider.formatBytes(status.inactiveBytes)),
            SpillStatusDetailRow(label: AppL10n.text(.wired), value: SystemMemoryProvider.formatBytes(status.wiredBytes)),
            SpillStatusDetailRow(label: AppL10n.text(.compressed), value: SystemMemoryProvider.formatBytes(status.compressedBytes)),
            SpillStatusDetailRow(label: AppL10n.text(.total), value: SystemMemoryProvider.formatBytes(status.totalBytes))
        ]
    }

    static func rows(for status: SystemStorageStatus) -> [SpillStatusDetailRow] {
        [
            SpillStatusDetailRow(label: AppL10n.text(.usage), value: status.value),
            SpillStatusDetailRow(label: AppL10n.text(.used), value: SystemMemoryProvider.formatBytes(status.usedBytes)),
            SpillStatusDetailRow(label: AppL10n.text(.available), value: SystemMemoryProvider.formatBytes(status.availableBytes)),
            SpillStatusDetailRow(label: AppL10n.text(.total), value: SystemMemoryProvider.formatBytes(status.totalBytes)),
            SpillStatusDetailRow(label: AppL10n.text(.state), value: status.state.detailTitle)
        ]
    }

    static func rows(for status: SystemGPUStatus) -> [SpillStatusDetailRow] {
        let unifiedCount = status.devices.filter(\.hasUnifiedMemory).count
        let lowPowerCount = status.devices.filter(\.isLowPower).count
        let headlessCount = status.devices.filter(\.isHeadless).count
        var rows = [
            SpillStatusDetailRow(label: AppL10n.text(.available), value: "\(status.availableDeviceCount) / \(status.totalDeviceCount)"),
            SpillStatusDetailRow(label: AppL10n.text(.budget), value: status.totalRecommendedMaxWorkingSetBytes > 0 ? SystemMemoryProvider.formatBytes(status.totalRecommendedMaxWorkingSetBytes) : "N/A"),
            SpillStatusDetailRow(label: AppL10n.text(.unified), value: "\(unifiedCount)"),
            SpillStatusDetailRow(label: AppL10n.text(.lowPower), value: "\(lowPowerCount)"),
            SpillStatusDetailRow(label: AppL10n.text(.headless), value: "\(headlessCount)")
        ]

        rows.append(contentsOf: status.devices.prefix(3).map { device in
            let traits = [
                device.hasUnifiedMemory ? AppL10n.text(.unified) : nil,
                device.isLowPower ? AppL10n.text(.lowPower) : nil,
                device.isRemovable ? AppL10n.text(.removable) : nil,
                device.isHeadless ? AppL10n.text(.headless) : nil
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
            SpillStatusDetailRow(label: AppL10n.text(.receive), value: SystemNetworkProvider.formatRate(status.receivedBytesPerSecond)),
            SpillStatusDetailRow(label: AppL10n.text(.upload), value: SystemNetworkProvider.formatRate(status.sentBytesPerSecond)),
            SpillStatusDetailRow(label: AppL10n.text(.total), value: SystemNetworkProvider.formatRate(status.totalBytesPerSecond)),
            SpillStatusDetailRow(label: AppL10n.text(.interfaces), value: "\(status.activeInterfaceCount)"),
            SpillStatusDetailRow(label: AppL10n.text(.sample), value: status.sampleInterval > 0 ? String(format: "%.1fs", status.sampleInterval) : AppL10n.text(.scanning)),
            SpillStatusDetailRow(label: AppL10n.text(.receivedTotal), value: SystemNetworkProvider.formatBytes(status.totalReceivedBytes)),
            SpillStatusDetailRow(label: AppL10n.text(.uploadedTotal), value: SystemNetworkProvider.formatBytes(status.totalSentBytes))
        ]
    }

    static func rows(for status: LocalAIToolStatus) -> [SpillStatusDetailRow] {
        var rows = [
            SpillStatusDetailRow(label: AppL10n.text(.status), value: status.value),
            SpillStatusDetailRow(label: AppL10n.text(.detail), value: status.subtitle ?? "N/A")
        ]

        rows.append(contentsOf: processRows(for: status.processSummary))

        if let recommendation = status.actionRecommendation {
            rows.append(SpillStatusDetailRow(label: AppL10n.text(.next), value: recommendation.title))
        }

        if let model = status.metadata.model, !model.isEmpty {
            rows.append(SpillStatusDetailRow(label: AppL10n.text(.model), value: model))
        }

        if let version = status.metadata.version, !version.isEmpty {
            rows.append(SpillStatusDetailRow(label: AppL10n.text(.version), value: version))
        }

        if let source = status.metadata.source, !source.isEmpty {
            rows.append(SpillStatusDetailRow(label: AppL10n.text(.source), value: source))
        }

        return rows
    }

    private static func processRows(for summary: LocalAIProcessSummary) -> [SpillStatusDetailRow] {
        var rows = [
            SpillStatusDetailRow(label: AppL10n.text(.processes), value: "\(summary.processCount)")
        ]

        guard summary.isRunning else {
            return rows
        }

        rows.append(contentsOf: [
            SpillStatusDetailRow(label: AppL10n.text(.cpu), value: summary.cpuPercentText),
            SpillStatusDetailRow(label: AppL10n.text(.memory), value: SystemMemoryProvider.formatBytes(summary.memoryBytes))
        ])

        rows.append(contentsOf: summary.processes.prefix(4).map { process in
            SpillStatusDetailRow(
                label: "\(AppL10n.text(.process)) \(process.processID)",
                value: [
                    process.executableName,
                    "CPU \(LocalAIProcessSummary.formatCPUPercent(process.cpuPercent))",
                    SystemMemoryProvider.formatBytes(process.memoryBytes)
                ].joined(separator: " / ")
            )
        })

        return rows
    }

    private static func boolText(_ value: Bool) -> String {
        value ? AppL10n.text(.yes) : AppL10n.text(.no)
    }

    private static func percentText(_ ratio: Double) -> String {
        SystemCPUProvider.percentText(ratio)
    }
}

extension SpillStatusState {
    var detailTitle: String {
        switch self {
        case .normal:
            return AppL10n.text(.normal)
        case .active:
            return AppL10n.text(.active)
        case .warning:
            return AppL10n.text(.warning)
        case .unavailable:
            return AppL10n.text(.unavailable)
        case .refreshing:
            return AppL10n.text(.refreshingActions)
        }
    }
}
