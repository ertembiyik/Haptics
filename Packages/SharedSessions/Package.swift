// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SharedSessions",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "AppHealthSession",
            targets: ["AppHealthSession"]
        ),
        .library(
            name: "AuthSession",
            targets: ["AuthSession"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.6.2")),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", .upToNextMajor(from: "11.6.0")),
        .package(path: "./FirebaseExtensions"),
        .package(path: "./LoggerExtensions"),
        .package(path: "./Utils"),
    ],
    targets: [
        .target(
            name: "AppHealthSession",
            dependencies: [
                .product(name: "LoggerExtensions", package: "LoggerExtensions"),
                .product(name: "FirebaseExtensions", package: "FirebaseExtensions"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "FirebaseDatabase", package: "firebase-ios-sdk"),
            ]
        ),
        .target(
            name: "AuthSession",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "CryptoUtils", package: "Utils"),
                .product(name: "LoggerExtensions", package: "LoggerExtensions"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
            ]
        ),
    ]
)
