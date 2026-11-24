// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TrainingsCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TrainingsCore", targets: ["TrainingsCore"])
    ],
    targets: [
        .target(name: "TrainingsCore"),
        .testTarget(name: "TrainingsCoreTests", dependencies: ["TrainingsCore"])
    ]
)
