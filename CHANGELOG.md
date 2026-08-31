# Changelog

All notable changes to this package are documented here.
Versions follow [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

### Added

- Added `MetadataSnapshot` and `MetadataPatch` for one-session comprehensive
  reads and omission-safe, verified partial edits.
- Added evidence-based format support levels and fixture-backed Ogg FLAC and XM
  round-trip coverage.
- Added the explicit `TagLibAudioMetadataLowLevel` product and cross-language
  metadata-schema consistency tests.
- Added schema-aware typed patch validation and a typed
  `committedButDurabilityUncertain` post-rename transaction outcome.
- Added container-native Patch mutation for MP4 track/disc pairs and advisory
  values, plus schema-aware custom-key and numeric constraint validation.

### Changed

- Upgraded the published dynamic binary from TagLib 2.1.1 to 2.3.1 and
  namespaced its framework, install name, bundle identifier, headers, and module
  map.
- Removed nested facade transactions so edits use one staging copy, and unified
  basic/raw/structured extraction into one TagLib session.
- Added selective projection extraction and consolidated Basic/PropertyMap
  post-write verification into one parser session.
- Split PropertyMap preservation extraction from raw ID3 frame enumeration so
  Basic reads and ordinary verification avoid unused raw-frame construction.
- Narrowed the process-wide lock to TagLib object lifetimes and moved transaction
  filesystem work outside it.
- Split the bridge transaction coordinator into a dedicated Objective-C++
  translation unit and centralized dual-version TagLib header selection.

### Fixed

- Preserved rich metadata omitted from basic writes, including raw multi-values,
  structured entries, artwork MIME information, and three-state advisory data.
- Preserved untouched standard multi-value fields during Basic writes without
  splitting normalized display strings, and made patch Boolean false distinct
  from field removal.
- Preserved schema-known fields outside `BasicMetadata`, defined Basic custom-key
  absence as preservation rather than deletion, and made preservation provenance
  caller read-only.
- Preserved omitted MP4 track/disc pair components, updated track totals in the
  native pair, and prevented contradictory native/freeform advisory values.
- Separated semantic equality from ephemeral UI identity and rejected numeric
  overflow at bridge boundaries.
- Flushed committed directory entries and reported post-rename durability
  failures without claiming rollback.

## [0.4.5] - 2026-08-27

### Fixed

- Serialized all Objective-C++ entry into TagLib to prevent concurrent M4A
  imports from racing TagLib 2.1.1's lazily initialized global MP4 item maps.
- Added a 12-worker, six-file M4A read stress test covering 300 facade reads.
- Audited equivalent mutable global state in ID3v2, RIFF/WAV, ASF/WMA, common
  handlers, and FileRef; documented the package concurrency contract and added
  concurrent cross-format read/write regression coverage.
- Kept mutex acquisition inside every Objective-C++ exception boundary so lock
  failures are converted to the established NSError or safe-return behavior.

---

## [0.4.4] - 2026-07-28

### Changed

- Completed the checksum-pinned TagLib binary release workflow and pointed the
  package manifest at the published immutable XCFramework asset.
- Prevented binary-release-only changes from unnecessarily triggering the main
  package CI workflow.

---

## [0.4.3] - 2026-07-25

### Added

- Added public-API compatibility regression tests for the Objective-C selector
  surface and the Swift facade's existing model nesting and write-result types.
- Added coverage for verification rollback, read-only capability schemas, raw
  merge preservation, structured ID3v2 chapter/table-of-contents/podcast
  round trips, unsigned ASF values, and concurrent destination changes.
- Added strict warning builds, a five-target Apple platform matrix, a remote
  SemVer consumer check, and release-archive slice validation to CI.

### Changed

- Moved the TagLib XCFramework out of the source repository and into a
  checksum-pinned GitHub Release asset that is immutable by project policy.
- Added a single version configuration and release workflow so future TagLib
  upgrades rebuild, verify, and publish the Apple binary independently from the
  Swift package source.
- Split the 8,000-line Objective-C++ bridge and 2,600-line Swift manager into
  focused implementation files without changing the compiled bridge translation
  unit or public headers and signatures.
- Strengthened mutation identity checks with size and nanosecond modification
  and change times, including the interval between the Swift facade's two read
  snapshots.

### Fixed

- Preserved untouched multi-value fields when applying raw property-map merges.
- Kept structured container advisories visible without treating them as failed
  read-back verification under `failurePolicy: .throw`.
- Added structured write and verification support for ID3v2 `CHAP`, `CTOC`, and
  `PCST` frames, including validation of unsigned numeric bounds.
- Preserved the full unsigned 64-bit range for ASF QWord attributes and rejected
  numeric overflow instead of passing values through signed `NSInteger`.
- Returned the established unsupported-format error for erase requests against
  non-writable formats and stopped advertising storable schemas for read-only
  formats.
- Prevented manual binary-release runs from publishing a branch commit under an
  unrelated tag; the workflow now verifies the requested tag and peeled commit.

---

## [0.4.2] - 2026-07-25

### Fixed

- Packaged the macOS TagLib framework with the required versioned bundle
  layout so Xcode application validation accepts embedded copies.

---

## [0.4.1] - 2026-07-25

### Fixed

- Declared the vendored TagLib XCFramework directly in the root package so
  tagged and revision-based remote SwiftPM consumers can resolve the package.

---

## [0.4.0] - 2026-07-24

### Added

- Added `StructuredMetadataReplaceableCollection` and the `replacingCollections`
  argument to structured writes so callers can explicitly remove the final
  artwork, lyrics, or comment entry with an empty collection.
- Added typed chapter and table-of-contents fields to `StructuredID3v2Frame`,
  including element IDs, timing/offset values, child IDs, ordering flags, and
  embedded-frame counts.
- Added registry consistency tests and broader fixture coverage for advanced
  fields, structured artwork, boolean atoms, malformed APE items, and direct
  bridge mutation failures.

### Changed

- Structured MP4 and ASF writes now apply top-level artwork collections,
  including multiple images and explicit removal.
- Structured post-write verification now compares typed values and collection
  cardinality instead of accepting key-only or count-only matches.
- Swift and bridge mutation coordinators now reject symbolic-link destinations,
  validate transactional copies, and refuse to commit if the destination file
  identity changed during the operation.
- Xiph extraction now uses the shared guarded PropertyMap reader instead of a
  duplicate unchecked parser.

### Fixed

- Fixed ID3v2 movement numbering by storing movement number and count together
  in the valid `MVIN` frame (for example, `2/4`) instead of using the invalid
  three-character `MVC` identifier.
- Fixed structured MP4 boolean writes so textual true/false values preserve the
  requested value.
- Fixed extended `BasicMetadata` verification and round trips for release,
  work, people, ReplayGain, iTunes, MusicBrainz, AcoustID, movement, BPM, and
  compilation fields.
- Fixed original release dates being reported as current release dates.
- Fixed structured MPEG saves to preserve ID3v2-only output without duplicating
  legacy tags.
- Fixed binary APE items using familiar text keys from being interpreted as
  text values.

---

## [0.3] - 2026-07-23

### Summary

This release is the initial public extraction of the TagLib bridge from the AudioMator app codebase into a standalone Swift Package. Every commit since the initial extraction (`5185e5d`) adds new API surface; nothing was removed from the pre-extraction internal bridge.

---

### Added

#### Documentation
- Added `docs/SUPPORT.md` as the current source-of-truth API guide, covering basic metadata, raw property maps, structured metadata, format capabilities, verification, erase behavior, field registry usage, bridge APIs, and practical integration recipes.
- Replaced the long README API reference with a concise project overview, installation instructions, quick-start examples, and links to the current support guide and license notes.

#### Format capability descriptors (`8ce60e96`)
- Added `FormatCapability` and `StructuredMetadataSupport` Swift APIs.
- Added `TagLibMetadataManager.formatCapability(for:)` and `formatCapabilities`.
- Added ObjC++ bridge capability dictionaries so readable/writable extension lists, support checks, and UI capability metadata are derived from one descriptor table.
- Added `MetadataFieldRegistry.schemas(withMappingsFor:)`, `schemas(storableIn:)`, and `schema(_:hasMappingFor:)`.
- Added unit tests that keep extension support, writable support, structured support caveats, and field schema filtering aligned with the capability table.
- Reduced repeated pure-PropertyMap write logic for tracker/module formats through a shared helper.

#### Fixture coverage (`8272d9f7`)
- Registered test audio and artwork resources in `Package.swift` so fixture-based tests run under SwiftPM.
- Added fixture round-trip tests across MP3, M4A, FLAC, AAC, OGG, and WAV.
- Added coverage for basic metadata writes and clears, artwork writes/removal, raw property map replace/merge behavior, multi-value property writes, structured metadata writes, and erase verification.

#### Format capability APIs (`53487c34`)
- `TagLibMetadataManager.isReadableFormat(_:) -> Bool`
- `TagLibMetadataManager.isWritableFormat(_:) -> Bool`
- `TagLibMetadataManager.readableExtensions: [String]`
- `TagLibMetadataManager.writableExtensions: [String]`
- Extended readable format set to include: `m4r`, `m4v`, `3g2`, `aifc`, `afc`, `dsdiff`, `shn`, `mod`, `module`, `nst`, `wow`, `s3m`, `it`, `xm`.
- `shn` (Shorten) is readable only — TagLib 2.1.1 does not support writing it.
- MOD-family formats (`mod`, `s3m`, `it`, `xm`) are now writable via the unified PropertyMap pipeline.
- `TagLibMetadataExtractor.isWritableFormat(_:)` and `writableExtensions()` added to the ObjC++ bridge header.

#### Verification and error handling (`18fa3357`)
- `TagLibMetadataManager.readMetadataResult(from:) throws -> BasicMetadata` — throwing read; replaces the optional-returning `readMetadata(from:)` at call sites that need error propagation.
- `TagLibManagerError.failedToReadWithUnderlying(String)` — new error case carrying the underlying description.
- `TagLibManagerError.verificationFailed([String])` — new error case carrying verification warning strings.
- `TagLibManagerError.failedToRead` — **deprecated**; use `failedToReadWithUnderlying(_:)`.
- `TagLibMetadataManager.RawPropertyMapWriteMode` — `.replace` (previous behavior) and `.merge` (read-modify-write on existing PropertyMap).
- `TagLibMetadataManager.VerificationFailurePolicy` — `.warn` (log only) or `.throw` (throw `verificationFailed`).
- `TagLibMetadataManager.MetadataWriteResult` — returned by all write functions; carries `warnings: [String]`.
- `TagLibMetadataManager.MetadataWriteVerificationContext` — explicit expectations for post-write reads.
- `TagLibMetadataManager.ArtworkVerificationExpectation` — `.unchanged`, `.present`, `.absent`.
- `writeMetadataWithVerification(_:to:failurePolicy:) throws -> MetadataWriteResult`
- `writeTagMetadata(_:to:verification:failurePolicy:) throws -> MetadataWriteResult`
- `writeTrackNumberText(_:discNumberText:to:verifyAfterWrite:failurePolicy:) throws -> MetadataWriteResult`
- `writeRawMetadataPropertyMapWithVerification(_:to:mode:verifyAfterWrite:failurePolicy:) throws -> MetadataWriteResult`
- `eraseAllMetadataWithVerification(from:failurePolicy:) throws -> MetadataWriteResult`
- `rawMetadataResult(from:) throws -> RawMetadataDump`
- Normalized exact-match key aliasing in `rawContainsCustomKey` (replaces previous fuzzy `contains` match).

#### Extended `BasicMetadata` fields (`583e93ac`)
New fields added to `BasicMetadata` and `TagLibAudioMetadata`:
- `musicBrainzAlbumArtistID`, `musicBrainzReleaseTrackID`, `musicBrainzWorkID`
- `acoustIDFingerprint`, `musicIPPUID`
- `asin`, `releaseStatus`, `originalAlbum`, `originalArtist`
- `discSubtitle`, `work`, `movementNumber`, `movementCount`
- ID3v2 direct frame parsing extended: `MVIN`, `TSST`, `TOAL`, `TOPE`.

#### Metadata field schema (`9b19fe52`)
- `MetadataFieldKey` — exhaustive enum of all known field identifiers (80+ values).
- `MetadataFieldCategory` — categorises fields for UI grouping.
- `MetadataFieldFormat` / `MetadataFieldStorageKind` / `MetadataFormatMapping` — per-format storage descriptors.
- `MetadataFieldSchema` — per-field descriptor with display name, property map keys, format mappings, and flags (`isMultiValue`, `isPeopleField`, `isRoleQualified`, `isArtworkField`).
- `MetadataFieldRegistry` — static lookup tables (`allSchemas`, `schemasByKey`, `canonicalPropertyMapKeys`, `multiValuePropertyMapKeys`, `peoplePropertyMapKeys`).
- `MetadataFieldRegistry.schema(for:)` and `schema(forPropertyMapKey:)` lookups.
- `MetadataFieldRegistry.shouldDisplayRawPropertyAsMultiValue(_:)`.
- `RawPropertyEntry.schema` and `RawPropertyEntry.shouldDisplayAsMultiValue` — schema helpers on the raw dump model.
- Table-driven ID3v2 and MP4 write helpers in the ObjC++ bridge (`ApplyWritableTextMappingsToID3v2Tag`, `ApplyWritableTextMappingsToMP4Tag`).
- `KnownMetadataFieldKeys()` now derived from the mapping table.

#### Structured metadata APIs (`06f447be`)
- `readStructuredMetadataResult(from:) throws -> StructuredMetadata`
- `readStructuredMetadata(from:) -> StructuredMetadata?`
- `writeStructuredMetadataWithVerification(_:to:riffPolicy:includeProperties:verifyAfterWrite:failurePolicy:) throws -> MetadataWriteResult`
- `writeRawMetadataPropertyMapValuesWithVerification(_:to:verifyAfterWrite:failurePolicy:) throws -> MetadataWriteResult` — multi-value PropertyMap write; preserves Xiph/Vorbis multi-value fields instead of collapsing to a semicolon-joined string.
- New Swift model types: `StructuredMetadata`, `StructuredPropertyEntry`, `StructuredID3v2Frame`, `StructuredMP4Atom`, `StructuredASFAttribute`, `StructuredArtwork`, `StructuredLyrics`, `StructuredComment`.
- `RIFFMetadataWritePolicy` — `.id3v2Only`, `.preserveInfo` (default), `.syncBasicFieldsToInfo` (documented, not yet applied; emits a warning).
- `MetadataValueSource` and `MetadataFieldProvenance` — track where track number text, disc number text, explicit flag, and artwork were sourced from.
- ID3v2 structured read extended: `UFID`, `WXXX`/URL frames, `COMM`, `USLT`, `APIC`, `CHAP`, `CTOC`, `PCST`.
- ID3v2 structured write: text/`TXXX`, `UFID`, `WXXX`/URL, `COMM`, `USLT`, `APIC`.
- MP4 typed atom read/write for common iTunes atoms; unknown freeform atoms preserved by default.
- ASF typed attribute read/write including `WM/Picture` artwork.
- FLAC/Xiph structured artwork reading.
- WAV write updated to `ID3v2` with `StripNone` to preserve existing RIFF INFO chunks.
- ObjC++ bridge: `structuredMetadata(for:)` and `writeStructuredMetadata(_:to:)` added.
- ObjC++ bridge: `writeRawPropertyMapValues(_:to:)` added for multi-value PropertyMap writes.

### Changed

- Consolidated stale and overlapping documentation into `docs/SUPPORT.md`.
- `writeMetadata(_:to:) throws -> Bool` — now internally calls `writeMetadataWithVerification`; warnings are printed rather than thrown by default. Return type and signature unchanged.
- `writeRawMetadataPropertyMap(_:to:mode:) throws -> Bool` — now internally calls `writeRawMetadataPropertyMapWithVerification`; warnings printed only.
- `eraseAllMetadata(from:) throws -> Bool` — now internally calls `eraseAllMetadataWithVerification`; warnings printed only.
- `rawContainsCustomKey` — matching changed from fuzzy `contains` to normalized exact match with explicit MP4 freeform prefix aliasing. Custom field verification results may differ for keys previously matched by substring.

### Fixed

#### Metadata write reliability (`8272d9f7`)
- Fixed MP3 and MP4 clear semantics so nil or empty `BasicMetadata` fields clear existing values instead of preserving stale metadata.
- Fixed `writeMetadataWithVerification` so `BasicMetadata.artworkData` is written through the bridge and verified after save.
- Fixed structured writes so including `properties` no longer prevents ID3v2 frames, MP4 atoms, artwork, comments, or lyrics from being applied.
- Expanded post-write verification to compare text fields and artwork presence, making incomplete writes easier to detect.

#### Metadata wipe reliability (`d7dcbc47`, `87a897ef`)
- Fixed MP4/M4A erase behavior by adding a native container-level strip path that removes leftover MP4 ItemMap atoms such as `atID`, `geID`, and `©pub`.
- Exposed `TagLibMetadataExtractor.wipeMetadata(from:)` through the bridge header for Swift erase flows.
- Extended `eraseAllMetadataWithVerification` to run a native wipe for MP3 and MP4-family formats after the standard clear flow.
- Strengthened native wipe support for FLAC, APE, WavPack, Musepack, WAV, TrueAudio, and DSDIFF, where clearing only the `PropertyMap` can leave residual container metadata.
- Kept generic empty-`PropertyMap` erase behavior for formats where TagLib clears the underlying storage through that path.

### Removed

- Removed outdated duplicate documentation files: `docs/API_OVERVIEW.md`, `docs/INTEGRATION_GUIDE.md`, `docs/INTEGRATION_NOTES.md`, `docs/METADATA_FIELDS.md`, `docs/SUPPORTED_FORMATS.md`, and `docs/TROUBLESHOOTING.md`.

### Deprecated

- `TagLibManagerError.failedToRead` — use `failedToReadWithUnderlying(_:)` at new call sites.

---

## [0.1.0] — 2026-04-25

Initial extraction of the TagLib bridge from AudioMator into a standalone Swift Package (`5185e5d`).

- `CTagLibBridge` target: TagLib 2.1.1 vendored source + ObjC++ bridge (`TagLibMetadataExtractor`).
- `TagLibAudioMetadata` target: Swift facade (`TagLibMetadataManager`, `BasicMetadata`, `RawMetadataDump`, `RawPropertyEntry`, `RawID3v2FrameEntry`).
- Initial supported formats: `mp3`, `mp2`, `aac`, `m4a`, `m4b`, `m4p`, `mp4`, `ogg`, `oga`, `opus`, `spx`, `flac`, `ape`, `wv`, `mpc`, `wma`, `asf`, `tta`, `wav`, `aiff`, `aif`, `dsf`, `dff`.
