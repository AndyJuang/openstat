// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenStat",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "OpenStatC",
            path: "Sources/OpenStatC",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "OpenStat",
            dependencies: ["OpenStatC"],
            path: "Sources/OpenStat"
        )
    ]
)
