// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WidgetsSession",
    platforms: [
        .iOS(.v14),
    ],
    products: [
        .library(
            name: "WidgetsSession",
            targets: ["WidgetsSession"]),
    ],
    dependencies: [
        .package(path: "../Packages/Configurations"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.12.0"))
    ],
    targets: [
        .target(
            name: "WidgetsSession",
            dependencies: [
                .product(name: "HapticsConfiguration", package: "Configurations"),
                .product(name: "Dependencies", package: "swift-dependencies")
            ]
        ),

    ]
)
