# TagLibAudioMetadata Support Guide

This guide explains how to use the public API in `TagLibAudioMetadata`.
It treats the Swift source and bridge header as the source of truth.

Use this document when you need to decide which API to call, what each model means,
and how to handle container-specific behavior after writes.

## Package Shape

`TagLibAudioMetadata` is a Swift Package with two targets:

- `TagLibAudioMetadata`: the Swift facade used by app code.
- `CTagLibBridge`: the Objective-C++ bridge around the bundled TagLib sources.

Most apps should import the Swift facade:

```swift
import TagLibAudioMetadata
```

The Swift module re-exports `CTagLibBridge`, so advanced callers can still reach
`TagLibMetadataExtractor` and `TagLibAudioMetadata` after importing the package.

Requirements:

- Swift tools version 6.0
- macOS 13+
- iOS 16+
- GNU C++20, configured by `Package.swift`

## API Layers

The package exposes three metadata layers. Pick the highest-level layer that keeps
the data you need.

| Layer | Main types | Use it for |
| --- | --- | --- |
| Basic metadata | `BasicMetadata`, `TagLibMetadataManager.readMetadataResult`, `writeMetadataWithVerification` | Track editors, library views, common tags, artwork, common IDs, ReplayGain, iTunes fields. |
| Raw property map | `RawMetadataDump`, `RawPropertyEntry`, `writeRawMetadataPropertyMapWithVerification` | Advanced editors that expose TagLib property keys directly. |
| Structured metadata | `StructuredMetadata`, `StructuredID3v2Frame`, `StructuredMP4Atom`, `StructuredASFAttribute` | Container-aware editing of ID3v2 frames, MP4 atoms, ASF attributes, comments, lyrics, and artwork. |

Start with `BasicMetadata`. Move to raw or structured APIs only when the user
needs to see or preserve container details that the basic model does not expose.

## Format Support

Check support before you show editing controls or attempt a write.

```swift
let ext = url.pathExtension

guard TagLibMetadataManager.isReadableFormat(ext) else {
    throw TagLibManagerError.unsupportedFormat
}

let canWrite = TagLibMetadataManager.isWritableFormat(ext)
let capability = TagLibMetadataManager.formatCapability(for: ext)
```

Use `formatCapability(for:)` for UI decisions. It reports the format family,
all extension aliases, metadata containers, artwork support, multi-value support,
structured support, and read-only caveats.

```swift
if let capability = TagLibMetadataManager.formatCapability(for: "m4a") {
    print(capability.identifier)              // "mp4"
    print(capability.extensions)              // extension aliases for the family
    print(capability.canWriteArtwork)
    print(capability.structuredWriteSupport)
}
```

`formatCapabilities` returns every known family:

```swift
let writableFamilies = TagLibMetadataManager.formatCapabilities.filter(\.isWritable)
```

`readableExtensions` and `writableExtensions` are extension lists derived from the
same capability data.

## Basic Metadata

`BasicMetadata` is the model for common app-level metadata. It stores text fields
as `String`, numbers as `Int`, booleans as `Bool`, audio properties as numeric
values, artwork as `Data?`, and unknown custom fields as `[String: String]`.

Use `BasicMetadata.empty` when you want to build a value from scratch:

```swift
var metadata = BasicMetadata.empty
metadata.title = "Nocturne"
metadata.artist = "Example Artist"
metadata.album = "Late Sessions"
metadata.track = 1
metadata.trackTotal = 12
metadata.trackNumberText = "01/12"
metadata.artworkData = try Data(contentsOf: coverURL)
```

Empty strings mean "clear this field" when you write through
`writeMetadataWithVerification`. Numeric zero means "unset" for number fields.

### Reading Basic Metadata

Prefer the throwing API in new code:

```swift
do {
    let metadata = try TagLibMetadataManager.readMetadataResult(from: url)
    print(metadata.title)
    print(metadata.duration)
} catch TagLibManagerError.unsupportedFormat {
    // The extension is missing or not supported by this bridge.
} catch TagLibManagerError.failedToReadWithUnderlying(let message) {
    // TagLib or the bridge failed while opening or parsing the file.
    print(message)
}
```

Use the optional API for compatibility paths where `nil` is enough:

```swift
if let metadata = TagLibMetadataManager.readMetadata(from: url) {
    print(metadata.album)
}
```

`readMetadata(from:)` prints the read error and returns `nil`. It does not let the
caller distinguish unsupported formats from corrupt files.

### Writing Basic Metadata

Use the verified write API for editable user data:

