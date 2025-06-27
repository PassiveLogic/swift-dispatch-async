// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "dispatch-async",
    products: [
        .library(
            name: "DispatchAsync",
            targets: ["DispatchAsync"])
    ],
    targets: [
        .target(
            name: "DispatchAsync"),
        .testTarget(
            name: "DispatchAsyncTests",
            dependencies: ["DispatchAsync"]
        ),
    ]
)
