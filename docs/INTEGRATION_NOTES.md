# Integration Notes — TagLibAudioMetadata

**Audience:** AudioMator maintainers integrating this package.  
**Package version covered:** commits `5185e5d`–`06f447be` (unreleased; intended as `0.2.0`).  
**TagLib version vendored:** 2.1.1.

---

## 1. Summary

### What changed

The bridge was extracted from AudioMator into a standalone Swift Package and then substantially extended across four commits following the initial extraction:

| Commit | Area |
|---|---|
| `18fa3357` | Throwing read API, write verification, merge write mode, new error cases |
| `583e93ac` | Extended `BasicMetadata` + bridge model with MusicBrainz, AcoustID, classical and release fields |
| `9b19fe52` | Public metadata field schema layer; table-driven bridge key mappings |
| `53487c34` | Explicit read vs. write capability APIs; MOD-family and extended read formats |
| `06f447be` | Structured metadata read/write; multi-value PropertyMap write; WAV write change; ID3v2/MP4/ASF/FLAC structured paths |

### Why it changed

- **Precision:** AudioMator needed verified writes (detect container normalization after save) without duplicating verification logic at every call site.
- **Completeness:** Classical, release, and MusicBrainz fields were stored in custom fields; they are now first-class.
- **Correctness:** Xiph/Vorbis multi-value fields were being collapsed into a single semicolon string by the prior `writeRawPropertyMap` path.
- **Discoverability:** The schema layer lets UI code enumerate supported fields and their display names without hardcoded lists in the app.
- **WAV safety:** Writing WAV with `Strip` was silently deleting RIFF INFO chunks; `StripNone` preserves them.

---

## 2. Public API Impact

### Added APIs

All of the following are `nonisolated static` on `TagLibMetadataManager` unless noted.

**Read:**
- `readMetadataResult(from:) throws -> BasicMetadata` — throwing form of the existing optional read.
- `readStructuredMetadataResult(from:) throws -> StructuredMetadata`
- `readStructuredMetadata(from:) -> StructuredMetadata?`
- `rawMetadataResult(from:) throws -> RawMetadataDump`

**Write:**
- `writeMetadataWithVerification(_:to:failurePolicy:) throws -> MetadataWriteResult`
- `writeTagMetadata(_:to:verification:failurePolicy:) throws -> MetadataWriteResult`
- `writeTrackNumberText(_:discNumberText:to:verifyAfterWrite:failurePolicy:) throws -> MetadataWriteResult`
- `writeRawMetadataPropertyMapWithVerification(_:to:mode:verifyAfterWrite:failurePolicy:) throws -> MetadataWriteResult`
- `writeRawMetadataPropertyMapValuesWithVerification(_:to:verifyAfterWrite:failurePolicy:) throws -> MetadataWriteResult`
- `writeStructuredMetadataWithVerification(_:to:riffPolicy:includeProperties:verifyAfterWrite:failurePolicy:) throws -> MetadataWriteResult`
- `eraseAllMetadataWithVerification(from:failurePolicy:) throws -> MetadataWriteResult`

**Format capability:**
- `isReadableFormat(_:) -> Bool`
- `isWritableFormat(_:) -> Bool`
- `readableExtensions: [String]`
- `writableExtensions: [String]`

**New types:**
- `MetadataWriteResult` — `warnings: [String]`
- `MetadataWriteVerificationContext`, `ArtworkVerificationExpectation`
- `RawPropertyMapWriteMode` — `.replace` / `.merge`
- `VerificationFailurePolicy` — `.warn` / `.throw`
- `RIFFMetadataWritePolicy` — `.id3v2Only` / `.preserveInfo` / `.syncBasicFieldsToInfo`
- `MetadataValueSource`, `MetadataFieldProvenance`
- `StructuredMetadata`, `StructuredPropertyEntry`, `StructuredID3v2Frame`, `StructuredMP4Atom`, `StructuredASFAttribute`, `StructuredArtwork`, `StructuredLyrics`, `StructuredComment`
- `MetadataFieldKey`, `MetadataFieldCategory`, `MetadataFieldFormat`, `MetadataFieldStorageKind`, `MetadataFormatMapping`, `MetadataFieldSchema`, `MetadataFieldRegistry`
- `TagLibManagerError.failedToReadWithUnderlying(String)`, `TagLibManagerError.verificationFailed([String])`

