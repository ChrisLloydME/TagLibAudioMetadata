# Installation and binary distribution

`TagLibAudioMetadata` remains the package product and Swift module consumed by
applications. Its root manifest exposes a checksum-pinned remote
`TagLib.xcframework` through a `binaryTarget`. `CTagLibBridge` depends on that
target and dynamically links `TagLib.framework`; it does not compile or fall
back to TagLib source.

The source repository contains no TagLib implementation source, framework
headers, or framework binaries. The Apple binary is published separately as a
checksum-pinned GitHub Release asset that is immutable by project policy.

## Add the package

```swift
dependencies: [
    .package(
        url: "https://github.com/ChrisLloydME/TagLibAudioMetadata.git",
        from: "0.4.3"
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

Do not add a second TagLib package or a system library dependency. The root
manifest already exposes the remote XCFramework as an internal binary target.

## Binary identity

| Field | Value |
| --- | --- |
| Upstream TagLib | `v2.1.1` |
| TagLib commit | `7d86716194777e0294453bfdc9dd170bd033e1f4` |
| utf8cpp commit | `df857efc5bbc2aa84012d865f7d7e9cccdc08562` |
| Binary release | `taglib-binary-2.1.1-r1` |
| Asset | `TagLib-2.1.1-apple-dynamic.xcframework.zip` |
| SwiftPM checksum | `a625c90c0996a8a37484bae1f2075913b591aba1b73cafb119446d9d2294a547` |

SwiftPM downloads the archive once, verifies the manifest checksum, and caches
the result. A modified or replaced asset is rejected. Published binary assets
must therefore be treated as immutable; corrections use a new `rN` release.

The release asset is public and requires no GitHub login, token, Keychain item,
or `.netrc` entry. SwiftPM enables credential providers by default; on a Mac
that already has a GitHub credential, command-line resolution can ask for
Keychain access before making an otherwise anonymous download. To prohibit any
credential lookup, use:

```sh
swift build --disable-keychain --disable-netrc
swift test --disable-keychain --disable-netrc
```

Denying Keychain access does not prevent this package from building when those
flags are used. Xcode package resolution also downloads the same public URL;
the package itself never requests or receives repository credentials.

## Supported slices

| Platform | Minimum | Architectures |
| --- | --- | --- |
| macOS | 13.0 | `arm64`, `x86_64` |
| iOS device | 16.0 | `arm64` |
| iOS Simulator | 16.0 | `arm64`, `x86_64` |

Headers and binaries in each slice are produced by the same CMake build from an
unmodified official checkout. No Homebrew or system TagLib is used. The macOS
slice uses the standard `Versions/A` framework layout required by application
validation.

## Embedding and signing

`TagLib.framework` is a real dynamic framework with install name
`@rpath/TagLib.framework/TagLib`. SwiftPM/Xcode copies the selected framework
slice into the product build and supplies its link settings. An app or framework
distribution must also ensure that the final app bundle embeds `TagLib.framework`
and signs it with the containing product.

For an Xcode application target, inspect **Frameworks, Libraries, and Embedded
Content** after package resolution. `TagLib.framework` must be present as **Embed
& Sign** for an app target. The release asset is intentionally unsigned; Xcode
signs the embedded copy during the application build. Command-line SwiftPM
executables use a build-directory rpath and the copied framework next to the
executable.

Useful checks on a built macOS executable are:

```sh
otool -L /path/to/executable | grep TagLib.framework
otool -l /path/to/executable | grep -A2 LC_RPATH
codesign --verify --deep --strict /path/to/App.app
```

For iOS, validate embedding and signing on the final `.app`, archive, or IPA;
the package repository intentionally contains no signing identity, notarization
credential, or pre-signed application artifact.

## Offline use

The first resolution requires access to the GitHub Release asset. Subsequent
offline builds can use SwiftPM's cache, but a fresh machine cannot resolve the
remote binary without either network access or a pre-populated SwiftPM cache.

For a controlled offline environment, mirror the exact ZIP internally and use a
private manifest fork with the mirror URL and the same checksum. Do not fall back
to Homebrew, a system TagLib, a static library, or source compilation, because
that changes the verified dependency boundary.

## Rebuild and package the binary

Requirements: Xcode with macOS, iPhoneOS, and iPhoneSimulator SDKs; CMake;
Ninja; Git; Zip; and command-line developer tools. From a clean checkout:

```sh
scripts/build-taglib-xcframework.sh --replace
```

`scripts/taglib-binary-version.env` is the single source of truth for the
upstream tag, exact commits, binary revision, release tag, and asset name. The
script clones and verifies those revisions, rejects modified upstream files,
builds all Release dynamic framework slices, validates the macOS versioned
bundle, creates the XCFramework ZIP under `.build/taglib-release`, and prints
the SwiftPM checksum. Its public Git operations disable credential helpers and
interactive authentication, so regeneration does not read GitHub credentials
from Keychain either.

An already verified local TagLib checkout can be used without cloning:

```sh
scripts/build-taglib-xcframework.sh \
  --source-dir /path/to/taglib-v2.1.1 \
  --replace
