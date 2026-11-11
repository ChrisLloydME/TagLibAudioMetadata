# Write semantics and metadata preservation

This document is the canonical contract for what the package promises to preserve, what it verifies, and where those promises end. It sits behind the API examples in the [writing guide](../guide/WRITING.md). The source code is authoritative.

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

`BasicMetadata` is a full projection, not a patch:

- `replaceBasicMetadata` has replacement semantics for fields the Basic replacement path actually writes. Empty strings and zero numeric values clear those fields where the container allows it.
- `updateBasicMetadata(at:_:)` reads a focused Basic snapshot, applies the closure, and passes the captured version to the replacement.
- Removing a key from `BasicMetadata.customFields` does not request deletion. Use `MetadataPatch(customFields: [key: .remove])` or a raw API. An explicitly supplied empty custom value clears that entry.
- The MP4-exclusive Basic properties are a documented exception: they are read into `BasicMetadata` but `replaceBasicMetadata` does not write them because the bridge writer model has no matching properties. Use `MetadataPatch` or structured writes for `director`, store IDs, TV fields, and related Booleans.

## Basic preservation rules

A Basic read retains raw cardinality and provenance for fields that Basic cannot fully represent. An unrelated Basic edit restores untouched data through exact native collections, including:

- standard multi-value arrays that are managed by the Basic writer, through exact MP4 atoms, ID3 multi-value frames, or Xiph/APE text keys;
- complete YEAR text and independent DATE, RELEASEDATE, and ORIGINALDATE slots (these are explicitly skipped by the generic raw-preservation loop and written through their own slots);
- on Xiph/APE families, all visible text keys (including role-qualified and schema-known keys) through their exact physical spelling;
- on tested ID3-backed formats, multi-value frames for schema fields that the Basic writer does not edit;
- unchanged native comment and lyric collections, including languages and descriptions, on tested ID3-backed formats;
- unknown Xiph/APE text keys and custom fields that the writer carries through.

The implementation does **not** replay a whole engine `PropertyMap` or use `preservedStandardValues`; that helper exists but has no caller. Preservation uses exact native paths: MP4 atoms/freeforms, Xiph/APE native text keys, ID3 multi-value frames, and restored native comment/lyric collections. This avoids rewriting independent YEAR/DATE frames through an ambiguous engine projection.

Basic does not guess cardinality by splitting a display string. It restores captured arrays only for fields it can identify. Unknown fields that the bridge does not model may survive because TagLib saves the native tag, but they are not reconstructed from the Basic model.

Editing or adding a schema-known name through `BasicMetadata.customFields` is rejected; use the typed field or a raw/structured API. Existing native custom attributes whose names overlap the schema may be carried through unchanged when their value is unchanged. The current validation does not reject the package-reserved hidden formatting names in custom data; do not use those names.

`BasicMetadata.format` reports the parser's codec/format name; it is not a conformance claim. For example, an ALAC `.m4a` is reported as ALAC where the reader exposes that codec. `publisher` maps to the native MP4 `©pub` atom and ID3 `TPUB`.

### Basic replacement and dates

`replaceBasicMetadata` applies replacement semantics to modeled fields and verifies them. It preserves untouched multi-value arrays through exact native writes and never replays the whole engine `PropertyMap`, because that projection merges independent YEAR/DATE frames.

There is no Year/date reconciliation:

- changing `year` writes only YEAR;
- changing `date` writes the same YEAR slot (legacy spelling);
- changing `standaloneDate` writes only the standalone DATE slot;
- changing `releaseDate` writes only RELEASEDATE;
- clearing one field never clears another;
- `YEAR=2004` and `RELEASEDATE=2017-06-09` are valid simultaneously;
- complete YEAR text such as `2021-07-15` round-trips without truncation.

`replaceBasicMetadata` and `updateBasicMetadata` validate an explicitly changed YEAR with `isRepresentableYearText` and throw `MetadataValidationError.invalidYearText` for new non-date text such as `"Spring 2021"`. An unchanged existing YEAR, including malformed text or a multi-value projection, is preserved without revalidation. All four untouched date owners retain native arrays, duplicates, whitespace and absence; no scalar Basic projection authorizes collapsing them. Native readback verifies this preservation before commit. The typed `applyMetadataPatch(.year:)` path does not run that Basic-specific validator; container/bridge validation still applies.

`replaceBasicMetadata` binds its preservation read to a file version even when the caller supplies no version. `updateBasicMetadata` additionally retains the caller-edit snapshot version. Neither performs cross-field intent resolution. On MP4, unchanged modeled native atoms and their compatibility aliases are replayed exactly; only explicitly edited owners retire their own aliases. Track/disc pairs retain their documented numeric normalization semantics. The legacy `MetadataValidationError.conflictingMP4Date` case is retained for source compatibility but is not produced.

## Typed patch rules

`applyMetadataPatch` validates before staging:

- Field/value kinds are checked against `MetadataFieldRegistry`.
- Track/disc components and totals accept `1...Int32.max` for text-backed pairs and `1...65535` for native MP4 pairs; BPM and movement numbering accept `0...Int32.max`.
- Store IDs and TV episode/season numbers use their declared non-negative native widths; the MP4 media-kind code is an unsigned 8-bit value.
- `.artwork`, `.custom`, and `.explicitContent` must use their dedicated patch properties.
- Role-qualified fields such as `.performer`, `.involvedPeople`, and `.musicianCredits` are rejected; use `RawMetadataPatch` or `StructuredMetadata`.
- Known keys, aliases, case variants, and typed/custom collisions are rejected in `customFields`.
- A patch cannot mix typed track/disc fields with `numberText`; `.date` and `.year` cannot both be supplied.
- Empty text and value arrays are rejected after trimming.
- A capability with an explicit writable-field allowlist is checked before staging. Raw APIs are not restricted by that high-level preflight.

