# Metadata preservation and write semantics

This document states what the package promises to preserve, what it verifies, and where those promises end. It is the canonical contract behind the API examples in [USAGE](USAGE.md).

The current source code is the source of truth. This document describes the current HEAD; historical records may describe different behavior.

## Preservation is semantic, not byte-for-byte

The package edits metadata through TagLib and replaces the destination with an atomic sibling copy. It does not rewrite the whole audio file as a format-aware serializer.

- Audio payload bytes are not intentionally changed by metadata writes. Tests compare encoded audio regions or independent packet hashes for representative formats.
- Known metadata that the API does not explicitly change is preserved where the format and TagLib representation allow it.
- Unknown or opaque native structures are often represented only by a display summary. If you do not edit them, they normally remain on disk because TagLib saves the native tag. Rebuilding a native tag from a snapshot alone is not guaranteed to reproduce opaque bytes.
- A snapshot is a comprehensive semantic snapshot, not a lossless native archive.
- Whole-map raw replacement deliberately owns the visible PropertyMap and is not a native archive.

## Model layers and fidelity

| Layer | Type | Fidelity | Best use |
| --- | --- | --- | --- |
| Comprehensive snapshot | `MetadataSnapshot` | Basic + raw PropertyMap + structured projections from one parser session. Still semantic, not byte-exact. | Editors that need all views and omission-safe patches. |
| Basic | `BasicMetadata` | Normalized common-field projection. Multi-value scalars are display strings. | Library views and common tag editing. |
| Raw | `RawMetadataDump`, `RawMetadataPatch` | Exact visible PropertyMap keys, value arrays, and ID3 frame summaries. Opaque native data may be summarized. | Power-user key/value editors and exact deltas. |
| Structured | `StructuredMetadata` | Container-aware frames, atoms, attributes, artwork, comments, and lyrics. Unsupported records are summarized or omitted. | Frame/atom-level editors. |

`BasicMetadata` cannot represent every frame, atom, attribute, comment, lyric, or artwork record. Its scalar multi-value fields are display strings; do not split them to reconstruct arrays. ID3 generally joins values with `", "`; MP4 artist/genre and generic/Xiph projections use `"; "`, while some native MP4 fields and freeforms use `", "`.

## Omission, removal, and empty values

The high-level APIs distinguish **unchanged**, **set**, and **removed**:

- A field absent from a `MetadataPatch` is unchanged.
- `MetadataPatchValue.remove` removes the field.
- Empty text, empty arrays, and arrays containing empty elements are validation errors, not deletion aliases.
- `MetadataArtworkPatch.unchanged` leaves artwork alone; `.replace` replaces the top-level artwork collection; `.removeAll` removes it.
- `MetadataNumberTextPatch` treats `nil` as unchanged, a nonempty string as set, and an empty string as remove for that pair.
- `explicitAdvisory = nil` is unchanged; `.unspecified` removes the representation; `.notExplicit`, `.explicit`, and `.clean` store the corresponding value.

`BasicMetadata` is different because it is a full projection, not a patch:

- `replaceBasicMetadata` has replacement semantics for fields Basic explicitly models. Empty strings and zero numeric values clear those fields where the container allows it.
- `updateBasicMetadata(at:_:)` reads a focused Basic snapshot, applies your closure, and passes the captured version to the replacement. It is the recommended read/modify/write convenience.
- Removing a key from `BasicMetadata.customFields` does not request deletion. Use `MetadataPatch(customFields: [key: .remove])` or a raw API. An explicitly supplied empty custom value clears that entry.

## Basic preservation rules

A Basic read retains a separate raw cardinality and provenance baseline. An unrelated Basic edit restores untouched data, including:

- standard multi-value arrays such as `ARTIST`, `COMPOSER`, `ALBUMARTIST`, and `GENRE`;
- full recording dates and documented aliases such as `PUBLISHER`, `CATALOG`, `ORIGINAL YEAR`, and MusicBrainz space forms;
- role-qualified people keys such as `PERFORMER:GUITAR`;
- schema-known fields Basic cannot express, such as `INVOLVEDPEOPLE` and `TRACKERNAME`;
- unknown custom fields;
- unchanged native comment and lyric collections, including languages and descriptions, on tested ID3-backed formats.

Editing or adding a schema-known name through `BasicMetadata.customFields` is rejected; use the typed field or a raw/structured API. Existing native custom attributes whose names overlap the schema may be carried through unchanged.

