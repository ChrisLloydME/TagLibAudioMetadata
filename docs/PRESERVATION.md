# Write semantics and metadata preservation

This document is the canonical contract for what the package promises to preserve, what it verifies, and where those promises end. It sits behind the API examples in [Usage](USAGE.md). The source code is authoritative.

## Semantic preservation, not byte-for-byte archiving

The package edits metadata through TagLib and commits a sibling staging copy with an atomic rename. It does not serialize the whole audio file from a Swift model.

- Audio payload bytes are not intentionally changed by metadata writes. Tests compare encoded audio regions or independent packet hashes for representative formats.
- Known metadata that the API does not explicitly change is preserved where the format and TagLib representation allow it.
- Unknown or opaque native structures are often represented only by a display/type summary. If they are not edited, they normally remain on disk because TagLib saves the native tag. Rebuilding a native tag from a snapshot alone is not guaranteed to reproduce opaque bytes.
- A `MetadataSnapshot` is a comprehensive semantic snapshot, not a lossless native archive.
- Whole-map raw replacement deliberately owns the visible `PropertyMap` and is not a native archive.

## Model layers and fidelity

| Layer | Types | Fidelity | Best use |
| --- | --- | --- | --- |
| Comprehensive snapshot | `MetadataSnapshot` | Basic + raw `PropertyMap` + structured projections from one extraction call. Still semantic, not byte-exact. | Editors that need all views and omission-safe patches. |
| Basic | `BasicMetadata`, `BasicMetadataSnapshot` | Normalized common-field projection. Multi-value scalars are display strings. | Library views and ordinary tag editing. |
| Raw | `RawMetadataDump`, `RawMetadataPatch` | Exact visible `PropertyMap` keys, value arrays, and raw ID3 frame summaries where exposed. Opaque native data may be summarized. | Power-user key/value editors and exact deltas. |
| Structured | `StructuredMetadata` | Container-aware frames, atoms, attributes, artwork, comments, and lyrics. Unsupported records are summarized or omitted. | Frame/atom-level editors. |

`BasicMetadata` cannot represent every frame, atom, attribute, comment, lyric, or artwork record. Its scalar multi-value fields are display strings; do not split them to reconstruct arrays. ID3 generally joins values with `", "`; MP4 artist/genre and generic/Xiph projections use `"; "`, while some native MP4 fields/freeforms use `", "`.

## Omission, removal, and empty values

The high-level patch APIs distinguish **unchanged**, **set**, and **removed**:

- A field absent from `MetadataPatch` is unchanged.
- `MetadataPatchValue.remove` removes the field.
- Empty text, empty arrays, and arrays containing empty elements are validation errors, not deletion aliases.
- `MetadataArtworkPatch.unchanged` leaves artwork alone; `.replace` replaces the top-level artwork collection; `.removeAll` removes it. `.replace([])` also removes everything.
- `MetadataNumberTextPatch` treats `nil` as unchanged, a nonempty string as set, and an empty string as remove for that pair.
- `explicitAdvisory = nil` is unchanged; `.unspecified` removes the representation; `.notExplicit`, `.clean`, and `.explicit` store the corresponding state.

An empty `MetadataPatch` or `RawMetadataPatch` is a no-op. It returns without staging, without checking `expectedVersion`, and without evaluating an audio guard. Validate that a patch has content before treating a guarded call as a continuity check.

`BasicMetadata` is different because it is a full projection, not a patch:

- `replaceBasicMetadata` has replacement semantics for fields Basic explicitly models. Empty strings and zero numeric values clear those fields where the container allows it.
- `updateBasicMetadata(at:_:)` reads a focused Basic snapshot, applies the closure, and passes the captured version to the replacement.
- Removing a key from `BasicMetadata.customFields` does not request deletion. Use `MetadataPatch(customFields: [key: .remove])` or a raw API. An explicitly supplied empty custom value clears that entry.

## Basic preservation rules

A Basic read retains a separate raw-cardinality and provenance baseline. An unrelated Basic edit restores untouched data where the format and bridge support it, including:

