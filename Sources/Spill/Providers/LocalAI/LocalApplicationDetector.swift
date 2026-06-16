import Foundation

enum LocalApplicationDetector {
    static func installedApplicationNames(for kinds: [LocalAIToolKind]) -> Set<String> {
        let applicationNames = kinds.flatMap(\.applicationNames)
        guard !applicationNames.isEmpty else {
            return []
        }

        let fileManager = FileManager.default
        let directories = [
            "/Applications",
            "\(NSHomeDirectory())/Applications"
        ]
        var installedNames = Set<String>()

        for applicationName in applicationNames {
            let appBundleName = "\(applicationName).app"
            let isInstalled = directories.contains { directory in
                fileManager.fileExists(atPath: "\(directory)/\(appBundleName)")
            }

            if isInstalled {
                installedNames.insert(applicationName)
            }
        }

        return installedNames
    }
}
