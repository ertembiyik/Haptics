// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ConversationsSession",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "ConversationsSession",
            targets: ["ConversationsSession"]
        ),
    ],
    dependencies: [
        .package(path: "./AnalyticsSession"),
        .package(path: "../Packages/SharedSessions"),
        .package(path: "../Packages/Configurations"),
        .package(path: "./RemoteDataModels"),
        .package(path: "./StoreSession"),
        .package(path: "./InvitesSession"),
        .package(path: "./UniversalActions"),
        .package(path: "../Packages/FirebaseExtensions"),
        .package(path: "../Packages/LoggerExtensions"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.12.0")),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", .upToNextMajor(from: "12.12.0")),
    ],
    targets: [
        .target(
            name: "ConversationsSession",
            dependencies: [
                .product(name: "AnalyticsSession", package: "AnalyticsSession"),
                .product(name: "AuthSession", package: "SharedSessions"),
                .product(name: "HapticsConfiguration", package: "Configurations"),
                .product(name: "RemoteDataModels", package: "RemoteDataModels"),
                .product(name: "StoreSession", package: "StoreSession"),
                .product(name: "InvitesSession", package: "InvitesSession"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "LoggerExtensions", package: "LoggerExtensions"),
                .product(name: "UniversalActions", package: "UniversalActions"),
                .product(name: "FirebaseExtensions", package: "FirebaseExtensions"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseDatabase", package: "firebase-ios-sdk"),
        
                .product(name: "FirebaseFunctions", package: "firebase-ios-sdk"),
            ]
        ),

    ]
)
