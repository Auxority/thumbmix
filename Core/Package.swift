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
        .testTarget(name: "ThumbmixCoreTests", dependencies: ["ThumbmixCore"]),
    ]
)
