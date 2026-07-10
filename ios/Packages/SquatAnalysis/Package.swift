// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SquatAnalysis",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SquatAnalysis",
            targets: ["SquatAnalysis"]
        )
    ],
    dependencies: [
        .package(path: "../PoseCore")
    ],
    targets: [
        .target(
            name: "SquatAnalysis",
            dependencies: ["PoseCore"]
        ),
        .testTarget(
            name: "SquatAnalysisTests",
            dependencies: ["SquatAnalysis"]
        )
    ]
)
