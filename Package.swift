// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GPUMonitor",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .executable(
            name: "GPUMonitor",
            targets: ["GPUMonitor"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "GPUMonitor",
            dependencies: [],
            path: "Sources",
            resources: [
                .copy("../servers.json")
            ]
        )
    ]
)
