// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FirebaseExtensions",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "FirebaseExtensions",
            targets: ["FirebaseExtensions"]),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", .upToNextMajor(from: "12.12.0")),
    ],
    targets: [
        .target(
            name: "FirebaseExtensions",
            dependencies: [
                .product(name: "FirebaseDatabase", package: "firebase-ios-sdk"),
            ]
        ),
    ]
)