```

The reference artifact was produced with Xcode 26.6 (build 17F113), Apple Clang
21.0.0, CMake 4.4.0, and Ninja 1.13.2. A different SDK or compiler can produce
different bytes even when source and options are identical. Review deployment
load commands, exported symbols, archive checksum, and the full test suite before
publishing a regenerated artifact.

## Publish an artifact

1. Update `scripts/taglib-binary-version.env` on `main` and review the upstream
   source.
2. Push the change. **Publish TagLib binary** automatically builds the archive,
   creates or completes the matching binary Release, obtains the real checksum,
   and commits the resulting URL and checksum to `Package.swift`.
3. The release workflow explicitly dispatches CI for the bot's manifest commit;
   verify the clean external consumer before publishing a new semantic package
   version.

The workflow can also be started manually with the matching
`taglib-binary-<version>-r<revision>` input. It uses the selected branch's
publishing tools instead of checking out a possibly older release tag.

The publishing workflow may attach an asset to an existing empty release, but
refuses to replace an existing same-named asset. If a published asset has a
build or packaging error, increment `TAGLIB_BINARY_REVISION` and publish a new
tag and asset instead of mutating the old one.

## Diagnostics

If resolution reports a failed binary download, verify that the release and
asset URL from `Package.swift` still exist. If the failure mentions Keychain or
credentials even though the asset is public, retry the command with
`--disable-keychain --disable-netrc`. If it reports a checksum mismatch, do not
bypass the check: confirm the release asset has not been replaced and that the
manifest checksum came from `swift package compute-checksum` for the exact ZIP.

If headers are missing, inspect SwiftPM's selected artifact cache and verify the
slice contains `Headers/taglib.h` and `Modules/module.modulemap`. If the linker
cannot find TagLib, run `swift build -v` and confirm the compile/link lines
reference the downloaded XCFramework rather than Homebrew or `/usr/local`.

If launch fails with `Library not loaded: @rpath/TagLib.framework/TagLib`, the
framework was linked but not embedded at a location covered by `LC_RPATH`.
Correct the consuming target's embedding/signing settings; do not replace the
binary with a static library.

For macOS validation failures, confirm the copied framework retains:

```text
TagLib.framework/Versions/A/TagLib
TagLib.framework/Versions/A/Resources/Info.plist
TagLib.framework/Versions/Current -> A
TagLib.framework/TagLib -> Versions/Current/TagLib
```

## Upgrade procedure

Keep dependency architecture and TagLib upgrades separate. For TagLib 2.3.x or
another future release:

1. Review upstream release notes, ABI/API changes, CMake options, dependencies,
   licenses, and supported Apple platforms.
2. Update the tag, commits, binary revision, release tag, and asset name in
   `scripts/taglib-binary-version.env`.
3. Rebuild every slice from one clean, unmodified source revision and publish a
   new immutable binary release.
4. Update only the remote URL and checksum in `Package.swift`.
5. Compare public Swift/Objective-C APIs and bridge import names.
6. Run behavior tests, sanitizers, the external consumer, iOS Simulator build,
   dynamic-link checks, and final macOS/iOS app validation.

Do not overwrite an existing binary release, patch upstream TagLib, reduce
platform support, or introduce a source/static fallback as part of an upgrade.
