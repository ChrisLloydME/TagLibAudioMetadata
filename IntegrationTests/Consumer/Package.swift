// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TagLibAudioMetadataConsumer",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    dependencies: [
        .package(name: "TagLibAudioMetadata", path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "TagLibAudioMetadataConsumer",
            dependencies: [
                .product(name: "TagLibAudioMetadata", package: "TagLibAudioMetadata"),
            ]
        ),
        .executableTarget(
            name: "TagLibAudioMetadataLowLevelConsumer",
            dependencies: [
                .product(name: "TagLibAudioMetadataLowLevel", package: "TagLibAudioMetadata"),
            ]
        ),
    ]
)