- standard multi-value arrays such as `ARTIST`, `COMPOSER`, `ALBUMARTIST`, and `GENRE`;
- full recording dates and documented aliases such as `PUBLISHER`, `CATALOG`, `ORIGINAL YEAR`, and MusicBrainz space forms;
- role-qualified people keys such as `PERFORMER:GUITAR`;
- schema-known fields Basic cannot express, such as `INVOLVEDPEOPLE` and `TRACKERNAME`;
- unknown custom fields;
- unchanged native comment and lyric collections, including languages and descriptions, on tested ID3-backed formats.

Basic does not guess cardinality by splitting a display string. It restores captured arrays only for fields it can identify. Unknown fields that the bridge does not model may survive because TagLib saves the native tag, but they are not reconstructed from the Basic model.

Editing or adding a schema-known name through `BasicMetadata.customFields` is rejected; use the typed field or a raw/structured API. Existing native custom attributes whose names overlap the schema may be carried through unchanged when their value is unchanged.

`BasicMetadata.format` reports the parser's codec/format name; it is not a conformance claim. For example, an ALAC `.m4a` is reported as ALAC where the reader exposes that codec. `publisher` maps to TagLib's `label` field.

### Basic replacement and MP4 dates

`replaceBasicMetadata` applies replacement semantics to modeled fields and verification checks them. `updateBasicMetadata` resolves a single-field MP4 year/releaseDate intent:

- if only `releaseDate` changed, `year` is projected from its first four characters;
- if only `year` changed, `releaseDate` keeps its existing suffix after the first four characters;
- a full `replaceBasicMetadata` with inconsistent non-empty MP4 `year`/`releaseDate` projections throws `MetadataValidationError.conflictingMP4Date`.

`BasicMetadata.year` is a compatibility projection, not a second independent MP4 date field.

## Typed patch rules

`applyMetadataPatch` validates before staging:

- Field/value kinds are checked against `MetadataFieldRegistry`.
- Track/disc components and totals accept `1...Int32.max`; BPM and movement numbering accept `0...Int32.max`.
- `.artwork`, `.custom`, and `.explicitContent` must use their dedicated patch properties.
- Role-qualified fields such as `.performer`, `.involvedPeople`, and `.musicianCredits` are rejected; use `RawMetadataPatch` or `StructuredMetadata`.
- Known keys, aliases, case variants, and typed/custom collisions are rejected in `customFields`.
- A patch cannot mix typed track/disc fields with `numberText`.
- Empty text and value arrays are rejected after trimming.
- A partial removal of a paired first component is rejected where a retained total cannot be represented.
- A capability with an explicit writable-field allowlist is checked before staging. Raw APIs are not restricted by that high-level preflight.

Applied changes are staged as a delta against the current `PropertyMap`. The bridge does not rebuild omitted Swift fields into a replacement map. Number pairs, advisory values, and artwork use container-aware paths.

### Number pairs

- ID3-backed formats use combined `TRCK`/`TPOS`; movement number/count uses `MVIN`. MP4 uses native `trkn`, `disk`, and `rtng`. Generic/Xiph formats use separate number/total keys; ASF uses native text pairs.
- Native MP4 `trkn`/`disk` are authoritative. A number write removes recognized conflicting aliases. An unrelated Basic edit preserves them.
- MP4 advisory uses `rtng`; recognized freeform aliases are removed when the advisory changes.
- Text-backed Booleans encode false as `"0"`; `.remove` makes the field absent.
- Legacy `AUDIOMATOR_*_TEXT` atoms remain readable formatting provenance. Editing the corresponding pair lazily migrates it to a package-neutral `TAGLIBAUDIOMETADATA_*_TEXT` atom while preserving padding. An unrelated edit leaves legacy provenance unchanged.
- Generic/Xiph `numberText` displays the first component and normalizes total padding; the numeric pair remains authoritative.

### Dates

- `.date` owns recording date/year.
- `.releaseDate` owns release date.
- `.originalReleaseDate` owns original release date.
- MP4 has one standard `©day` atom. `.releaseDate` owns it; typed `.date` is rejected for MP4.
- `updateBasicMetadata` resolves single-field MP4 year/releaseDate intent. A full replacement with inconsistent non-empty projections rejects.

## Raw map rules

