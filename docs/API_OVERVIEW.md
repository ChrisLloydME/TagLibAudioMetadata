# API Overview

This document describes every public type in the `TagLibAudioMetadata` Swift Package, grouped by purpose. For installation and quick-start examples, see the [README](../README.md). For field-level detail, see [METADATA_FIELDS.md](METADATA_FIELDS.md).

---

## Public modules

The package exposes two targets:

| Target | Role |
| --- | --- |
| `TagLibAudioMetadata` | Swift facade. Import this target in application code. |
| `CTagLibBridge` | Objective-C++ bridge. Re-exported automatically by `TagLibAudioMetadata`. Available to advanced callers. |

Importing `TagLibAudioMetadata` is sufficient for all standard use cases. The `CTagLibBridge` types (`TagLibMetadataExtractor`, `TagLibAudioMetadata`) are also available after that single import.

---

## 1. Format support queries

Use these APIs before showing write controls or before opening a file.

### `TagLibMetadataManager` — format-support static properties and functions

```swift
// Bool checks
TagLibMetadataManager.isReadableFormat("flac")      // → true
TagLibMetadataManager.isWritableFormat("shn")       // → false

// Lists
TagLibMetadataManager.readableExtensions            // [String]
TagLibMetadataManager.writableExtensions            // [String]

// Capability descriptor for one extension (case-insensitive)
let cap = TagLibMetadataManager.formatCapability(for: "m4a")

// All capability descriptors
let all = TagLibMetadataManager.formatCapabilities  // [FormatCapability]
```

### `FormatCapability`

```swift
public struct FormatCapability: Hashable, Sendable, Identifiable {
    public var identifier: String               // Stable family ID, e.g. "mp4"
    public var displayName: String              // Human-readable, e.g. "MP4 / MPEG-4 Audio"
    public var codecName: String                // Codec hint, e.g. "AAC/MP4"
    public var primaryExtension: String         // e.g. "m4a"
    public var extensions: [String]             // All aliases for the family
    public var containers: [String]             // Metadata containers present
    public var isReadable: Bool
    public var isWritable: Bool
    public var canReadArtwork: Bool
    public var canWriteArtwork: Bool
    public var preservesMultiValueProperties: Bool
    public var structuredReadSupport: StructuredMetadataSupport
    public var structuredWriteSupport: StructuredMetadataSupport
    public var readOnlyReason: String?          // Set when isWritable == false
    public var notes: String?
    public var metadataFieldFormats: Set<MetadataFieldFormat>  // Derived from containers
}
```

`FormatCapability` is the preferred source for enabling or disabling editor controls because `isWritable`, `canWriteArtwork`, and `preservesMultiValueProperties` vary by format family. Looking up by any alias (e.g., `"MP4"` or `"m4a"`) returns the same `FormatCapability` with `identifier == "mp4"`.

### `StructuredMetadataSupport`

```swift
public enum StructuredMetadataSupport: String {
    case none        // No structured support exposed
    case propertyMap // PropertyMap-level structured access
    case container   // Container-native structured access (ID3v2, MP4 atoms, ASF, Xiph)
}
```

---

## 2. Reading metadata

### `TagLibMetadataManager.readMetadataResult(from:)` — preferred throwing read

```swift
public static func readMetadataResult(from url: URL) throws -> BasicMetadata
```

Throws `TagLibManagerError.unsupportedFormat` for unrecognized extensions and `TagLibManagerError.failedToReadWithUnderlying(_:)` for file-level failures. Use this for new code.

```swift
do {
    let metadata = try TagLibMetadataManager.readMetadataResult(from: url)
    print(metadata.title, metadata.artist, metadata.duration)
} catch TagLibManagerError.unsupportedFormat {
    // file extension is missing or not in the supported list
} catch TagLibManagerError.failedToReadWithUnderlying(let message) {
    print("Read failed: \(message)")
}
```

### `TagLibMetadataManager.readMetadata(from:)` — compatibility optional read

```swift
public static func readMetadata(from url: URL) -> BasicMetadata?
```

Returns `nil` for unsupported formats and failures. Prints the error internally. Suitable for code that does not need to distinguish error cases.

### `TagLibMetadataManager.rawMetadataResult(from:)` — raw PropertyMap + ID3v2 frames

```swift
public static func rawMetadataResult(from url: URL) throws -> RawMetadataDump
```

