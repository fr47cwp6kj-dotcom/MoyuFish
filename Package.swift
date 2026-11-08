// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MoyuFish",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MoyuFishCore", targets: ["MoyuFishCore"]),
        .executable(name: "MoyuFish", targets: ["MoyuFishApp"]),
        .executable(name: "MoyuFishCoreChecks", targets: ["MoyuFishCoreChecks"])
    ],
    dependencies: [],
    targets: [
        .target(name: "MoyuFishCore"),
        .executableTarget(
            name: "MoyuFishApp",
            dependencies: ["MoyuFishCore"]
        ),
        .executableTarget(name: "MoyuFishCoreChecks", dependencies: ["MoyuFishCore"]),
        .testTarget(name: "MoyuFishCoreTests", dependencies: ["MoyuFishCore"])
    ],
    swiftLanguageVersions: [.v5]
)
