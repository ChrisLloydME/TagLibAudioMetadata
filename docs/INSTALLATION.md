# Installation and binary distribution

`TagLibAudioMetadata` remains the package product and Swift module consumed by
applications. Its root manifest exposes the repository-local
`TagLib.xcframework` through a `binaryTarget`. `CTagLibBridge` depends on that
target and dynamically links `TagLib.framework`; it does not compile or fall
back to TagLib source.

## Add the package

```swift
dependencies: [
    .package(
        url: "https://github.com/ChrisLloydME/TagLibAudioMetadata.git",
        from: "0.4.2"
    ),
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(
                name: "TagLibAudioMetadata",
                package: "TagLibAudioMetadata"
            ),
        ]
    ),
]
```

Application code still uses only:

```swift
import TagLibAudioMetadata
```

Do not add the vendored binary package directory directly to an application.
The root manifest already exposes the XCFramework as an internal target.

## Supported slices

| Platform | Minimum | Architectures |
| --- | --- | --- |
| macOS | 13.0 | `arm64`, `x86_64` |
| iOS device | 16.0 | `arm64` |
| iOS Simulator | 16.0 | `arm64`, `x86_64` |

The artifact contains unmodified TagLib 2.1.1 at commit
`7d86716194777e0294453bfdc9dd170bd033e1f4`, with utf8cpp commit
`df857efc5bbc2aa84012d865f7d7e9cccdc08562`. Headers and binaries are produced
by the same CMake invocation for each slice. No Homebrew or system TagLib is
used.

## Embedding and signing

`TagLib.framework` is a real dynamic framework with install name
`@rpath/TagLib.framework/TagLib`. SwiftPM/Xcode copies the selected framework
slice into the product build and supplies its link settings. An app or framework
distribution must also ensure that the final app bundle embeds `TagLib.framework`
and signs it with the containing product.

For an Xcode application target, inspect **Frameworks, Libraries, and Embedded
Content** after package resolution. `TagLib.framework` must be present as **Embed
& Sign** for an app target. Do not pre-sign the committed artifact with a
developer identity; Xcode should sign the embedded copy during the application
build. Command-line SwiftPM executables use a build-directory rpath and the
copied framework next to the executable.

Useful checks on a built macOS executable are:

```sh
otool -L /path/to/executable | grep TagLib.framework
otool -l /path/to/executable | grep -A2 LC_RPATH
codesign --verify --deep --strict /path/to/App.app
```

For iOS, validate embedding and signing on the final `.app`, archive, or IPA;
the package repository intentionally contains no signing identity, notarization
credential, or pre-signed application artifact.

## Offline and local use

The committed XCFramework is self-contained. A checkout can resolve and build
offline because the root manifest uses a relative binary target path:

```swift
.binaryTarget(
    name: "TagLib",
    path: "Vendor/TagLibBinaryPackage/Artifacts/TagLib.xcframework"
)
```

Keep the repository layout intact when copying or vendoring the package. The
network is needed only when regenerating the XCFramework without a local source
checkout. To rebuild from an already verified local TagLib checkout:

```sh
scripts/build-taglib-xcframework.sh \
  --source-dir /path/to/taglib-v2.1.1 \
  --replace
```

## Rebuild the binary

Requirements: Xcode with macOS, iPhoneOS, and iPhoneSimulator SDKs; CMake;
Ninja; Git; and command-line developer tools. From a clean checkout:

```sh
scripts/build-taglib-xcframework.sh --replace
```

The script clones `v2.1.1`, verifies the exact TagLib and utf8cpp commits,
rejects modified or untracked upstream files, builds Release dynamic frameworks,
sets macOS 13/iOS 16 deployment targets and fixed architectures, creates the
XCFramework, and writes `Artifacts/TagLib.xcframework/CHECKSUMS.txt`.

The reference artifact was produced with Xcode 26.6 (build 17F113), Apple Clang
21.0.0, CMake 4.4.0, and Ninja 1.13.2. A different Apple SDK or compiler can
produce different bytes even when source and options are identical; review the
new checksums, deployment load commands, exported symbols, and tests before
accepting a regenerated artifact.

## Diagnostics

If package resolution reports a missing binary target, confirm that this path
exists and is a valid XCFramework:

```sh
Vendor/TagLibBinaryPackage/Artifacts/TagLib.xcframework/Info.plist
```

If headers are missing, verify that the selected framework slice contains both
`Headers/taglib.h` and `Modules/module.modulemap`. If the linker cannot find
TagLib, run `swift build -v` and confirm that the compile/link lines reference
the XCFramework slice rather than Homebrew or `/usr/local` paths.

If launch fails with `Library not loaded: @rpath/TagLib.framework/TagLib`, the
framework was linked but not embedded at a location covered by `LC_RPATH`.
Correct the consuming target's embedding/signing settings; do not replace the
binary with a static library.

If the installed artifact may be stale or mismatched, validate it from its own
directory:

```sh
cd Vendor/TagLibBinaryPackage/Artifacts/TagLib.xcframework
shasum -a 256 -c CHECKSUMS.txt
```

## Upgrade procedure

Keep dependency migration and TagLib upgrades separate. For a later upgrade:

1. Change the pinned tag and commits in the build script on a dedicated branch.
2. Review upstream release notes, ABI/API changes, CMake options, dependencies,
   licenses, and supported Apple platforms.
3. Rebuild every slice from one clean, unmodified source revision.
4. Compare public Swift/Objective-C APIs and bridge import names.
5. Run the full behavior, sanitizer, consumer, iOS Simulator, and dynamic-link
   checks before replacing the 2.1.1 artifact.

TagLib 2.3.x should be evaluated independently; it is not part of this migration.
