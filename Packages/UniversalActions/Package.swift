// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "UniversalActions",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        .library(
            name: "UniversalActions",
            targets: ["UniversalActions"]
        ),
    ],
    dependencies: [
        .package(path: "../Packages/FoundationExtensions"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.6.2"))
    ],
    targets: [
        .target(
            name: "UniversalActions",
            dependencies: [
                .product(name: "FoundationExtensions", package: "FoundationExtensions"),
                .product(name: "Dependencies", package: "swift-dependencies")
            ]
        ),
    ]
)
