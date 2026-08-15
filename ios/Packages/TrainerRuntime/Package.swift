// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TrainerRuntime",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "TrainerRuntime",
            targets: ["TrainerRuntime"]
        )
    ],
    dependencies: [
        .package(path: "../PoseCore"),
        .package(path: "../SquatAnalysis"),
        .package(path: "../TrainerCore")
    ],
    targets: [
        .target(
            name: "TrainerRuntime",
            dependencies: ["PoseCore", "SquatAnalysis", "TrainerCore"]
        ),
        .testTarget(
            name: "TrainerRuntimeTests",
            dependencies: [
                "TrainerRuntime",
                "PoseCore",
                "SquatAnalysis",
                "TrainerCore"
            ]
        )
    ]
)
