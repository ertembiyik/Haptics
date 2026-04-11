// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LinksFactory",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        .library(
            name: "LinksFactory",
            targets: ["LinksFactory"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.12.0"))
    ],
    targets: [
        .target(
            name: "LinksFactory",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies")
            ]
        ),
    ]
)
