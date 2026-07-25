# TagLib dynamic package migration report

Date: 2026-07-23
Phase: dependency architecture only; TagLib remains 2.1.1

This document records the 0.3 migration baseline. Version 0.4.0 adds public
structured-metadata fields and reliability behavior described in `CHANGELOG.md`;
the digest comparisons below intentionally remain migration-time evidence.

## Outcome

The root `TagLibAudioMetadata` package declares a binary target named `TagLib`
backed by `Vendor/TagLibBinaryPackage/Artifacts/TagLib.xcframework`. The
existing `CTagLibBridge` target depends on that target and dynamically links
the selected framework slice.

`Sources/CTagLibBridge/taglib` and its 250 tracked source/header/license files
were removed after the external build passed. All former TagLib header search
paths and source exclusions were removed. There is no source/static fallback.

## Exact upstream input

| Input | Revision |
| --- | --- |
| TagLib | tag `v2.1.1`, commit `7d86716194777e0294453bfdc9dd170bd033e1f4` |
| utf8cpp submodule | `df857efc5bbc2aa84012d865f7d7e9cccdc08562` |

The artifact was built from an unmodified official checkout. The former
vendored tree differed from that revision in five files: four commented
`taglib_config.h` includes and one relative utf8cpp include, plus an extra ftest
header. Those source-direct-compilation workarounds were not copied into the
external library. Official CMake generates and installs the configuration
headers instead.

The official TagLib LGPL-2.1/MPL-1.1 texts and utf8cpp Boost Software License
text are preserved byte-for-byte in `Vendor/TagLibBinaryPackage/Licenses`.

## Artifact configuration and reproduction

The build script fixes Release/dynamic framework mode, zlib, hidden visibility,
disabled tests/examples/bindings, deployment targets, architectures, the TagLib
tag/commit, and the utf8cpp commit. It rejects modified or untracked upstream
source.

```sh
scripts/build-taglib-xcframework.sh --replace
```

Offline with an existing exact checkout:

```sh
scripts/build-taglib-xcframework.sh \
  --source-dir /path/to/taglib-v2.1.1 \
  --replace
```

Produced slices:

| Slice | Architectures | Minimum OS | Type |
| --- | --- | --- | --- |
| macOS | `arm64`, `x86_64` | 13.0 | Mach-O dynamic framework |
| iOS device | `arm64` | 16.0 | Mach-O dynamic framework |
| iOS Simulator | `arm64`, `x86_64` | 16.0 | Mach-O dynamic framework |

Every slice has install name `@rpath/TagLib.framework/TagLib` and links only
Apple SDK zlib, libc++, and libSystem. The artifact is 7.9 MB. The SHA-256 of
its generated `CHECKSUMS.txt` is
`7b6d9294744f0accfb0cc7ad7e27b9935c66d22d62d887e25d7050ae1d9ac23b`.

Reference toolchain: Xcode 26.6 (17F113), Apple Clang 21.0.0, CMake 4.4.0,
Ninja 1.13.2. A different toolchain may produce different bytes and requires
review even with identical source and options.

## Public API comparison

| Surface | Before | After | Result |
| --- | --- | --- | --- |
| SwiftPM product | `TagLibAudioMetadata` | `TagLibAudioMetadata` | Unchanged |
| Swift module | `TagLibAudioMetadata` | `TagLibAudioMetadata` | Unchanged |
| Bridge module | `CTagLibBridge` | `CTagLibBridge` | Unchanged |
| Swift API digest | `8825de3d3889d40520ebb5ea70f55abe79a25df3a8b100a23bae0afe4ee271f3` | Same | Byte-identical |
| Bridge API digest | `3b889004de89b2c701152e66bd60e2063ab00233bac1b0cbf81659a249d95a13` | Same | Byte-identical |
| Objective-C header | `1c0f2c3ef8f6fd45709b4976fa8f0d8b37b6e438655fd2e5336d2ce7c2934d84` | Same | Byte-identical |

The Swift digest contains 466 public symbols. Key public types remain
`TagLibMetadataManager`, `TagLibMetadataExtractor`, `TagLibAudioMetadata`,
`BasicMetadata`, raw/structured metadata models, capability models, field
schema types, and `TagLibManagerError`.

The re-exported bridge retains these Swift import names:

`dumpMetadataText(from:)`, `extractMetadata(from:)`, `formatCapabilities()`,
`formatCapability(for:)`, `isSupportedFormat(_:)`, `isWritableFormat(_:)`,
`rawMetadata(for:)`, `structuredMetadata(for:)`, `supportedExtensions()`,
`wipeMetadata(from:)`, `writableExtensions()`, `writeMetadata(_:to:)`,
`writeRawPropertyMap(_:to:)`, `writeRawPropertyMapValues(_:to:)`,
`writeStructuredMetadata(_:to:)`,
`writeTrackNumber(_:totalTracks:padWidth:to:)`, and
`writeTrackNumberText(_:discNumberText:to:)`.

The Objective-C error domain remains `TagLibMetadataExtractor`. Its literal
error codes remain:

`1, 2, 10-23, 30-36, 40-47, 50-57, 100-102, 118-119, 122-123, 126-127,
130-131, 134-135, 138-139, 142-143, 150-151, 154-155, 158-159, 162-163,
222-224, 227-244, 9000-9001, 9100-9107`.

