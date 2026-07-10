// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TrainerCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "TrainerCore",
            targets: ["TrainerCore"]
        )
    ],
    targets: [
        .target(name: "TrainerCore"),
        .testTarget(
            name: "TrainerCoreTests",
            dependencies: ["TrainerCore"]
        )
    ]
)
