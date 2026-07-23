// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TagLibAudioMetadata",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "TagLibAudioMetadata",
            targets: ["TagLibAudioMetadata"]
        ),
    ],
    dependencies: [
        .package(path: "Vendor/TagLibBinaryPackage"),
    ],
    targets: [
        .target(
            name: "CTagLibBridge",
            dependencies: [
                .product(name: "TagLibBinary", package: "TagLibBinaryPackage"),
            ],
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("Foundation"),
            ]
        ),
        .target(
            name: "TagLibAudioMetadata",
            dependencies: ["CTagLibBridge"]
        ),
        .testTarget(
            name: "TagLibAudioMetadataTests",
            dependencies: ["TagLibAudioMetadata"],
            resources: [
                .process("Audio"),
                .process("Artwork"),
            ]
        ),
    ],
    cxxLanguageStandard: .gnucxx20
)