`BasicMetadata.format` reports the parser's format family and is not a codec conformance claim. For example, an ALAC `.m4a` is reported as ALAC where the reader exposes that codec.

## Typed patch rules

`applyMetadataPatch` validates before staging:

- Field/value kinds are checked against `MetadataFieldRegistry`.
- Track/disc components and totals accept `1...INT_MAX`; BPM and movement numbering accept `0...INT_MAX`.
- `.artwork`, `.custom`, and `.explicitContent` must use their dedicated patch properties.
- Role-qualified fields such as `.performer`, `.involvedPeople`, and `.musicianCredits` are rejected; use `RawMetadataPatch` or `StructuredMetadata`.
- Known keys, aliases, case variants, and typed/custom collisions are rejected in `customFields`.
- A patch cannot mix typed track/disc fields with `numberText`.
- Empty text and value arrays are rejected after trimming.
- A partial removal of a paired first component is rejected where a retained total cannot be represented.

Applied changes are staged as a delta against the current PropertyMap. The bridge does not rebuild omitted Swift fields into a replacement map. Number pairs, advisory values, and artwork use container-aware paths.

### Number and advisory representations

- ID3-backed formats use combined `TRCK`/`TPOS` and `MVIN`. MP4 uses native `trkn`, `disk`, and `rtng`. Generic/Xiph formats use separate number/total keys.
- Native MP4 `trkn`/`disk` are authoritative. A number write removes recognized conflicting aliases. An unrelated Basic edit preserves them.
- MP4 advisory uses `rtng`; recognized freeform aliases are removed when the advisory changes.
- Text-backed booleans encode false as `"0"`; `.remove` makes the field absent.
- Legacy `AUDIOMATOR_*_TEXT` atoms remain readable formatting provenance. Editing the corresponding pair lazily migrates it to a package-neutral `TAGLIBAUDIOMETADATA_*_TEXT` atom, preserving padding. An unrelated edit leaves legacy provenance unchanged.

### Dates

- `.date` owns recording date/year.
- `.releaseDate` owns release date.
- `.originalReleaseDate` owns original release date.
- MP4 has one standard `©day` atom. `.releaseDate` owns it; typed `.date` is rejected for MP4.
- `updateBasicMetadata` resolves single-field MP4 year/releaseDate intent. A full `replaceBasicMetadata` must supply consistent projections or throws `MetadataValidationError.conflictingMP4Date`.

## Raw map rules

`RawMetadataPatch` is a delta over the visible TagLib PropertyMap:

- Keys omitted from both `valuesToSet` and `removingKeys` are unchanged.
- Array boundaries, duplicate values, empty strings, and whitespace are significant.
- An empty array is invalid; use `removingKeys`.
- Keys are normalized to uppercase. Conflicting case variants are rejected.
- Native MP4 `----:` atom keys are rejected; use `StructuredMetadata.mp4Atoms`.
- Hidden internal formatting keys cannot be written.
- Verification compares the complete visible PropertyMap before commit. This catches omission and exact-value mismatches but is not an oracle for opaque native data that TagLib does not expose.

The whole-map compatibility writers have two modes:

- `.replace` replaces the visible PropertyMap with the supplied keys. It can remove WAV INFO and cannot reconstruct native fields that are not visible through `properties()`. Use it only when the caller deliberately owns the complete visible map.
- `.merge` applies a delta, preserves omitted visible keys, hidden MP4 freeform atoms, and WAV INFO, and removes a key when the supplied value is empty.

Prefer `RawMetadataPatch` for preservation-oriented partial edits.

## Structured rules

`writeStructuredMetadataWithVerification` edits only the top-level collections present in the payload, except where a collection is explicitly named for replacement.

- With `includeProperties == true`, supplied properties are a **delta**. Omitted keys and native structures are preserved. An empty `values` array removes that key.
- With `includeProperties == false`, a non-empty `properties` array is rejected.
- `artwork`, `lyrics`, and `comments` use replace-all semantics when non-empty. Empty arrays are omitted by default; include the collection in `replacingCollections` to remove its final entries.
- Opaque ID3 frames returned with `type == "unknown"` are inspection-only. Omit them from writes; omitted frames remain on disk. Supplying one throws `unsupportedID3v2FrameType`.
- `StructuredArtwork.container` is informational. The writer selects the destination container from the file format; verification compares payload, MIME type, and applicable picture metadata. Picture type `0` (`Other`) is valid; an omitted type defaults to Front Cover (`3`).
- APE-family artwork writes support one front image. ID3v2, MP4, ASF, FLAC, and Xiph support the entries those containers can store.