`RawMetadataPatch` is a delta over the visible TagLib `PropertyMap`:

- Keys omitted from both `valuesToSet` and `removingKeys` are unchanged.
- Array boundaries, duplicate values, empty strings, and whitespace are significant.
- An empty array is invalid; use `removingKeys`.
- Keys are normalized to uppercase. Keys with surrounding whitespace, NULs, or conflicts after normalization are rejected.
- Native MP4 `----:` atom keys are rejected; use `StructuredMetadata.mp4Atoms`.
- Hidden internal formatting keys are rejected by `RawMetadataPatch`. Do not use package-reserved keys.
- Verification compares the complete visible `PropertyMap` before commit. This catches omission and exact-value mismatches but is not an oracle for opaque native data that TagLib does not expose.

The whole-map compatibility writers have two modes:

- `.replace` replaces the visible `PropertyMap` with the supplied keys. It cannot reconstruct native fields that are not visible through `properties()`. WAV INFO is a separate surface: omitted INFO keys can survive the ID3v2 replacement and cause verification to fail. Use a structured `.id3v2Only` write or an explicit deletion of both surfaces when INFO removal is intended. Use `.replace` only when the caller deliberately owns the complete visible map.
- `.merge` applies a delta, preserves omitted visible keys, hidden MP4 freeform atoms, and WAV INFO, and removes a key when the supplied value or array is empty. Values and elements are trimmed and empty elements are dropped; array boundaries otherwise remain.

Prefer `RawMetadataPatch` for preservation-oriented partial edits. It preserves exact value strings within the limits of the native container and requires explicit removals.

## Structured rules

`writeStructuredMetadataWithVerification` edits only the top-level collections present in the payload, except where a collection is explicitly named for replacement.

- With `includeProperties == true`, supplied properties are a **delta**. Omitted keys and native structures are preserved. An empty `values` array removes that key.
- With `includeProperties == false`, a non-empty `properties` array is rejected by the Swift facade.
- `artwork`, `lyrics`, and `comments` use replace-all semantics when non-empty. Empty arrays are omitted by default; include the collection in `replacingCollections` to remove its final entries.
- Opaque ID3 frames returned with `type == "unknown"` are inspection-only. Omit them from writes; omitted frames remain on disk. Supplying one throws `MetadataValidationError.unsupportedID3v2FrameType`.
- `StructuredArtwork.container` is informational. The writer selects the destination container from the file format; verification compares payload, MIME type, and applicable picture metadata. Picture type `0` (`Other`) is valid; an omitted type defaults to Front Cover (`3`).
- APE-family artwork writes support one front image. ID3v2, MP4, ASF, FLAC, and Xiph support the entries those containers can store.
- MP4 atom writing supports `stringList`, `bool`, `int`, `uint`, `byte`, `longLong`, and `intPair`. Other inspected item types are ignored by the writer; omit them.
- ASF attributes are upserts. GUID attributes are inspection-only. There is no individual structured deletion operation.
- DSD structured writes are PropertyMap deltas and artwork. Replacing native ID3 frame/comment/lyric collections through the structured writer is unsupported. A Basic edit that would require replaying existing DSD native collections rejects rather than normalizing them.
- ID3 URL and UFID frames have no individual structured removal operation. Empty payloads reject instead of pretending to remove them.

### RIFF write policy

`RIFFMetadataWritePolicy` is meaningful for structured WAV writes. AIFF/AIFF-C have no RIFF INFO surface, so `.id3v2Only` has no additional effect there; `.syncBasicFieldsToInfo` still rejects because it is not implemented. For every other format the policy value is ignored; it does not synchronize Basic fields into RIFF INFO.

- `.preserveInfo` (default): write structured data and keep existing RIFF INFO.
- `.id3v2Only`: write structured ID3v2 data, then remove RIFF INFO.
- `.syncBasicFieldsToInfo`: reserved and not implemented; rejects for WAV/AIFF with `unsupportedWritePolicy`.

Basic and typed Patch WAV writes target ID3v2 and always leave RIFF INFO untouched. Raw PropertyMap edits follow key ownership: existing INFO keys update INFO, ID3v2 keys update ID3v2, and new keys go to ID3v2.

