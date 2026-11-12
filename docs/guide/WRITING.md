# Writing metadata

This guide is task-oriented. Signatures are in the [manager API](../reference/API.md), value types in the [model reference](../reference/MODELS.md), field policy in the [field reference](../reference/FIELDS.md), and preservation/verification rules in [Write semantics](../explanation/PRESERVATION.md). The source code remains authoritative.

## Choose a write surface

| Need | API | Semantics |
| --- | --- | --- |
| Change only explicitly named fields | `applyMetadataPatch` | Omission-safe typed delta. Recommended for ordinary edits. |
| Read, modify a few Basic fields, write back | `updateBasicMetadata` | Captures a version, applies a closure, replaces the Basic projection. |
| Replace the complete Basic projection | `replaceBasicMetadata` | Empty/default fields clear modeled values; unchanged scalar date projections preserve exact native arrays. Not a patch. |
| Edit exact `PropertyMap` keys and arrays | `RawMetadataPatch` / `applyRawMetadataPatch` | Delta over the visible PropertyMap; explicit removals. |
| Replace or merge the complete visible map | `writeRawMetadataPropertyMap*WithVerification` | Whole-map ownership or explicit merge. |
| Edit ID3 frames, MP4 atoms, ASF attributes, artwork, comments, lyrics | `writeStructuredMetadataWithVerification` | Container-aware collections. |
| Write formatted track/disc text directly | `writeTrackNumberText` | The supplied text is the authoritative input. |
| Erase metadata | `eraseAllMetadataWithVerification` | Writes an empty model, clears the visible map, wipes native metadata where supported, verifies. |
| Use a bridge capability the facade does not wrap | `writeTagMetadata` / direct bridge | Bridge model write; no facade semantic verification unless requested. |

Every mutating facade API stages a sibling copy and commits it atomically. See [Transactions](../explanation/TRANSACTIONS.md).

## Apply a typed patch

`MetadataPatch` is an omission-safe delta. Absent fields are unchanged.

```swift
let snapshot = try TagLibMetadataManager.readSnapshot(from: url)

let patch = MetadataPatch(
    fields: [
        .title: .text("Edited Title"),
        .track: .integer(2),
        .trackTotal: .integer(10)
    ],
    customFields: ["APP_EDITOR_STATE": .values(["reviewed", "approved"])],
    explicitAdvisory: .clean,
    artwork: .unchanged
)

let result = try TagLibMetadataManager.applyMetadataPatch(
    patch,
    to: url,
    expectedVersion: snapshot.fileVersion
)

for warning in result.warnings {
    print("Warning:", warning)
}
```

Rules enforced before staging:

- Field/value kinds come from `MetadataFieldRegistry`. Track, disc, totals, BPM, movement numbering, MP4 store IDs, and TV numbers are integers; compilation and the MP4 Booleans are Booleans; ordinary fields accept text and, when the schema is multi-value, an array.
- Track/disc components accept `1...Int32.max` for text-backed pairs and `1...65535` on native MP4 pairs. Movement numbering accepts `0...Int32.max` at the schema layer, with MP4 restricted to `0...32767`. `rate` accepts an integer at the schema layer but is read-only for typed writes.
- An existing ID3v2.3 tag is read-only for date fields: a typed date patch rejects before staging, even when the requested value equals the current value. Inspect `StructuredMetadata.id3v2MajorVersion` before offering date edits for a concrete file.
- Role-qualified fields `.performer`, `.involvedPeople`, and `.musicianCredits` are rejected because their keys carry roles. Use a raw or structured API.
- `customFields` accepts only unknown keys. Known keys, aliases, case variants, and a typed/custom collision are rejected.
- `.text` and `.values` are trimmed once; empty text, empty arrays, and empty elements are errors. `.remove` is the explicit deletion request.
- A patch cannot mix `numberText` with typed track/disc fields.
- `.date` and `.year` cannot both be supplied.
- A format's explicit writable-field allowlist is checked before staging.