Returns the raw `PropertyMap` entries and ID3v2 frames as TagLib exposes them. Use this for metadata inspector or editor UI.

```swift
let dump = try TagLibMetadataManager.rawMetadataResult(from: url)

for prop in dump.properties {
    print("\(prop.key) = \(prop.value)")  // multi-value: prop.values
}
for frame in dump.id3v2Frames {
    print("\(frame.frameID): \(frame.value)")
}
```

### `TagLibMetadataManager.rawMetadata(from:)` — compatibility optional

Returns `RawMetadataDump?`. Use `.empty` as the fallback value when you do not care about the error.

### `TagLibMetadataManager.readStructuredMetadataResult(from:)` — container-aware structured read

```swift
public static func readStructuredMetadataResult(from url: URL) throws -> StructuredMetadata
```

Returns a `StructuredMetadata` value that contains typed containers (ID3v2 frames, MP4 atoms, ASF attributes, Xiph comments, artwork, lyrics, and comments). Use this when a field cannot be safely represented as a single string.

```swift
let structured = try TagLibMetadataManager.readStructuredMetadataResult(from: url)

for artwork in structured.artwork {
    print(artwork.mimeType, artwork.pictureType ?? "unknown", artwork.data.count)
}
for comment in structured.comments {
    print(comment.language, comment.description, comment.text)
}
```

### `TagLibMetadataManager.rawMetadataText(from:)` — plain-text dump

```swift
public static func rawMetadataText(from url: URL) -> String?
```

Returns a human-readable plain-text dump. Use it for diagnostics and copy/paste in debug UI.

---

## 3. Writing metadata

### `TagLibMetadataManager.writeMetadataWithVerification(_:to:failurePolicy:)` — preferred write

```swift
@discardableResult
public static func writeMetadataWithVerification(
    _ meta: BasicMetadata,
    to url: URL,
    failurePolicy: VerificationFailurePolicy = .warn
) throws -> MetadataWriteResult
```

Writes a `BasicMetadata` value. After writing, it re-reads the file and checks key fields for container normalization. Empty strings clear the corresponding tag field; `0` clears numeric fields.

```swift
var metadata = BasicMetadata.empty
metadata.title = "Symphony No. 9"
metadata.artist = "Beethoven"
metadata.track = 1
metadata.trackTotal = 4
metadata.artworkData = imageData   // nil → preserve existing artwork

let result = try TagLibMetadataManager.writeMetadataWithVerification(metadata, to: url)
for warning in result.warnings {
    print("Warning: \(warning)")
}
```

Pass `failurePolicy: .throw` to throw `TagLibManagerError.verificationFailed([String])` instead of returning warnings.

### `TagLibMetadataManager.writeMetadata(_:to:)` — convenience write

```swift
@discardableResult
public static func writeMetadata(_ meta: BasicMetadata, to url: URL) throws -> Bool
```

Wraps `writeMetadataWithVerification`. Prints verification warnings; returns `true` on success. Use this when warnings only need to be logged, not acted on.

### `TagLibMetadataManager.writeTrackNumberText(_:discNumberText:to:verifyAfterWrite:failurePolicy:)` — track/disc renumbering

```swift
@discardableResult
public static func writeTrackNumberText(
    _ trackNumberText: String,
    discNumberText: String?,
    to url: URL,
    verifyAfterWrite: Bool = true,
    failurePolicy: VerificationFailurePolicy = .warn
) throws -> MetadataWriteResult
```

Writes only track and disc number text. Useful for renumbering while keeping zero-padded format like `01/10`. Pass `discNumberText: nil` to leave the disc field unchanged.

### `TagLibMetadataManager.writeTagMetadata(_:to:verification:failurePolicy:)` — low-level bridge write

```swift
@discardableResult
public static func writeTagMetadata(
    _ metadata: TagLibAudioMetadata,
    to url: URL,
    verification: MetadataWriteVerificationContext = .none,
    failurePolicy: VerificationFailurePolicy = .warn
) throws -> MetadataWriteResult
```

Writes a `TagLibAudioMetadata` Objective-C bridge model directly. Use this when a field exists on `TagLibAudioMetadata` (e.g., `removeArtwork`) that does not have a counterpart in `BasicMetadata`.

