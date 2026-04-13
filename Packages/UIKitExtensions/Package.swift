// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "UIKitExtensions",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        .library(
            name: "UIKitExtensions",
            targets: [
                "UIKitExtensions"
            ]
        ),
        .library(
            name: "UIKitPrivateExtensions",
            targets: [
                "UIKitPrivateExtensions"
            ]
        ),
    ], 
    dependencies: [
        .package(path: "./FoundationExtensions"),
        .package(path: "./Resources"),
    ],
    targets: [
        .target(
            name: "UIKitExtensions",
            dependencies: [
                .product(name: "FoundationExtensions", package: "FoundationExtensions"),
                .product(name: "Resources", package: "Resources"),
            ]
        ),
        .target(
            name: "UIKitPrivateExtensions"
        ),
    ]
)
