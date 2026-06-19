import Foundation
import SystemConfiguration

enum PrivateUsageDeviceName {
    static func current(
        copyComputerName: () -> String? = {
            SCDynamicStoreCopyComputerName(nil, nil) as String?
        },
        fallbackHostName: String? = Host.current().localizedName
    ) -> String? {
        sanitize(copyComputerName()) ?? sanitize(fallbackHostName)
    }

    private static func sanitize(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 80 else {
            return nil
        }

        guard trimmed.rangeOfCharacter(from: .controlCharacters) == nil else {
            return nil
        }

        return trimmed
    }
}