```swift
// Remove artwork without touching other fields
let tag = TagLibAudioMetadata()
tag.removeArtwork = true
try TagLibMetadataManager.writeTagMetadata(
    tag,
    to: url,
    verification: .init(
        expectedTrackNumber: nil,
        expectedTrackTotal: nil,
        expectedTrackNumberText: nil,
        expectedDiscNumber: nil,
        expectedDiscTotal: nil,
        expectedDiscNumberText: nil,
        expectedExplicitContent: nil,
        artworkExpectation: .absent,
        customFieldKeys: []
    )
)
```

### `TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification(_:to:mode:verifyAfterWrite:failurePolicy:)`

```swift
@discardableResult
public static func writeRawMetadataPropertyMapWithVerification(
    _ properties: [String: String],
    to url: URL,
    mode: RawPropertyMapWriteMode = .replace,
    verifyAfterWrite: Bool = true,
    failurePolicy: VerificationFailurePolicy = .warn
) throws -> MetadataWriteResult
```

Writes TagLib `PropertyMap` key/value pairs.

- `.replace` — replaces the entire PropertyMap with exactly the provided keys.
- `.merge` — reads the current map, updates the provided keys, and saves. An empty string removes the key.

```swift
// Replace: clear everything and write only these keys
try TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification(
    ["TITLE": "New Title", "ARTIST": "New Artist"],
    to: url,
    mode: .replace
)

// Merge: change only TITLE, leave everything else
try TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification(
    ["TITLE": "Updated Title"],
    to: url,
    mode: .merge
)

// Merge: delete COMMENT, leave everything else
try TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification(
    ["COMMENT": ""],
    to: url,
    mode: .merge
)
```

### `TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(_:to:verifyAfterWrite:failurePolicy:)`

```swift
@discardableResult
public static func writeRawMetadataPropertyMapValuesWithVerification(
    _ properties: [String: [String]],
    to url: URL,
    verifyAfterWrite: Bool = true,
    failurePolicy: VerificationFailurePolicy = .warn
) throws -> MetadataWriteResult
```

Writes multi-value PropertyMap entries without flattening. Use this for Xiph/Vorbis containers (FLAC, Ogg Vorbis, Ogg Opus, Ogg FLAC, Ogg Speex) when a field such as `ARTIST` or `GENRE` has multiple distinct values.

```swift
try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(
    ["ARTIST": ["Alice", "Bob"], "GENRE": ["Electronic", "Ambient"]],
    to: url
)
```

### `TagLibMetadataManager.writeStructuredMetadataWithVerification(_:to:riffPolicy:includeProperties:verifyAfterWrite:failurePolicy:)`

Writes structured container-specific metadata. Only collections included in the `StructuredMetadata` payload are changed; unincluded collections are preserved.

```swift
var structured = try TagLibMetadataManager.readStructuredMetadataResult(from: url)
structured.comments = [
    StructuredComment(language: "eng", description: "", text: "Review notes"),
]
let result = try TagLibMetadataManager.writeStructuredMetadataWithVerification(
    structured,
    to: url,
    riffPolicy: .preserveInfo  // default: preserve RIFF INFO on WAV files
)
```

### `TagLibMetadataManager.eraseAllMetadataWithVerification(from:failurePolicy:)` — metadata wipe

```swift
@discardableResult
public static func eraseAllMetadataWithVerification(
    from url: URL,
    failurePolicy: VerificationFailurePolicy = .warn
) throws -> MetadataWriteResult
```

Clears structured fields, removes artwork, writes an empty PropertyMap, and reports any residual metadata after the operation.

---

## 4. Write verification

All verified write functions return `MetadataWriteResult`:

```swift
public struct MetadataWriteResult: Sendable {
    public var warnings: [String]
}
```

`warnings` is non-empty when the re-read after a write did not match the expected values. Possible causes: container normalized a value (e.g., `01/12` → `1/12`), a field is unsupported in that format, artwork could not be confirmed, or a custom key was renamed.

Control behavior with `VerificationFailurePolicy`:

```swift
public enum VerificationFailurePolicy: Sendable {
    case warn   // return warnings in MetadataWriteResult (default)
    case throw  // throw TagLibManagerError.verificationFailed([String])
}
```

Pass `verifyAfterWrite: false` when you want to skip the read-back pass entirely (e.g., in a tight batch loop that verifies separately).

---

## 5. Data models

### `BasicMetadata`