```swift
var metadata = try TagLibMetadataManager.readMetadataResult(from: url)
metadata.title = "New Title"
metadata.artist = "New Artist"
metadata.track = 2
metadata.trackTotal = 10
metadata.trackNumberText = "02/10"

let result = try TagLibMetadataManager.writeMetadataWithVerification(
    metadata,
    to: url,
    failurePolicy: .warn
)

for warning in result.warnings {
    print("Metadata warning:", warning)
}
```

`writeMetadataWithVerification` writes through the bridge and reads the file back
to check important fields. Containers can normalize or reject values. The method
reports those cases as warnings.

Set `failurePolicy: .throw` when a warning should fail the operation:

```swift
try TagLibMetadataManager.writeMetadataWithVerification(
    metadata,
    to: url,
    failurePolicy: .throw
)
```

With `.throw`, verification warnings become
`TagLibManagerError.verificationFailed([String])`.

Use `writeMetadata(_:to:)` only when you want the convenience wrapper:

```swift
try TagLibMetadataManager.writeMetadata(metadata, to: url)
```

It prints verification warnings and returns `true` on success.

### Track and Disc Number Text

Many containers store track and disc numbers as text such as `01/12`.
`BasicMetadata` keeps both parsed numbers and the original text form:

- `track` and `trackTotal` store parsed numeric values.
- `disc` and `discTotal` store parsed numeric values.
- `trackNumberText` and `discNumberText` preserve formatting when possible.

Use `writeTrackNumberText` for renumbering features that should keep padding:

```swift
let result = try TagLibMetadataManager.writeTrackNumberText(
    "03/12",
    discNumberText: "01/02",
    to: url
)

if !result.warnings.isEmpty {
    print(result.warnings)
}
```

Pass `discNumberText: nil` to leave the disc text unchanged.

### Artwork

Read artwork from `BasicMetadata.artworkData`:

```swift
let metadata = try TagLibMetadataManager.readMetadataResult(from: url)
if let artwork = metadata.artworkData {
    renderArtwork(artwork)
}
```

Write artwork by assigning image data:

```swift
var metadata = try TagLibMetadataManager.readMetadataResult(from: url)
metadata.artworkData = try Data(contentsOf: coverURL)

let result = try TagLibMetadataManager.writeMetadataWithVerification(metadata, to: url)
```

Check `FormatCapability.canWriteArtwork` before enabling artwork editing. Some
formats can read tags but cannot persist artwork.

To remove artwork through the low-level bridge model:

```swift
let bridgeMetadata = TagLibAudioMetadata()
bridgeMetadata.removeArtwork = true

try TagLibMetadataManager.writeTagMetadata(
    bridgeMetadata,
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

### Provenance

`BasicMetadata.provenance` explains where selected values came from.

```swift
let metadata = try TagLibMetadataManager.readMetadataResult(from: url)

switch metadata.provenance.trackNumberText {
case .nativeTag:
    print("The container exposed track text directly.")
case .rawFallback:
    print("The manager recovered track text from raw metadata.")
case .derivedNumeric:
    print("The manager derived text from parsed numeric values.")
case .none:
    print("No track text was available.")
default:
    break
}
```

`MetadataValueSource` values:

- `nativeTag`: TagLib exposed the value through its main tag API.
- `propertyMap`: TagLib exposed the value through the normalized property map.
- `id3v2Frame`: the value came from an ID3v2 frame.
- `rawFallback`: the manager recovered a value from the raw dump.
- `derivedNumeric`: the manager derived text from numeric fields.
- `none`: the value was not present.

## Raw Metadata

Raw metadata exposes TagLib `PropertyMap` entries and ID3v2 frame summaries.
Use it for inspection panels, power-user editors, debugging, and custom tag work.

### Reading Raw Metadata

```swift
let dump = try TagLibMetadataManager.rawMetadataResult(from: url)

for property in dump.properties {
    print(property.key, property.values)
}

