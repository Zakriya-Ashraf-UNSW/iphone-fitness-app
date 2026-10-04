// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SharedWorkoutModels",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "SharedWorkoutModels",
            targets: ["SharedWorkoutModels"]
        ),
    ],
    targets: [
        .target(
            name: "SharedWorkoutModels",
            path: "Sources",
            resources: [
                .process("default_exercises.json")
            ]
        ),
    ]
)