Applied changes use exact native targets: MP4 atoms/freeforms, ID3 text/user-text/versioned frames, or native Xiph/APE text keys. The bridge does not rebuild omitted Swift fields into a replacement map. Number pairs, advisory values, and artwork use container-aware paths.

### Number pairs

- ID3-backed formats use combined `TRCK`/`TPOS`; movement number/count uses `MVIN`. MP4 uses native `trkn`/`disk`. Xiph uses `TRACKNUMBER`/`TRACKTOTAL`; APE uses `TRACK`/`TRACKTOTAL`; ASF uses native text pairs.
- Positive native components remain visible even when legacy values disagree, but the inventory reports ambiguity and blocks ordinary edits of that group until explicit resolution. Native Xiph/APE keys and ASF attributes are classified as native. Standalone or private-only legacy totals can be recovered through an explicit normalization plan. Untouched groups are not resolved or cleaned. Typed edits preserve a sole recoverable total before writing the touched native pair.
- Removing a number retains its total through MP4 `0/total`, ID3 `/total`, or separate Xiph/APE keys. ASF rejects a number-zero-plus-total pair without a verified codec. Bounds are checked before mutation. Normalization plans are immutable and permanently bound to their captured version.
- An unrelated Basic edit preserves orphan totals and both private namespaces. It does not canonicalize a pair merely because the file was loaded.
- Private `AUDIOMATOR_*_TEXT` and `TAGLIBAUDIOMETADATA_*_TEXT` atoms are not created or renamed by default write surfaces, including formatted-number convenience APIs. `planNumberNormalization` + `applyNumberNormalization` is the only cleanup path and removes only explicitly listed identities under the captured version.
- MP4 advisory uses `rtng`; recognized freeform aliases are removed when the advisory is explicitly changed. A Basic replacement always supplies an advisory projection and therefore can remove recognized MP4 freeform advisory aliases even when the caller did not intentionally edit the advisory.
- Text-backed Booleans encode false as `"0"`; `.remove` makes the field absent. MP4 Boolean atoms distinguish present `0` from absence.

### Dates

- `.year` (canonical) and `.date` (legacy spelling, mutually exclusive) own the YEAR slot.
- `.standaloneDate` owns the independent DATE slot.
- `.releaseDate` owns RELEASEDATE.
- `.originalReleaseDate` owns ORIGINALDATE.
- MP4 YEAR is `©day`; RELEASEDATE and DATE are freeforms. ID3 dates are written in the frame identity that matches the existing tag major version.
- No field is synthesized from another, and no year-equality validation or cross-field clearing occurs.

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
- `artwork` uses replace-all semantics when non-empty. Empty arrays are omitted by default; include the collection in `replacingCollections` to remove its final entries.
- `lyrics` and `comments` use replace-all semantics on ID3-backed formats and TrueAudio. MP4 ignores structured `comments`/`lyrics`; APE-family and FLAC/Ogg reject them. The facade then fails verification if those entries were expected. Use Basic or native atoms for MP4 comments/lyrics and an ID3-capable API for the others.
- Opaque ID3 frames returned with `type == "unknown"` are inspection-only. Omit them from writes; omitted frames remain on disk. Supplying one throws `MetadataValidationError.unsupportedID3v2FrameType`.
- ID3 writable frame types are `text`, `versionedText`, `userText`, `url`, `ufid`, `chapter`, `tableOfContents`, and `podcast`. `versionedText` requires the version-specific `v23ID`/`v24ID` or description fields; `APIC`, `COMM`, and `USLT` belong in the dedicated collections.
- `StructuredID3v2Frame.fields` is merged into the bridge payload dictionary. Leave it empty; a key can overwrite `id`, `type`, `value`, or `values`.
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
| `replaceBasicMetadata` / `updateBasicMetadata` | Basic fields, custom-field values, number/advisory expectations, artwork, and preservation data. The MP4-exclusive Basic properties are not written or verified by this path. |
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
- That `replaceBasicMetadata` writes every property present on `BasicMetadata`; the MP4-exclusive fields are read/patch-only at that surface.


## Independent date preservation corrections

The working tree verifies unchanged date owners separately from engine aliases. Xiph/APE expose exact native YEAR/DATE, including absence; generic PropertyMap replay preserves their spelling, arrays and native types. Raw deltas change only the requested native date keys, while full raw replacement intentionally replaces the visible map. ID3/MP4 verification compares untouched date frames/atoms and permits only value-preserving legacy YEAR promotion when creating the first rich tag. See [the mapping contract](../reference/MAPPING_SPEC.md#working-tree-conformance-repairs).

### Encoder ownership and MP4 pair decoding

Encoded By and Encoder Settings are independent. `ENCODEDBY` maps to ID3 `TENC`, MP4 `©enc` and ASF `WM/EncodedBy`; `ENCODING` (with the `ENCODERSETTINGS` read alias) maps to `TSSE`, `©too` and `WM/EncodingSettings`. Neither is a fallback for the other.

MP4 `trkn`/`disk` components use unsigned 16-bit storage, including 32768…65535. Bridge Basic, number-text, structured and retention reads normalize the pinned engine's signed `IntPair` projection to the stored unsigned value. This does not change other tools' signed decoding behavior; movement integers still have their separate 0…32767 bound.
