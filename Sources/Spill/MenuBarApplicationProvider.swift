import AppKit

struct MenuBarApplicationCandidate: Sendable {
    let processIdentifier: pid_t
    let ownerName: String
    let bundleIdentifier: String?
    let usesMenuBarFallback: Bool
}

struct MenuBarApplicationProvider {
    func candidates() -> [MenuBarApplicationCandidate] {
        NSWorkspace.shared.runningApplications
            .filter { !$0.isTerminated && $0.processIdentifier > 0 }
            .sorted { first, second in
                priority(for: first) < priority(for: second)
            }
            .map { application in
                MenuBarApplicationCandidate(
                    processIdentifier: application.processIdentifier,
                    ownerName: application.localizedName
                        ?? application.bundleIdentifier
                        ?? "PID \(application.processIdentifier)",
                    bundleIdentifier: application.bundleIdentifier,
                    usesMenuBarFallback: usesMenuBarFallback(for: application)
                )
            }
    }

    private func priority(for application: NSRunningApplication) -> Int {
        switch application.bundleIdentifier {
        case "com.apple.systemuiserver":
            return 0
        case "com.apple.controlcenter":
            return 1
        default:
            if application.activationPolicy == .accessory {
                return 2
            }

            return 3
        }
    }

    private func usesMenuBarFallback(for application: NSRunningApplication) -> Bool {
        priority(for: application) <= 1
            || application.activationPolicy == .accessory
            || application.activationPolicy == .prohibited
    }
}
