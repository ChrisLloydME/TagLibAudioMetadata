# Usage guide

This guide shows how to choose and use the public API. It is task-oriented; the complete signature index is in the [API reference](API_REFERENCE.md). The source code remains authoritative for behavior.

Use the canonical documents for deeper contracts:

- [Write semantics](PRESERVATION.md) — omission, deletion, Basic preservation, verification, erase.
- [Formats](FORMATS.md) — capability evidence and container-specific limits.
- [Transactions](TRANSACTIONS.md) — staging, atomicity, durability, locking.
- [Audio-content continuity](AUDIO_CONTENT_CONTINUITY.md) — optional audio guards.

## Choose the right layer

| Need | Start with | Why |
| --- | --- | --- |
| Show common tags in a library or editor | `BasicMetadata` via `readMetadataResult` or `readBasicSnapshot` | Normalized, compact, easy to bind to UI. |
| Preserve data the UI does not expose while editing a few fields | `MetadataSnapshot` + `MetadataPatch` | One coherent read and an omission-safe delta. |
| Replace the complete common-field projection | `replaceBasicMetadata` or `updateBasicMetadata` | Explicit replacement semantics for modeled Basic fields. |
| Edit exact `PropertyMap` keys/arrays | `RawMetadataDump`, `RawMetadataPatch` | Exact visible cardinality and explicit removals. |
| Edit ID3 frames, MP4 atoms, ASF attributes, or multiple artwork/comment/lyric records | `StructuredMetadata` | Container-aware collections. |
| Reject stale edits based on an earlier read | `MetadataFileVersion` | Optimistic filesystem revision check. |
| Rebase after a metadata-only conflict without replacing audio | `MetadataAudioContentIdentity` + guarded patch overload | Distinguishes changed audio from changed metadata. |

`BasicMetadata` is a projection, not a lossless document. If the UI does not expose a field, do not assume a Basic round trip preserves it. Use a snapshot and a patch when preservation matters.

## Read metadata

### Read Basic metadata

```swift
import TagLibAudioMetadata

let url = URL(fileURLWithPath: "/path/to/song.flac")

do {
    let metadata = try TagLibMetadataManager.readMetadataResult(from: url)
    print(metadata.title)
    print(metadata.artist)
    print(metadata.duration)
} catch TagLibManagerError.unsupportedFormat {
    // Missing extension or a format the bridge does not register.
} catch TagLibManagerError.failedToReadWithUnderlying(let detail) {
    // The selected parser could not open or validate the file.
    print(detail)
}
```

`readMetadataResult` reads the Basic projection and the visible `PropertyMap` from one pass and rejects a file whose observed identity changes during the read. It does not construct structured/container inspector models.

Optional readers collapse every failure to `nil`:

```swift
if let metadata = TagLibMetadataManager.bestEffortMetadata(from: url) {
    print(metadata.album)
}
```

Use a best-effort reader only when losing the error is intentional. Typed `TagLibManagerError` cases usually tell the UI what to do next.

### Read Basic metadata with a version token

```swift
let snapshot = try TagLibMetadataManager.readBasicSnapshot(from: url)
show(snapshot.metadata)

let version = snapshot.fileVersion
// Pass version to a later write to reject a stale edit.
```

`readBasicSnapshot` avoids building raw and structured inspector models while still returning a `MetadataFileVersion`. It is the right loader for a Basic editor.

### Read a comprehensive snapshot

```swift
let snapshot = try TagLibMetadataManager.readSnapshot(from: url)

print(snapshot.basic.title)
print(snapshot.raw.properties)
print(snapshot.structured.artwork)
print(snapshot.structured.id3v2Frames)
```

`readSnapshot` obtains Basic, raw, and structured projections from one parser session and rejects a file that changes during extraction. It is a semantic snapshot, not a byte-exact native archive. Unknown or opaque native records may be summarized, and leaving them out of a patch does not necessarily reconstruct their bytes.

### Read raw metadata

