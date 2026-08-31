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
        .library(
            name: "TagLibAudioMetadataLowLevel",
            targets: ["CTagLibBridge"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "TagLib",
            url: "https://github.com/ChrisLloydME/TagLibAudioMetadata/releases/download/taglib-binary-2.1.1-r1/TagLib-2.1.1-apple-dynamic.xcframework.zip",
            checksum: "67947a18a807d01a2b11714b1733569ec0414af581a21c06158323b162900864"
        ),
        .target(
            name: "CTagLibBridge",
            dependencies: ["TagLib"],
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