**New `BasicMetadata` fields:**
`musicBrainzAlbumArtistID`, `musicBrainzReleaseTrackID`, `musicBrainzWorkID`, `acoustIDFingerprint`, `musicIPPUID`, `asin`, `releaseStatus`, `originalAlbum`, `originalArtist`, `discSubtitle`, `work`, `movementNumber`, `movementCount`.

### Removed APIs

None. No previously public API was removed.

### Renamed APIs

None.

### Deprecated APIs

- `TagLibManagerError.failedToRead` — compiler warning will appear at any `catch .failedToRead` site. Replace with `catch .failedToReadWithUnderlying`.

### Behavior-only changes (same signature, different behavior)

- `writeMetadata(_:to:)`, `writeRawMetadataPropertyMap(_:to:mode:)`, `eraseAllMetadata(from:)` — these now internally call the `WithVerification` variants and print warnings. Return type `Bool` is always `true` when the call does not throw. No breaking behavior change for callers that do not inspect warnings.
- `rawContainsCustomKey` (internal) — matching is now normalized exact-match with MP4 freeform prefix aliasing. Custom field write verification results may differ for keys that previously matched by substring. This is a correctness fix.

---

## 3. AudioMator Integration Impact

### Does AudioMator need code changes?

**Not immediately required.** The existing `readMetadata(from:)`, `writeMetadata(_:to:)`, `eraseAllMetadata(from:)`, and `writeRawMetadataPropertyMap(_:to:)` call sites compile and behave identically. However, several improvements are recommended:

### Call sites that may be affected

| AudioMator call site pattern | Recommendation |
|---|---|
| `catch .failedToRead` | Change to `catch .failedToReadWithUnderlying(let msg)` to get the error description. |
| Any code that checks `isSupported` via a local hardcoded extension list | Replace with `TagLibMetadataManager.isReadableFormat` / `isWritableFormat`. |
| Write calls where the app verifies the result by re-reading | Remove the app-side verification; use the `WithVerification` variants instead. |
| Write calls for multi-artist or multi-genre Vorbis/FLAC files | Switch to `writeRawMetadataPropertyMapValuesWithVerification` to preserve multiple values per key. |
| Any WAV write path that previously relied on RIFF INFO chunks being stripped | Review — RIFF INFO is now preserved by default after the `StripNone` change. |
| UI code that lists all supported metadata fields by name | Use `MetadataFieldRegistry.allSchemas` instead of a local list. |
| Any code that conditionally shows fields for classical/multi-movement content | `BasicMetadata` now contains `work`, `movementNumber`, `movementCount`, `discSubtitle`, `originalAlbum`, `originalArtist` directly. |

### UI-visible behavior changes

- **WAV files:** Tags written to `.wav` files no longer strip RIFF INFO chunks. Files that previously lost their INFO block on save will now retain it.
- **Xiph/FLAC multi-value fields** (artists, genres, etc.) — if the app uses `writeRawMetadataPropertyMapValuesWithVerification`, multiple values are stored as distinct Vorbis comment entries rather than being joined with `;`. If the app still uses the single-value `writeRawPropertyMap` path, behavior is unchanged.
- **Verification warnings** — `writeMetadata(_:to:)` now prints warnings to stdout when a container normalizes or drops a written value. Previously, such silent normalization was undetected.
- **Explicit content flag source** — `BasicMetadata.provenance.explicitContent` now correctly reports whether the value came from a TXXX frame, a PropertyMap entry, or the native tag, enabling more accurate "is this field actually set?" checks in UI.

---

## 4. Metadata Behavior Impact

### Supported formats affected

| Change | Formats |
|---|---|
| WAV: write now uses `ID3v2` + `StripNone` | `wav` |
| Multi-value PropertyMap write path added | `flac`, `ogg`, `oga`, `opus`, `spx` (Xiph/Vorbis), `ape`, `wv`, `mpc` |
| MOD-family write via PropertyMap pipeline | `mod`, `module`, `nst`, `wow`, `s3m`, `it`, `xm` |
| ID3v2 structured frame read extended | `mp3`, `mp2`, `aac`, `wav`, `aiff`, `aif` |
| MP4 typed atom read/write | `m4a`, `m4b`, `m4p`, `m4r`, `m4v`, `mp4`, `3g2` |
| ASF typed attribute read/write | `wma`, `asf` |
| FLAC/Xiph structured artwork reading | `flac`, `ogg`, `oga` |

