// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacPrism",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "MacPrismC",
            path: "Sources/MacPrismC",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "MacPrism",
            dependencies: ["MacPrismC"],
            path: "Sources/MacPrism",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("Security")
            ]
        )
    ]
)
