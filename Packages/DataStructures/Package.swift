// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DataStructures",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        .library(
            name: "ReusePool",
            targets: ["ReusePool"]
        ),
        .library(
            name: "StateMachine",
            targets: ["StateMachine"]
        ),
        .library(
            name: "GeoHash",
            targets: ["GeoHash"]
        )
    ],
    targets: [
        .target(name: "ReusePool"),
        .target(name: "StateMachine"),
        .target(name: "GeoHash")
    ]
)
