// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ThumbmixCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ThumbmixCore", targets: ["ThumbmixCore"]),
    ],
    targets: [
        .target(name: "ThumbmixCore"),
        .target(name: "FakeM32", dependencies: ["ThumbmixCore"]),
        .executableTarget(name: "fake-m32", dependencies: ["FakeM32"]),
        .executableTarget(name: "m32-probe", dependencies: ["ThumbmixCore"]),
        .testTarget(name: "ThumbmixCoreTests", dependencies: ["ThumbmixCore", "FakeM32"]),
    ]
)
