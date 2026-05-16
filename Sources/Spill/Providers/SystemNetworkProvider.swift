import Darwin
import Foundation
import SystemConfiguration

struct SystemNetworkReading: Hashable, Sendable {
    let isReachable: Bool
    let connectionRequired: Bool
    let canConnectAutomatically: Bool
    let interventionRequired: Bool

    var hasUsableRoute: Bool {
        isReachable && (!connectionRequired || (canConnectAutomatically && !interventionRequired))
    }
}

struct SystemNetworkStatus: Hashable, Sendable {
    let value: String
    let subtitle: String?
    let availabilityRatio: Double
    let state: SpillStatusState
    let symbolName: String
    let isAvailable: Bool
    let isReachable: Bool
    let connectionRequired: Bool
    let canConnectAutomatically: Bool
    let interventionRequired: Bool

    var statusItem: SpillStatusItem {
        SpillStatusItem(
            id: "network",
            providerID: SystemNetworkProvider.providerID,
            title: "Network",
            value: value,
            subtitle: subtitle,
            symbolName: symbolName,
            state: state,
            sortPriority: 15
        )
    }
}

struct SystemNetworkProvider: SpillStatusProvider {
    static let providerID = SpillProviderID(rawValue: "system")

    let id = "system.network"
    let title = "Network"

    func snapshot() async -> [SpillStatusItem] {
        [Self.status().statusItem]
    }

    static func status() -> SystemNetworkStatus {
        status(from: SystemNetworkReader.current())
    }

    static func status(from reading: SystemNetworkReading?) -> SystemNetworkStatus {
        guard let reading else {
            return SystemNetworkStatus(
                value: "N/A",
                subtitle: nil,
                availabilityRatio: 0,
                state: .unavailable,
                symbolName: "network",
                isAvailable: false,
                isReachable: false,
                connectionRequired: false,
                canConnectAutomatically: false,
                interventionRequired: false
            )
        }

        if reading.hasUsableRoute {
            return SystemNetworkStatus(
                value: "Online",
                subtitle: "Default Route",
                availabilityRatio: 1,
                state: .normal,
                symbolName: "network",
                isAvailable: true,
                isReachable: reading.isReachable,
                connectionRequired: reading.connectionRequired,
                canConnectAutomatically: reading.canConnectAutomatically,
                interventionRequired: reading.interventionRequired
            )
        }

        if reading.isReachable && reading.connectionRequired {
            return SystemNetworkStatus(
                value: "Standby",
                subtitle: "Connection Required",
                availabilityRatio: 0.5,
                state: .active,
                symbolName: "network",
                isAvailable: false,
                isReachable: reading.isReachable,
                connectionRequired: reading.connectionRequired,
                canConnectAutomatically: reading.canConnectAutomatically,
                interventionRequired: reading.interventionRequired
            )
        }

        return SystemNetworkStatus(
            value: "Offline",
            subtitle: "No Route",
            availabilityRatio: 0,
            state: .warning,
            symbolName: "network",
            isAvailable: false,
            isReachable: reading.isReachable,
            connectionRequired: reading.connectionRequired,
            canConnectAutomatically: reading.canConnectAutomatically,
            interventionRequired: reading.interventionRequired
        )
    }
}

private enum SystemNetworkReader {
    static func current() -> SystemNetworkReading? {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)

        guard let reachability = withUnsafePointer(to: &zeroAddress, { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                SCNetworkReachabilityCreateWithAddress(nil, sockaddrPointer)
            }
        }) else {
            return nil
        }

        var flags = SCNetworkReachabilityFlags()
        guard SCNetworkReachabilityGetFlags(reachability, &flags) else {
            return nil
        }

        let canConnectAutomatically = flags.contains(.connectionOnDemand)
            || flags.contains(.connectionOnTraffic)

        return SystemNetworkReading(
            isReachable: flags.contains(.reachable),
            connectionRequired: flags.contains(.connectionRequired),
            canConnectAutomatically: canConnectAutomatically,
            interventionRequired: flags.contains(.interventionRequired)
        )
    }
}