### Fields affected

**Newly readable/writable via `BasicMetadata`:**
- `discSubtitle` → ID3v2 `TSST`, MP4 freeform `DISCSUBTITLE`
- `work` → ID3v2 `TXXX:WORK`, MP4 freeform `WORK`
- `movement` → ID3v2 `MVNM`, MP4 freeform `MOVEMENT`
- `movementNumber` → ID3v2 `MVIN`, MP4 freeform `MOVEMENTNUMBER`
- `movementCount` → ID3v2 `MVC`, MP4 freeform `MOVEMENTCOUNT`
- `originalAlbum` → ID3v2 `TOAL`, MP4 freeform `ORIGINALALBUM`
- `originalArtist` → ID3v2 `TOPE`, MP4 freeform `ORIGINALARTIST`
- `asin` → ID3v2 `TXXX:ASIN`, MP4 freeform `ASIN`
- `releaseStatus` → ID3v2 `TXXX:RELEASESTATUS`, MP4 freeform `RELEASESTATUS`
- `musicBrainzAlbumArtistID`, `musicBrainzReleaseTrackID`, `musicBrainzWorkID` → format-appropriate TXXX / MP4 freeform
- `acoustIDFingerprint` → `TXXX:Acoustid Fingerprint` / MP4 freeform
- `musicIPPUID` → `TXXX:MusicIP PUID` / MP4 freeform

### Read behavior changes

- ID3v2 `CHAP`, `CTOC`, `PCST` frames are now parsed into `StructuredMetadata.id3v2Frames` (TagLib 2.1.1 exposes them as read-only; the high-level chapter editor is not yet exposed).
- ID3v2 `UFID`, `WXXX`, and URL frames appear in `StructuredMetadata.id3v2Frames` with typed fields.
- `COMM` and `USLT` are surfaced in `StructuredMetadata.comments` / `.lyrics` with language and description.
- FLAC/Xiph and ASF artwork is now returned in `StructuredMetadata.artwork` as typed `StructuredArtwork` entries.
- MP4 atoms are returned in `StructuredMetadata.mp4Atoms` with type strings and optional integer pair fields.
- Track/disc number text fallback: if the native tag does not expose the text form but a numeric value is present, `BasicMetadata.trackNumberText` / `.discNumberText` now falls back to the raw PropertyMap value. `BasicMetadata.provenance` records whether the source was `.nativeTag`, `.rawFallback`, or `.derivedNumeric`.

### Write behavior changes

- **WAV `StripNone`:** `RIFF INFO` chunks are preserved alongside the ID3v2 chunk. Previously, the write path may have stripped INFO on save.
- **`syncBasicFieldsToInfo`:** Setting `riffPolicy: .syncBasicFieldsToInfo` on `writeStructuredMetadataWithVerification` emits a warning string in `MetadataWriteResult.warnings` but does not yet apply INFO sync. Do not depend on it syncing fields until this boundary is removed.
- Multi-value keys written via `writeRawMetadataPropertyMapValuesWithVerification` are stored as distinct Vorbis comment entries on Xiph containers, not as a `;`-joined single string.
- ID3v2 structured write: `UFID`, `WXXX`, `COMM`, `USLT`, `APIC` frames are written with correct typed constructors rather than falling through to text fallback.
- MP4 structured write: typed atoms use the appropriate `MP4::Item` variant (string list, int pair, boolean, freeform) instead of always writing strings.

### Fallback behavior changes

- Previous `writeRawPropertyMap` custom-field verification used a `contains`-based substring match. It now uses normalized exact match with explicit MP4 freeform prefix aliasing (`----:com.apple.iTunes:<KEY>` ↔ `<KEY>`). Keys that happened to match by substring but were not the exact intended key will now correctly report a verification warning.

---

## 5. Compatibility

### Source compatibility

**Fully source-compatible.** Every existing call site compiles without changes. New parameters have defaults. Deprecated `failedToRead` generates a compiler warning but does not break builds.

