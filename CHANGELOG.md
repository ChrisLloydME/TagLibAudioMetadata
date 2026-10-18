# Changelog

All notable changes to this package are documented here.
Versions follow [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

### Verification hardening — 2026-10-18

— Added pinned, independently decoded DSF, DSDIFF, APE, and Musepack fixtures;
  promoted their configured fixture coverage without expanding native write APIs.
- Added independent native ASF type/language/stream/artwork checks, encoded audio
  preservation across seven formats, and deterministic snapshot conflict tests.
- Fixed ASF WORD updates adding conflicting DWORD siblings; reject ambiguous
  widths and overflow. Unsupported GUID encoding now rejects before mutation.
- Persisted ASF totals in native number/total text pairs across normalized writers.
- Enabled and strengthened the corpus test with reproducible generated tones;
  measured snapshot/write/flush costs through the existing opt-in benchmark.
- Expanded legacy reader, erase, deprecated and version-aware source compilation.
- See `docs/VERIFICATION_HARDENING_2026-10-18.md` for evidence and limitations.

### Independent remediation verification — 2026-10-18

- Preserved omitted APE/ASF artwork in structured writes and retained native
  picture attributes during MIME corrections; APE back covers now report their
  correct role.
- Preserved complete Basic recording-date arrays/aliases and native ID3 comment
  and lyric languages/descriptions; intentional field edits clear stale aliases.
- Repaired Basic custom-field deletion and preserved unchanged native attributes
  whose names overlap the schema. Ambiguous new/edited custom names remain rejected.
- Kept typed WAV edits on ID3v2 while raw deltas retain key-ownership behavior;
  strengthened INFO tests with independently seeded title data. Added the missing
  native lock/exception boundary and checked final RIFF policy persistence.
- Rejected opaque ID3 frame edits and embedded NULs in Basic/bridge-model writes;
  validated total-only normalized requests on native number-pair paths.
- Normalized raw merge keys and rejected conflicting case variants.
- Preserved underlying native/filesystem errors with
  `operationFailedWithUnderlying` and `underlyingError`.
- Retained legacy writer function-reference signatures through forwarding
  overloads alongside version-aware APIs. `.warn` remains compilable and cannot
  permit an unverified commit.
- Added independent MP4 atom/audio checks, ASF sibling payload checks, constructed
  APE/ID3 inputs, and source-compatibility coverage. TrueAudio structured ID3
  collections now work and report `.container` support.
- See `docs/INDEPENDENT_REVIEW_2026-10-18.md` for per-finding evidence, exact
  verification results, limitations, and the merge assessment.

### Remediation — 2026-10-18

- Fixed structured `properties` writes to merge into the current PropertyMap
  instead of replacing omitted metadata; non-empty properties now require
  `includeProperties: true`, empty value arrays delete one key, and write
  verification compares the requested values.
- Fixed Basic round trips to preserve full recording dates, documented aliases
  (`PUBLISHER`, `CATALOG`, `ORIGINAL YEAR`, MusicBrainz space forms), qualified
  people keys, and multiple described comments/lyrics. ID3 no longer duplicates
  TDRC with legacy TYER or writes ID3v1 joined projections during an ID3v2 update.
- Rejected embedded NULs and role-qualified typed Patch fields before mutation;
  Basic custom-field verification now compares values rather than key presence.
- Structured ID3 collection frames (APIC/COMM/USLT) are no longer returned in
  `id3v2Frames` and are rejected in that collection; use artwork/comments/lyrics.
- Raw whole-map `.merge` now applies a delta and preserves MP4 hidden atoms and
  WAV INFO; `.replace` no longer injects private number-formatting atoms.
- Corrected WAV INFO/ID3 surface handling, implemented `.id3v2Only` stripping,
  and made Basic WAV writes target ID3v2 without copying INFO values.
- Added dedicated Structured artwork paths for raw AAC, APE/WavPack/Musepack,
  ASF, and TrueAudio; artwork verification no longer requires a caller-supplied
  container name. ASF structured attributes now upsert without clearing siblings.
- Fixed number-total canonical keys, MP3/WAV stale total frames, and partial
  paired-component removal; unrepresentable partial removal is rejected.
- Corrected ALAC codec/bit-depth reporting, multi-value capability flags, MP4
  date schema filtering, AAC artwork, and ASF Basic custom/advisory persistence.
- Added `expectedVersion` to structured, whole-map raw, and low-level tag writes.
- Added `MetadataValidationError`, `operationFailed`, role-qualified and
  partial-pair Patch errors, and `ArtworkVerificationExpectation.skip`; restored
  the deprecated `.warn` source spelling with no verification bypass.
- Added `F_FULLFSYNC` with `fsync` fallback and clarified that `.durable` is an
  OS-level flush, not a hardware/power-loss guarantee.
- Added regression coverage and generated fixtures for ALAC, ASF/WMA, TrueAudio,
  and WavPack, plus independent RIFF INFO parsing and WAV policy tests.

### Historical release provenance

The 0.5.1–0.5.3 summaries below were reconstructed from existing tag boundaries
during verification hardening. They are selected changes verified from commit
history, not contemporaneous release announcements. Tag target commit dates
are not asserted to be release publication dates; historical verification
results and complete compatibility guarantees are not reconstructed.

### Fixed

- Made high-level writes return committed parent-directory durability uncertainty
  through `MetadataWriteResult.commitStatus` instead of throwing after rename.
- Made formatted track and disc patch intent independent, including unchanged,
  set, and remove semantics, so editing one pair cannot rewrite the other.
- Added explicitly named `replaceBasicMetadata` and version-checked
  `updateBasicMetadata`; deprecated ambiguous whole-object write names that could
  make a sparse `BasicMetadata.empty` value look like a partial update.
- Removed the obsolete `failurePolicy` parameter from primary verified-write
  APIs. Verification mismatches always abort; deprecated overloads and the
  one-case policy type remain for source compatibility.
- Deprecated the lossy `isExplicit` setter. The Boolean remains available as a
  read projection, while mutations use the four-state `explicitAdvisory` model.
- Added clearly named `bestEffortMetadata`, `bestEffortRawMetadata`,
  `bestEffortRawMetadataText`, and `bestEffortStructuredMetadata` conveniences;
  deprecated ambiguous optional read names that silently collapse read errors.
- Separated declared extension discovery (`capability(forExtension:)`,
  `isReadableExtension`, and `isWritableExtension`) from concrete-file
  validation through the new throwing `probeFile(at:)` API. Ambiguous legacy
  extension lookup names remain as deprecated wrappers.
- Added `readBasicSnapshot(from:)` for consumers that need Basic metadata and a
  matching optimistic-concurrency token without constructing structured
  inspector models.
- Routed `updateBasicMetadata(at:_:)` through that focused snapshot path instead
  of constructing a comprehensive inspector snapshot.
- Made capability lookup expressions explicit enough to compile consistently
  across every supported CI Swift toolchain.
- Staged transactions now request same-volume copy-on-write cloning through
  `copyfile`; macOS automatically falls back to an ordinary copy when cloning is
  unavailable. Both transaction engines retain ACL/xattr/stat preservation and
  the existing atomic verification/commit sequence.

- Removed transaction-bypassing in-place mutators and coordination helpers from
  the public Low-Level header; the Swift facade now imports them from a dedicated
  non-product implementation target.

- Unified `artistType` on `MUSICBRAINZ_ARTISTTYPE` as the canonical PropertyMap
  key and strengthened schema tests to compare exact ordered mappings.
- Made full PropertyMap replacement verification compare the complete visible
  result, including removal of omitted keys; multi-value writes now expose an
  explicit `.replace`/`.merge` mode.
- Made verification mismatches unconditionally transactional failures and made
  unsupported RIFF INFO synchronization fail before mutation begins.
- Exported a typed low-level committed-but-durability-uncertain error contract.

- Preserved the untouched total component when patching WAV track or disc
  numbers stored in native ID3v2 number pairs, and verified both components
  after partial pair updates.
- Made native MP4/M4A `trkn` and `disk` pairs authoritative over conflicting
  legacy freeform number aliases, and removed those aliases during number
  writes so totals cannot become stale.

## [0.5.3] - reconstructed tag summary

Tag target: `03473c9`; changes since `0.5.2` (`62dcf9b`).

- Added focused Basic snapshots and used them for Basic updates (`5174cf0`,
  `fdef171`); introduced copy-on-write staging (`2fb5597`).
- Separated extension support from parser probing and clarified lossy read and
  whole-Basic replacement APIs (`2ceac41`, `1eb4069`, `300f16d`).
- Returned committed durability uncertainty and repaired independent formatted
  number-patch outcomes (`1436956`).
- Extracted the format registry and reorganized tests (`c5edb86`, `e1e54b7`).
- Documentation and maintenance records completed at the tagged baseline.
  The later audit/remediation fixes above were not included in this tag.

## [0.5.2] — reconstructed tag summary

Tag target: `62dcf9b`; changes since `0.5.1` (`cafcf40`).

- Clarified write contracts and separated unsafe in-place bridge APIs into the
  internal module (`fa34ed4`, `f6a314d`).
- Distinguished read-content identity changes from status-only changes
  (`f0ea153`); finalized the maintenance journal (`62dcf9b`).

## [0.5.1] — reconstructed tag summary

Tag target: `cafcf40`; changes since `0.5.0` (`283caba`).

- Added exact raw deltas, stale-snapshot checks, stable same-entry coordination,
  and precommit verification (`dcfa18a`, `7acb266`, `8adf4c4`, `683103d`).
- Added content-based Ogg detection, bounded identification reads, transactional
  FLAC artwork and WAV INFO preservation (`64daf83`, `e0ecf9b`,
  `10a6eea`, `76b02ea`).
- Added formatted number-patch support, exact WAV number text, and repairs for
  split storage and preserved totals (`252c16d`, `514c7ef`, `42bc1c3`,
  `b44bf4c`).
- Added opt-in snapshot throughput and corpus checks and documented transaction
  guarantees (`e18d823`, `73a5975`, `9e931a3`).
- Separated recording and release date storage (`763e31f`).

## [0.5.0] - 2026-09-01

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

- Structured ID3v2 text and `TXXX` writes now preserve native ordered value
  lists. `TXXX` descriptions remain frame identity rather than being duplicated
  into `StructuredID3v2Frame.values`, and post-write verification compares value
  cardinality, ordering, and contents instead of joined display strings.
- Structured ID3v2 and ASF artwork now preserve valid picture type code `0`
  (`Other`). Artwork verification checks container-supported MIME type, picture
  type, description, and image data rather than image bytes alone.
- Earlier work advertised PropertyMap-level TrueAudio/TTA Structured writes, which
  matches its implemented mutation path; Structured reads continue to expose its
  ID3v2 container.
- Preserved rich metadata omitted from basic writes, including raw multi-values,
  structured entries, artwork MIME information, and four-state advisory data.
- Preserved untouched standard multi-value fields during Basic writes without
  splitting normalized display strings, and made patch Boolean false distinct
  from field removal.
- Preserved schema-known fields outside `BasicMetadata`, defined Basic custom-key
  absence as preservation rather than deletion, and made preservation provenance
  caller read-only.
- Preserved omitted MP4 track/disc pair components, updated track totals in the
  native pair, and prevented contradictory native/freeform advisory values.
- Kept generic PropertyMap track/disc numbers and totals in separate canonical
  keys instead of redundantly encoding totals in both fields.
- Removed all recognized conflicting MP4 advisory aliases when making native
  `rtng` authoritative.
- Canonicalized MP4 advisory writes across Basic and Patch APIs, and prevented
  ordinary Basic writes from introducing private AudioMator track/disc formatting
  atoms into standard-only files.
- Restored the distinct absent, not-explicit, explicit, and clean advisory states;
  canonical MP4/M4A writes now emit `rtng` values `0`, `1`, and `2` respectively
  for the three present states while retaining legacy `rtng = 4` read compatibility.
- Synchronized existing AudioMator MP4 track/disc formatting provenance after
  Basic numeric edits while keeping native `trkn`/`disk` authoritative and
  preserving unchanged formatted text during unrelated edits.
- Made `.remove` the explicit unset operation for track/disc pair components,
  rejected integer zero for those fields, and preserved omitted native ID3
  movement number/count components in `MVIN`.
- Rejected typed Patch fields before staging when a format publishes a reliable
  explicit writable-field allowlist, without restricting Raw APIs.
- Normalized Patch text and arrays once for mutation and verification, rejected
  empty values in favor of `.remove`, and stopped ordinary MP4 number patches
  from injecting new AudioMator-specific formatting atoms.
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
