# TagLibAudioMetadata

`TagLibAudioMetadata` is a Swift Package for reading, writing, erasing, and
inspecting audio metadata through an Objective-C++ bridge that dynamically
links a packaged TagLib XCFramework. App code works with a Swift facade instead
of TagLib C++ APIs.

Use it when an app needs:

- Common tags such as title, artist, album, track and disc numbers, dates,
  artwork, MusicBrainz and AcoustID identifiers, classical fields, ReplayGain,
  iTunes fields, and custom fields.
- Raw TagLib `PropertyMap` access for advanced metadata editors.
- Container-aware structured metadata for ID3v2 frames, MP4 atoms, ASF
  attributes, lyrics, comments, and artwork.
- Format capability checks before enabling read, write, artwork, or structured
  editing controls.
- Post-write verification warnings when a container normalizes or drops data.

## Requirements

- Swift tools version 6.0
- macOS 13+
- iOS 16+
- GNU C++20, configured by `Package.swift`

Consumers do not need Homebrew, CMake, or a system TagLib installation. The
repository root package mounts an isolated local Swift Package whose
`binaryTarget` contains the required dynamic framework slices.

## Installation

Add the package to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ChrisLloydME/TagLibAudioMetadata.git", branch: "main")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "TagLibAudioMetadata", package: "TagLibAudioMetadata")
        ]
    )
]
```

Then import the Swift facade:

```swift
import TagLibAudioMetadata
```

The Swift module re-exports the underlying `CTagLibBridge` target. Advanced
callers can reach `TagLibMetadataExtractor` and `TagLibAudioMetadata` after the
same import, but normal app code should start with `TagLibMetadataManager`.

See [docs/INSTALLATION.md](docs/INSTALLATION.md) for the package boundary,
supported slices, dynamic framework embedding and signing, offline use,
artifact rebuild commands, and diagnostics.

## Quick Start

Read metadata with the throwing API:

```swift
let url = URL(fileURLWithPath: "/path/to/song.flac")

do {
    let metadata = try TagLibMetadataManager.readMetadataResult(from: url)
    print(metadata.title)
    print(metadata.artist)
    print(metadata.duration)
} catch TagLibManagerError.unsupportedFormat {
    print("Unsupported file format")
} catch {
    print("Could not read metadata: \(error)")
}
```

Write common metadata and inspect verification warnings:

```swift
var metadata = try TagLibMetadataManager.readMetadataResult(from: url)
metadata.title = "New Title"
metadata.artist = "New Artist"
metadata.track = 1
metadata.trackTotal = 12
metadata.trackNumberText = "01/12"

let result = try TagLibMetadataManager.writeMetadataWithVerification(
    metadata,
    to: url,
    failurePolicy: .warn
)

