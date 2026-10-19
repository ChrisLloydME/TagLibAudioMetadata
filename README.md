# TagLibAudioMetadata

`TagLibAudioMetadata` is a Swift package for reading, editing, verifying, and erasing audio metadata on macOS and iOS. Applications use a Swift facade; an Objective-C++ bridge links a checksum-pinned, namespaced TagLib 2.3.1 XCFramework.

The package supports common tags, artwork, MusicBrainz and AcoustID identifiers, ReplayGain, raw multi-value PropertyMap data, and container-aware ID3v2, MP4, ASF, Xiph, APE, FLAC, and RIFF metadata. It is a semantic metadata editor, not a lossless native-tag archive.

## Requirements

- Swift tools 6.0
- macOS 13+
- iOS 16+
- Xcode toolchain with GNU C++20 support
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

The range selects the newest compatible tagged release. The latest tag at the time of writing is `0.5.3`; see the [changelog](CHANGELOG.md) for release history. APIs described under `[Unreleased]` are on `main` and are not part of a tag yet; select `main` or an exact revision deliberately when evaluating them. Production dependencies should use a tag.

Most targets need only the facade:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "TagLibAudioMetadata", package: "TagLibAudioMetadata")
    ]
)
```

Advanced clients that directly use the bridge must also declare the low-level product and import `CTagLibBridge`:

```swift
.product(name: "TagLibAudioMetadataLowLevel", package: "TagLibAudioMetadata")
```

Starting in 0.5, the facade does not re-export bridge declarations. The public bridge exposes transactional mutators; package-internal in-place primitives are not a supported product.

The binary is a dynamic framework. The final app or archive must embed and sign `TagLibAudioMetadataTagLib.framework` and resolve `@rpath/TagLibAudioMetadataTagLib.framework/TagLibAudioMetadataTagLib`. SwiftPM links it; your app target owns embedding and signing. See [Installation](docs/INSTALLATION.md) for slices, binary identity, offline builds, and diagnostics.

## Quick start

Read a coherent snapshot:

```swift
import TagLibAudioMetadata

let url = URL(fileURLWithPath: "/path/to/song.flac")
let snapshot = try TagLibMetadataManager.readSnapshot(from: url)

print(snapshot.basic.title)
print(snapshot.raw.properties)
print(snapshot.structured.artwork)
```

`MetadataSnapshot` is a comprehensive semantic snapshot, not a lossless native serialization. Supported multi-value and container-specific data are retained; unknown or opaque native frames/atoms may be summarized rather than exposed as reconstructable payloads.

Apply only the requested changes:

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

Omitted fields are unchanged. `.remove` is the explicit deletion request. Verification mismatches throw before commit; warnings are non-fatal container advisories. Use either typed track/disc fields or `numberText` in one patch, not both.

For a Basic read/modify/write workflow, use `updateBasicMetadata(at:_:)`; it captures a version and rejects a stale edit. `replaceBasicMetadata` replaces the complete modeled Basic projection, so empty/default fields clear values. The older `writeMetadata` and `writeMetadataWithVerification` names are deprecated because replacement semantics were easy to mistake for a partial update.

Check capability evidence before enabling controls:

```swift
let capability = try TagLibMetadataManager.probeFile(at: url)
print(capability.supportLevel)
print(capability.writeSupport(for: .artwork))
```

`probeFile` validates readability with the selected parser; it does not test POSIX write permission, ACLs, disk space, or sandbox access. Use `capability(forExtension:)` only for declared-format discovery where no file exists yet.

## Reliability contract

Transactional facade and public bridge writes:

1. reject final symlinks, hard-linked files, setuid/setgid files, and non-regular paths;
2. create one sibling, same-volume copy-on-write clone when supported, with an ordinary-copy fallback;
3. mutate the copy; verified facade APIs compare requested metadata, while direct bridge mutators check only that the staged file remains readable;
4. request `F_FULLFSYNC` on the copy (falling back to `fsync` where the filesystem rejects it), recheck destination identity, atomically rename, and sync the parent directory.

A failure before rename leaves the original pathname and bytes unchanged and removes the temporary copy. If the final directory flush fails, the rename has already committed; high-level writes return `MetadataWriteResult.commitStatus == .durabilityUncertain(...)`. `.durable` means the requested OS-level flush completed, not a hardware or power-loss guarantee.

Reads capture a `MetadataFileVersion`; pass it as `expectedVersion` to reject a stale edit. TagLib parser and mutation work is serialized by a process-wide recursive mutex, and same-entry transactions are serialized by a directory-identity/name lock shared by the facade and bridge. This is **process-local coordination, not cross-process exclusion**. An external writer can still race the final identity check and rename. See [Transactions and concurrency](docs/TRANSACTIONS.md).

`MetadataPatch` and `RawMetadataPatch` are omission-safe deltas. Raw APIs use prefixless TagLib PropertyMap keys; native MP4 `----:` atom identifiers must go through `StructuredMetadata.mp4Atoms`. Neither delta comparison is a lossless oracle for opaque native metadata that TagLib does not expose.

## Format evidence

The capability registry contains 22 families and 37 extensions. A `fixtureCovered` label means the repository has a fixture and regression coverage for that extension, not that every field, alias, codec variant, or platform works.

| Evidence level | Families / extensions |
| --- | --- |
| Fixture-covered | MP3, M4A (AAC and ALAC fixtures), FLAC, Ogg Vorbis (`ogg`), Ogg FLAC (`oga`), WAV, raw AAC, FastTracker XM, TrueAudio, WavPack, ASF/WMA, APE, Musepack, DSF, DSDIFF, Opus |
| Experimental | S3M, Impulse Tracker |
| Read-only | MOD (`.mod`, `.module`, `.nst`, `.wow`) and Shorten |
| Upstream-supported (unverified here) | Remaining aliases and families, including AIFF/AIFF-C, Speex, and less-common MP4 extensions |

AIFF/AIFF-C has a generated PCM fixture and focused tests, but its configured family label remains upstream-supported. Query `FormatCapability` for the extension and field in question rather than hard-coding this table. Fixture provenance and hashes are in [Tests/TagLibAudioMetadataTests/Audio/README.md](Tests/TagLibAudioMetadataTests/Audio/README.md).

## Audio-content continuity

Opt-in audio identities help a consumer distinguish a metadata-only conflict from replaced audio:

```swift
let baseline = try TagLibMetadataManager.readSnapshot(
    from: url, includingAudioContent: true
)

