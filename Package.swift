// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Spill",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Spill", targets: ["Spill"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.1"),
        .package(url: "https://github.com/getsentry/sentry-cocoa.git", from: "9.18.0")
    ],
    targets: [
        .executableTarget(
            name: "Spill",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "Sentry", package: "sentry-cocoa")
            ],
            resources: [
                .copy("Resources/adapters"),
                .process("Resources/Brand"),
                .process("Resources/Localization")
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .unsafeFlags([
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks"
                ])
            ]
        ),
        .testTarget(name: "SpillTests", dependencies: ["Spill"])
    ]
)
