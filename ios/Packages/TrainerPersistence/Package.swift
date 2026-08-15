// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TrainerPersistence",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "TrainerPersistence",
            targets: ["TrainerPersistence"]
        )
    ],
    dependencies: [
        .package(path: "../TrainerCore")
    ],
    targets: [
        .target(
            name: "TrainerPersistence",
            dependencies: ["TrainerCore"]
        ),
        .testTarget(
            name: "TrainerPersistenceTests",
            dependencies: ["TrainerPersistence", "TrainerCore"]
        )
    ]
)
