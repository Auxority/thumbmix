// swift-tools-version: 6.0
import PackageDescription

// `thumbmix-mcp`, the Mac tool that lets an AI client read and set the desk over MCP. Its own package, so the official
// MCP SDK and what it pulls in never reach Core or the app's dependency graph.
let package = Package(
    name: "ThumbmixMCP",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../Core"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", exact: "0.12.1"),
    ],
    targets: [
        .target(
            name: "ThumbmixMCP",
            dependencies: [
                .product(name: "ThumbmixCore", package: "Core"), .product(name: "MCP", package: "swift-sdk"),
            ]),
        .executableTarget(
            name: "thumbmix-mcp",
            dependencies: [
                "ThumbmixMCP", .product(name: "ThumbmixCore", package: "Core"), .product(name: "FakeM32", package: "Core"),
            ]),
        .testTarget(
            name: "ThumbmixMCPTests",
            dependencies: [
                "ThumbmixMCP", .product(name: "ThumbmixCore", package: "Core"), .product(name: "FakeM32", package: "Core"),
            ]),
    ]
)
