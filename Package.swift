// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StyleSync",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .watchOS(.v9),
        .tvOS(.v16)
    ],
    products: [
        .library(
            name: "StyleSync",
            targets: ["StyleSync"]
        ),
    ],
    dependencies: [
        // Add any external dependencies here if needed
    ],
    targets: [
        .target(
            name: "StyleSync",
            dependencies: [],
            path: "StyleSync/Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "StyleSyncTests",
            dependencies: ["StyleSync"],
            path: "StyleSync/Tests"
        ),
    ]
)