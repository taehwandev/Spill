import Foundation

struct TokenUsageDashboardWorkItemKey: Hashable {
    let projectID: String
    let taskType: TokenUsageTaskType
    let stage: TokenUsageStage
    let dayBucket: String

    var id: String {
        [
            "work",
            projectID,
            taskType.rawValue,
            stage.rawValue,
            dayBucket
        ]
            .map(Self.safeIDPart)
            .joined(separator: "_")
    }

    private static func safeIDPart(_ value: String) -> String {
        let scalars = value.lowercased().unicodeScalars.map { scalar -> String in
            CharacterSet.alphanumerics.contains(scalar) ? String(scalar) : "_"
        }
        return scalars.joined()
            .split(separator: "_")
            .joined(separator: "_")
    }
}