for warning in result.warnings {
    print("Metadata warning: \(warning)")
}
```

Check capabilities before showing editing controls:

```swift
if let capability = TagLibMetadataManager.formatCapability(for: url.pathExtension) {
    print(capability.isWritable)
    print(capability.canWriteArtwork)
    print(capability.structuredWriteSupport)
}
```

## Reliability Contract

Throwing read and inspect APIs reject missing, empty, truncated, corrupt, and
extension-disguised files. `unsupportedFormat` is reserved for extensions not
listed by the capability registry; parse and I/O failures use
`failedToReadWithUnderlying`. Verification mismatches use
`verificationFailed`. Objective-C++ bridge failures retain the stable
`TagLibMetadataExtractor` NSError domain; transactional facade failures use the
`TagLibMetadataManager` domain and codes 1001-1006. Adding new public
`TagLibManagerError` cases is intentionally deferred because it would break
exhaustive client switches.

All Swift facade mutations and all public bridge mutators operate on a
same-directory copy and commit with a same-volume atomic rename only after the
bridge operation and requested verification succeed. A failed write or erase
therefore leaves the destination bytes unchanged. Swift facade mutations reject
symbolic links; direct bridge mutations resolve a link and transactionally
replace its regular-file target to preserve the bridge's historical behavior.
Direct bridge mutations require one file-sized sibling copy. Swift facade calls
also keep their verification-stage copy, so they can temporarily require two
additional file-sized copies.

`TagLibAudioMetadata` is a full-replacement low-level model, not a patch object.
Unset strings and zero numeric values clear fields where the container permits.
For a partial edit, read the current model, modify it, and then write it back, or
use the raw merge and structured omitted-collection APIs.

Calls are synchronous and the returned Foundation values own copies of any C++
buffers. C++ pointers never escape the bridge, ARC owns returned Objective-C
objects, and all exported Objective-C++ selectors contain C++ exception
boundaries. The package does not promise same-path write serialization: callers
must serialize concurrent mutations to one canonical file path. Independent
files may be processed concurrently.

## Verified Format Matrix

The capability registry describes 22 format families and 37 extensions. The
matrix separates declared capability from fixture-backed evidence. `Inspect`
means raw and/or structured inspection; aliases share a parser but are not
individually fixture-tested.

| Format family | Declared operations | Licensed fixture | Verified operations |
| --- | --- | --- | --- |
| MPEG-ID3 (`mp3`, `mp2`) | Read/write/erase/inspect | MP3 | Read, write, erase, artwork, structured inspect/write; MP2 alias unverified |
| Raw AAC (`aac`) | Read/write/erase/inspect | AAC | Read and basic write/clear |
| MP4 (`m4a`, `m4r`, `m4b`, `m4p`, `mp4`, `m4v`, `3g2`) | Read/write/erase/inspect | M4A | Read, write, erase, artwork, raw and structured inspect/write; aliases unverified |
| FLAC (`flac`) | Read/write/erase/inspect | FLAC | Read, write, erase, artwork, raw multi-value inspect/write |
| Ogg Vorbis (`ogg`) | Read/write/erase/inspect | OGG | Read, write, erase, artwork, raw multi-value inspect/write |
| WAV (`wav`) | Read/write/erase/inspect | WAV | Read, write, repeated erase, artwork, structured write, PCM payload preservation |
| Ogg Opus (`opus`) | Read/write/erase/inspect | None | Unverified |
| Ogg FLAC (`oga`) | Read/write/erase/inspect | None | Unverified |
| Ogg Speex (`spx`) | Read/write/erase/inspect | None | Unverified |
| Monkey's Audio (`ape`) | Read/write/erase/inspect | None | Unverified |
| WavPack (`wv`) | Read/write/erase/inspect | None | Unverified |
| Musepack (`mpc`) | Read/write/erase/inspect | None | Unverified |
| AIFF (`aiff`, `aif`, `aifc`, `afc`) | Read/write/erase/inspect | None | Unverified |
| TrueAudio (`tta`) | Read/write/erase/inspect | None | Unverified |
| ASF/WMA (`wma`, `asf`) | Read/write/erase/inspect | None | Unverified |
| DSF (`dsf`) | Read/write/erase/inspect | None | Unverified |
| DSDIFF (`dff`, `dsdiff`) | Read/write/erase/inspect | None | Unverified |
| Shorten (`shn`) | Read/inspect; read-only | None | Unverified |
| MOD (`mod`, `module`, `nst`, `wow`) | Read/write/erase/inspect | None | Unverified |
| S3M (`s3m`) | Read/write/erase/inspect | None | Unverified |
| Impulse Tracker (`it`) | Read/write/erase/inspect | None | Unverified |
| FastTracker (`xm`) | Read/write/erase/inspect | None | Unverified |

Unverified families remain capability claims derived from bundled TagLib and
bridge routing, not release-grade operational evidence. Do not enable destructive
editing for them solely from this table without adding a licensed fixture and
the same read/write/erase/inspect tests.

## Test Fixture Provenance

All repository media fixtures are synthetic: a 440 Hz sine wave and a solid blue
image generated locally, with no third-party recording or photograph. The
generated files are provided under this repository's MIT license. The following
commands reproduce their content shape (encoder versions can change bytes):

```sh
ffmpeg -f lavfi -i sine=frequency=440:duration=0.5 -ar 44100 -ac 2 -map_metadata -1 -c:a libmp3lame -b:a 128k testAudioFile.mp3
ffmpeg -fflags +bitexact -f lavfi -i sine=frequency=440:duration=0.5 -ar 44100 -ac 2 -map_metadata -1 -metadata encoder= -flags:a +bitexact -c:a aac -b:a 128k testAudioFile.m4a
ffmpeg -f lavfi -i sine=frequency=440:duration=0.5 -ar 44100 -ac 2 -map_metadata -1 -c:a flac testAudioFile.flac
ffmpeg -f lavfi -i sine=frequency=440:duration=0.5 -ar 44100 -ac 2 -map_metadata -1 -c:a aac -b:a 128k -f adts testAudioFile.aac
ffmpeg -f lavfi -i sine=frequency=440:duration=0.5 -ar 44100 -ac 2 -map_metadata -1 -c:a vorbis -strict -2 -q:a 4 testAudioFile.ogg
ffmpeg -f lavfi -i sine=frequency=440:duration=0.5 -ar 44100 -ac 2 -map_metadata -1 -c:a pcm_s16le intermediate.wav
afconvert intermediate.wav -o testAudioFile.wav -f WAVE -d LEI16
ffmpeg -f lavfi -i color=c=blue:s=64x64:d=0.1 -frames:v 1 testCover.jpg
```

Current SHA-256 values are:

| Fixture | SHA-256 |
| --- | --- |
| `testAudioFile.aac` | `535f95dfc0d1feca89a2a80d60f4279ed15b4d057a784c5f181cb02a6881a7d3` |
| `testAudioFile.flac` | `01fbdf57907e9c799d0c98f641ec3b543b2ed91473a5a4e15df8ed072bd786f2` |
| `testAudioFile.m4a` | `af2171faed73cc10f21feefa980073b62a0d086ea390c2af3455127cfed3fb24` |
| `testAudioFile.mp3` | `9db9e5033b1c6d4fea48dc2b13e606f0b70625f86391bcbf0b9044f72f2012dc` |
| `testAudioFile.ogg` | `9901df8170531d790f421c69a864e57b53cfc921cf760cc267c46de25bcca6ad` |
| `testAudioFile.wav` | `fce6f158bdc9bdd9a0f9e2092da3c5d4686540076177d20227b5059e9b2cf218` |
| `testCover.jpg` | `a291a5c9f462515de487230e2780a754c38d9f8f18742e4d3d98d6d0e9ac8954` |

## Verification Report

Pre-migration baseline on 2026-07-23 used Apple Swift 6.3.3:

| Command | Result |
| --- | --- |
| `swift package clean && swift build` | Passed in 26.69 seconds; verbose output compiled the vendored TagLib `.cpp` files |
| `swift test` | Passed 20 tests |
| `swift test --sanitize=address` | Passed 20 tests |
| `swift test --sanitize=thread` | Passed 20 tests |

Final verification on the same host:

| Command | Result |
| --- | --- |
| `swift package clean && swift build` | Passed in 8.28 seconds; copied `TagLib.framework` and compiled only the bridge `.mm` file plus Swift sources |
| `swift test` | Passed 20 tests; no failures |
| `swift test --sanitize=address` | Passed 20 tests; no Address Sanitizer findings |
| `swift test --sanitize=thread` | Passed 20 tests; no Thread Sanitizer findings |
| Consumer executable | Built and ran with only `import TagLibAudioMetadata`; reported 37 readable extensions |
| iOS Simulator cross-build | Passed for `arm64-apple-ios16.0-simulator` with minimum iOS 16.0 |
| API digests | Swift and Objective-C bridge JSON SHA-256 values are byte-for-byte identical to baseline |
| Dynamic link audit | Test bundle loads `@rpath/TagLib.framework/TagLib`; 362 unresolved C++ references bind to TagLib and no overlapping global definitions were found |

Reliability regressions cover invalid and disguised reads, explicit raw and
structured failures, corrupt/unwritable/symlink mutation paths, facade and direct
bridge rollback by byte comparison, malformed/null-like/partial structured
payloads, Unicode and long values, ordered multi-values, unknown fields,
repeated reads and erase, exact artwork bytes, and WAV PCM payload preservation.
CI verifies artifact checksums, clean build/test, consumer integration, dynamic
linkage, Address Sanitizer, Thread Sanitizer, and an iOS 16 Simulator
cross-build as separate macOS jobs.

Residual risks are the unverified format families above, no package-level
same-file concurrency guarantee, inode/hard-link identity changes caused by
atomic replacement, and the intentionally deferred public Swift write-error
enum expansion. Sanitizer availability and results are recorded with each
release because Apple toolchain/runtime support varies by host.

## Documentation

The current API guide lives in [docs/SUPPORT.md](docs/SUPPORT.md). It covers:

- Basic metadata reads and writes.
- Raw property map reads and writes.
- Structured metadata reads and writes.
- Format capability descriptors.
- Verification warnings and failure policies.
- Metadata erase behavior.
- Field registry usage.
- Low-level bridge APIs.
- Practical integration recipes.

The complete migration evidence and API comparison are in
[docs/MIGRATION_REPORT.md](docs/MIGRATION_REPORT.md).

Binary distribution and rebuild details are in
[docs/INSTALLATION.md](docs/INSTALLATION.md). License details for the packaged
TagLib binary and its exact corresponding source revision are in
[docs/THIRD_PARTY_NOTICES.md](docs/THIRD_PARTY_NOTICES.md).

## Package Layout

| Target | Role |
| --- | --- |
| `TagLibAudioMetadata` | Swift facade for application code. |
| `CTagLibBridge` | Existing Objective-C++ API bridge; dynamically linked to TagLib. |
| `Vendor/TagLibBinaryPackage` | Isolated Swift Package exposing `TagLib.xcframework` as the `TagLibBinary` product. |

The root `Package.swift` mounts `Vendor/TagLibBinaryPackage` by relative path.
There is no TagLib source target, static fallback, Homebrew lookup, or system
library lookup. The committed XCFramework contains dynamic macOS, iOS device,
and iOS Simulator slices built from unmodified TagLib 2.1.1.

## License

This package's Swift and Objective-C++ bridge code is released under the MIT
License. See [LICENSE](LICENSE).

The dynamically packaged TagLib library is dual-licensed under LGPL-2.1 and
MPL-1.1. The exact upstream license texts are included at:

- `Vendor/TagLibBinaryPackage/Licenses/COPYING.LGPL`
- `Vendor/TagLibBinaryPackage/Licenses/COPYING.MPL`

The bundled utf8cpp dependency is licensed under the Boost Software License
1.0; its text is at
`Vendor/TagLibBinaryPackage/Licenses/utfcpp-LICENSE`.

Applications that distribute this package must comply with the MIT license for
the bridge code and either the LGPL-2.1 or MPL-1.1 terms for TagLib.
