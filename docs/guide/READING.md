# Reading metadata

This guide is task-oriented. Signatures are in the [manager API](../reference/API.md), value types in the [model reference](../reference/MODELS.md), and field mappings in the [field reference](../reference/FIELDS.md). The source code remains authoritative.

## Choose a read layer

| Need | Start with | What it returns |
| --- | --- | --- |
| Common tags for a library or editor | `readBasicSnapshot` or `readMetadataResult` | Normalized `BasicMetadata`, optionally a version token. |
| All views from one observed revision | `readSnapshot` | Basic, raw `PropertyMap`, structured collections, and a version. |
| Exact visible `PropertyMap` keys and arrays | `rawMetadataResult` | `RawMetadataDump`. Does not build structured inspector models. |
| ID3 frames, MP4 atoms, ASF attributes, artwork, lyrics, comments | `readStructuredMetadataResult` | `StructuredMetadata`. |
| An optimistic revision token | `fileVersion` or a snapshot | `MetadataFileVersion`. |
| A guarded audio/continuity token | `readSnapshot(from:includingAudioContent:)` | Snapshot plus optional `MetadataAudioContentIdentity`. |

`BasicMetadata` is a projection, not a lossless document. If the UI does not expose a field, do not assume a Basic round trip preserves it. Use a snapshot and a patch when preservation matters.

## Read Basic metadata

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

`readMetadataResult` makes one extraction call and rejects a file whose observed identity changes during the read. It requests all bridge projections internally because Basic date and MP4 fields are resolved from exact native data; it does not return `RawMetadataDump` or `StructuredMetadata` and does not construct the public structured inspector model.

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

`readBasicSnapshot` does not return structured inspector models, but like `readMetadataResult` it still derives them internally. It is the right loader for a Basic editor that needs a version token.

## Read a comprehensive snapshot

```swift
let snapshot = try TagLibMetadataManager.readSnapshot(from: url)

print(snapshot.basic.title)
print(snapshot.raw.properties)
print(snapshot.structured.artwork)
print(snapshot.structured.id3v2Frames)
```

`readSnapshot` obtains Basic, raw, and structured projections in one extraction call and rejects a file that changes during extraction. The file version is non-optional in a snapshot returned by this API. It is a semantic snapshot, not a byte-exact native archive. Unknown or opaque native records may be summarized, and leaving them out of a patch does not necessarily reconstruct their bytes.

## Read raw metadata

```swift
let dump = try TagLibMetadataManager.rawMetadataResult(from: url)

for property in dump.properties {
    print(property.key, property.values)
}

for frame in dump.id3v2Frames {
    print(frame.description ?? "", frame.value)
}
```

`RawPropertyEntry.value` is a joined display projection; `values` is authoritative for cardinality. `schema` links a property key to the field registry when known. `shouldDisplayAsMultiValue` is a UI hint based on schema mappings and qualified prefixes. Raw properties are sorted case-insensitively by key.

`bestEffortRawMetadataText` returns copyable diagnostic text:

```swift
if let text = TagLibMetadataManager.bestEffortRawMetadataText(from: url) {
    print(text)
}
```

Raw ID3v2 frame summaries are populated for the extraction paths that request them. Containers such as MP4, ASF, FLAC, Ogg, APE, DSD, and tracker formats may expose structured collections instead. Do not assume `id3v2Frames` is populated for every file.

## Read structured metadata

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

## Capture a file version

```swift
let version = try TagLibMetadataManager.fileVersion(at: url)
```

A version captures device, inode, size, link count, modification time, and status-change time for an observed regular file. It is an optimistic token, not a lock or content hash. See [Transactions](../explanation/TRANSACTIONS.md) for how versions are checked during a write.

## Extraction options

The bridge exposes `basic`, `raw`, `structured`, `propertyMap`, and `rawFrames` option bits. The facade selects them for you:

| Call | Options | Notes |
| --- | --- | --- |
| `readSnapshot` | all | Basic, raw, structured. |
| `readMetadataResult` / `readBasicSnapshot` | all | Basic returned; raw/structured derived internally. |
| `rawMetadataResult` | raw | Visible PropertyMap and raw frame summaries. |
| `readStructuredMetadataResult` | structured | Structured collections. |

Direct bridge clients can pass a custom mask to `TagLibMetadataExtractor.metadataProjections(for:options:)`. The bridge `All` option is `NSUIntegerMax`; the Swift `MetadataExtractionOptions.all` is the union of its five known bits. Requesting `.propertyMap` alone returns `raw` with properties; `.rawFrames` alone returns `raw` with frames; `.raw` includes both. See [Bridge reference](../reference/BRIDGE.md).

## Audio-content continuity

Opt-in audio identities help distinguish a metadata-only conflict from replaced audio:

```swift
let baseline = try TagLibMetadataManager.readSnapshot(
    from: url,
    includingAudioContent: true
)

guard let originalAudio = baseline.audioContentIdentity else {
    // Unsupported layout or absent identity: require explicit reload.
    return
}
```

A nil identity never establishes continuity. Availability is limited to native FLAC and single-data-chunk WAVE/AIFF/AIFF-C. See [Audio-content continuity](../explanation/AUDIO_CONTENT_CONTINUITY.md).

## Errors

| Error | Typical response |
| --- | --- |
| `TagLibManagerError.unsupportedFormat` | Disable reading for the extension. |
| `TagLibManagerError.invalidFile` | The URL is not a regular file or is a final symlink. |
| `TagLibManagerError.failedToReadWithUnderlying` | The parser could not open or validate the file; surface the detail. |
| `TagLibManagerError.fileChanged` | The file changed during a snapshot read; reload. |
| `MetadataAudioContentError.unavailable` | The layout cannot be guarded; do not infer continuity. |

## Related references

- [Writing metadata](WRITING.md) — patches, raw deltas, Basic replacement, structured writes, erase.
- [Capabilities](CAPABILITIES.md) — declared format and field support.
- [Manager API](../reference/API.md) and [model reference](../reference/MODELS.md) — exact declarations.
- [Transactions](../explanation/TRANSACTIONS.md) — version, staging, and concurrency semantics.
