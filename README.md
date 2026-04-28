# TagLibAudioMetadata

`TagLibAudioMetadata` is a Swift Package wrapper around a bundled TagLib bridge. It reads, writes, erases, and inspects audio metadata through a Swift facade, without requiring callers to work with TagLib C++ APIs directly.

The package is intended for app code that needs:

- Common audio metadata such as title, artist, album, track/disc numbers, dates, artwork, MusicBrainz IDs, ReplayGain, iTunes fields, and custom fields.
- Raw TagLib `PropertyMap` access for advanced metadata editors.
- Post-write verification warnings so apps can detect container-specific normalization or unsupported fields.
- A compatibility API that returns `nil`, plus throwing APIs for callers that need precise error handling.

## Requirements

- Swift tools version: `6.0`
- Platforms:
  - macOS 13+
  - iOS 16+
- C++ standard: GNU C++20, configured by the package.

## Installation

Add the package to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ChrisLloydME/TagLibAudioMetadata.git", branch: "main")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "TagLibAudioMetadata", package: "TagLibAudioMetadata")
        ]
    )
]
```

Then import the Swift facade:

```swift
import TagLibAudioMetadata
```

`TagLibAudioMetadata` re-exports the underlying `CTagLibBridge`, so advanced callers can also use `TagLibMetadataExtractor` and `TagLibAudioMetadata` directly after importing this package.

## Supported Formats

Check support before showing write controls or attempting to parse a file:

```swift
let readable = TagLibMetadataManager.isReadableFormat(url.pathExtension)
let writable = TagLibMetadataManager.isWritableFormat(url.pathExtension)
let readableExtensions = TagLibMetadataManager.readableExtensions
let writableExtensions = TagLibMetadataManager.writableExtensions
```

Readable extensions:

`mp3`, `mp2`, `aac`, `m4a`, `m4r`, `m4b`, `m4p`, `mp4`, `m4v`, `3g2`, `ogg`, `oga`, `opus`, `spx`, `flac`, `ape`, `wv`, `mpc`, `wma`, `asf`, `tta`, `wav`, `aiff`, `aif`, `aifc`, `afc`, `dsf`, `dff`, `dsdiff`, `shn`, `mod`, `module`, `nst`, `wow`, `s3m`, `it`, `xm`.

Writable extensions:

All readable extensions except `shn`. TagLib 2.1.1 exposes Shorten metadata for reading, but its Shorten writer reports saving as unsupported.

This package follows the capabilities of the bundled TagLib source. The current vendored TagLib is 2.1.1; Matroska/WebM support appears in newer upstream TagLib releases and requires updating the vendored TagLib sources before this bridge can expose it.

Tag support varies by container. Some formats may normalize values, drop unsupported fields, or store fields under format-specific keys. Use the verification APIs when the result matters.

## Quick Start

Read metadata:

```swift
let url = URL(fileURLWithPath: "/path/to/song.flac")

do {
    let metadata = try TagLibMetadataManager.readMetadataResult(from: url)
    print(metadata.title)
    print(metadata.artist)
    print(metadata.duration)
} catch TagLibManagerError.unsupportedFormat {
    print("Unsupported file format")
} catch {
    print("Could not read metadata: \(error)")
}
```

Edit and write metadata:

```swift
var metadata = try TagLibMetadataManager.readMetadataResult(from: url)
metadata.title = "New title"
metadata.artist = "New artist"
metadata.track = 1
metadata.trackTotal = 12
metadata.trackNumberText = "01/12"

let result = try TagLibMetadataManager.writeMetadataWithVerification(
    metadata,
    to: url,
    failurePolicy: .warn
)

