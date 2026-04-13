// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "AyoWidgetCacheStore",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "AyoWidgetCacheStore",
            targets: ["AyoWidgetCacheStore"]
        ),
    ],
    targets: [
        .target(
            name: "AyoWidgetCacheStore"
        ),
    ]
)
