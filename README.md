# TagLibAudioMetadata

`TagLibAudioMetadata` is a Swift package for reading, editing, verifying, and erasing audio metadata on macOS and iOS. A Swift facade is backed by an Objective-C++ bridge to a checksum-pinned, namespaced TagLib 2.3.1 XCFramework.

The package exposes normalized common tags, container-aware ID3v2, MP4, ASF, Xiph, APE, FLAC, and RIFF metadata, artwork, MusicBrainz and AcoustID identifiers, ReplayGain, and raw multi-value `PropertyMap` data. It is a semantic metadata editor, not a lossless native-tag archive: metadata the package does not expose may still survive because TagLib saves the native tag, but byte-for-byte reconstruction is not promised.

## At a glance

| Topic | Summary |
| --- | --- |
| Platforms | macOS 13+, iOS 16+, Swift tools 6.0, GNU C++20 |
| Products | `TagLibAudioMetadata` (Swift facade) and `TagLibAudioMetadataLowLevel` (`CTagLibBridge`) |
| Format coverage | 22 families and 37 extensions; query `FormatCapability` rather than hard-coding the matrix |
| Reads | Basic, raw `PropertyMap`, structured container models, and an optional audio-content identity |
| Writes | Typed patches, Basic replacement/update, raw deltas, whole-map replacement/merge, structured writes, and verified erase |
| Commit model | Sibling staging copy, atomic rename, file and parent-directory sync; process-local coordination only |

## Requirements

- Swift tools 6.0
- macOS 13 or later
- iOS 16 or later
- An Xcode toolchain with GNU C++20 support
- Network access on first resolution to fetch the pinned binary release

## Installation

```swift
dependencies: [
    .package(
        url: "https://github.com/ChrisLloydME/TagLibAudioMetadata.git",
        from: "0.5.0"
    )
]
```

The range selects the newest compatible tagged release. The latest tag at the time of writing is `0.5.3`; release history is in the [changelog](CHANGELOG.md). Production dependencies should select a tag or an exact revision.

Most targets need only the facade product:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "TagLibAudioMetadata", package: "TagLibAudioMetadata")
    ]
)
```

Targets that name bridge types must also declare the low-level product and import its module:

```swift
.product(name: "TagLibAudioMetadataLowLevel", package: "TagLibAudioMetadata")
```

```swift
import CTagLibBridge
```

The facade does not re-export bridge declarations. The TagLib binary is a dynamic framework: the final app or archive must embed and sign `TagLibAudioMetadataTagLib.framework` and resolve `@rpath/TagLibAudioMetadataTagLib.framework/TagLibAudioMetadataTagLib`. See [Installation](docs/INSTALLATION.md) for slices, binary identity, offline builds, and diagnostics.

## Quick start

Read one coherent snapshot instead of opening the file three times:

```swift
import TagLibAudioMetadata

let url = URL(fileURLWithPath: "/path/to/song.flac")
let snapshot = try TagLibMetadataManager.readSnapshot(from: url)

print(snapshot.basic.title)
print(snapshot.raw.properties)
print(snapshot.structured.artwork)
```

Apply only explicitly requested changes:

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
    expectedVersion: snapshot.fileVersion
)

print(result.commitStatus)
for warning in result.warnings {
    print(warning)
}
```

Fields absent from a patch are unchanged; `.remove` is the explicit deletion request. Do not mix typed track/disc fields with `numberText` in one patch. Verification mismatches throw before commit; a successful result carries only residual container advisories.

For a Basic read/modify/write, use `updateBasicMetadata(at:_:)`, which captures a version and rejects a stale edit. `replaceBasicMetadata` replaces the complete modeled Basic projection, so empty/default fields clear values. The older `writeMetadata` and `writeMetadataWithVerification` names are deprecated because replacement semantics were easy to mistake for a partial update.

Check capability evidence before enabling controls:

```swift
let capability = try TagLibMetadataManager.probeFile(at: url)
print(capability.supportLevel)
print(capability.writeSupport(for: .artwork))
```

`probeFile` validates readability with the selected parser; it does not test POSIX write permission, ACLs, disk space, or sandbox access. Use `capability(forExtension:)` only for declared-format discovery when no file exists yet.

## What the write APIs guarantee

Verified facade writes:

1. reject final symlinks, hard-linked files, setuid/setgid files, and non-regular paths;
2. stage one sibling copy on the same volume, using a copy-on-write clone when available and an ordinary copy otherwise;
3. mutate and, for verified APIs, compare the requested metadata on that copy;
4. request `F_FULLFSYNC` on the copy (falling back to `fsync` where the filesystem rejects it), recheck the destination identity, atomically rename, and sync the parent directory.

A failure before rename leaves the original path and bytes unchanged and removes the temporary copy. If the final directory sync fails after rename, the write has already committed; high-level APIs report `MetadataWriteResult.commitStatus == .durabilityUncertain(...)`. `.durable` means the requested OS-level flush completed, not a hardware or power-loss guarantee.

Snapshot reads capture a `MetadataFileVersion`; pass it as `expectedVersion` to reject a stale edit. TagLib parser and mutation work is serialized by a process-wide recursive mutex, and same-entry transactions are serialized by a directory-identity/name lock shared by the facade and bridge. This is **process-local coordination, not cross-process exclusion**. An external writer can still race the final identity check and rename. See [Transactions and concurrency](docs/TRANSACTIONS.md).