`MetadataPatchValue` has four value forms and one deletion form: `.text`, `.integer`, `.boolean`, `.values`, and `.remove`. `.boolean(false)` writes `"0"`; it is not deletion. The complete per-field kind and range table is generated in the [field reference](../reference/FIELDS.md#typed-patch-value-contract).

Comment and lyric routing depends on the container. Typed `.comment` and `.lyrics` patches own qualified `COMM`/`USLT` collections on ID3-backed formats, but use the ordinary `©cmt`/`©lyr` atoms on MP4. The structured `comments`/`lyrics` collections are a separate surface and remain unsupported on MP4.

### Omission, removal, and boolean states

```swift
// Leave the title unchanged; remove the comment; set the mood.
let patch = MetadataPatch(fields: [
    .comment: .remove,
    .mood: .text("Focused")
])
```

`MetadataPatch.isEmpty` is true when no field, custom field, advisory, artwork, or number-text intent is present. An empty patch returns an empty result without staging or validating a version/audio guard.

`explicitAdvisory` has four meaningful values: `nil` means unchanged, `.unspecified` removes the representation, and `.notExplicit`, `.clean`, or `.explicit` stores the corresponding state. `BasicMetadata.isExplicit` is a lossy Boolean projection; assigning `false` records `.clean`, not `.notExplicit` or absence.

`.replace([])` for artwork removes every artwork entry, just like `.removeAll`; `.removeAll` is the explicit intent form.

### Track, disc, and formatted number text

Track and disc fields are semantic pairs. Patching only `.track` preserves the existing total; patching only `.trackTotal` preserves the number. Native ID3 formats use combined `TRCK`/`TPOS`, MP4 uses `trkn`/`disk`, and generic/Xiph formats use separate number/total keys. ID3 movement uses `MVIN`; MP4 movement uses independent `©mvi`/`©mvc` atoms. A semantic movement patch preserves the untouched component, while Basic and low-level pair writes intentionally own both movement components.

Removing a first component while retaining a total is supported on MP4 (`0/total` sentinel), ID3-backed formats (`/total` text), and separate Xiph/APE keys. ASF rejects a number-zero-plus-total pair because it has no verified total-only representation. Remove both components to clear an ASF pair.

Use `numberText` only when formatted text is the authoritative input:

```swift
let patch = MetadataPatch(
    numberText: .init(trackNumberText: "02/10", discNumberText: "01/02")
)
```

`nil` leaves a pair unchanged, a non-empty string sets it, and an empty string removes it. Do not combine `numberText` with typed track/disc fields in the same patch.

Ordinary numeric Basic and patch writes use native numeric storage. On MP4 they do not add private formatting atoms to a standard-only file. Legacy `AUDIOMATOR_*_TEXT` and `TAGLIBAUDIOMETADATA_*_TEXT` atoms are never created or renamed by default write surfaces; they are preserved until an explicit, version-guarded normalization plan retires selected identities.

MP4 track/disc numbers and totals round-trip through 65535 as unsigned 16-bit components. Some external readers interpret the high half as signed; the package preserves the native value. MP4 movement number/count uses the separate `©mvi`/`©mvc` atoms and a `0...32767` range; larger values reject before staging rather than being clamped.

A number-only `numberText` value preserves the resolved existing total. Exact MP4 text padding has no portable atom, so the display normalizes to the native pair.

### Recover legacy totals

```swift
let inventory = try TagLibMetadataManager.numberingInventory(at: url)
print(inventory.track.total.state)      // absent, native, recoveredLegacy, ambiguous, invalid
print(inventory.track.privateTexts)     // exact legacy MP4 identities and values

let plan = try TagLibMetadataManager.planNumberNormalization(
    at: url,
    policy: .useLegacy,
    groups: [.track, .disc]
)
print(plan.trackNumber, plan.trackTotal)
print(plan.removals, plan.privateRemovals)

try TagLibMetadataManager.applyNumberNormalization(plan, to: url)
```

`planNumberNormalization` requires a headless policy; there is no implicit application preference. `.useNative` keeps actual native components, `.useLegacy` selects an unambiguous legacy candidate, and `.replace(number:total:)` supplies an explicit pair for each selected group. Neither policy resolves or modifies unselected groups.

`.useLegacy` falls back to a native component only when there are no legacy candidates. If legacy candidates exist but are ambiguous, the call throws `MetadataPatchValidationError.ambiguousNumberRecovery`; resolve it with `.replace` instead of guessing. A stale plan must be rebuilt; passing a newer `expectedVersion` cannot override the captured token. The apply step writes the native pair first, retires only the selected aliases in the same transaction, and verifies persistence and removal.

### Year, date, and release date

`year`, `standaloneDate`, `releaseDate`, and `originalReleaseDate` are independent. `YEAR=2004` and `RELEASEDATE=2017-06-09` are valid together.

```swift
try TagLibMetadataManager.applyMetadataPatch(
    MetadataPatch(fields: [
        .year: .text("2004"),
        .standaloneDate: .text("2003-02-01"),
        .releaseDate: .text("2017-06-09"),
        .originalReleaseDate: .text("1999")
    ]),
    to: url
)
```

MP4 YEAR is `©day`. RELEASEDATE and DATE are explicit freeform extensions; nothing is synthesized. Changing or clearing one field never rewrites another. `year` stores complete text and is not truncated to four characters. `updateBasicMetadata` performs no reconciliation, and `MetadataValidationError.conflictingMP4Date` is retained only for source compatibility.

An existing ID3v2.3 tag cannot accept independent date edits. Typed date patches reject before mutation; a Basic replacement rejects only when one of the four date values changes, so an unrelated edit still preserves the native dates. Read `StructuredMetadata.id3v2MajorVersion` for a concrete file. An extension-level `writeSupport` result may describe the verified ID3v2.4 codec and does not override concrete v2.3 read-only behavior.

The typed `.date` YEAR alias has been removed. Use `.year` for YEAR and `.standaloneDate` for independent DATE. The old serialized field-key token `date` is rejected rather than redirected.

`BasicMetadata.date` carries the independent standalone DATE projection, equivalent to typed `.standaloneDate`; `BasicMetadata.year` carries YEAR.

`replaceBasicMetadata` and `updateBasicMetadata` validate YEAR text with `isRepresentableYearText`; non-date text such as `"Spring 2021"` throws `MetadataValidationError.invalidYearText`. The typed patch path does not run that Basic-specific validator.

### MP4-exclusive fields

The registry adds `director` (`©dir`), `itunesAccount` (`apID`), `itunesComposerID` (`cmID`), `itunesCountryID` (`sfID`), `itunesGapless` (`pgap`), `itunesHDVideo` (`hdvd`), `itunesOwner` (`ownr`), `rate` (`rate`), `showMovement` (`shwm`), `storeDescription` (`sdes`), and the TV episode/network/season/show/sort atoms plus `itunesMediaType` (`stik`). Store IDs and TV numbers are lossless integers; Booleans distinguish present false from absence. `rate` is registered read-only because no verified native rating type or scale is available for typed writes, and the media-kind label vocabulary is not bound to numeric codes. Unknown existing media-kind codes are preserved.

These fields are readable through `BasicMetadata`, but `replaceBasicMetadata` does not write them: the bridge writer model has no matching properties. Use `applyMetadataPatch` or structured writes for them. See [Preservation](../explanation/PRESERVATION.md#basic-preservation-rules).

## Native ownership and integer bounds

Content Group, Grouping and Work remain distinct. MP4 uses `©grp`, `----:com.apple.iTunes:GROUPING` and `©wrk`; ID3 uses `TIT1`, `GRP1` and `TXXX:WORK`; Xiph/APE use `CONTENTGROUP`, `GROUPING` and `WORK`. A missing MP4 Content Group is empty and does not fall back to independent Grouping. Semantic verification permits the engine's overlapping PropertyMap projection for the edited owner while checking untouched native siblings.

MP4 Encoded By owns `©enc`; Encoder Settings owns `©too`. Compatible freeform `ENCODEDBY` and `ENCODING`/`ENCODERSETTINGS` values are read under those respective owners. Editing Encoded By must not remove an independent legacy Encoder Settings value, and neither field is a fallback for the other.

MP4 track/disc components accept `0...65535` as unsigned stored components where the pair permits a retained total; a present number component starts at one. Movement Number and Count use separate integer atoms `©mvi` and `©mvc` and accept `0...32767`. Semantic, Basic and structured facade preflight reject out-of-range values before staging; bridge writers also guard their native range. Typed `.integer(0)` stays present for movement, whereas `.remove` deletes the atom. Basic/low-level zero retains its existing absent/default meaning.

## Artwork

```swift
let cover = try Data(contentsOf: coverURL)

let patch = MetadataPatch(artwork: .replace([
    StructuredArtwork(
        pictureType: "Front Cover",
        pictureTypeCode: 3,
        mimeType: "image/jpeg",
        description: "Front cover",
        data: cover
    )
]))

try TagLibMetadataManager.applyMetadataPatch(patch, to: url)
```

`.unchanged` leaves the artwork collection alone, `.replace` replaces the top-level collection, and `.removeAll` removes it. Artwork support is container-specific; check `FormatCapability.canWriteArtwork`. APE-family containers accept one front image; ID3v2, MP4, ASF, FLAC, and Xiph support the entries their containers store. `container` is informational: the writer selects the destination container from the file format.

## Replace or update Basic metadata

`replaceBasicMetadata` replaces the complete Basic projection for fields it writes:

```swift
var metadata = try TagLibMetadataManager.readMetadataResult(from: url)
metadata.title = "New Title"
metadata.artist = "New Artist"
metadata.track = 2
metadata.trackTotal = 10

let result = try TagLibMetadataManager.replaceBasicMetadata(
    metadata,
    to: url
)
```

Empty strings and zero numbers clear modeled fields where the container allows it. A custom field key removed from `customFields` is not a deletion request; use `MetadataPatch(customFields: [key: .remove])` or a raw API. An explicitly supplied empty custom value clears that entry.

For read/modify/write, prefer the version-checked convenience:

```swift
let result = try TagLibMetadataManager.updateBasicMetadata(at: url) { metadata in
    metadata.title = "New Title"
    metadata.genre = "Ambient"
}
```

`updateBasicMetadata` reads a focused Basic snapshot, applies the closure, and passes the captured version to `replaceBasicMetadata`. It is safer than reading and replacing in separate UI events without a version.

`BasicMetadata.empty` is a complete replacement value, not a partial patch. Do not use it to clear only one field.

## Apply a raw delta

Use `RawMetadataPatch` for exact partial `PropertyMap` edits:

```swift
let patch = RawMetadataPatch(
    valuesToSet: ["ARTIST": ["Primary Artist", "Featured Artist"]],
    removingKeys: ["OLD_WORKFLOW_KEY"]
)

let result = try TagLibMetadataManager.applyRawMetadataPatch(
    patch,
    to: url,
    expectedVersion: snapshot.fileVersion
)
```

Keys are normalized to uppercase. Omitted keys are unchanged. Array boundaries, duplicate values, empty strings, and whitespace are significant; an empty array is invalid and must be expressed with `removingKeys`. Conflicting keys after normalization are rejected. Native MP4 `----:` atom keys and hidden package formatting keys are rejected; use `StructuredMetadata.mp4Atoms` for native atoms. The complete visible `PropertyMap` is verified after the delta.

## Replace or merge a whole visible map

Use the whole-map writers only when the caller deliberately owns the complete visible map or an explicit merge:

```swift
try TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification(
    [
        "TITLE": "Raw Title",
        "MOOD": "Focused"
    ],
    to: url,
    mode: .replace
)
```

`.replace` removes omitted visible keys from the map it writes. It does not reconstruct native data TagLib does not expose. Arrays that exactly match the current visible values are retained literally rather than normalized; new or changed arrays are trimmed. YEAR and DATE remain distinct keys during verification, so replacement cannot silently merge their arrays. On WAV, RIFF INFO is a separate surface and is not removed by this call; omitted INFO keys can remain and make verification fail. Use a structured `.id3v2Only` write to remove INFO, or delete both surfaces explicitly. `.merge` preserves omitted visible keys and native structures and treats an empty value as removal:

```swift
try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(
    [
        "ARTIST": ["One", "Two"],
        "OLD_KEY": []
    ],
    to: url,
    mode: .merge
)
```

The values variant preserves array boundaries. Both writers accept `expectedVersion` and `verifyAfterWrite`; setting `verifyAfterWrite: false` skips readback comparison but still stages and commits atomically. Do not describe such a write as verified.

## Write structured metadata

```swift
let payload = StructuredMetadata(
    properties: [
        .init(key: "TITLE", values: ["Structured Title"])
    ],
    id3v2Frames: [
        .init(frameID: "TIT3", type: "text", values: ["Subtitle"])
    ],
    comments: [
        .init(language: "eng", description: "", text: "Editor comment")
    ]
)

let result = try TagLibMetadataManager.writeStructuredMetadataWithVerification(
    payload,
    to: url,
    includeProperties: true
)
```

`includeProperties` controls whether `properties` participates. With `false`, a non-empty properties array is rejected; with `true`, non-empty properties are a delta and an empty `values` array removes that key.

Non-empty `artwork` uses replace-all semantics. Empty arrays are omitted by default so a partial edit does not erase existing data. To remove the final entries, name the collections explicitly:

```swift
try TagLibMetadataManager.writeStructuredMetadataWithVerification(
    StructuredMetadata(),
    to: url,
    replacingCollections: [.artwork, .lyrics, .comments]
)
```

Lyrics/comments replace-all is supported on ID3-backed formats and TrueAudio. MP4 ignores structured comments/lyrics; APE-family and FLAC/Ogg reject them. Do not use those collections for MP4 or Xiph/APE files. For MP4, use the typed `.comment`/`.lyrics` fields, which address `©cmt`/`©lyr`, or a native atom write.

Structured text values are exact payloads rather than display text. ID3 frame arrays and MP4 `stringList` entries retain order, duplicates, and surrounding whitespace. An empty array removes the frame identity or MP4 item where that type supports removal. The trimming performed by typed patch values does not apply to structured values.

### ID3v2 frames

```swift
let frame = StructuredID3v2Frame(
    frameID: "TIT3",
    type: "text",
    values: ["Subtitle"]
)
```

Supported write types are `text`, `versionedText`, `userText`, `url`, `ufid`, `chapter`, `tableOfContents`, and `podcast`. `versionedText` uses `v23ID`/`v24ID` and optional descriptions for frames whose identity differs between ID3v2.3 and v2.4. `APIC`, `COMM`, and `USLT` must be edited through `artwork`, `comments`, and `lyrics`; `unknown` frames are read-only. `CHAP`/`CTOC` require a non-empty `elementID`; `UFID` requires an owner and non-empty data; URL frames require a `W`-prefixed ID and a non-empty URL.

An ID3 `text` or `userText` entry with both empty `values` and empty `value` removes that frame identity. For `userText`, the description identifies the owner. Verification checks absence and preserves unrelated frames. URL/UFID removal has no equivalent empty-payload operation.

`StructuredID3v2Frame.fields` is merged into the bridge payload dictionary and can overwrite reserved dictionary keys. Leave it empty.

### MP4 atoms

```swift
let atom = StructuredMP4Atom(
    key: "----:com.apple.iTunes:CATALOGNUMBER",
    type: "stringList",
    values: ["ABC-123"]
)

try TagLibMetadataManager.writeStructuredMetadataWithVerification(
    StructuredMetadata(mp4Atoms: [atom]),
    to: url
)
```

Supported write types are `stringList`, `bool`, `int`, `uint`, `byte`, `longLong`, and `intPair`. Inspection-only types such as `coverArtList`, `byteVectorList`, `void`, and `stem` are ignored by the writer; omit them. Use the `artwork` collection for `covr`. Set `remove: true` on an atom to remove that exact native key.

### ASF attributes

ASF attributes preserve key, type, language, and stream; they are upserts, not replace-all collections. `string`, `bool`, `int`, `int64`, and `binary` are writable. `guid` is inspection-only and rejected. An `int` update retains an unambiguous existing WORD/DWORD width; a new attribute uses DWORD. Ambiguous or overflowing WORD/DWORD updates reject. There is no individual structured deletion operation; use verified full erase only when deleting everything is intended.

### Structured artwork, lyrics, and comments

```swift
let artwork = StructuredArtwork(
    pictureTypeCode: 3,
    mimeType: "image/jpeg",
    description: "Front cover",
    data: cover
)

try TagLibMetadataManager.writeStructuredMetadataWithVerification(
    StructuredMetadata(artwork: [artwork]),
    to: url
)
```

`StructuredArtwork.container` is informational. `pictureTypeCode == 0` is valid (`Other`); an omitted type defaults to Front Cover (`3`). Verification compares bytes and MIME type everywhere, plus picture type and description for containers that serialize them (MP4 `covr` does not).

Lyrics and comments are replace-all collections where supported. Empty text entries are skipped and cannot be verified as present.

DSF/DSDIFF accept ID3 frame upserts, PropertyMap deltas and artwork through the structured writer. Comment/lyric collection replacement remains unsupported; a Basic edit that needs to replay those native collections fails without committing.

## Write formatted number text directly

```swift
let result = try TagLibMetadataManager.writeTrackNumberText(
    "03/12",
    discNumberText: "01/02",
    to: url
)
```

`nil` leaves the disc pair unchanged; an empty string removes it. This API is for renumbering or formatting features where the text is authoritative. Ordinary numeric writes may normalize padding.

## Erase metadata

```swift
let result = try TagLibMetadataManager.eraseAllMetadataWithVerification(from: url)

for warning in result.warnings {
    print("Erase warning:", warning)
}
```

Verified erase writes an empty model, clears the visible property map, wipes the native metadata container where supported, and re-reads the staged file. Detected residual fields throw `TagLibManagerError.verificationFailed` before commit. Erase is bounded by the metadata surfaces the parser exposes; it is not a forensic scrub of every container byte. For mixed TrueAudio APEv2 surfaces, reconcile with an APE-aware tool first.

## Write through the low-level bridge model

Only use this path when you need a bridge capability the facade does not wrap. It requires the low-level product and both imports:

```swift
import TagLibAudioMetadata
import CTagLibBridge

guard let metadata = try TagLibMetadataExtractor.extractMetadata(from: url) else {
    throw TagLibManagerError.failedToReadWithUnderlying("The bridge did not return a metadata model.")
}
metadata.title = "Bridge Title"
metadata.trackNumber = 1
metadata.totalTracks = 10

try TagLibMetadataManager.writeTagMetadata(
    metadata,
    to: url,
    verification: .none
)
```

`TagLibAudioMetadata` is a writer model for fields the bridge maps. A sparse instance replaces mapped fields and clears them where the format allows; it is not an omission-safe patch. On read, the low-level model resolves YEAR and standalone DATE from their native owners on MP4, ID3, Xiph, and APE instead of deriving one from another's engine projection. On write, unchanged scalar projections do not collapse a native MP4 custom-field array or rebuild untouched native date owners. The model is still scalar: it cannot represent every native array or opaque structure, so use selective patches and structured APIs for those edits.

`writeTagMetadata` with `.none` performs no semantic readback; the transaction validates the original audio before staging and the bridge mutation is called directly. Prefer the facade's verified APIs for normal editing. See [Bridge reference](../reference/BRIDGE.md).

## Verification, warnings, and commit status

Verified facade writes compare requested values on the staged copy before rename. A mismatch throws `TagLibManagerError.verificationFailed([String])` and nothing is committed. A successful `MetadataWriteResult.warnings` contains residual container advisories; it does not contain mismatch warnings, because those abort the transaction.

```swift
let result = try TagLibMetadataManager.replaceBasicMetadata(metadata, to: url)
showWarnings(result.warnings)
```

The comparison scope differs by API:

| API | Verified scope |
| --- | --- |
| `applyMetadataPatch` | Requested typed/custom values, unedited visible `PropertyMap` fields, native date/owner absence, ASF native attributes, artwork, number/advisory expectations, and format-aware storage. |
| `applyRawMetadataPatch` | The complete visible `PropertyMap` after the delta. |
| `replaceBasicMetadata` / `updateBasicMetadata` | Basic fields, custom values, number/advisory expectations, artwork, and preserved raw values. MP4-exclusive Basic fields are not written or verified. |
| `writeStructuredMetadataWithVerification` | Requested structured collections and properties, including ordered frame values and artwork semantics. |
| `writeTrackNumberText` | Track/disc numbers and text where the container preserves exact text. |
| `writeTagMetadata` | Only the checks in `MetadataWriteVerificationContext`; `.none` checks no metadata values. |
| Direct bridge mutators | Staged-file readability only, not semantic readback. |

A successful write may return `.durable` or `.durabilityUncertain(detail)`. The latter means the rename committed but the final directory sync failed; surface it as a committed state and do not retry blindly. `.durable` means the requested OS-level flush completed, not a hardware or power-loss guarantee.

## Errors

Use the typed errors to distinguish recoverable UI states:

| Error | Typical response |
| --- | --- |
| `TagLibManagerError.unsupportedFormat` | Disable editing for the extension. |
| `TagLibManagerError.fileChanged` | Reload the file and reapply the edit. |
| `TagLibManagerError.hardLinkedFile` | Explain that atomic replacement would split the link; edit a copy. |
| `TagLibManagerError.verificationFailed` | The file was not committed; inspect details and reload. |
| `MetadataPatchValidationError` | Fix the patch before staging. See the complete cases in the [model reference](../reference/MODELS.md#metadatapatchvalidationerror). |
| `MetadataValidationError` | Fix the structured/Basic payload before staging. |
| `RawMetadataPatchError` | Fix keys or values before staging. |
| `MetadataAudioContentError.changed` | Audio changed; reload instead of rebasing. |
| `MetadataAudioContentError.unavailable` | The layout cannot be guarded; require explicit reload. |

`MetadataWriteResult.commitStatus == .durabilityUncertain` is not a failure to commit. Surface it as a committed result with a durability warning.

## Recipes

### Build a read-only inspector

```swift
let metadata = try TagLibMetadataManager.readMetadataResult(from: url)
let rawText = TagLibMetadataManager.bestEffortRawMetadataText(from: url)

titleLabel.text = metadata.title
artistLabel.text = metadata.artist
debugTextView.text = rawText ?? ""
```

### Save user edits and surface warnings

```swift
do {
    let result = try TagLibMetadataManager.replaceBasicMetadata(metadata, to: url)
    showWarnings(result.warnings)
} catch TagLibManagerError.unsupportedFormat {
    showError("This file type cannot be edited.")
} catch TagLibManagerError.verificationFailed(let details) {
    showError("The file was not saved: \(details.joined(separator: "; "))")
} catch {
    showError("The file could not be saved: \(error.localizedDescription)")
}
```

### Preserve multi-value artists

```swift
try TagLibMetadataManager.applyRawMetadataPatch(
    RawMetadataPatch(valuesToSet: ["ARTIST": ["Primary Artist", "Featured Artist"]]),
    to: url
)
```

### Add a typed or custom field

```swift
let patch = MetadataPatch(
    fields: [.catalogNumber: .text("ABC-123")],
    customFields: ["APP_REVIEW_STATE": .text("Approved")]
)

try TagLibMetadataManager.applyMetadataPatch(
    patch,
    to: url,
    expectedVersion: snapshot.fileVersion
)
```

Schema-known keys such as `CATALOGNUMBER` belong in `fields`; `customFields` rejects known keys and aliases so one semantic field cannot be written through two representations.

### Batch edit with per-file error handling

```swift
for url in urls {
    do {
        var metadata = try TagLibMetadataManager.readMetadataResult(from: url)
        metadata.album = "Batch Album"
        _ = try TagLibMetadataManager.replaceBasicMetadata(metadata, to: url)
    } catch TagLibManagerError.verificationFailed(let details) {
        report(url, details)
    } catch {
        report(url, [String(describing: error)])
    }
}
```

## Related references

- [Reading metadata](READING.md) — snapshots, raw and structured reads.
- [Capabilities](CAPABILITIES.md) — declared format and field support.
- [Write semantics](../explanation/PRESERVATION.md) — preservation, verification, erase.
- [Transactions](../explanation/TRANSACTIONS.md) — staging, durability, concurrency.
- [Audio-content continuity](../explanation/AUDIO_CONTENT_CONTINUITY.md) — guarded rebases.
- [Field reference](../reference/FIELDS.md) — keys, native targets, patch constraints.
- [Mapping test acceptance](../operations/MAPPING_TEST_STRATEGY.md) — independent matrices and coverage limits.
