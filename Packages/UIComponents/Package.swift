// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "UIComponents",
    platforms: [
        .iOS(.v14),
    ],
    products: [
        .library(
            name: "UIComponents",
            targets: ["UIComponents"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/layoutBox/PinLayout.git",
            .upToNextMajor(from: "1.10.6")
        ),
        .package(path: "./FoundationExtensions"),
        .package(path: "./Utils"),
        .package(path: "./UIKitExtensions"),
        .package(path: "./DataStructures"),
        .package(path: "./Resources"),
    ],
    targets: [
        .target(
            name: "UIComponents",
            dependencies: [
                .product(name: "PinLayout", package: "PinLayout"),
                .product(name: "FoundationExtensions", package: "FoundationExtensions"),
                .product(name: "Utils", package: "Utils"),
                .product(name: "UIKitExtensions", package: "UIKitExtensions"),
                .product(name: "StateMachine", package: "DataStructures"),
                .product(name: "Resources", package: "Resources"),
                .product(name: "UIKitPrivateExtensions", package: "UIKitExtensions")
            ]
        ),
    ]
)
