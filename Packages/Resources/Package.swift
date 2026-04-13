// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Resources",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        .library(
            name: "Resources",
            targets: ["Resources"]
        ),
    ],
    targets: [
        .target(name: "Resources")
    ]
)