```swift
let dump = try TagLibMetadataManager.rawMetadataResult(from: url)

for property in dump.properties {
    print(property.key, property.values)
}

for frame in dump.id3v2Frames {
    print(frame.frameID, frame.description ?? "", frame.value)
}
```

`RawPropertyEntry.value` is a joined display projection; `values` is authoritative for cardinality. `schema` links a property key to the field registry when known. `shouldDisplayAsMultiValue` is a UI hint based on schema mappings and qualified prefixes.

`bestEffortRawMetadataText` returns copyable diagnostic text:

```swift
if let text = TagLibMetadataManager.bestEffortRawMetadataText(from: url) {
    print(text)
}
```

Raw ID3v2 frame summaries are populated for the ID3 extraction paths that request them (MPEG/ID3, WAV, AIFF, TTA). Containers such as MP4, ASF, FLAC, and Ogg expose structured collections instead.

### Read structured metadata

```swift
let structured = try TagLibMetadataManager.readStructuredMetadataResult(from: url)

for frame in structured.id3v2Frames {
    print(frame.frameID, frame.type, frame.values)
}

for atom in structured.mp4Atoms {
    print(atom.key, atom.type, atom.values)
}

for warning in structured.warnings {
    print("Structured read warning:", warning)
}
```

Structured collections are container-specific. A format may populate `properties` only, or may expose frames/atoms/attributes, artwork, lyrics, comments, or warnings. Do not assume every collection is populated for every file.

For ID3v2 text frames, `values` is the ordered native string list; `value` is a display projection. `TXXX.description` identifies the user-text frame and is not duplicated into `values`. `APIC`, `COMM`, and `USLT` are returned in the dedicated `artwork`, `comments`, and `lyrics` collections rather than `id3v2Frames`.

Opaque ID3 frames are returned with `type == "unknown"` and are inspection-only. Omit them from a write payload; supplying one throws `MetadataValidationError.unsupportedID3v2FrameType`.

## Write metadata

### Apply a typed patch

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

- Field/value kinds come from `MetadataFieldRegistry`: `.bpm`, `.track`, `.disc`, and movement fields are integers; `.compilation` is Boolean; artwork, explicit advisory, and custom data use dedicated properties.
- Track/disc components accept `1...Int32.max`; BPM and movement numbering accept `0...Int32.max`.
- Role-qualified fields `.performer`, `.involvedPeople`, and `.musicianCredits` are rejected because their keys carry roles. Use a raw or structured API.
- `customFields` accepts only unknown keys. Known keys, aliases, case variants, and a typed/custom collision are rejected.
- `.text` and `.values` are trimmed once; empty text, empty arrays, and empty elements are errors. `.remove` is the explicit deletion request.
- A patch cannot mix `numberText` with typed track/disc fields.

`MetadataPatchValue` has four field-value forms and one deletion form: `.text`, `.integer`, `.boolean`, `.values`, and `.remove`. `.boolean(false)` writes `"0"`; it is not deletion.

#### Omission, removal, and boolean states

```swift
// Leave the title unchanged; remove the comment; set the mood.
let patch = MetadataPatch(fields: [
    .comment: .remove,
    .mood: .text("Focused")
])
```

`MetadataPatch.isEmpty` is true when no field, custom field, advisory, artwork, or number-text intent is present. An empty patch returns an empty result without staging or validating a version/audio guard.

`explicitAdvisory` has four meaningful values: `nil` means unchanged, `.unspecified` removes the representation, and `.notExplicit`, `.clean`, or `.explicit` stores the corresponding state. `BasicMetadata.isExplicit` is a lossy Boolean projection; assigning `false` records `.clean`, not `notExplicit` or absence.

#### Track, disc, and formatted number text

Track and disc fields are semantic pairs. Patching only `.track` preserves the existing total; patching only `.trackTotal` preserves the number. Native ID3 formats use combined `TRCK`/`TPOS`, MP4 uses `trkn`/`disk`, and generic/Xiph formats use separate number/total keys. ID3 movement uses `MVIN`; patching one movement component preserves the other.

A first component cannot be removed while retaining a total on formats that cannot represent a missing number with a total. Remove both components to clear the pair.

