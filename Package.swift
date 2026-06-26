// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "lexer-fsa",
    platforms: [.macOS(.v11), .iOS(.v12)],
    products: [
        .library(name: "LexerFSA", targets: ["LexerFSA"]),
        .executable(name: "fsa", targets: ["fsa"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.2"),
        .package(url: "https://github.com/JohnSundell/ShellOut.git", from: "2.0.0"),
        .package(url: "https://github.com/SwiftDocOrg/GraphViz", from: "0.4.0"),
    ],
    targets: [
        .target(
            name: "LexerFSA",
            dependencies: [
                .product(name: "GraphViz", package: "graphViz"),
            ]
        ),
        .testTarget(
            name: "LexerFSATests",
            dependencies: [
                "LexerFSA",
            ],
            path: "Tests/AutomatonTests"
        ),
        // Move executable target to its destination when library confirmed working.
        .executableTarget(
            name: "fsa",
            dependencies: [
                "LexerFSA",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "ShellOut", package: "shellout"),
                .product(name: "GraphViz", package: "graphViz"),
            ]
        ),
    ]
)