for warning in result.warnings {
    print("Metadata warning: \(warning)")
}
```

Use the simpler compatibility write API when warnings only need to be printed:

```swift
try TagLibMetadataManager.writeMetadata(metadata, to: url)
```

## Main Swift API

Use `TagLibMetadataManager` for normal Swift app code.

### `readMetadataResult(from:)`

```swift
public static func readMetadataResult(from url: URL) throws -> BasicMetadata
```

Reads structured metadata and audio properties from a supported file. This is the preferred read API when the caller needs to distinguish unsupported formats from read failures.

```swift
do {
    let metadata = try TagLibMetadataManager.readMetadataResult(from: url)
    print(metadata.album)
} catch TagLibManagerError.unsupportedFormat {
    // File extension is missing or unsupported.
} catch TagLibManagerError.failedToReadWithUnderlying(let message) {
    print(message)
}
```

### `readMetadata(from:)`

```swift
public static func readMetadata(from url: URL) -> BasicMetadata?
```

Compatibility read API. It returns `nil` for unsupported formats and read failures, and prints the error.

```swift
if let metadata = TagLibMetadataManager.readMetadata(from: url) {
    print(metadata.title)
}
```

Use `readMetadataResult(from:)` for new code that needs reliable error handling.

### `writeMetadataWithVerification(_:to:failurePolicy:)`

```swift
@discardableResult
public static func writeMetadataWithVerification(
    _ meta: BasicMetadata,
    to url: URL,
    failurePolicy: TagLibMetadataManager.VerificationFailurePolicy = .warn
) throws -> TagLibMetadataManager.MetadataWriteResult
```

Writes a `BasicMetadata` value and verifies important fields afterward. Empty strings are written as `nil`, which clears/removes the field where the container supports it. Numeric fields use `0` as the unset/clear value.

```swift
var metadata = BasicMetadata.empty
metadata.title = "Example"
metadata.artist = "Artist"
metadata.album = "Album"
metadata.track = 1
metadata.trackTotal = 10
metadata.disc = 1
metadata.discTotal = 2
metadata.isExplicit = true
metadata.customFields = ["MOOD": "Focused"]

let result = try TagLibMetadataManager.writeMetadataWithVerification(metadata, to: url)
if !result.warnings.isEmpty {
    print(result.warnings)
}
```

Set `failurePolicy: .throw` to convert verification warnings into `TagLibManagerError.verificationFailed`.

```swift
try TagLibMetadataManager.writeMetadataWithVerification(
    metadata,
    to: url,
    failurePolicy: .throw
)
```

### `writeMetadata(_:to:)`

```swift
@discardableResult
public static func writeMetadata(_ meta: BasicMetadata, to url: URL) throws -> Bool
```

Convenience wrapper around `writeMetadataWithVerification`. It returns `true` on success and prints verification warnings.

```swift
try TagLibMetadataManager.writeMetadata(metadata, to: url)
```

### `writeTagMetadata(_:to:verification:failurePolicy:)`

```swift
@discardableResult
public static func writeTagMetadata(
    _ metadata: TagLibAudioMetadata,
    to url: URL,
    verification: TagLibMetadataManager.MetadataWriteVerificationContext = .none,
    failurePolicy: TagLibMetadataManager.VerificationFailurePolicy = .warn
) throws -> TagLibMetadataManager.MetadataWriteResult
```

Low-level write API for callers that want to construct the Objective-C bridge model directly. Use this when a field exists on `TagLibAudioMetadata` but your code does not want to pass through `BasicMetadata`.

```swift
let metadata = TagLibAudioMetadata()
metadata.title = "Bridge title"
metadata.artist = "Bridge artist"
metadata.trackNumber = 3
metadata.totalTracks = 12
metadata.trackNumberText = "03/12"

let verification = TagLibMetadataManager.MetadataWriteVerificationContext(
    expectedTrackNumber: 3,
    expectedTrackTotal: 12,
    expectedTrackNumberText: "03/12",
    expectedDiscNumber: nil,
    expectedDiscTotal: nil,
    expectedDiscNumberText: nil,
    expectedExplicitContent: nil,
    artworkExpectation: .unchanged,
    customFieldKeys: []
)