Use `numberText` only when formatted text is the authoritative input:

```swift
let patch = MetadataPatch(
    numberText: .init(trackNumberText: "02/10", discNumberText: "01/02")
)
```

`nil` leaves a pair unchanged, a non-empty string sets it, and an empty string removes it. Do not combine `numberText` with typed track/disc fields in the same patch.

Ordinary numeric Basic and Patch writes use native numeric storage. On MP4 they do not add private formatting atoms to a standard-only file. If legacy `AUDIOMATOR_*_TEXT` formatting provenance exists and the corresponding pair is edited, the package migrates it to the package-neutral `TAGLIBAUDIOMETADATA_*_TEXT` namespace while retaining padding. Use `writeTrackNumberText` for an intentional formatted-text write.

#### Dates on MP4

MP4 has one standard date atom, `©day`. `.releaseDate` owns it; typed `.date` writes are rejected for MP4. `.date` owns the recording date/year where the container has a separate representation.

`updateBasicMetadata` reconciles a single-field MP4 year/releaseDate edit. A full `replaceBasicMetadata` with inconsistent non-empty `year` and `releaseDate` projections throws `MetadataValidationError.conflictingMP4Date`; an empty `year` is allowed and the date projection supplies the year.

#### Artwork

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

### Replace or update Basic metadata

`replaceBasicMetadata` replaces the complete Basic projection:

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

### Apply a raw delta

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

Keys are normalized to uppercase. Omitted keys are unchanged. Array boundaries, duplicate values, empty strings, and whitespace are significant; an empty array is invalid and must be expressed with `removingKeys`. Conflicting keys after normalization are rejected. Native MP4 `----:` atom keys are rejected; use `StructuredMetadata.mp4Atoms`. The complete visible `PropertyMap` is verified after the delta.

### Replace or merge a whole visible map

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

`.replace` removes omitted visible keys from the map it writes. It does not reconstruct native data TagLib does not expose. On WAV, RIFF INFO is a separate surface and is not removed by this call; omitted INFO keys can remain and make verification fail. Use a structured `.id3v2Only` write to remove INFO, or delete both surfaces explicitly. `.merge` preserves omitted visible keys and native structures and treats an empty value as removal:

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

### Write structured metadata

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

Non-empty `artwork`, `lyrics`, and `comments` arrays use replace-all semantics. Empty arrays are omitted by default so a partial edit does not erase existing data. To remove the final entries, name the collections explicitly:

```swift
try TagLibMetadataManager.writeStructuredMetadataWithVerification(
    StructuredMetadata(),
    to: url,
    replacingCollections: [.artwork, .lyrics, .comments]
)
```

#### ID3v2 frames

```swift
let frame = StructuredID3v2Frame(
    frameID: "TIT3",
    type: "text",
    values: ["Subtitle"]
)
```

Supported write types are `text`, `userText`, `url`, `ufid`, `chapter`, `tableOfContents`, and `podcast`. `APIC`, `COMM`, and `USLT` must be edited through `artwork`, `comments`, and `lyrics`; `unknown` frames are read-only. `CHAP`/`CTOC` require a non-empty `elementID`; `UFID` requires an owner and non-empty data; URL frames require a `W`-prefixed ID and a non-empty URL. `fields` is reserved and currently ignored.

#### MP4 atoms

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

Supported write types are `stringList`, `bool`, `int`, `uint`, `byte`, `longLong`, and `intPair`. Inspection-only types such as `coverArtList`, `byteVectorList`, `void`, and `stem` should be omitted; supplying one is not a supported mutation, and readback verification fails when it is enabled. Use the `artwork` collection for `covr`.

#### ASF attributes

ASF attributes preserve key, type, language, and stream; they are upserts, not replace-all collections. `string`, `bool`, `int`, `int64`, and `binary` are writable. `guid` is inspection-only and rejected. An `int` update retains an unambiguous existing WORD/DWORD width; a new attribute uses DWORD. Ambiguous or overflowing WORD/DWORD updates reject. There is no individual structured deletion operation; use verified full erase only when deleting everything is intended.