### Behavior compatibility

**Mostly compatible.** Two behavior changes require review:

1. **WAV writes** — RIFF INFO is no longer stripped. If AudioMator previously relied on writing WAV to clear the INFO block, that no longer happens automatically. Use `eraseAllMetadataWithVerification` or an explicit structured write with an empty INFO section if INFO removal is needed.

2. **Custom field verification** — The stricter exact-match aliasing means that a custom field whose key happened to partially match another key will now correctly emit a verification warning instead of silently passing. No data is lost; the warning is informational.

### Suggested semantic version bump

**Minor (`0.2.0`).**

Rationale: substantial API additions, two limited behavior changes (WAV StripNone, verification matching), no removals, full source compatibility. Neither behavior change corrupts existing data; they are correctness fixes.

---

## 6. Risks

### Data loss risks

- **Low.** The WAV `StripNone` change means INFO chunks are *preserved* rather than stripped, which is net-safer. No previously writable data is now unwritable.
- The `.syncBasicFieldsToInfo` policy is documented but not yet applied; no incomplete partial write can occur because the code path currently only appends a warning.
- `writeRawMetadataPropertyMapValuesWithVerification` replaces the entire PropertyMap on write (like the existing `writeRawPropertyMap`); callers that construct a partial key set will overwrite unrelated keys. This is pre-existing behavior, not new.

### Format-specific regressions

- **MOD/S3M/IT/XM write:** these formats now accept writes via the PropertyMap pipeline. TagLib's support for writing tracker formats is limited; the actual subset of writable fields is small and format-dependent. Do not write tags to tracker files and expect round-trip fidelity beyond basic text fields.
- **Shorten (`shn`):** reported as readable. Attempting to write will throw `TagLibManagerError.unsupportedFormat`. Guard all write paths with `isWritableFormat`.
- **WAV:** as noted above, INFO preservation is a correctness fix but changes the observable file content after a write. Bitwise-identical round-trip is no longer guaranteed for WAV files that previously had INFO stripped.

### Threading or performance risks

- All `TagLibMetadataManager` methods are `nonisolated static`. The bridge serializes its TagLib calls; concurrent calls to the same file URL from multiple threads are **not** safe. This is unchanged from before extraction.
- The new `WithVerification` functions perform an additional read pass after every write. Each verified write takes roughly 2× the I/O of an unverified write. For batch operations (e.g. mass renumbering), pass `verifyAfterWrite: false` and handle verification separately if latency matters.
- `MetadataFieldRegistry.allSchemas` is a `nonisolated static let` computed at first access. It is thread-safe (Swift runtime guarantee) but the first call allocates ~80 `MetadataFieldSchema` structs. This is negligible in practice.

---

## 7. Validation Checklist

Test each scenario below after integrating the package update. Results marked **expected** describe what should be observed.

### 7.1 WAV write preserves RIFF INFO

- **File:** any `.wav` file that contains a RIFF INFO chunk (e.g. `Artist` / `Album` in the INFO block, inspectable with a hex editor or `ffprobe`).
- **Action:** write any `BasicMetadata` change via `TagLibMetadataManager.writeMetadata(_:to:)`.
- **Expected:** RIFF INFO block is present and unchanged after the write; only the ID3v2 chunk reflects the new values. `MetadataWriteResult.warnings` is empty.

### 7.2 Xiph/FLAC multi-value artist round-trip

- **File:** a `.flac` file with `ARTIST` as two separate Vorbis comment entries (e.g. "Artist A" and "Artist B").
- **Action:** read via `rawMetadataResult(from:)`, confirm `RawPropertyEntry.values` has two elements; write back via `writeRawMetadataPropertyMapValuesWithVerification(["ARTIST": ["Artist A", "Artist B"]], to: url)`.
- **Expected:** re-read shows two distinct `ARTIST` entries; `StructuredMetadata.properties` contains one `StructuredPropertyEntry` for `ARTIST` with `values: ["Artist A", "Artist B"]`. No semicolons in any stored value.

### 7.3 Throwing read on unsupported file

- **File:** a `.txt` or `.pdf` file.
- **Action:** `try TagLibMetadataManager.readMetadataResult(from: url)`.
- **Expected:** throws `TagLibManagerError.unsupportedFormat`. The optional `readMetadata(from:)` returns `nil` without crashing.