try TagLibMetadataManager.writeTagMetadata(
    metadata,
    to: url,
    verification: verification
)
```

### `writeTrackNumberText(_:discNumberText:to:verifyAfterWrite:failurePolicy:)`

```swift
@discardableResult
public static func writeTrackNumberText(
    _ trackNumberText: String,
    discNumberText: String?,
    to url: URL,
    verifyAfterWrite: Bool = true,
    failurePolicy: TagLibMetadataManager.VerificationFailurePolicy = .warn
) throws -> TagLibMetadataManager.MetadataWriteResult
```

Writes only track/disc number text. This is useful for renumbering while preserving padding such as `01/10`.

```swift
try TagLibMetadataManager.writeTrackNumberText(
    "01/10",
    discNumberText: "01/02",
    to: url
)
```

Pass `discNumberText: nil` to leave the disc field unchanged. Pass an empty track value to clear track number data where the container supports it.

### `rawMetadataResult(from:)`

```swift
public static func rawMetadataResult(from url: URL) throws -> RawMetadataDump
```

Reads raw metadata as TagLib sees it. This is intended for metadata inspector/editor UI where users need direct `PropertyMap` keys and ID3v2 frames.

```swift
let dump = try TagLibMetadataManager.rawMetadataResult(from: url)

for property in dump.properties {
    print("\(property.key) = \(property.value)")
}

for frame in dump.id3v2Frames {
    print("\(frame.frameID): \(frame.value)")
}
```

### `rawMetadata(from:)`

```swift
public static func rawMetadata(from url: URL) -> RawMetadataDump?
```

Compatibility raw metadata API. It returns `nil` if the format is unsupported or extraction fails.

```swift
let dump = TagLibMetadataManager.rawMetadata(from: url) ?? .empty
```

### `rawMetadataText(from:)`

```swift
public static func rawMetadataText(from url: URL) -> String?
```

Returns a readable plain-text dump of TagLib properties and ID3v2 frames. Use it for diagnostics, copy/paste, or debug UI.

```swift
if let text = TagLibMetadataManager.rawMetadataText(from: url) {
    print(text)
}
```

### `writeRawMetadataPropertyMapWithVerification(_:to:mode:verifyAfterWrite:failurePolicy:)`

```swift
@discardableResult
public static func writeRawMetadataPropertyMapWithVerification(
    _ properties: [String: String],
    to url: URL,
    mode: TagLibMetadataManager.RawPropertyMapWriteMode = .replace,
    verifyAfterWrite: Bool = true,
    failurePolicy: TagLibMetadataManager.VerificationFailurePolicy = .warn
) throws -> TagLibMetadataManager.MetadataWriteResult
```

Writes raw TagLib `PropertyMap` key/value pairs.

Replace mode writes exactly the provided map:

```swift
try TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification(
    [
        "TITLE": "Replacement title",
        "ARTIST": "Replacement artist"
    ],
    to: url,
    mode: .replace
)
```

Merge mode updates selected keys while preserving other existing property-map entries. Empty values remove matching keys:

```swift
let result = try TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification(
    [
        "TITLE": "Merged title",
        "COMMENT": ""
    ],
    to: url,
    mode: .merge,
    failurePolicy: .throw
)

print(result.warnings)
```

Raw writes trim empty keys and values before passing them to TagLib. In `.replace` mode, passing an empty dictionary clears the property map where supported.

### `writeRawMetadataPropertyMap(_:to:mode:)`

```swift
@discardableResult
public static func writeRawMetadataPropertyMap(
    _ properties: [String: String],
    to url: URL,
    mode: TagLibMetadataManager.RawPropertyMapWriteMode = .replace
) throws -> Bool
```

Convenience wrapper around the verified raw write API. It returns `true` on success and prints verification warnings.

```swift
try TagLibMetadataManager.writeRawMetadataPropertyMap(
    ["ALBUM": "Raw album"],
    to: url,
    mode: .merge
)
```

### `eraseAllMetadataWithVerification(from:failurePolicy:)`

```swift
@discardableResult
public static func eraseAllMetadataWithVerification(
    from url: URL,
    failurePolicy: TagLibMetadataManager.VerificationFailurePolicy = .warn
) throws -> TagLibMetadataManager.MetadataWriteResult
```

Attempts to remove all metadata. The implementation clears common structured fields, removes artwork, replaces the raw property map with an empty map, then re-reads the file to report any remaining metadata.

```swift
let result = try TagLibMetadataManager.eraseAllMetadataWithVerification(
    from: url,
    failurePolicy: .warn
)