#### Structured artwork, lyrics, and comments

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

Lyrics and comments are replace-all collections. Empty text entries are skipped and cannot be verified as present.

### Write formatted number text directly

```swift
let result = try TagLibMetadataManager.writeTrackNumberText(
    "03/12",
    discNumberText: "01/02",
    to: url
)
```

`nil` leaves the disc pair unchanged; an empty string removes it. This API is for renumbering or formatting features where the text is authoritative. Ordinary numeric writes may normalize padding.

### Erase metadata

```swift
let result = try TagLibMetadataManager.eraseAllMetadataWithVerification(from: url)

for warning in result.warnings {
    print("Erase warning:", warning)
}
```

Verified erase writes an empty model, clears the visible property map, wipes the native metadata container where supported, and re-reads the staged file. Detected residual fields throw `TagLibManagerError.verificationFailed` before commit. Erase is bounded by the metadata surfaces the parser exposes; it is not a forensic scrub of every container byte. For mixed TrueAudio APEv2 surfaces, reconcile with an APE-aware tool first.

### Write through the low-level bridge model

Only use this path when you need a bridge capability the facade does not wrap. It requires the low-level product and `import CTagLibBridge`.

```swift
import CTagLibBridge

let metadata = try TagLibMetadataExtractor.extractMetadata(from: url)
metadata.title = "Bridge Title"
metadata.trackNumber = 1
metadata.totalTracks = 10
metadata.trackNumberText = "01/10"

try TagLibMetadataManager.writeTagMetadata(
    metadata,
    to: url,
    verification: .none
)
```

`TagLibAudioMetadata` is a writer model for fields the bridge maps. A sparse instance replaces mapped fields and clears them where the format allows; it is not an omission-safe patch. `writeTagMetadata` with `.none` performs no semantic or staged-file readability readback; the transaction validates the original audio before staging and then commits the mutation. Prefer the facade's verified APIs for normal editing.

## Verification, warnings, and commit status

Verified facade writes compare requested values on the staged copy before rename. A mismatch throws `TagLibManagerError.verificationFailed([String])` and nothing is committed. A successful `MetadataWriteResult.warnings` contains non-fatal container advisories; an empty array describes only the checks that API requested.

```swift
let result = try TagLibMetadataManager.replaceBasicMetadata(metadata, to: url)
showWarnings(result.warnings)
```

The comparison scope differs by API:

| API | Verified scope |
| --- | --- |
| `applyMetadataPatch` | Requested typed/custom values, unedited visible `PropertyMap` fields, artwork, number/advisory expectations, and format-aware storage. |
| `applyRawMetadataPatch` | The complete visible `PropertyMap` after the delta. |
| `replaceBasicMetadata` / `updateBasicMetadata` | Basic fields, custom values, number/advisory expectations, artwork, and preserved raw values. |
| `writeStructuredMetadataWithVerification` | Requested structured collections and properties, including ordered frame values and artwork semantics. |
| `writeTagMetadata` | Only the checks in `MetadataWriteVerificationContext`; `.none` checks no metadata values. |
| Direct bridge mutators | Staged-file readability only, not semantic readback. |

A successful write may return `.durable` or `.durabilityUncertain(detail)`. The latter means the rename committed but the final directory sync failed; surface it as a committed state and do not retry blindly. `.durable` means the requested OS-level flush completed, not a hardware or power-loss guarantee.

## Capability discovery

```swift
let capability = try TagLibMetadataManager.probeFile(at: url)

print(capability.identifier)
print(capability.isWritable)
print(capability.structuredWriteSupport)
print(capability.writeSupport(for: .artwork))
```

`probeFile` parses the concrete file before returning the declared family capability. It does not test POSIX write permission, ACLs, disk space, or sandbox access; attempt a write or check those separately when an editability decision depends on them.

`capability(forExtension:)` does not open a file:

```swift
if let capability = TagLibMetadataManager.capability(forExtension: "m4a") {
    print(capability.extensions)
    print(capability.supportLevel)
    print(capability.supportLevel(forExtension: "mp4"))
}
```

