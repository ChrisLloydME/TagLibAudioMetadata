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
    targets: [
        .binaryTarget(
            name: "TagLib",
            url: "https://github.com/ChrisLloydME/TagLibAudioMetadata/releases/download/taglib-binary-2.1.1-r1/TagLib-2.1.1-apple-dynamic.xcframework.zip",
            checksum: "a625c90c0996a8a37484bae1f2075913b591aba1b73cafb119446d9d2294a547"
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