Version 0.4.0 additionally uses bridge transaction code `9108` when the
destination file identity changes before commit.

The Swift facade error domain remains `TagLibMetadataManager`, including
transaction codes 1001-1006. No public model, signature, import name,
synchronous calling behavior, declared format capability, or error contract was
changed.

## Verification results

Pre-migration baseline:

| Command | Result |
| --- | --- |
| `swift package clean && swift build` | Passed in 26.69 s; compiled vendored TagLib `.cpp` files |
| `swift test` | 20/20 passed |
| `swift test --sanitize=address` | 20/20 passed |
| `swift test --sanitize=thread` | 20/20 passed |

Post-migration:

| Command/check | Result |
| --- | --- |
| `swift package clean && swift build` | Passed in 8.28 s; copied `TagLib.framework`, compiled one bridge `.mm` and Swift sources |
| `swift test` | 20/20 passed |
| `swift test --sanitize=address` | 20/20 passed, no finding |
| `swift test --sanitize=thread` | 20/20 passed, no finding |
| iOS Simulator command | Passed for `arm64-apple-ios16.0-simulator` using iPhoneSimulator 26.5 SDK |
| Additional architecture builds | Passed for `x86_64-apple-macosx13.0` and `x86_64-apple-ios16.0-simulator` |
| Consumer package | Built and ran using only `import TagLibAudioMetadata`, including from a checkout with an arbitrary directory name; 37 readable extensions |
| Artifact checksums | Every file passed `shasum -a 256 -c CHECKSUMS.txt` |

The existing tests exercise basic reads/writes/clears, erase, raw replace/merge
and multi-value metadata, structured metadata, artwork write/removal, error
mapping paths, corrupt inputs, symlink/unwritable failures, and byte-preserving
transaction rollback.

## Dynamic-link evidence

Verbose build output selected and copied
`Vendor/TagLibBinaryPackage/Artifacts/TagLib.xcframework/macos-arm64_x86_64/TagLib.framework`
and compiled only `Sources/CTagLibBridge/TagLibMetadataExtractor.mm` for the
bridge. `CTagLibBridge.build` contains that one object, its dependency file, and
module map; it contains no TagLib source objects.

`otool -L` on the test bundle reports:

```text
@rpath/TagLib.framework/TagLib
```

Its `LC_RPATH` includes `@loader_path/../../../`, resolving to the SwiftPM debug
directory where `TagLib.framework` is copied. Symbol inspection found 362
undefined TagLib C++ references bound to the `TagLib` image, zero overlapping
global C++ definitions between the test bundle and framework, no TagLib static
archive/dylib beside the framework, and no C/C++ TagLib source remaining under
`Sources/CTagLibBridge`.

For application distribution, Xcode must embed and sign the selected dynamic
framework in the final app. See `INSTALLATION.md`; this repository intentionally
contains no developer signing identity or release credentials.

## Remaining compatibility risks

- The licensed fixtures cover the same six principal fixture families as the
  baseline. The other declared format families remain unverified. Official
  CMake-generated format macros replace the former source-compilation
  workarounds, so those unfixture-backed families should receive fixtures before
  making stronger behavior-equivalence claims.
- The committed dynamic artifact was produced with a newer reference Apple SDK
  than some CI/developer machines may use. Its minimum load commands are macOS
  13/iOS 16, but CI must prove compatibility on the selected runner/toolchain.
- SwiftPM command-line tests prove build-directory rpath resolution. Each final
  iOS/macOS application or archive still needs an embed-and-sign inspection.
- Rebuilding with another compiler/SDK is source/configuration reproducible but
  not guaranteed byte-for-byte reproducible.
- The sanitizer commands instrument the Swift/Objective-C++ consumer side and
  load the production Release XCFramework. The precompiled TagLib C++ slice is
  not itself rebuilt with ASan/TSan instrumentation; use a separate diagnostic
  artifact if upstream-internal sanitizer coverage is required.
- Existing same-path concurrency, hard-link/inode replacement, and unverified
  format limitations are unchanged from the facade reliability contract.

## Recommendation for TagLib 2.3.x

As checked on 2026-07-23, the current upstream stable line is
[2.3.x (2.3.1)](https://github.com/taglib/taglib/releases/tag/v2.3.1).
Evaluate it in a separate change after this architecture is stable:

1. Pin the exact 2.3.x tag and commit plus all submodule/dependency revisions.
2. Compare CMake defaults, exported C++ ABI, generated headers, dependencies,
   licenses, minimum Apple platform behavior, and release notes.
3. Compile the unchanged Objective-C++ bridge against the new headers before
   considering any bridge edits.
4. Build all three dynamic slices, compare exported symbols/install names, and
   rerun the byte-identical public API comparison.
5. Expand fixture coverage for currently unverified families and compare
   serialized metadata bytes/containers, not only high-level field values.
6. Treat any required public API/error change, source patch, platform reduction,
   or static-link fallback as a separate product decision.

Do not replace the 2.1.1 artifact merely because a newer tag exists; accept an
upgrade only after behavior and distribution compatibility evidence is at least
as strong as this migration baseline.
