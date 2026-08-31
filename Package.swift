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
            url: "https://github.com/ChrisLloydME/TagLibAudioMetadata/releases/download/taglib-binary-2.3.1-r2/TagLibAudioMetadataTagLib-2.3.1-apple-dynamic.xcframework.zip",
            checksum: "d7a36b2492266a17fcd97bd776cd841d9fc85275270bc0c3cb9621395b3178c7"
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
