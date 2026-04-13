// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SharedUI",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "ForceUpdateUI",
            targets: ["ForceUpdateUI"]
        ),
        .library(
            name: "RegistrationUI",
            targets: ["RegistrationUI"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/layoutBox/PinLayout.git",
            .upToNextMajor(from: "1.10.6")
        ),
        .package(path: "./UIComponents"),
        .package(path: "./Resources"),
        .package(path: "./LoggerExtensions"),
        .package(path: "./SharedSessions"),
        .package(
            url: "https://github.com/izyumkin/MCEmojiPicker",
            .upToNextMinor(from: "1.2.5")
        )
    ],
    targets: [
        .target(
            name: "ForceUpdateUI",
            dependencies: [
                .product(name: "PinLayout", package: "PinLayout"),
                .product(name: "UIComponents", package: "UIComponents"),
                .product(name: "Resources", package: "Resources"),
                .product(name: "LoggerExtensions", package: "LoggerExtensions"),
            ]
        ),
        .target(
            name: "RegistrationUI",
            dependencies: [
                .product(name: "PinLayout", package: "PinLayout"),
                .product(name: "UIComponents", package: "UIComponents"),
                .product(name: "Resources", package: "Resources"),
                .product(name: "AuthSession", package: "SharedSessions"),
                .product(name: "MCEmojiPicker", package: "MCEmojiPicker")
            ]
        ),
    ]
)
