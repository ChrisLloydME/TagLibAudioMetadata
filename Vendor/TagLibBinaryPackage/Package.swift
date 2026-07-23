// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TagLibBinaryPackage",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "TagLibBinary",
            targets: ["TagLib"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "TagLib",
            path: "Artifacts/TagLib.xcframework"
        ),
    ]
)
