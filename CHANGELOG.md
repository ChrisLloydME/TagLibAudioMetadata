# Changelog

All notable changes to this package are documented here.
Versions follow [Semantic Versioning](https://semver.org/).

---

## [Unreleased] - 2026-05-27

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
- ID3v2 direct frame parsing extended: `MVIN`, `MVC`, `TSST`, `TOAL`, `TOPE`.

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
