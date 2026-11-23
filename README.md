# TagLibAudioMetadata

`TagLibAudioMetadata` is a Swift package for reading, editing, verifying, and erasing audio metadata on macOS and iOS. A Swift facade is backed by an Objective-C++ bridge to a checksum-pinned, namespaced TagLib 2.3.1 XCFramework.

The package exposes normalized common tags, container-aware ID3v2, MP4, ASF, Xiph, APE, FLAC, and RIFF metadata, artwork, MusicBrainz and AcoustID identifiers, ReplayGain, exact multi-value `PropertyMap` data, structured frames/atoms/attributes, automatic track/disc number resolution, and an explicit number-normalization API. It is a semantic metadata editor, not a lossless native-tag archive: metadata the package does not expose may still survive because TagLib saves the native tag, but byte-for-byte reconstruction is not promised.

> **Release status.** Version `0.8.1` (2026-11-17) is the current release. It is a patch release: no public signature was removed, mapping contract `AM-TLAM-MAPPING-2.2` and the TagLib 2.3.1-r2 binary are unchanged. It does change numbering behavior, so read [Migration](docs/operations/MIGRATION.md#migrating-from-0-8-0-to-0-8-1) before upgrading from `0.8.0`.

> **Documentation scope.** Current pages describe the development source. See [Migration](docs/operations/MIGRATION.md#unreleased-changes) for unreleased changes and the `0.8.1` tag for documentation matching the current release. The package-side `AM-TLAM-MAPPING-2.2` contract was introduced in `0.7.0`; `0.7.1` added date/ownership corrections; `0.7.2` finalized the audit, native-mapping, test-system and MP4 Content Group repairs; `0.7.3` added sparse native-owner preservation; `0.8.0` added the breaking API cleanup, public write-contract repairs and independent contract test system; `0.8.1` adds automatic numbering resolution, explicit-zero intent and fail-closed opaque recovery. Mapping contract 2.2 and its native target layouts are unchanged.

The `0.8.1` evidence is the recorded package-only Debug campaign at source `558df00`; the recorded gates, environment and limits are in [Status](docs/operations/STATUS.md), and the repair details are in the [numbering-contract record](docs/records/remediation/REM-2026-11-17-numbering-contract-repairs.md).

## At a glance

| Topic | Summary |
| --- | --- |
| Platforms | macOS 13+, iOS 16+, Swift tools 6.4, GNU C++20 |
| Products | `TagLibAudioMetadata` (Swift facade) and `TagLibAudioMetadataLowLevel` (`CTagLibBridge`) |
| Format coverage | 22 families and 37 extensions; query `FormatCapability` rather than hard-coding the matrix |
| Reads | Basic, raw `PropertyMap`, structured container models, numbering inventory, and an optional audio-content identity |
| Writes | Typed patches, Basic replacement/update, raw deltas, whole-map replacement/merge, structured writes, automatic number resolution, explicit number normalization, and verified erase |
| Commit model | Sibling staging copy, atomic rename, file and parent-directory sync; process-local coordination only |

## What changed in 0.8.1

Version `0.8.1` is a patch release. It changes numbering behavior without changing public signatures, the mapping-contract ID, or the TagLib binary.

- **Ordinary numbering edits resolve and clean up atomically.** Typed, Basic and `numberText` track/disc edits resolve an explicit component first, then the canonical native sibling, then an unambiguous legacy candidate. Recognized `AUDIOMATOR_*_TEXT` and `TAGLIBAUDIOMETADATA_*_TEXT` provenance of the edited group retires in the same staged transaction. Untouched groups, foreign namespaces and unrelated fields survive.
- **Explicit zero is intent.** `5/0`, and an empty total after a slash, store an explicit zero and never recover the previous total. Only an omitted total is resolved. The rule applies through the facade and direct bridge on MP4, ID3, FLAC, Ogg and APE/WavPack.
- **Opaque partial evidence fails closed.** Malformed or multi-value private evidence cannot supply a missing canonical component; typed and number-text writes reject with `ambiguousNumberRecovery` before staging. A valid native component remains authoritative, and a full explicit replacement still succeeds.
- **The contract lane grew with the repair.** The gate covers 36 contracts, 81 scenarios, 62 adapters, 97 policy regressions and 23 calibration mutants, with 306 Swift Testing declarations in 55 suites.
- **Scope.** Acceptance is package-only Debug at `558df00`; no Release lane, hosted CI, device run or application acceptance was performed for this source. See [Status](docs/operations/STATUS.md), [Migration](docs/operations/MIGRATION.md#migrating-from-0-8-0-to-0-8-1), and [Testing](docs/operations/TESTING.md).

## What changed in 0.8.0

Version `0.8.0` is a breaking release with no native mapping-contract change. Migration contract 2.2 and every registered native target remain in place.

- **Breaking API cleanup.** The typed `.date` YEAR alias, obsolete read/write and failure-policy overloads, old function-reference arities, Boolean advisory setters and verification expectations, and outdated capability/error aliases are removed. See [Migration](docs/operations/MIGRATION.md#migrating-from-0-7-3-to-0-8-0).
- **Public writers share native validation.** Scalar, whole-model, structured, and raw writes reject out-of-range native representations before staging. Whole-model writes preserve schema-known but unmodeled owners and private numbering provenance while modeled `nil` still removes values.
- **Legacy reads and date protection are stricter.** Legal ID3v2.3 frame-status flags and bounded grouping are read literally, DSDIFF `ID3` is located through declared `PROP` children, and WAV/AIFF saves retain the observed ID3 version. Existing v2.3 tags remain read-only for independent date changes.
- **Selective I/O and ownership boundaries.** Snapshots, storage identity, projection reads and transactions have explicit internal ownership, and unrequested native projections are skipped without caching concrete files.
- **The contract test system is canonical.** At `0.8.0`, `scripts/validate-contracts.sh` reconciled 907 public-surface rows against 34 contracts and 75 scenarios, executed 62 public adapters through independent native oracles, and required 13 calibrated defects to be detected before accepting the complete framework gate. `0.8.1` expands this to 36 contracts, 81 scenarios and 23 mutants.

The TagLib binary is unchanged from `0.7.3` (2.3.1-r2). Recorded package-only acceptance, sanitizer, consumer and minimum-platform evidence for `0.8.0` is in [Status](docs/operations/STATUS.md); release preparation changed documentation only. The 2026-11-15 [public write-contract repairs](docs/records/remediation/REM-2026-11-15-public-write-contract.md) and [contract-system acceptance](docs/records/remediation/REM-2026-11-15-test-system-acceptance.md) are the release's evidence.

## Earlier releases

Version `0.7.3` added sparse native-owner preservation across public write surfaces and low-level reads, including native MP4/ID3 date owners and ASF custom attributes. Version `0.7.2` finalized the audit, native-mapping, test-system and MP4 Content Group repairs; `0.7.1` corrected date/ownership and verification; `0.7.0` introduced mapping contract 2.2. Release notes are in the [changelog](CHANGELOG.md), and consumer-visible changes are in [Migration](docs/operations/MIGRATION.md).

## Requirements

- Swift tools 6.4
- macOS 13 or later
- iOS 16 or later
- An Xcode toolchain with GNU C++20 support
- Network access on first resolution to fetch the pinned binary release

## Installation

```swift
dependencies: [
    .package(
        url: "https://github.com/ChrisLloydME/TagLibAudioMetadata.git",
        from: "0.8.1"
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

Targets that name bridge types must also declare the low-level product and import its module:

```swift
.product(name: "TagLibAudioMetadataLowLevel", package: "TagLibAudioMetadata")
```

```swift
import CTagLibBridge
```

The facade does not re-export bridge declarations. The TagLib binary is a dynamic framework: the final app or archive must embed and sign `TagLibAudioMetadataTagLib.framework` and resolve `@rpath/TagLibAudioMetadataTagLib.framework/TagLibAudioMetadataTagLib`. See [Installation](docs/operations/INSTALLATION.md) for slices, binary identity, offline builds, and diagnostics.

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

Fields absent from a patch are unchanged; `.remove` is the explicit deletion request. `numberText` and typed track/disc fields may be mixed only across different pairs; both representations for the same pair are rejected. Number-text pairs are resolved and range-checked against the captured version before staging. Verification mismatches throw before commit; a successful result carries only residual container advisories.

Year, Date, Release Date, Original Release Date, and Purchase Date are independent. `.year` is the YEAR field; `.standaloneDate` is the independent DATE field. Version `0.8.0` removed the ambiguous typed `.date` alias. `.standaloneDate` writes DATE, and `.releaseDate` writes RELEASEDATE; no field is synthesized from another. On MP4, `©day` is YEAR and Release Date is a `RELEASEDATE` freeform extension. Existing ID3v2.3 tags are read-only for independent date edits; inspect `StructuredMetadata.id3v2MajorVersion` before offering them.

For a Basic read/modify/write, use `updateBasicMetadata(at:_:)`, which captures a version and rejects a stale edit. `replaceBasicMetadata` replaces the complete modeled Basic projection, so empty/default fields clear values. Version `0.8.0` removed the older `writeMetadata` and `writeMetadataWithVerification` aliases; see [migration](docs/operations/MIGRATION.md#migrating-from-0-7-3-to-0-8-0). `replaceBasicMetadata` uses the typed planner for every editable Basic field, including MP4-exclusive properties such as director and the TV/movement atoms. `.rate` remains read-only because no verified native rating scale exists. Unsupported fields/values still fail through the same capability and validation rules as `MetadataPatch`.

Check capability evidence before enabling controls:

```swift
let capability = try TagLibMetadataManager.probeFile(at: url)
print(capability.supportLevel)
print(capability.writeSupport(for: .artwork))
```

`probeFile` validates readability with the selected parser; it does not test POSIX write permission, ACLs, disk space, or sandbox access. `writeSupport` is a coarse declared check, not a typed-write promise; `MetadataFieldRegistry.schemas(storableIn:)` uses that same destination-aware policy (so XM lists title, comment and tracker name, and role-qualified fields are not advertised). Field-level `aggregateCapability` is a best-available summary across families, not a portability guarantee. Use `capability(forExtension:)` only for declared-format discovery when no file exists yet.

## What the write APIs guarantee

Verified facade writes:

1. reject final symlinks, hard-linked files, setuid/setgid files, and non-regular paths;
2. stage one sibling copy on the same volume, using a copy-on-write clone when available and an ordinary copy otherwise;
3. mutate and, for verified APIs, compare the requested metadata on that copy;
4. request `F_FULLFSYNC` on the copy (falling back to `fsync` where the filesystem rejects it), recheck the destination identity, atomically rename, and sync the parent directory.

A failure before rename leaves the original path and bytes unchanged and removes the temporary copy. If the final directory sync fails after rename, the write has already committed; high-level APIs report `MetadataWriteResult.commitStatus == .durabilityUncertain(...)`. `.durable` means the requested OS-level flush completed, not a hardware or power-loss guarantee.

Snapshot reads capture a `MetadataFileVersion`; pass it as `expectedVersion` to reject a stale edit. TagLib parser and mutation work is serialized by a process-wide recursive mutex, and same-entry transactions are serialized by a directory-identity/name lock shared by the facade and bridge. This is **process-local coordination, not cross-process exclusion**. An external writer can still race the final identity check and rename. See [Transactions and concurrency](docs/explanation/TRANSACTIONS.md).

Ordinary compatibility aliases of a track/disc pair (for example MP4 `TRACKTOTAL`/`DISCTOTAL` freeforms) may retire after an explicit edit of that pair, once their values are recovered into native `trkn`/`disk`. That cleanup is pair-scoped: untouched groups and both private `AUDIOMATOR_*_TEXT` and `TAGLIBAUDIOMETADATA_*_TEXT` namespaces survive ordinary writes. Recognized private provenance **of an edited group** also retires in the same transaction, which is the `0.8.1` behavior; untouched provenance is preserved. No default surface creates or renames these atoms, and the explicit, version-guarded normalization plan remains available for headless cleanup. See [Write semantics](docs/explanation/PRESERVATION.md#number-pairs-and-native-bounds).

`MetadataPatch` and `RawMetadataPatch` are omission-safe deltas. Raw APIs use prefixless TagLib `PropertyMap` keys; native MP4 `----:` atom identifiers must go through `StructuredMetadata.mp4Atoms`. Unchanged native date owners are restored across PropertyMap replay, including native absence, and a scalar projection does not authorize collapsing an existing native array. Neither delta comparison is a lossless oracle for opaque native metadata that TagLib does not expose. See [Write semantics](docs/explanation/PRESERVATION.md).

## Format evidence

The capability registry contains 22 families and 37 extensions. `fixtureCovered` means the repository contains a fixture and regression coverage for that extension; it does not mean every field, alias, codec variant, or platform works. The generated matrix is in [Formats](docs/reference/FORMATS.md).

| Evidence level | Families / extensions |
| --- | --- |
| Fixture-covered | MP3 (`mp3`), M4A (AAC and ALAC fixtures), FLAC, Ogg Vorbis (`ogg`), Ogg FLAC (`oga`), WAV, raw AAC (`aac`), FastTracker XM, TrueAudio (`tta`), WavPack (`wv`), ASF/WMA (`wma`), APE (`ape`), Musepack (`mpc`), DSF (`dsf`), DSDIFF (`dff`), Opus (`opus`) |
| Experimental | S3M and Impulse Tracker (`s3m`, `it`); title/comment writes only, tracker name readable |
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

Availability is limited to WAV, AIFF/AIFF-C, and native FLAC. WAVE `bext` and `iXML` are excluded because TagLib may relocate them during a metadata save; other ancillary edits can change the token. Two missing identities never establish continuity. Other formats require an explicit reload. See [Audio-content continuity](docs/explanation/AUDIO_CONTENT_CONTINUITY.md).

## Documentation

Start at the [documentation hub](docs/README.md), which maps tasks to the canonical document for each topic. The source code and `Package.swift` are the final authority for behavior and dependency identity; current documents describe the code at the revision you are reading, while [engineering records](docs/records/README.md) are immutable evidence about past revisions.

| Topic | Document |
| --- | --- |
| Documentation hub and ownership | [docs/README.md](docs/README.md) |
| Release history | [CHANGELOG.md](CHANGELOG.md) |
| Getting started | [docs/guide/GETTING_STARTED.md](docs/guide/GETTING_STARTED.md) |
| Reading metadata | [docs/guide/READING.md](docs/guide/READING.md) |
| Writing metadata | [docs/guide/WRITING.md](docs/guide/WRITING.md) |
| Capabilities and field support | [docs/guide/CAPABILITIES.md](docs/guide/CAPABILITIES.md) |
| Manager API (generated) | [docs/reference/API.md](docs/reference/API.md) |
| Models and errors (generated) | [docs/reference/MODELS.md](docs/reference/MODELS.md) |
| Field registry | [docs/reference/FIELDS.md](docs/reference/FIELDS.md) |
| Format matrix and limits | [docs/reference/FORMATS.md](docs/reference/FORMATS.md) |
| Public Objective-C bridge | [docs/reference/BRIDGE.md](docs/reference/BRIDGE.md) |
| Mapping contract and matrix | [docs/reference/MAPPING_SPEC.md](docs/reference/MAPPING_SPEC.md), [docs/reference/MAPPING_MATRIX.md](docs/reference/MAPPING_MATRIX.md) |
| Architecture | [docs/explanation/ARCHITECTURE.md](docs/explanation/ARCHITECTURE.md) |
| Preservation and verification | [docs/explanation/PRESERVATION.md](docs/explanation/PRESERVATION.md) |
| Transactions, durability, concurrency | [docs/explanation/TRANSACTIONS.md](docs/explanation/TRANSACTIONS.md) |
| Audio-content identity | [docs/explanation/AUDIO_CONTENT_CONTINUITY.md](docs/explanation/AUDIO_CONTENT_CONTINUITY.md) |
| Installation, binary identity, signing | [docs/operations/INSTALLATION.md](docs/operations/INSTALLATION.md) |
| Testing and evidence limits | [docs/operations/TESTING.md](docs/operations/TESTING.md) |
| Mapping test acceptance | [docs/operations/MAPPING_TEST_STRATEGY.md](docs/operations/MAPPING_TEST_STRATEGY.md) |
| Current validation status | [docs/operations/STATUS.md](docs/operations/STATUS.md) |
| Development and maintenance | [docs/operations/DEVELOPMENT.md](docs/operations/DEVELOPMENT.md) |
| Commit messages | [docs/operations/COMMIT_MESSAGES.md](docs/operations/COMMIT_MESSAGES.md) |
| Compatibility and migration | [docs/operations/MIGRATION.md](docs/operations/MIGRATION.md) |
| Third-party notices | [docs/operations/THIRD_PARTY_NOTICES.md](docs/operations/THIRD_PARTY_NOTICES.md) |
| Historical audits and reviews | [docs/records/README.md](docs/records/README.md) |
| Completed assignments and startup prompts | [docs/records/assignments/README.md](docs/records/assignments/README.md) |

The documentation pipeline generates the API, model, field, format, and mapping references from source. Run `python3 scripts/check-docs.py` before committing. CI covers documentation checks, strict warnings-as-errors, the contract lane (inventory/catalog reconciliation, 23-defect calibration, and the complete Debug or Release framework gate), release builds, AddressSanitizer, ThreadSanitizer, minimum-platform compilation, consumers, and a dynamic-link audit. Configured jobs are not evidence that an unrun commit passed. The latest observed validation state, including the environment-dependent privilege-bit caveat, is in [Status](docs/operations/STATUS.md).

## License

The Swift facade and Objective-C++ bridge are MIT licensed. The distributed TagLib library is available under LGPL-2.1 or MPL-1.1, and utf8cpp under the Boost Software License 1.0. Exact texts and source revisions are in [Third-party notices](docs/operations/THIRD_PARTY_NOTICES.md).
