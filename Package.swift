// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "grammar-fsa",
    platforms: [.macOS(.v11), .iOS(.v12)],
    products: [
        .library(name: "Automaton", targets: ["Automaton"])
    ],
    dependencies: [
        .package(url: "https://github.com/SwiftDocOrg/GraphViz", from: "0.4.0"),
    ],
    targets: [
        .target(
            name: "Automaton",
            dependencies: [
                .product(name: "GraphViz", package: "graphViz"),
            ]
        ),
        .testTarget(name: "AutomatonTests", dependencies: ["Automaton"]),
    ]
)
