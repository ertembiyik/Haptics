// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Effects",
    platforms: [
        .iOS(.v12),
    ],
    products: [
        .library(
            name: "ParticleDissolveEffect",
            targets: ["ParticleDissolveEffect"]
        ),
        .library(
            name: "WaveDistortionView",
            targets: ["WaveDistortionView"]
        )
    ],
    targets: [
        .target(
            name: "ShelfPack",
            cSettings: [
                .headerSearchPath("Private")
            ]
        ),
        .target(
            name: "STCMeshView",
            cSettings: [
                .headerSearchPath("Private")
            ]
        ),
        .target(name: "HierarchyNotifiedLayer"),
        .target(
            name: "ParticleDissolveEffect",
            dependencies: [
                "ShelfPack",
                "HierarchyNotifiedLayer"
            ]
        ),
        .target(
            name: "WaveDistortionView",
            dependencies: [
                "STCMeshView",
                "HierarchyNotifiedLayer"
            ]
        ),
    ],
    cxxLanguageStandard: .cxx20
)