The primary Swift value type for reading and writing. All string fields default to `""`, numerics to `0`, booleans to `false`, `artworkData` to `nil`, and `customFields` to `[:]`. Use `BasicMetadata.empty` as a starting point when building a value to write.

Key fields and types are documented in the main [README](../README.md#basicmetadata) and fully enumerated in [METADATA_FIELDS.md](METADATA_FIELDS.md).

The `provenance: MetadataFieldProvenance` property reports where selected values were sourced from. It is informational and is not written back to the file.

### `RawMetadataDump`

```swift
public struct RawMetadataDump: Hashable, Sendable {
    public var properties: [RawPropertyEntry]   // TagLib PropertyMap
    public var id3v2Frames: [RawID3v2FrameEntry] // ID3v2 frames when available
}
```

### `RawPropertyEntry`

```swift
public struct RawPropertyEntry: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var key: String          // e.g. "TITLE", "MUSICBRAINZ_ARTISTID"
    public var value: String        // Display form; multi-values joined with "; "
    public var values: [String]     // Individual values (for multi-value fields)
    public var count: Int
    public var schema: MetadataFieldSchema?         // Convenience lookup
    public var shouldDisplayAsMultiValue: Bool      // Convenience flag
}
```

### `RawID3v2FrameEntry`

```swift
public struct RawID3v2FrameEntry: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var frameID: String        // e.g. "TIT2", "TRCK", "TXXX", "COMM"
    public var value: String
    public var description: String?   // Set for TXXX, COMM, USLT
    public var language: String?      // Set for COMM, USLT
}
```

### `StructuredMetadata`

```swift
public struct StructuredMetadata: Hashable, Sendable {
    public var properties: [StructuredPropertyEntry]   // PropertyMap
    public var id3v2Frames: [StructuredID3v2Frame]     // ID3v2 typed frames
    public var mp4Atoms: [StructuredMP4Atom]           // MP4 typed atoms
    public var asfAttributes: [StructuredASFAttribute] // ASF typed attributes
    public var artwork: [StructuredArtwork]            // All artwork entries
    public var lyrics: [StructuredLyrics]              // USLT / ©lyr entries
    public var comments: [StructuredComment]           // COMM / comment entries
    public var warnings: [String]                      // Capability/read warnings
}
```

### Structured sub-types

| Type | Key fields |
| --- | --- |
| `StructuredPropertyEntry` | `key: String`, `values: [String]` |
| `StructuredID3v2Frame` | `frameID`, `type`, `value`, `values`, `description`, `language`, `url`, `owner`, `data`, `fields` |
| `StructuredMP4Atom` | `key`, `type`, `value`, `values`, `first`, `second`, `freeformDescription` |
| `StructuredASFAttribute` | `key`, `type`, `value`, `data`, `pictureType`, `mimeType`, `description`, `language`, `stream` |
| `StructuredArtwork` | `container`, `pictureType`, `pictureTypeCode`, `mimeType`, `description`, `data` |
| `StructuredLyrics` | `language`, `description`, `text` |
| `StructuredComment` | `language`, `description`, `text` |

---

## 6. Error handling

```swift
public enum TagLibManagerError: Error, Sendable {
    case unsupportedFormat
    case failedToReadWithUnderlying(String)
    case verificationFailed([String])

    @available(*, deprecated, message: "Use failedToReadWithUnderlying(_:)")
    case failedToRead
}
```

| Case | When thrown |
| --- | --- |
| `unsupportedFormat` | File extension is absent or not in the supported list. |
| `failedToReadWithUnderlying(_:)` | TagLib opened the file but could not extract metadata; the associated string carries a description. |
| `verificationFailed(_:)` | Write succeeded but the post-write read did not match expectations, and `failurePolicy == .throw`. The array contains the warning strings. |
| `failedToRead` | Deprecated. Equivalent to `failedToReadWithUnderlying` without a message. |

---

## 7. Field schema and registry

`MetadataFieldRegistry` is a static lookup table for metadata field descriptors. It is intended for advanced editor UI code that needs to enumerate supported fields, display names, or format-specific storage keys.

```swift
// Look up by field key
let schema = MetadataFieldRegistry.schema(for: .albumArtist)
print(schema?.propertyMapKeys ?? []) // ["ALBUMARTIST", "ALBUM ARTIST"]

// Look up by raw PropertyMap key (case-insensitive)
let schema = MetadataFieldRegistry.schema(forPropertyMapKey: "MUSICBRAINZ_ARTISTID")

// All schemas for fields with MP4 mappings
let mp4Schemas = MetadataFieldRegistry.schemas(withMappingsFor: .mp4)

// All schemas storable in a given format family
let cap = TagLibMetadataManager.formatCapability(for: "m4a")!
let mp4Fields = MetadataFieldRegistry.schemas(storableIn: cap)

// Whether a key is multi-value for display purposes
MetadataFieldRegistry.shouldDisplayRawPropertyAsMultiValue("ARTIST") // → true
```

### `MetadataFieldKey`

An exhaustive enum of all known semantic field identifiers (80+ cases). See [METADATA_FIELDS.md](METADATA_FIELDS.md) for the complete list.

### `MetadataFieldCategory`

Groups fields for UI sections:

`basic`, `numbering`, `artwork`, `lyricsAndComments`, `dates`, `people`, `peopleRoles`, `sorting`, `identifiers`, `release`, `replayGain`, `itunes`, `technical`, `custom`

### `MetadataFieldFormat`

Identifies the metadata container system:

`tagLibPropertyMap`, `id3v2`, `mp4`, `xiph`, `ape`, `asf`, `flac`, `matroska`

### `MetadataFieldStorageKind`

How the field is stored in a particular container:

`nativeTag`, `propertyMap`, `textFrame`, `userTextFrame`, `mp4Atom`, `mp4Freeform`, `complexProperty`, `binary`, `pattern`

### `MetadataFieldSchema`

Per-field descriptor:

```swift
public struct MetadataFieldSchema: Identifiable, Hashable, Sendable {
    public var key: MetadataFieldKey
    public var displayName: String
    public var category: MetadataFieldCategory
    public var propertyMapKeys: [String]            // TagLib PropertyMap key names
    public var mappings: [MetadataFormatMapping]    // Per-container storage descriptors
    public var isMultiValue: Bool
    public var isPeopleField: Bool
    public var isRoleQualified: Bool                // e.g. PERFORMER:<instrument>
    public var isArtworkField: Bool
}
```

---

## 8. Provenance tracking

```swift
public enum MetadataValueSource: String, Hashable, Sendable {
    case nativeTag        // Read from the format's native tag
    case propertyMap      // Read from TagLib PropertyMap
    case id3v2Frame       // Read from an ID3v2 frame directly
    case rawFallback      // Derived from a raw PropertyMap entry
    case derivedNumeric   // Derived from a numeric value when text form was absent
    case none             // Source unknown or field was not present
}

public struct MetadataFieldProvenance: Hashable, Sendable {
    public var trackNumberText: MetadataValueSource
    public var discNumberText: MetadataValueSource
    public var explicitContent: MetadataValueSource
    public var artwork: MetadataValueSource
}
```

`BasicMetadata.provenance` is populated during a read. It is informational and is not written back to the file.

---

## 9. Write policies

### `RawPropertyMapWriteMode`

```swift
public enum RawPropertyMapWriteMode: Sendable {
    case replace  // Replace the entire PropertyMap
    case merge    // Read-modify-write; empty values delete keys
}
```

### `RIFFMetadataWritePolicy`

```swift
public enum RIFFMetadataWritePolicy: String, Hashable, Sendable {
    case id3v2Only              // Target only ID3v2 collections in the write payload
    case preserveInfo           // Default: write ID3v2, leave RIFF INFO intact
    case syncBasicFieldsToInfo  // Reserved; not yet applied (emits a warning)
}
```

### `ArtworkVerificationExpectation`

```swift
public enum ArtworkVerificationExpectation: Sendable {
    case unchanged  // Do not verify artwork presence
    case present    // Verify that artwork is present after write
    case absent     // Verify that artwork was removed
}
```

---

## 10. Low-level Objective-C++ bridge

The bridge types are available after `import TagLibAudioMetadata` because `CTagLibBridge` is re-exported.

| Symbol | Role |
| --- | --- |
| `TagLibMetadataExtractor` | Class with class methods for extraction, writing, and format queries. |
| `TagLibAudioMetadata` | NSObject property bag with all metadata fields including `removeArtwork`. |

Prefer `TagLibMetadataManager` for Swift code. Use the bridge directly only when you need a field or behavior not exposed by the Swift layer (currently: `removeArtwork`, `writeTrackNumber(_:totalTracks:padWidth:to:)`).
