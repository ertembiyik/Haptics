// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AnalyticsSession",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        .library(
            name: "AnalyticsSession",
            targets: ["AnalyticsSession"]
        ),
    ],
    dependencies: [
        .package(path: "./RemoteDataModels"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.6.2")),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", .upToNextMajor(from: "11.6.0")),
    ],
    targets: [
        .target(
            name: "AnalyticsSession",
            dependencies: [
                .product(name: "RemoteDataModels", package: "RemoteDataModels"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
            ]
        ),
    ]
)
