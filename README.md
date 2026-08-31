# TagLibAudioMetadata

`TagLibAudioMetadata` is a Swift package for reading, editing, verifying, and
erasing audio metadata on macOS and iOS. Applications use a Swift facade; an
Objective-C++ bridge dynamically links a checksum-pinned TagLib 2.3.1
XCFramework.

It supports common tags, artwork, MusicBrainz and AcoustID identifiers,
ReplayGain, raw multi-value property maps, and container-aware ID3v2, MP4, ASF,
Xiph, APE, FLAC, and RIFF metadata.

## Requirements and installation

- Swift tools 6.0
- macOS 13+
- iOS 16+
- Xcode toolchains capable of GNU C++20

```swift
dependencies: [
    .package(
        url: "https://github.com/ChrisLloydME/TagLibAudioMetadata.git",
        from: "0.4.5"
    )
]
```

Most targets need only the facade product:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "TagLibAudioMetadata", package: "TagLibAudioMetadata")
    ]
)
```

Advanced clients that intentionally use the Objective-C bridge should depend
on `TagLibAudioMetadataLowLevel` and `import CTagLibBridge`. The facade still
re-exports the bridge for source compatibility, but that is a migration aid,
not the preferred dependency boundary.

The binary is fetched from the public
[`taglib-binary-2.3.1-r2`](https://github.com/ChrisLloydME/TagLibAudioMetadata/releases/tag/taglib-binary-2.3.1-r2)
release. No Homebrew, CMake, system TagLib, or vendored source fallback is used.
See [Installation](docs/INSTALLATION.md) for embedding and diagnostics.

## Recommended API

Read a complete editing snapshot in one bridge session:

```swift
import TagLibAudioMetadata

let url = URL(fileURLWithPath: "/path/to/song.flac")
let snapshot = try TagLibMetadataManager.readSnapshot(from: url)

print(snapshot.basic.title)
print(snapshot.raw.properties)
print(snapshot.structured.artwork)
```

Apply only the requested changes while preserving everything else:

```swift
let patch = MetadataPatch(
    fields: [
        .title: .text("New Title"),
        .track: .text("01/12")
    ],
    customFields: ["MOOD": .values(["Focused", "Calm"])],
    explicitAdvisory: .clean,
    artwork: .unchanged
)

let result = try TagLibMetadataManager.applyMetadataPatch(
    patch,
    to: url,
    failurePolicy: .throw
)
```

`BasicMetadata` remains a convenient normalized projection, but it is not a
lossless editing document: it flattens some multi-value and container-specific
data. For professional editors, read `MetadataSnapshot` and write
`MetadataPatch`, raw multi-value maps, or structured metadata. A basic
full-model write intentionally means replacement: empty strings and zero
numeric values clear corresponding fields where the container allows it.

Check capability evidence before enabling controls:

```swift
if let capability = TagLibMetadataManager.formatCapability(for: url.pathExtension) {
    print(capability.supportLevel)
    print(capability.writeSupport(for: .artwork))
}
```

Support levels are `verified`, `experimental`, `upstreamSupported`, `readOnly`,
and `unsupported`. They distinguish fixture-backed package behavior from a
parser path merely exposed by upstream TagLib.

## Reliability contract

Throwing reads reject missing, empty, truncated, corrupt, and
extension-disguised files. Snapshot reads also reject a destination whose file
identity changes during extraction.

Every facade or public bridge mutation:

1. rejects symlinks and requires an existing regular file;
2. makes one sibling, same-volume copy;
3. mutates and verifies the copy;
4. flushes the copy, rechecks destination identity, atomically renames it, and
   flushes the parent directory.

A failure before rename leaves the original pathname and bytes unchanged and
cleans up the temporary copy. The rename changes inode identity and does not
retarget other hard links. If the final directory flush fails, the rename has
already committed and the API reports that distinct durability error.
Sibling-copy creation also requires write access to the parent directory.
Security-scoped URLs must already be accessed by the caller; App Sandbox and
code-signing behavior are integration responsibilities.

TagLib parser and mutation work is protected by a process-wide recursive mutex.
Copying, flushing, and renaming occur outside that mutex. Calls on independent
files are safe, but callers must serialize mutations to the same canonical path
when operation order matters.

## Format evidence

The registry contains 22 families and 37 extensions.

| Level | Families/extensions |
| --- | --- |
| Verified | MP3, M4A, FLAC, Ogg Vorbis (`ogg`), Ogg FLAC (`oga`), WAV, raw AAC, FastTracker XM |
| Experimental | S3M, Impulse Tracker |
| Read-only | MOD family and Shorten |
| Upstream-supported | Untested aliases and the remaining TagLib families, including Opus, Speex, APE, WavPack, Musepack, AIFF, TrueAudio, ASF/WMA, DSF, and DSDIFF |

Verified means the repository has a licensed fixture and relevant read/write
round-trip regression coverage. It does not imply that every alias or every
container-specific field has been tested. Query `FormatCapability` for the
extension and field in question rather than hard-coding this summary.

Fixture origins and hashes are recorded in
[Tests/TagLibAudioMetadataTests/Audio/README.md](Tests/TagLibAudioMetadataTests/Audio/README.md).

## Architecture and verification

The package deliberately exposes two products:

| Product | Module | Purpose |
| --- | --- | --- |
| `TagLibAudioMetadata` | `TagLibAudioMetadata` | Stable Swift facade and application models |
| `TagLibAudioMetadataLowLevel` | `CTagLibBridge` | Explicit advanced Objective-C bridge access |

The binary framework is named `TagLibAudioMetadataTagLib`, with install name
`@rpath/TagLibAudioMetadataTagLib.framework/TagLibAudioMetadataTagLib`, to avoid
colliding with a generic `TagLib.framework`. Public headers expose no C++ types.
The dynamic framework still exports TagLib C++ symbols, so loading another
incompatible TagLib C++ implementation into the same process remains an ABI
risk.

The current acceptance matrix passes 62 tests, strict warnings-as-errors,
Address Sanitizer, Thread Sanitizer, both facade and low-level consumer
packages, a dynamic-link/bundle audit, and builds for macOS arm64/x86_64, iOS
arm64, and iOS Simulator arm64/x86_64.

See [Architecture](docs/ARCHITECTURE.md), [Support](docs/SUPPORT.md),
[Thread safety](docs/THREAD_SAFETY.md), and the
[migration report](docs/MIGRATION_REPORT.md) for detailed contracts and
remaining risks.

## License

The Swift facade and Objective-C++ bridge are MIT licensed. The distributed
TagLib library is available under LGPL-2.1 or MPL-1.1, and utf8cpp under the
Boost Software License 1.0. Exact license texts and source revisions are in
[Third-party notices](docs/THIRD_PARTY_NOTICES.md).
