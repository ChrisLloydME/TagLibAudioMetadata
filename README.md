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

`MetadataSnapshot` is a comprehensive semantic snapshot, not a lossless native
serialization. Unsupported/opaque frames or atoms may be summarized rather than
retained as reconstructable payload bytes.

Apply only the requested changes while preserving everything else:

```swift
let patch = MetadataPatch(
    fields: [
        .title: .text("New Title"),
        .track: .integer(1),
        .trackTotal: .integer(12)
    ],
    customFields: ["APP_WORKFLOW": .values(["Focused", "Calm"])],
    explicitAdvisory: .clean,
    artwork: .unchanged
)

let result = try TagLibMetadataManager.applyMetadataPatch(
    patch,
    to: url,
    failurePolicy: .throw
)
```

Typed patch values are checked against `MetadataFieldRegistry` before staging.
Known keys and aliases are rejected in `customFields`; use `fields` (or a
dedicated patch property) for schema-known metadata. Unknown custom keys remain
available and are normalized before mutation. Track/disc numbers and totals
accept `1...INT_MAX`; use `.remove` to unset those components. Numeric fields
whose schema permits zero, such as BPM and movement numbering, accept
`0...INT_MAX`. Invalid values fail before a staging copy is made. Formats with
explicit field allowlists reject unsupported typed fields before mutation; Raw
APIs remain permissive.

Patch text and array elements are trimmed once before mutation, and verification
uses those same normalized values. Empty text, empty arrays, and arrays containing
empty elements are rejected; `.remove` is the only high-level deletion request.

The bridge applies requested PropertyMap changes to the current map in one
session; omitted keys are not rebuilt in Swift. For text-backed booleans,
`.boolean(false)` writes `"0"`, while `.remove` removes the key.

Track and disc numbers are container-aware. MP4/M4A patches update native
`trkn`/`disk` pairs and preserve an omitted number or total. Advisory patches
likewise update native MP4 `rtng` or the supported ID3 representation; they do
not create a contradictory freeform advisory. MP4 cleanup is limited to the
recognized aliases `ITUNESADVISORY`, `ADVISORY`, `EXPLICITCONTENT`, and
`EXPLICIT`.

Advisory metadata has four semantic states: `.unspecified` means the field is
absent, while `.notExplicit`, `.explicit`, and `.clean` mean a field is present.
Canonical MP4/M4A storage is respectively absent, `rtng = 0`, `rtng = 1`, and
`rtng = 2`, matching Apple/iTunes metadata. ID3 and generic PropertyMap formats
retain their established container-specific `ITUNESADVISORY` representation
using values `0`, `1`, and `2`. Legacy `4`, text `TRUE`/`YES`/`EXPLICIT`, and
`FALSE`/`NO`/`NONE`/`-1` remain readable; a high-level rewrite emits canonical
values. The compatibility Boolean `isExplicit` is intentionally lossy: use
`explicitAdvisory` whenever absence, not-explicit, and clean must remain distinct.

Basic MP4 advisory writes use the same canonical `rtng` helper and alias cleanup
as Patch writes, so switching between the two high-level APIs cannot leave a
contradictory recognized freeform advisory. ID3 movement number/count patches
likewise preserve the omitted component of native `MVIN`.

Generic PropertyMap formats store number and total separately as
`TRACKNUMBER`/`TRACKTOTAL` and `DISCNUMBER`/`DISCTOTAL`; ID3 retains combined
`TRCK`/`TPOS` text. Ordinary MP4 Patch or Basic writes do not create private
`AUDIOMATOR_*_TEXT` atoms. If such a formatting atom already exists, it is
formatting provenance: native `trkn`/`disk` remains authoritative, and a Basic
numeric edit synchronizes the private text while retaining its established
number padding. An unrelated Basic edit preserves the existing formatted text
unchanged. Use `writeTrackNumberText` when formatted number text itself is the
intentional input.

`BasicMetadata` remains a convenient normalized projection, but it is not a
lossless editing document. Values read from a file retain a separate raw
cardinality/provenance baseline, so unrelated Basic edits preserve untouched
standard multi-values, schema-known fields Basic cannot model, and custom fields
without splitting display strings on semicolons. Removing a key from
`BasicMetadata.customFields` is not a deletion tombstone; use
`MetadataPatchValue.remove` for explicit deletion.

For professional editors, read `MetadataSnapshot` and write
`MetadataPatch`, raw multi-value maps, or structured metadata. A basic
write has replacement semantics for fields Basic explicitly models: empty
strings and zero numeric values clear those fields where the container allows
it. Internal preservation provenance is readable but not caller-mutable.

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
already committed and the API throws
`TagLibManagerError.committedButDurabilityUncertain`; retrying may repeat an
already-committed operation.
Sibling-copy creation also requires write access to the parent directory.
Security-scoped URLs must already be accessed by the caller; App Sandbox and
code-signing behavior are integration responsibilities.

TagLib parser and mutation work is protected by a process-wide recursive mutex.
Objective-C projection objects copied directly from live TagLib values are also
built under that lock; Swift model conversion, copying, flushing, and renaming
occur outside it. Calls on independent
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

The current local acceptance matrix passes 94 tests, strict warnings-as-errors,
Address Sanitizer, Thread Sanitizer, and builds both facade and low-level
consumer packages. The published binary's broader platform and dynamic-link
matrix remains documented in the migration report.

See [Architecture](docs/ARCHITECTURE.md), [Support](docs/SUPPORT.md),
[Thread safety](docs/THREAD_SAFETY.md), and the
[migration report](docs/MIGRATION_REPORT.md) for detailed contracts and
remaining risks.

## License

The Swift facade and Objective-C++ bridge are MIT licensed. The distributed
TagLib library is available under LGPL-2.1 or MPL-1.1, and utf8cpp under the
Boost Software License 1.0. Exact license texts and source revisions are in
[Third-party notices](docs/THIRD_PARTY_NOTICES.md).
