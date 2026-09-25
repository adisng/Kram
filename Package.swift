// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KRAM",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "kram", targets: ["KRAM"]),
        .library(name: "KRAMCore", targets: ["KRAMCore"]),
    ],
    targets: [
        .executableTarget(
            name: "KRAM",
            dependencies: ["KRAMCore"],
            path: "Sources/KRAM"
        ),
        .target(
            name: "KRAMCore",
            dependencies: [],
            path: "Sources/KRAMCore"
        ),
        .testTarget(
            name: "KRAMCoreTests",
            dependencies: ["KRAMCore"],
            path: "Tests/KRAMCoreTests"
        ),
    ]
)
