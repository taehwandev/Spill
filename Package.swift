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
    targets: [
        .executableTarget(name: "Spill")
    ]
)