// Later, compare non-nil baseline.audioContentIdentity with a fresh snapshot,
// then commit with both guards:
try TagLibMetadataManager.applyMetadataPatch(
    patch, to: url,
    expectedVersion: currentVersion,
    expectedAudioContent: originalAudio
)
```

Availability is limited to WAV, AIFF/AIFF-C, and native FLAC. WAVE `bext` and `iXML` are excluded because TagLib may relocate them during a metadata save; other ancillary edits can change the token. Two missing identities never establish continuity. Other formats require explicit reload. See [Audio-content continuity](docs/AUDIO_CONTENT_CONTINUITY.md).

## Documentation

| Topic | Document |
| --- | --- |
| Documentation hub and navigation | [docs/README.md](docs/README.md) |
| Installation, binary identity, signing | [docs/INSTALLATION.md](docs/INSTALLATION.md) |
| Public API guide and recipes | [docs/USAGE.md](docs/USAGE.md) |
| Symbol-level API index | [docs/API_REFERENCE.md](docs/API_REFERENCE.md) |
| Format capability and limitations | [docs/FORMATS.md](docs/FORMATS.md) |
| Preservation and write semantics | [docs/PRESERVATION.md](docs/PRESERVATION.md) |
| Transactions, filesystem, thread safety | [docs/TRANSACTIONS.md](docs/TRANSACTIONS.md) |
| Architecture and source layout | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| Testing and verification guidance | [docs/TESTING.md](docs/TESTING.md) |
| Current validation status | [docs/STATUS.md](docs/STATUS.md) |
| Compatibility and migration | [docs/MIGRATION.md](docs/MIGRATION.md) |
| Development and maintenance | [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) |
| Historical audits, reviews, remediation | [docs/records/README.md](docs/records/README.md) |

The CI configuration covers strict warnings-as-errors, tests, release builds, AddressSanitizer, ThreadSanitizer, minimum-platform compilation, consumers, and a dynamic-link audit. Configured jobs are not evidence that an unrun commit passed. The latest observed validation state, including the command-line privilege-bit environment caveat, is in [Status](docs/STATUS.md). Historical assessments are preserved as records and are not current merge decisions.

## License

The Swift facade and Objective-C++ bridge are MIT licensed. The distributed TagLib library is available under LGPL-2.1 or MPL-1.1, and utf8cpp under the Boost Software License 1.0. Exact texts and source revisions are in [Third-party notices](docs/THIRD_PARTY_NOTICES.md).