for warning in result.warnings {
    print(warning)
}
```

Use `failurePolicy: .throw` if residual metadata should fail the operation.

### `eraseAllMetadata(from:)`

```swift
@discardableResult
public static func eraseAllMetadata(from url: URL) throws -> Bool
```

Convenience wrapper around `eraseAllMetadataWithVerification`. It returns `true` on success and prints warnings.

```swift
try TagLibMetadataManager.eraseAllMetadata(from: url)
```

## Data Models

### `BasicMetadata`

`BasicMetadata` is the main Swift value model. Use `BasicMetadata.empty` to create a blank value for writing.

String fields default to `""`, numeric fields default to `0`, booleans default to `false`, `artworkData` defaults to `nil`, and `customFields` defaults to `[:]`.

Important fields:

| Field | Type | Meaning |
| --- | --- | --- |
| `title`, `artist`, `album`, `albumArtist` | `String` | Core release and artist tags. |
| `composer`, `genre`, `comment`, `lyrics` | `String` | Common descriptive tags. |
| `track`, `trackTotal`, `disc`, `discTotal` | `Int` | Parsed numeric track/disc values. `0` means absent/unset. |
| `trackNumberText`, `discNumberText` | `String` | Original or preferred text form, for example `01/12`. Use this when padding matters. |
| `year`, `releaseDate`, `originalReleaseDate` | `String` | Date fields. `releaseDate` is preferred over `year` when writing normalized properties. |
| `isrc`, `barcode`, `catalogNumber`, `releaseCountry`, `releaseType` | `String` | Release identifiers and release metadata. |
| `musicBrainzArtistID`, `musicBrainzAlbumID`, `musicBrainzTrackID`, `musicBrainzReleaseGroupID` | `String` | MusicBrainz identifiers. |
| `publisher`, `copyright`, `encodedBy`, `encoderSettings` | `String` | Label/legal/encoding fields. `publisher` maps to the bridge `label` field. |
| `sortTitle`, `sortArtist`, `sortAlbum`, `sortAlbumArtist`, `sortComposer` | `String` | Sort keys. |
| `conductor`, `remixer`, `producer`, `engineer`, `lyricist` | `String` | Personnel fields. |
| `subtitle`, `grouping`, `movement`, `mood`, `language`, `musicalKey` | `String` | Descriptive and classical/music library fields. |
| `replayGainTrack`, `replayGainAlbum` | `String` | ReplayGain values. |
| `mediaType` | `String` | Media type descriptor. |
| `itunesAlbumID`, `itunesArtistID`, `itunesCatalogID`, `itunesGenreID`, `itunesMediaType`, `itunesPurchaseDate`, `itunesNorm`, `itunesSMPB` | `String` | iTunes-specific metadata. |
| `artistType` | `String` | Artist type, typically from MusicBrainz-style metadata. |
| `bpm` | `Int` | Beats per minute. |
| `isCompilation`, `isExplicit` | `Bool` | Compilation and explicit-content flags. |
| `duration`, `bitrate`, `sampleRate`, `channels`, `bitDepth`, `format` | `Double`/`Int`/`String` | Audio properties read from the file. These are informational; normal writes focus on tag metadata. |
| `artworkData` | `Data?` | Embedded artwork bytes when read. |
| `customFields` | `[String: String]` | Additional app/user-defined metadata keys. |
| `provenance` | `MetadataFieldProvenance` | Indicates where selected values came from. |

### `RawMetadataDump`

```swift
public struct RawMetadataDump {
    public var properties: [RawPropertyEntry]
    public var id3v2Frames: [RawID3v2FrameEntry]
}
```

`properties` contains normalized TagLib `PropertyMap` entries. `id3v2Frames` contains MP3 ID3v2 frame details when available.

### `RawPropertyEntry`

```swift
public struct RawPropertyEntry: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var key: String
    public var value: String
    public var values: [String]
    public var count: Int
}
```

- `key`: TagLib property key such as `TITLE`, `TRACKNUMBER`, or `MUSICBRAINZ_TRACKID`.
- `value`: Display value. Multi-value fields are joined with `; `.
- `values`: Individual values when TagLib exposes multiple values.
- `count`: Number of values.

### `RawID3v2FrameEntry`

```swift
public struct RawID3v2FrameEntry: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var frameID: String
    public var value: String
    public var description: String?
    public var language: String?
}
```

Useful for inspecting MP3-specific frames such as `TXXX`, `COMM`, `TRCK`, `TPOS`, and attached text frames.

### `MetadataFieldProvenance` and `MetadataValueSource`

`BasicMetadata.provenance` tells you where selected values came from:

```swift
public enum MetadataValueSource: String {
    case nativeTag
    case propertyMap
    case id3v2Frame
    case rawFallback
    case derivedNumeric
    case none
}
```

Tracked fields:

- `trackNumberText`
- `discNumberText`
- `explicitContent`
- `artwork`

Use this when UI needs to explain whether a value was read from native tags, raw properties, ID3v2 frames, or derived from numeric fallback data.

## Write Verification

Verified write APIs return:

```swift
public struct MetadataWriteResult: Sendable {
    public var warnings: [String]
}
```

Warnings mean the write call succeeded, but a follow-up read did not exactly match the requested values. Common causes:

- The container normalized `01/12` to `1/12`.
- A field is unsupported by that file type.
- Embedded artwork could not be confirmed.
- A custom raw key was renamed or dropped by TagLib/container rules.
- Erase left residual metadata in another tag container.

Control warning behavior with:

```swift
public enum VerificationFailurePolicy {
    case warn
    case `throw`
}
```

- `.warn`: return warnings in `MetadataWriteResult`.
- `.throw`: throw `TagLibManagerError.verificationFailed([String])` when warnings are present.

## Raw PropertyMap Notes

Raw `PropertyMap` keys are TagLib-normalized textual keys. Common keys include:

- `TITLE`
- `ARTIST`
- `ALBUM`
- `ALBUMARTIST`
- `DATE`
- `YEAR`
- `TRACKNUMBER`
- `TRACKTOTAL`
- `DISCNUMBER`
- `DISCTOTAL`
- `GENRE`
- `COMMENT`
- `LYRICS`
- `ISRC`
- `BARCODE`
- `MUSICBRAINZ_ARTISTID`
- `MUSICBRAINZ_ALBUMID`
- `MUSICBRAINZ_TRACKID`
- `REPLAYGAIN_TRACK_GAIN`
- `REPLAYGAIN_ALBUM_GAIN`
- `ITUNESADVISORY`

For normal app code, prefer `BasicMetadata`. Use raw property-map APIs only when you are building an advanced editor or need to preserve/edit keys outside the structured model.

## Error Handling

`TagLibManagerError` cases:

```swift
public enum TagLibManagerError: Error {
    case unsupportedFormat
    case failedToReadWithUnderlying(String)
    case verificationFailed([String])