### ASF and DSD boundaries

- ASF structured attributes are upserts by identity, not replace-all collections. They preserve type, language, and stream identity.
- ASF GUID attributes are inspection-only with the pinned encoder; omit them to preserve them.
- ASF `int` projections retain an unambiguous existing WORD/DWORD width. A new attribute uses DWORD. WORD overflow and ambiguous same-identity width updates reject.
- DSD structured writes are PropertyMap deltas and artwork. Replacing native ID3 frame/comment/lyric collections through the structured writer is unsupported.
- Mixed TrueAudio APEv2 metadata rejects before commit because the pinned handler cannot reconcile both surfaces.

## Verification model

Verified facade APIs read the staged file back before commit and throw `TagLibManagerError.verificationFailed` on a requested-value mismatch. What is compared depends on the API:

| API | Verification scope |
| --- | --- |
| `applyMetadataPatch` | Requested typed/custom values, unedited visible `PropertyMap` fields, artwork, number/advisory expectations, and format-aware storage. |
| `applyRawMetadataPatch` | The complete visible `PropertyMap` after the delta. |
| `replaceBasicMetadata` / `updateBasicMetadata` | Basic fields, custom-field values, number/advisory expectations, artwork, and preservation data. |
| `writeStructuredMetadataWithVerification` | Requested structured collections and properties, with ordered frame values and artwork semantics. |
| `writeTrackNumberText` | Track/disc numbers and text where the container preserves exact text. |
| `writeTagMetadata` | Only the checks in `MetadataWriteVerificationContext`; `.none` checks no metadata values. |
| Direct `CTagLibBridge` mutators | Transactional staging and readability only, not semantic readback. |

Additional rules:

- Verification mismatches always abort the transaction. `VerificationFailurePolicy.warn` is deprecated and has no bypass effect.
- `MetadataWriteResult.warnings` contains residual container advisories after a successful verification. Mismatch warnings are thrown, not returned. An empty warnings array describes only the checks requested by that API.
- `.present` artwork verification is presence-only; `expectedArtworkData` and `expectedArtworkMIMEType` add exact checks.
- Basic and typed number checks accept numeric-equivalent formatting. Exact raw map verification compares strings and can reject normalized padding.
- Structured lyric/comment entries with empty text are skipped by the writer and fail verification if expected as present entries.
- The raw whole-map writers, `writeTrackNumberText`, and `writeStructuredMetadataWithVerification` expose `verifyAfterWrite`. Setting it to `false` opts out of readback comparison for that call; the transaction still stages and commits atomically, but the requested values are not verified. Do not describe such a write as verified.
- If the final directory sync fails after rename, the write has already committed. `MetadataWriteResult.commitStatus` is `.durabilityUncertain`; do not retry as though nothing happened.

Verification is not a lossless oracle. Metadata that TagLib does not expose cannot be compared by these APIs.

## Erase

`eraseAllMetadataWithVerification` writes an empty metadata model, clears the raw `PropertyMap`, wipes the native metadata container where supported, and reads the file back. Detected residual fields cause a thrown verification failure before commit.

Erase is limited to the metadata surfaces exposed by the supported parser. It is not a forensic scrub of every unknown container byte. For ASF, the native attribute and picture map is cleared and verified. Mixed TrueAudio APEv2 surfaces reject before commit. Use a dedicated sanitizer when the requirement goes beyond the package's metadata model.

## Transaction relationship

Preservation and verification happen on a sibling staging copy. The destination is replaced only after the operation, verification, file flush, and final identity check succeed. A failure before rename leaves the original pathname and bytes unchanged. See [Transactions](TRANSACTIONS.md) for the sequence, durability status, and concurrency limits.

## What is not promised

- Byte-for-byte preservation of unknown native structures when a native tag is rebuilt or a whole visible map is replaced.
- Preservation of metadata that the pinned TagLib parser does not expose.
- Universal field or codec support for a format whose label is `fixtureCovered`.
- Cross-process exclusion or hardware/power-loss durability.
- Behavior that the current tests do not exercise merely because the code compiles.
- That a successful write with warnings is a partial failure; warnings are residual advisories after the requested checks passed.