### RIFF write policy

`RIFFMetadataWritePolicy` applies to WAV. AIFF/AIFF-C structured writes use ID3v2 and have no RIFF INFO surface, so `.id3v2Only` has no additional effect there:

- `.preserveInfo` (default): write structured data and keep existing RIFF INFO.
- `.id3v2Only`: write structured ID3v2 data, then remove RIFF INFO.
- `.syncBasicFieldsToInfo`: reserved and not implemented; rejects before staging with `unsupportedWritePolicy`.

Basic, typed Patch, and structured WAV writes target ID3v2 and leave INFO untouched unless `.id3v2Only` is selected. Raw PropertyMap edits follow key ownership: existing INFO keys update INFO, ID3v2 keys update ID3v2, new keys go to ID3v2.

### ASF and DSD boundaries

- ASF structured attributes are upserts by identity, not replace-all collections. They preserve type, language, and stream identity. There is no individual structured removal operation.
- ASF GUID attributes are inspection-only with the pinned encoder; omit them to preserve them.
- DSD structured writes are PropertyMap deltas and artwork. Replacing native ID3 frame/comment/lyric collections through the structured writer is unsupported. A Basic edit that would need to replay DSD native collections rejects rather than normalizing them.
- ID3 URL and UFID frames have no individual structured removal operation. Empty payloads reject instead of pretending to remove them.

## Verification model

Verified facade APIs read the staged file back before commit and throw `TagLibManagerError.verificationFailed` on a requested-value mismatch. What is compared depends on the API:

| API | Verification scope |
| --- | --- |
| `applyMetadataPatch` | Requested typed/custom values, unedited visible PropertyMap fields, artwork, number/advisory expectations, and format-aware storage. |
| `applyRawMetadataPatch` | The complete visible PropertyMap after the delta. |
| `replaceBasicMetadata` / `updateBasicMetadata` | Basic fields, custom-field values, number/advisory expectations, artwork, and preservation data. |
| `writeStructuredMetadataWithVerification` | Requested structured collections and properties, with element-by-element frame/text comparison and artwork semantics. |
| `writeTagMetadata` | Only the checks in `MetadataWriteVerificationContext`; the default `.none` checks no metadata values. |
| Direct `CTagLibBridge` mutators | Transactional staging and readability only, not semantic readback. |

Additional rules:

- Verification mismatches always abort the transaction. `VerificationFailurePolicy.warn` is deprecated and has no bypass effect.
- `MetadataWriteResult.warnings` contains non-fatal container advisories after a successful verification. An empty warnings array describes only the checks requested by that API.
- `.present` artwork verification is presence-only; `expectedArtworkData` and `expectedArtworkMIMEType` add exact checks.
- Basic and typed number checks accept numeric-equivalent formatting. Exact raw map verification compares strings and can reject normalized padding.
- Empty FLAC comment values that TagLib drops are rejected by exact-value verification.

The raw whole-map writers and `writeStructuredMetadataWithVerification` expose a `verifyAfterWrite` parameter. Setting it to `false` opts out of readback comparison for that call; the transaction still stages and commits atomically, but the requested values are not verified. Do not describe such a write as verified.

Verification is not a lossless oracle. Metadata that TagLib does not expose cannot be compared by these APIs.

## Erase

`eraseAllMetadataWithVerification` writes an empty metadata model, clears the raw PropertyMap, wipes the native metadata container where supported, and reads the file back. Detected residual fields cause a thrown verification failure before commit.

Erase is limited to the metadata surfaces exposed by the supported parser. It is not a forensic scrub of every unknown container byte. For ASF, the native attribute and picture map is cleared and verified. Mixed TrueAudio APEv2 surfaces reject before commit. Use a dedicated tool when you need to sanitize a file beyond the package's metadata model.

## Transaction relationship

Preservation and verification happen on a sibling staging copy. The destination is replaced only after the operation, verification, file flush, and final identity check succeed. A failure before rename leaves the original pathname and bytes unchanged. See [TRANSACTIONS](TRANSACTIONS.md) for the full sequence, durability status, and concurrency limits.

## What is not promised

- Byte-for-byte preservation of unknown native structures when a native tag is rebuilt or a whole visible map is replaced.
- Preservation of metadata that the pinned TagLib parser does not expose.
- Universal field or codec support for a format whose label is `fixtureCovered`.
- Cross-process exclusion or hardware/power-loss durability.
- Any behavior that the current tests do not exercise, simply because the code compiles.