    // Deprecated:
    case failedToRead
}
```

Typical handling:

```swift
do {
    let result = try TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification(
        ["TITLE": "Title"],
        to: url,
        mode: .merge,
        failurePolicy: .throw
    )
    print(result.warnings)
} catch TagLibManagerError.unsupportedFormat {
    print("Unsupported format")
} catch TagLibManagerError.verificationFailed(let warnings) {
    print("Write completed but verification failed: \(warnings)")
} catch {
    print("TagLib operation failed: \(error)")
}
```

## Low-Level Bridge API

Advanced callers can use the Objective-C++ bridge directly.

### `TagLibMetadataExtractor.extractMetadata(from:)`

```swift
let metadata = try TagLibMetadataExtractor.extractMetadata(from: url)
print(metadata.title ?? "")
```

Returns a `TagLibAudioMetadata` object.

### `TagLibMetadataExtractor.writeMetadata(_:to:)`

```swift
let metadata = TagLibAudioMetadata()
metadata.title = "Title"
metadata.removeArtwork = false

try TagLibMetadataExtractor.writeMetadata(metadata, to: url)
```

Writes the bridge model directly. In most Swift code, prefer `TagLibMetadataManager.writeTagMetadata` so you can use verification.

### `TagLibMetadataExtractor.writeTrackNumberText(_:discNumberText:to:)`

```swift
try TagLibMetadataExtractor.writeTrackNumberText(
    "01/10",
    discNumberText: "01/02",
    to: url
)
```

Low-level track/disc text write.

### `TagLibMetadataExtractor.writeTrackNumber(_:totalTracks:padWidth:to:)`

```swift
try TagLibMetadataExtractor.writeTrackNumber(
    1,
    totalTracks: 10,
    padWidth: 2,
    to: url
)
```

Writes track number and optional total using the requested padding width.

### `TagLibMetadataExtractor.writeRawPropertyMap(_:to:)`

```swift
try TagLibMetadataExtractor.writeRawPropertyMap(
    ["TITLE": "Raw title"],
    to: url
)
```

Replaces the file's property map with the provided key/value pairs. Prefer `TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification` unless you specifically need the raw bridge call.

### `TagLibMetadataExtractor.rawMetadata(for:)`

```swift
let raw = try TagLibMetadataExtractor.rawMetadata(for: url)
let properties = raw["properties"]
let frames = raw["id3v2Frames"]
```

Returns a Foundation dictionary with `properties` and `id3v2Frames` arrays. Prefer `TagLibMetadataManager.rawMetadataResult(from:)` for typed Swift models.

### `TagLibMetadataExtractor.dumpMetadataText(from:)`

```swift
let text = try TagLibMetadataExtractor.dumpMetadataText(from: url)
print(text)
```

Returns a plain-text dump from the bridge.

### `TagLibMetadataExtractor.isSupportedFormat(_:)` and `supportedExtensions()`

```swift
if TagLibMetadataExtractor.isSupportedFormat("flac") {
    print(TagLibMetadataExtractor.supportedExtensions())
}
```

Use these APIs for extension-based gating before read/write operations.

## Artwork

Reading fills `BasicMetadata.artworkData` when embedded artwork is found.

Structured `BasicMetadata` writes do not currently expose a separate "remove artwork" flag. If you need direct artwork removal, use `TagLibAudioMetadata` with `writeTagMetadata`:

```swift
let metadata = TagLibAudioMetadata()
metadata.removeArtwork = true

try TagLibMetadataManager.writeTagMetadata(
    metadata,
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

`eraseAllMetadataWithVerification(from:)` also sets `removeArtwork = true`.

## Practical Guidance

- Use `readMetadataResult(from:)` and `writeMetadataWithVerification(_:to:)` for most app features.
- Use `trackNumberText` and `discNumberText` when preserving padding matters.
- Use raw property-map APIs for advanced editors, not for routine title/artist/album updates.
- Treat `MetadataWriteResult.warnings` as user-visible or log-worthy information when metadata accuracy matters.
- Keep backup copies or write to duplicates when building batch editing workflows; metadata containers differ in what they can preserve.

## Debug Logging

Set the environment variable `AUDIOMATOR_TAGLIB_DEBUG` to `1`, `true`, `yes`, or `on` to enable bridge debug logging.

```sh
AUDIOMATOR_TAGLIB_DEBUG=1 swift run
```