### 7.4 Verification failure policy `.throw`

- **File:** an MP3 with BPM that the container normalizes (e.g. a non-integer string like `"120.5"`).
- **Action:** write `BasicMetadata` with `bpm = 120` and then call with `failurePolicy: .throw` after manually corrupting the re-read to simulate mismatch (or use a format that drops BPM).
- **Expected:** throws `TagLibManagerError.verificationFailed(["..."])` with a non-empty warnings array.

### 7.5 Classical fields round-trip (MP3)

- **File:** an `.mp3` test file with no existing classical tags.
- **Action:** write `BasicMetadata` with `work = "Symphony No. 9"`, `movementNumber = 1`, `movementCount = 4`, `discSubtitle = "Disc 1: Symphonies"`.
- **Expected:** re-read via `readMetadataResult` returns the same values. `rawMetadataResult` shows `WORK`, `MOVEMENTNUMBER`, `MOVEMENTCOUNT`, `DISCSUBTITLE` in properties.

### 7.6 Classical fields round-trip (M4A)

- Same as 7.5 but with an `.m4a` file.
- **Expected:** values stored as `----:com.apple.iTunes:WORK`, `----:com.apple.iTunes:MOVEMENTNUMBER`, etc. Re-read via `readMetadataResult` returns the same values.

### 7.7 Format capability guard

- **Action:** call `TagLibMetadataManager.isWritableFormat("shn")`.
- **Expected:** `false`. Attempting `writeMetadata` to a `.shn` file throws `TagLibManagerError.unsupportedFormat`.

### 7.8 Merge write mode

- **File:** a `.flac` file with `TITLE = "Old Title"` and `ARTIST = "Old Artist"`.
- **Action:** `writeRawMetadataPropertyMapWithVerification(["TITLE": "New Title"], to: url, mode: .merge)`.
- **Expected:** after write, `TITLE` is `"New Title"` and `ARTIST` is still `"Old Artist"`. `ARTIST` was not touched.

### 7.9 Merge write delete via empty value

- Same setup as 7.8.
- **Action:** `writeRawMetadataPropertyMapWithVerification(["ARTIST": ""], to: url, mode: .merge)`.
- **Expected:** `ARTIST` is absent after write; `TITLE` is unchanged.

### 7.10 Structured ID3v2 APIC round-trip

- **File:** an `.mp3` with embedded front-cover artwork.
- **Action:** `readStructuredMetadataResult(from:)`.
- **Expected:** `StructuredMetadata.artwork` contains at least one `StructuredArtwork` entry where `data` is non-empty, `mimeType` is `"image/jpeg"` or `"image/png"`, and `pictureType` is `"Front Cover"`.

### 7.11 ASF/WMA artwork structured read

- **File:** a `.wma` file with embedded `WM/Picture`.
- **Action:** `readStructuredMetadataResult(from:)`.
- **Expected:** `StructuredMetadata.asfAttributes` contains an entry with `key == "WM/Picture"` and non-nil `data` and `mimeType`. Also present in `StructuredMetadata.artwork`.

### 7.12 Deprecated error case compiler warning

- **Action:** add `catch TagLibManagerError.failedToRead {}` anywhere in the AudioMator codebase.
- **Expected:** Swift compiler emits a deprecation warning. No build error. Remove all `failedToRead` catch sites before the next major release.

### 7.13 Schema lookup

- **Action:** `MetadataFieldRegistry.schema(for: .work)`.
- **Expected:** returns a non-nil `MetadataFieldSchema` with `displayName == "Work"`, `category == .basic`, `propertyMapKeys == ["WORK"]`, and a mapping entry with `format == .id3v2` and `storageKind == .userTextFrame`.

### 7.14 `syncBasicFieldsToInfo` warning (not applied)

- **File:** any `.wav`.
- **Action:** `writeStructuredMetadataWithVerification(metadata, to: url, riffPolicy: .syncBasicFieldsToInfo)`.
- **Expected:** call succeeds (no throw); `MetadataWriteResult.warnings` contains a string mentioning `syncBasicFieldsToInfo`; INFO block is **not** updated.