for frame in dump.id3v2Frames {
    print(frame.frameID, frame.description ?? "", frame.value)
}
```

Use `rawMetadata(from:)` when `nil` is enough:

```swift
let dump = TagLibMetadataManager.rawMetadata(from: url)
```

Use `rawMetadataText(from:)` for copyable diagnostics:

```swift
if let text = TagLibMetadataManager.rawMetadataText(from: url) {
    print(text)
}
```

`RawPropertyEntry.schema` links a raw property key to the field registry when the
key is known. `shouldDisplayAsMultiValue` tells UI code whether to show the entry
as a multi-value field.

### Writing Raw Property Maps

Use `writeRawMetadataPropertyMapWithVerification` when you edit flat
`[String: String]` values:

```swift
try TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification(
    [
        "TITLE": "Raw Title",
        "MOOD": "Focused",
        "CUSTOM_CASE": "Alpha"
    ],
    to: url,
    mode: .replace
)
```

`RawPropertyMapWriteMode.replace` writes exactly the provided map.
Use it for a full editor save where the UI owns the complete property map.

```swift
try TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification(
    [
        "MOOD": "",
        "CUSTOM_CASE": "Beta"
    ],
    to: url,
    mode: .merge
)
```

`RawPropertyMapWriteMode.merge` starts from the current property map, applies
the supplied keys, and removes a key when the supplied value is empty.

Use `writeRawMetadataPropertyMapValuesWithVerification` when the container can
preserve arrays:

```swift
try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(
    ["ARTIST": ["One", "Two"]],
    to: url
)
```

This is the better API for Xiph/Vorbis-style multi-value fields.

The convenience wrapper `writeRawMetadataPropertyMap(_:to:mode:)` writes and
prints warnings:

```swift
try TagLibMetadataManager.writeRawMetadataPropertyMap(
    ["TITLE": "Edited"],
    to: url,
    mode: .merge
)
```

## Structured Metadata

Structured metadata exposes container-specific records while keeping them in
Swift value types. Use it when your UI needs to edit ID3v2 frames, MP4 atoms, ASF
attributes, multiple comments, multiple lyrics entries, or multiple artwork
records.

### Reading Structured Metadata

```swift
let structured = try TagLibMetadataManager.readStructuredMetadataResult(from: url)

for frame in structured.id3v2Frames {
    print(frame.frameID, frame.type, frame.value)
}

for atom in structured.mp4Atoms {
    print(atom.key, atom.type, atom.values)
}

for warning in structured.warnings {
    print("Structured read warning:", warning)
}
```

Use `readStructuredMetadata(from:)` for an optional result:

```swift
let structured = TagLibMetadataManager.readStructuredMetadata(from: url)
```

### Writing Structured Metadata

```swift
let payload = StructuredMetadata(
    properties: [
        .init(key: "TITLE", values: ["Structured Title"])
    ],
    id3v2Frames: [
        .init(
            frameID: "TIT3",
            type: "text",
            value: "Subtitle",
            values: ["Subtitle"]
        )
    ],
    comments: [
        .init(language: "eng", description: "", text: "Editor comment")
    ]
)

let result = try TagLibMetadataManager.writeStructuredMetadataWithVerification(
    payload,
    to: url,
    includeProperties: true,
    failurePolicy: .warn
)
```

`includeProperties` controls whether `StructuredMetadata.properties` is included
in the bridge payload. Leave it `false` when you only want to edit frames, atoms,
attributes, artwork, comments, or lyrics.

For MP4 freeform atoms:

```swift
let payload = StructuredMetadata(
    mp4Atoms: [
        .init(
            key: "----:com.apple.iTunes:CATALOGNUMBER",
            type: "stringList",
            values: ["ABC-123"]
        )
    ]
)

try TagLibMetadataManager.writeStructuredMetadataWithVerification(payload, to: url)
```

For structured artwork:

```swift
let artwork = StructuredArtwork(
    container: "id3v2",
    pictureType: "Front Cover",
    pictureTypeCode: 3,
    mimeType: "image/jpeg",
    data: try Data(contentsOf: coverURL)
)

try TagLibMetadataManager.writeStructuredMetadataWithVerification(
    StructuredMetadata(artwork: [artwork]),
    to: url
)
```

`RIFFMetadataWritePolicy` applies to WAV/AIFF-style containers:

- `.id3v2Only`: write structured ID3v2 data only.
- `.preserveInfo`: keep existing RIFF INFO fields.
- `.syncBasicFieldsToInfo`: currently reports a warning because the structured
  bridge does not apply INFO synchronization yet.

## Erasing Metadata

Use the verified erase API when the user chooses a destructive metadata clear:

```swift
let result = try TagLibMetadataManager.eraseAllMetadataWithVerification(
    from: url,
    failurePolicy: .warn
)

