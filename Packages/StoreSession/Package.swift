// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StoreSession",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "StoreSession",
            targets: ["StoreSession"]
        ),
    ],
    dependencies: [
        .package(path: "./AnalyticsSession"),
        .package(path: "../Packages/SharedSessions"),
        .package(path: "../Packages/Configurations"),
        .package(path: "../Packages/CombineExtensions"),
        .package(path: "../Packages/LoggerExtensions"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.6.2"))
    ],
    targets: [
        .target(
            name: "StoreSession",
            dependencies: [
                .product(name: "AnalyticsSession", package: "AnalyticsSession"),
                .product(name: "AuthSession", package: "SharedSessions"),
                .product(name: "HapticsConfiguration", package: "Configurations"),
                .product(name: "CombineExtensions", package: "CombineExtensions"),
                .product(name: "LoggerExtensions", package: "LoggerExtensions"),
                .product(name: "Dependencies", package: "swift-dependencies")
            ]
        ),
    ]
)
