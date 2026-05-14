import Foundation
import IOKit.ps

struct SystemPowerReading: Hashable, Sendable {
    let currentCapacity: Int?
    let maxCapacity: Int?
    let isCharging: Bool
    let isACPowered: Bool
    let hasBattery: Bool
}

struct SystemPowerStatus: Hashable, Sendable {
    let value: String
    let subtitle: String?
    let chargeRatio: Double
    let state: SpillStatusState
    let symbolName: String
    let hasBattery: Bool
    let isCharging: Bool
    let isACPowered: Bool

    var statusItem: SpillStatusItem {
        SpillStatusItem(
            id: "power",
            providerID: SystemPowerProvider.providerID,
            title: "Power",
            value: value,
            subtitle: subtitle,
            symbolName: symbolName,
            state: state,
            sortPriority: 20
        )
    }
}

struct SystemPowerProvider: SpillStatusProvider {
    static let providerID = SpillProviderID(rawValue: "system")

    let id = "system.power"
    let title = "Power"

    func snapshot() async -> [SpillStatusItem] {
        [Self.status().statusItem]
    }

    static func status() -> SystemPowerStatus {
        status(from: SystemPowerReader.current())
    }

    static func status(from reading: SystemPowerReading?) -> SystemPowerStatus {
        guard let reading else {
            return unavailableStatus()
        }

        guard reading.hasBattery else {
            if reading.isACPowered {
                return SystemPowerStatus(
                    value: "AC",
                    subtitle: "External Power",
                    chargeRatio: 1,
                    state: .normal,
                    symbolName: "powerplug.fill",
                    hasBattery: false,
                    isCharging: false,
                    isACPowered: true
                )
            }

            return unavailableStatus()
        }

        guard let currentCapacity = reading.currentCapacity,
              let maxCapacity = reading.maxCapacity,
              maxCapacity > 0
        else {
            return unavailableStatus()
        }

        let ratio = (Double(currentCapacity) / Double(maxCapacity)).clamped(to: 0...1)
        let value = "\(Int((ratio * 100).rounded()))%"
        let subtitle = subtitle(for: reading)

        return SystemPowerStatus(
            value: value,
            subtitle: subtitle,
            chargeRatio: ratio,
            state: state(for: ratio, isCharging: reading.isCharging, isACPowered: reading.isACPowered),
            symbolName: symbolName(for: ratio, isCharging: reading.isCharging),
            hasBattery: true,
            isCharging: reading.isCharging,
            isACPowered: reading.isACPowered
        )
    }

    private static func subtitle(for reading: SystemPowerReading) -> String {
        if reading.isCharging {
            return "Charging"
        }

        if reading.isACPowered {
            return "On Power"
        }

        return "On Battery"
    }

    private static func state(
        for chargeRatio: Double,
        isCharging: Bool,
        isACPowered: Bool
    ) -> SpillStatusState {
        if isCharging {
            return .active
        }

        if !isACPowered && chargeRatio <= 0.2 {
            return .warning
        }

        return .normal
    }

    private static func symbolName(for chargeRatio: Double, isCharging: Bool) -> String {
        if isCharging {
            return "bolt.fill"
        }

        if chargeRatio <= 0.2 {
            return "battery.25"
        }

        return "battery.100"
    }

    private static func unavailableStatus() -> SystemPowerStatus {
        SystemPowerStatus(
            value: "N/A",
            subtitle: nil,
            chargeRatio: 0,
            state: .unavailable,
            symbolName: "powerplug",
            hasBattery: false,
            isCharging: false,
            isACPowered: false
        )
    }
}

private enum SystemPowerReader {
    static func current() -> SystemPowerReading? {
        guard let snapshotSource = IOPSCopyPowerSourcesInfo() else {
            return nil
        }

        let snapshot = snapshotSource.takeRetainedValue()
        let providingPowerSource = powerSourceType(from: snapshot)
        let isACPowered = providingPowerSource == (kIOPSACPowerValue as String)

        guard let sourceList = IOPSCopyPowerSourcesList(snapshot) else {
            return SystemPowerReading(
                currentCapacity: nil,
                maxCapacity: nil,
                isCharging: false,
                isACPowered: isACPowered,
                hasBattery: false
            )
        }

        let sources = sourceList.takeRetainedValue() as NSArray

        for source in sources {
            let powerSource = source as CFTypeRef

            guard let descriptionSource = IOPSGetPowerSourceDescription(snapshot, powerSource),
                  let description = descriptionSource.takeUnretainedValue() as? [String: Any]
            else {
                continue
            }

            guard let currentCapacity = description[kIOPSCurrentCapacityKey as String] as? Int,
                  let maxCapacity = description[kIOPSMaxCapacityKey as String] as? Int
            else {
                continue
            }

            let powerSourceState = description[kIOPSPowerSourceStateKey as String] as? String
            let sourceIsACPowered = powerSourceState == (kIOPSACPowerValue as String) || isACPowered

            return SystemPowerReading(
                currentCapacity: currentCapacity,
                maxCapacity: maxCapacity,
                isCharging: (description[kIOPSIsChargingKey as String] as? Bool) == true,
                isACPowered: sourceIsACPowered,
                hasBattery: true
            )
        }

        return SystemPowerReading(
            currentCapacity: nil,
            maxCapacity: nil,
            isCharging: false,
            isACPowered: isACPowered,
            hasBattery: false
        )
    }

    private static func powerSourceType(from snapshot: CFTypeRef) -> String? {
        guard let typeSource = IOPSGetProvidingPowerSourceType(snapshot) else {
            return nil
        }

        return typeSource.takeUnretainedValue() as String
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