`MetadataPatch` and `RawMetadataPatch` are omission-safe deltas. Raw APIs use prefixless TagLib `PropertyMap` keys; native MP4 `----:` atom identifiers must go through `StructuredMetadata.mp4Atoms`. Neither delta comparison is a lossless oracle for opaque native metadata that TagLib does not expose. See [Write semantics](docs/PRESERVATION.md).

## Format evidence

The capability registry contains 22 families and 37 extensions. `fixtureCovered` means the repository contains a fixture and regression coverage for that extension; it does not mean every field, alias, codec variant, or platform works.

| Evidence level | Families / extensions |
| --- | --- |
| Fixture-covered | MP3 (`mp3`), M4A (AAC and ALAC fixtures), FLAC, Ogg Vorbis (`ogg`), Ogg FLAC (`oga`), WAV, raw AAC (`aac`), FastTracker XM, TrueAudio (`tta`), WavPack (`wv`), ASF/WMA (`wma`), APE (`ape`), Musepack (`mpc`), DSF (`dsf`), DSDIFF (`dff`), Opus (`opus`) |
| Experimental | S3M and Impulse Tracker (`s3m`, `it`); title/comment writes only |
| Read-only | MOD (`.mod`, `.module`, `.nst`, `.wow`) and Shorten (`shn`) |
| Upstream-supported (unverified here) | Remaining aliases and families, including AIFF/AIFF-C, Speex, and less-common MP4 extensions |

AIFF/AIFF-C has a generated PCM fixture and focused tests, but its configured family label remains `upstreamSupported`. Query `FormatCapability` for the extension and field in question rather than hard-coding this table. Fixture provenance and hashes are in [Tests/TagLibAudioMetadataTests/Audio/README.md](Tests/TagLibAudioMetadataTests/Audio/README.md).

## Audio-content continuity

Opt-in audio identities help a consumer distinguish a metadata-only conflict from replaced audio:

```swift
let baseline = try TagLibMetadataManager.readSnapshot(
    from: url,
    includingAudioContent: true
)

// Later, compare non-nil baseline.audioContentIdentity with a fresh snapshot,
// then commit with both guards:
try TagLibMetadataManager.applyMetadataPatch(
    patch,
    to: url,
    expectedVersion: currentVersion,
    expectedAudioContent: originalAudio
)
```

Availability is limited to WAV, AIFF/AIFF-C, and native FLAC. WAVE `bext` and `iXML` are excluded because TagLib may relocate them during a metadata save; other ancillary edits can change the token. Two missing identities never establish continuity. Other formats require an explicit reload. See [Audio-content continuity](docs/AUDIO_CONTENT_CONTINUITY.md).

## Documentation

Start at the [documentation hub](docs/README.md), which maps tasks to the canonical document for each topic. The source code and `Package.swift` are the final authority for behavior and dependency identity; current documents describe the code at the revision you are reading, while [engineering records](docs/records/README.md) are immutable evidence about past revisions.

| Topic | Document |
| --- | --- |
| Documentation hub and ownership | [docs/README.md](docs/README.md) |
| Installation, binary identity, signing | [docs/INSTALLATION.md](docs/INSTALLATION.md) |
| Task-based API guide and recipes | [docs/USAGE.md](docs/USAGE.md) |
| Complete Swift API reference | [docs/API_REFERENCE.md](docs/API_REFERENCE.md) |
| Field registry and container mappings | [docs/FIELD_SCHEMA.md](docs/FIELD_SCHEMA.md) |
| Public Objective-C bridge | [docs/BRIDGE.md](docs/BRIDGE.md) |
| Format capability and limitations | [docs/FORMATS.md](docs/FORMATS.md) |
| Preservation, omission, and verification | [docs/PRESERVATION.md](docs/PRESERVATION.md) |
| Transactions, durability, thread safety | [docs/TRANSACTIONS.md](docs/TRANSACTIONS.md) |
| Audio-content identity and rebasing | [docs/AUDIO_CONTENT_CONTINUITY.md](docs/AUDIO_CONTENT_CONTINUITY.md) |
| Architecture and source layout | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| Testing and evidence limits | [docs/TESTING.md](docs/TESTING.md) |
| Current validation status | [docs/STATUS.md](docs/STATUS.md) |
| Compatibility and migration | [docs/MIGRATION.md](docs/MIGRATION.md) |
| Development and maintenance | [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) |
| Historical audits, reviews, remediation | [docs/records/README.md](docs/records/README.md) |

The CI configuration covers documentation checks, strict warnings-as-errors, tests, release builds, AddressSanitizer, ThreadSanitizer, minimum-platform compilation, consumers, and a dynamic-link audit. Configured jobs are not evidence that an unrun commit passed. The latest observed validation state, including the environment-dependent privilege-bit caveat, is in [Status](docs/STATUS.md). Historical assessments are preserved as records and are not current merge decisions.

## License

The Swift facade and Objective-C++ bridge are MIT licensed. The distributed TagLib library is available under LGPL-2.1 or MPL-1.1, and utf8cpp under the Boost Software License 1.0. Exact texts and source revisions are in [Third-party notices](docs/THIRD_PARTY_NOTICES.md).
