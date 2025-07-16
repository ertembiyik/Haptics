// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "InvitesSession",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "InvitesSession",
            targets: ["InvitesSession"]),
    ],
    dependencies: [
        .package(path: "../Packages/Configurations"),
        .package(path: "../Packages/FirebaseExtensions"),
        .package(path: "../Packages/LoggerExtensions"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.6.2")),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", .upToNextMajor(from: "11.6.0")),
    ],
    targets: [
        .target(
            name: "InvitesSession",
            dependencies: [
                .product(name: "HapticsConfiguration", package: "Configurations"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "FirebaseExtensions", package: "FirebaseExtensions"),
                .product(name: "FirebaseDatabase", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFunctions", package: "firebase-ios-sdk"),
                .product(name: "LoggerExtensions", package: "LoggerExtensions"),
            ]
        ),

    ]
)
