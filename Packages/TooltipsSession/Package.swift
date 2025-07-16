// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TooltipsSession",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        .library(
            name: "TooltipsSession",
            targets: ["TooltipsSession"]),
    ],
    dependencies: [
        .package(path: "../Packages/Configurations"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.6.2")),
    ],
    targets: [
        .target(
            name: "TooltipsSession",
            dependencies: [
                .product(name: "HapticsConfiguration", package: "Configurations"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
    ]
)
