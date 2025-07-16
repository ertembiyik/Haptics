// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Configurations",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        .library(
            name: "HapticsConfiguration",
            targets: ["HapticsConfiguration"]
        ),
    ],
    dependencies: [
        .package(path: "./Resources"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.6.2"))
    ],
    targets: [
        .target(
            name: "HapticsConfiguration",
            dependencies: [
                .product(name: "Resources", package: "Resources"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                "Configuration"
            ]
        ),
        .target(name: "Configuration"),
    ]
)
