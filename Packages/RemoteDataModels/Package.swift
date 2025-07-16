// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RemoteDataModels",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        .library(
            name: "RemoteDataModels",
            targets: ["RemoteDataModels"]
        ),
    ],
    dependencies: [
        .package(path: "../Packages/UIKitExtensions")
    ],
    targets: [
        .target(
            name: "RemoteDataModels",
            dependencies: [
                .product(name: "UIKitExtensions", package: "UIKitExtensions")
            ]
        ),

    ]
)
