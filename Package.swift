// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Spill",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Spill", targets: ["Spill"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.1")
    ],
    targets: [
        .executableTarget(
            name: "Spill",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks"
                ])
            ]
        ),
        .testTarget(name: "SpillTests", dependencies: ["Spill"])
    ]
)
