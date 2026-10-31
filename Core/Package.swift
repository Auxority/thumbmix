// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ThumbmixCore",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ThumbmixCore", targets: ["ThumbmixCore"]),
        .library(name: "FakeM32", targets: ["FakeM32"]),
    ],
    dependencies: [
        // The official MCP SDK, for `thumbmix-mcp` only: ThumbmixCore and the app never import it.
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", exact: "0.12.1")
    ],
    targets: [
        .target(name: "ThumbmixCore", resources: [.process("Resources")]),
        .target(name: "FakeM32", dependencies: ["ThumbmixCore"]),
        .executableTarget(name: "fake-m32", dependencies: ["FakeM32"]),
        .executableTarget(name: "m32-probe", dependencies: ["ThumbmixCore"]),
        .target(
            name: "ThumbmixMCP",
            dependencies: ["ThumbmixCore", .product(name: "MCP", package: "swift-sdk")]),
        .executableTarget(name: "thumbmix-mcp", dependencies: ["ThumbmixMCP", "ThumbmixCore", "FakeM32"]),
        .testTarget(name: "ThumbmixCoreTests", dependencies: ["ThumbmixCore", "FakeM32", "ThumbmixMCP"]),
    ]
)
