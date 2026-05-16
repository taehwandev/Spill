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
            return unavailableStatus()
        }

        return status(from: reading, routeState: routeState(for: reading))
    }

    private static func status(
        from reading: SystemNetworkReading,
        routeState: SystemNetworkRouteState
    ) -> SystemNetworkStatus {
        SystemNetworkStatus(
            value: routeState.value,
            subtitle: routeState.subtitle,
            availabilityRatio: routeState.availabilityRatio,
            state: routeState.state,
            symbolName: "network",
            isAvailable: routeState.isAvailable,
            isReachable: reading.isReachable,
            connectionRequired: reading.connectionRequired,
            canConnectAutomatically: reading.canConnectAutomatically,
            interventionRequired: reading.interventionRequired
        )
    }

    private static func routeState(for reading: SystemNetworkReading) -> SystemNetworkRouteState {
        if reading.hasUsableRoute {
            return .online
        }

        if reading.isReachable && reading.connectionRequired {
            return .standby
        }

        return .offline
    }

    private static func unavailableStatus() -> SystemNetworkStatus {
        SystemNetworkStatus(
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
}

private enum SystemNetworkRouteState {
    case online
    case standby
    case offline

    var value: String {
        switch self {
        case .online:
            return "Online"
        case .standby:
            return "Standby"
        case .offline:
            return "Offline"
        }
    }

    var subtitle: String {
        switch self {
        case .online:
            return "Default Route"
        case .standby:
            return "Connection Required"
        case .offline:
            return "No Route"
        }
    }

    var availabilityRatio: Double {
        switch self {
        case .online:
            return 1
        case .standby:
            return 0.5
        case .offline:
            return 0
        }
    }

    var state: SpillStatusState {
        switch self {
        case .online:
            return .normal
        case .standby:
            return .active
        case .offline:
            return .warning
        }
    }

    var isAvailable: Bool {
        self == .online
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