for warning in result.warnings {
    print("Erase warning:", warning)
}
```

The manager writes an empty `TagLibAudioMetadata`, clears the raw property map,
wipes the native metadata container for supported families, and reads back the
file to report residual fields.

The convenience wrapper prints warnings:

```swift
try TagLibMetadataManager.eraseAllMetadata(from: url)
```

## Verification

Write methods that return `MetadataWriteResult` may include warnings. A warning
means the bridge completed the write call, then the read-back check found a
difference or could not confirm part of the requested change.

Common warning causes:

- The container normalized number formatting, such as `01/10` to `1/10`.
- The container does not support a field.
- A custom field was stored under a container-specific alias.
- Artwork could not be confirmed after write.
- Structured metadata collections changed shape after TagLib saved the file.

Choose the failure policy per workflow:

```swift
// Let the save succeed and show warnings in the UI.
try TagLibMetadataManager.writeMetadataWithVerification(
    metadata,
    to: url,
    failurePolicy: .warn
)

// Treat verification differences as save failures.
try TagLibMetadataManager.writeMetadataWithVerification(
    metadata,
    to: url,
    failurePolicy: .throw
)
```

Use `.throw` for tests, batch processing, and workflows where silent
normalization would be data loss.

## Field Registry

`MetadataFieldRegistry` describes known fields, their display names, categories,
PropertyMap keys, and container mappings.

Use it to build metadata editor UIs:

```swift
let basicFields = MetadataFieldRegistry.allSchemas.filter {
    $0.category == .basic
}
```

Find a schema by enum key:

```swift
let titleSchema = MetadataFieldRegistry.schema(for: .title)
```

Find a schema by raw property map key:

```swift
let schema = MetadataFieldRegistry.schema(forPropertyMapKey: "MUSICBRAINZ_TRACKID")
```

Filter fields by format family:

```swift
let id3Fields = MetadataFieldRegistry.schemas(withMappingsFor: .id3v2)
```

Filter fields by a runtime format capability:

```swift
if let capability = TagLibMetadataManager.formatCapability(for: url.pathExtension) {
    let supportedFields = MetadataFieldRegistry.schemas(storableIn: capability)
}
```

Check whether a field has a mapping:

```swift
if MetadataFieldRegistry.schema(.title, hasMappingFor: .mp4) {
    print("Title has an MP4 mapping.")
}
```

Normalize raw property keys before comparisons:

```swift
let key = MetadataFieldRegistry.normalizePropertyMapKey(" musicbrainz_trackid ")
// "MUSICBRAINZ_TRACKID"
```

## Field Model Reference

`BasicMetadata` includes these field groups.

Core:

- `title`, `artist`, `album`, `albumArtist`
- `composer`, `genre`, `comment`, `lyrics`

Numbering:

- `track`, `trackTotal`, `trackNumberText`
- `disc`, `discTotal`, `discNumberText`
- `movementNumber`, `movementCount`

Dates:

- `year`
- `releaseDate`
- `originalReleaseDate`

People and roles:

- `conductor`, `remixer`, `producer`, `engineer`, `lyricist`
- `originalArtist`

Sorting:

- `sortTitle`, `sortArtist`, `sortAlbum`, `sortAlbumArtist`, `sortComposer`

Identifiers:

- `isrc`, `barcode`, `asin`, `catalogNumber`
- `musicBrainzArtistID`, `musicBrainzAlbumID`, `musicBrainzAlbumArtistID`
- `musicBrainzTrackID`, `musicBrainzReleaseGroupID`
- `musicBrainzReleaseTrackID`, `musicBrainzWorkID`
- `acoustID`, `acoustIDFingerprint`, `musicIPPUID`

Release and work metadata:

- `publisher`, `copyright`
- `releaseType`, `releaseStatus`, `releaseCountry`, `artistType`
- `originalAlbum`, `discSubtitle`, `work`, `movement`
- `subtitle`, `grouping`, `mood`, `language`, `musicalKey`

Technical and playback metadata:

- `encodedBy`, `encoderSettings`
- `replayGainTrack`, `replayGainAlbum`
- `mediaType`, `bpm`, `isCompilation`, `isExplicit`

iTunes metadata:

- `itunesAlbumID`, `itunesArtistID`, `itunesCatalogID`, `itunesGenreID`
- `itunesMediaType`, `itunesPurchaseDate`
- `itunesNorm`, `itunesSMPB`

Read-only audio properties:

- `duration`
- `bitrate`
- `sampleRate`
- `channels`
- `bitDepth`
- `format`

Other:

- `artworkData`
- `customFields`
- `provenance`

Audio properties are read from the file. The basic write path maps common tag
fields, artwork, and custom fields back to the bridge model.

## Error Reference

`TagLibManagerError` can report:

- `unsupportedFormat`: the URL has no extension or the bridge does not support it.
- `failedToReadWithUnderlying(String)`: TagLib or the bridge failed while reading.
- `verificationFailed([String])`: verification produced warnings and the caller
  requested `failurePolicy: .throw`.
- `failedToRead`: deprecated. Use `failedToReadWithUnderlying`.

## Low-Level Bridge API

Most Swift app code should call `TagLibMetadataManager`. Use the bridge directly
only when you need a property or method the facade does not wrap.

`TagLibAudioMetadata` is an Objective-C class with nullable properties. It maps
closely to the bridge writer. This is useful for partial low-level writes:

```swift
let metadata = TagLibAudioMetadata()
metadata.title = "Bridge Title"
metadata.trackNumber = 1
metadata.totalTracks = 10
metadata.trackNumberText = "01/10"