`formatCapabilities` returns every family, and `readableExtensions`/`writableExtensions` derive extension lists from the registry. `fixtureCovered`, `experimental`, `upstreamSupported`, and `readOnly` are evidence labels, not runtime proof. See [Formats](FORMATS.md).

## Field registry

`MetadataFieldRegistry` is the public field-semantics table. Use it to build editors instead of hard-coding container keys.

```swift
let basicFields = MetadataFieldRegistry.allSchemas.filter {
    $0.category == .basic
}

let title = MetadataFieldRegistry.schema(for: .title)
let byKey = MetadataFieldRegistry.schema(forPropertyMapKey: "MUSICBRAINZ_TRACKID")
let id3Fields = MetadataFieldRegistry.schemas(withMappingsFor: .id3v2)
let writableFields = MetadataFieldRegistry.schemas(storableIn: capability)
```

`schema(forPropertyMapKey:)` recognizes common qualified prefixes such as `PERFORMER:`, `INVOLVEDPEOPLE:`, `MUSICIANCREDITS:`, `COMMENT:`, and `LYRICS:`. `normalizePropertyMapKey` trims whitespace and uppercases; use it before key comparisons.

## Recipes

### Build a read-only inspector

```swift
let metadata = try TagLibMetadataManager.readMetadataResult(from: url)
let rawText = TagLibMetadataManager.bestEffortRawMetadataText(from: url)

titleLabel.text = metadata.title
artistLabel.text = metadata.artist
debugTextView.text = rawText ?? ""
```

### Enable controls from capability evidence

```swift
let capability = try TagLibMetadataManager.probeFile(at: url)

titleField.isEnabled = capability.isWritable
artworkButton.isEnabled = capability.canWriteArtwork
structuredButton.isEnabled = capability.structuredWriteSupport != .none
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
    showError("The file could not be saved.")
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

### Rebase after a metadata-only conflict

```swift
let baseline = try TagLibMetadataManager.readSnapshot(
    from: url,
    includingAudioContent: true
)

let current = try TagLibMetadataManager.readSnapshot(
    from: url,
    includingAudioContent: true
)

guard let originalAudio = baseline.audioContentIdentity,
      let currentAudio = current.audioContentIdentity,
      let currentVersion = current.fileVersion else {
    throw MetadataAudioContentError.unavailable // Explicit reload required.
}

guard originalAudio == currentAudio else {
    throw MetadataAudioContentError.changed // Audio changed; reload required.
}

let patch = MetadataPatch(fields: [.title: .text("Reviewed title")])
try TagLibMetadataManager.applyMetadataPatch(
    patch,
    to: url,
    expectedVersion: currentVersion,
    expectedAudioContent: originalAudio
)
```

This checks audio continuity; it does not choose a field-level merge policy. The metadata conflict still needs an application decision.

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

## Low-level bridge notes

The public bridge header is `Sources/CTagLibBridge/include/TagLibMetadataExtractor.h`. It exposes Foundation/Objective-C declarations only. Bridge mutators are transactional but do not inherit the facade's semantic verification.

Enable bridge diagnostics with `TAGLIBAUDIOMETADATA_DEBUG` set to `1`, `true`, `yes`, or `on`. Diagnostics are for troubleshooting and are not a stable output format.

Use the bridge directly only for a capability the facade does not wrap. For normal applications, the Basic, typed-patch, raw-patch, and structured APIs above are more expressive and safer.

## Related contracts

- [API reference](API_REFERENCE.md) — every public declaration, default, model, and error.
- [Write semantics](PRESERVATION.md) — what is preserved, what is verified, and what is not promised.
- [Formats](FORMATS.md) — family/extension evidence and container boundaries.
- [Transactions](TRANSACTIONS.md) — staging, durability, and process-local concurrency.
- [Audio-content continuity](AUDIO_CONTENT_CONTINUITY.md) — identity algorithm, availability, and rebasing.
- [Testing](TESTING.md) — how to verify behavior in your environment.
- [Migration](MIGRATION.md) — deprecated names and behavior changes.