try TagLibMetadataManager.writeTagMetadata(metadata, to: url)
```

`TagLibMetadataExtractor` exposes bridge methods such as:

- `extractMetadata(from:)`
- `writeMetadata(_:to:)`
- `writeTrackNumberText(_:discNumberText:to:)`
- `writeRawPropertyMap(_:to:)`
- `writeRawPropertyMapValues(_:to:)`
- `structuredMetadata(for:)`
- `writeStructuredMetadata(_:to:)`
- `wipeMetadata(from:)`
- `rawMetadata(for:)`
- `dumpMetadataText(from:)`
- `isSupportedFormat(_:)`
- `isWritableFormat(_:)`
- `supportedExtensions()`
- `writableExtensions()`
- `formatCapability(for:)`
- `formatCapabilities()`

The manager wraps these methods with Swift models, support checks, and
verification. Prefer the manager unless you have a specific bridge-level need.

## Practical Recipes

### Build a Read-Only Inspector

```swift
let metadata = try TagLibMetadataManager.readMetadataResult(from: url)
let rawText = TagLibMetadataManager.rawMetadataText(from: url)

titleLabel.text = metadata.title
artistLabel.text = metadata.artist
debugTextView.text = rawText ?? ""
```

### Build an Editor With Capability-Based Controls

```swift
guard let capability = TagLibMetadataManager.formatCapability(for: url.pathExtension) else {
    return
}

titleField.isEnabled = capability.isWritable
artworkButton.isEnabled = capability.canWriteArtwork
structuredButton.isEnabled = capability.structuredWriteSupport != .none
```

### Save User Edits and Surface Warnings

```swift
do {
    let result = try TagLibMetadataManager.writeMetadataWithVerification(
        metadata,
        to: url,
        failurePolicy: .warn
    )
    showWarnings(result.warnings)
} catch TagLibManagerError.unsupportedFormat {
    showError("This file type cannot be edited.")
} catch {
    showError("The file could not be saved.")
}
```

### Preserve Multi-Value Artists

```swift
try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(
    ["ARTIST": ["Primary Artist", "Featured Artist"]],
    to: url
)
```

### Add a Custom Field

```swift
var metadata = try TagLibMetadataManager.readMetadataResult(from: url)
metadata.customFields["CATALOGNUMBER"] = "ABC-123"

try TagLibMetadataManager.writeMetadataWithVerification(metadata, to: url)
```

For an MP4 freeform atom where you need the exact atom key, use structured
metadata instead:

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

### Batch Verify Writes

```swift
for url in urls {
    var metadata = try TagLibMetadataManager.readMetadataResult(from: url)
    metadata.album = "Batch Album"

    do {
        try TagLibMetadataManager.writeMetadataWithVerification(
            metadata,
            to: url,
            failurePolicy: .throw
        )
    } catch TagLibManagerError.verificationFailed(let warnings) {
        report(url, warnings)
    }
}
```

## Notes for App Integrators

Call the support APIs with extensions, not full paths:

```swift
TagLibMetadataManager.isReadableFormat(url.pathExtension)
```

Treat a successful write with warnings as a partial success. The file was saved,
but the saved metadata may not exactly match the requested value.

Do not assume that a field maps to the same storage key in every container. Use
`MetadataFieldRegistry` to show mappings and `FormatCapability` to decide which
controls to expose.

Do not flatten multi-value fields unless your UI has decided to lose that
structure. Use `writeRawMetadataPropertyMapValuesWithVerification` for arrays.

Use structured metadata for frame-level editors. Use basic metadata for normal
library editing.

When erasing metadata, expect residual warnings on formats that preserve unknown
or unsupported fields. Show those warnings instead of presenting the operation as
an unconditional wipe.
