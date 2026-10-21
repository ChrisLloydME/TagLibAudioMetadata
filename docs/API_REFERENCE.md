# Public API reference

This is the maintained index of the package's public Swift surface and the public Objective-C bridge. It describes the declarations at the current source revision; the source remains authoritative for exact types and default arguments. Code blocks omit access modifiers and `nonisolated` annotations for readability.

Use it with the task-oriented [Usage guide](USAGE.md). Behavioral contracts live in [Write semantics](PRESERVATION.md), [Transactions](TRANSACTIONS.md), and [Formats](FORMATS.md) rather than being repeated here.

## Availability and products

| Item | Value |
| --- | --- |
| Swift tools | 6.0 |
| Minimum platforms | macOS 13, iOS 16 |
| Swift product | `TagLibAudioMetadata` (module `TagLibAudioMetadata`) |
| Low-level product | `TagLibAudioMetadataLowLevel` (module `CTagLibBridge`) |
| Internal target | `CTagLibBridgeInternalAPI`; not a library product and not supported for external use |
| Binary dependency | TagLib 2.3.1 dynamic XCFramework, pinned by URL and checksum |

`import TagLibAudioMetadata` exposes the facade. `import CTagLibBridge` is required to name bridge types such as `TagLibAudioMetadata` and `TagLibMetadataExtractor`. The facade does not re-export bridge declarations.

## Extraction options

```swift
struct MetadataExtractionOptions: OptionSet, Sendable {
    let rawValue: UInt
    init(rawValue: UInt)
    static let basic: MetadataExtractionOptions
    static let raw: MetadataExtractionOptions
    static let structured: MetadataExtractionOptions
    static let propertyMap: MetadataExtractionOptions
    static let rawFrames: MetadataExtractionOptions
    static let all: MetadataExtractionOptions
}
```

This Swift option set mirrors the bridge's `TagLibMetadataExtractionOptions` bits. `all` is the union of all five bits. The facade's read methods select their own options; direct bridge clients pass the imported `TagLibMetadataExtractionOptions` value to `metadataProjections(for:options:)`.

## `TagLibMetadataManager`

`TagLibMetadataManager` is a `public struct` used only through `nonisolated static` members. All reads, writes, and capability queries are synchronous and throwing unless marked otherwise. `URL` parameters must be file URLs for mutation; read APIs reject non-file URLs through their format/validation path.

### Reads

```swift
static func readMetadataResult(from url: URL) throws -> BasicMetadata
static func readBasicSnapshot(from url: URL) throws -> BasicMetadataSnapshot
static func readBasicSnapshot(from url: URL, includingAudioContent: Bool) throws -> BasicMetadataSnapshot
static func readSnapshot(from url: URL) throws -> MetadataSnapshot
static func readSnapshot(from url: URL, includingAudioContent: Bool) throws -> MetadataSnapshot
static func rawMetadataResult(from url: URL) throws -> RawMetadataDump
static func readStructuredMetadataResult(from url: URL) throws -> StructuredMetadata
static func fileVersion(at url: URL) throws -> MetadataFileVersion
```

| API | Returns | Notes |
| --- | --- | --- |
| `readMetadataResult` | Normalized Basic metadata | Reads Basic plus the visible `PropertyMap`; does not build structured inspector models. Rejects a file whose observed identity changes during the read. |
| `readBasicSnapshot` | Basic metadata and non-optional `MetadataFileVersion` | Focused read for editors that need an optimistic token. The `includingAudioContent` overload also returns an optional audio identity. |
| `readSnapshot` | Basic, raw, and structured projections plus an optional file version | One parser session. The `includingAudioContent` overload additionally streams the audio identity. Rejects a file changed during extraction with `fileChanged`. |
| `rawMetadataResult` | `RawMetadataDump` | Visible `PropertyMap` entries and raw ID3v2 frame summaries where the parser exposes them. |
| `readStructuredMetadataResult` | `StructuredMetadata` | Container-specific frames/atoms/attributes and artwork/lyrics/comments collections. |
| `fileVersion` | `MetadataFileVersion` | Opaque filesystem revision of an existing regular file; rejects final symlinks and non-regular paths. |

Optional convenience readers collapse every failure to `nil`:

```swift
static func bestEffortMetadata(from url: URL) -> BasicMetadata?
static func bestEffortRawMetadata(from url: URL) -> RawMetadataDump?
static func bestEffortRawMetadataText(from url: URL) -> String?
static func bestEffortStructuredMetadata(from url: URL) -> StructuredMetadata?
```

`bestEffortRawMetadataText` prefers the bridge's text dump and falls back to a formatted dump of `RawMetadataDump`. It is diagnostic text, not a stable serialization format.

Deprecated read names: `readMetadata(from:)`, `rawMetadata(from:)`, `readStructuredMetadata(from:)`, and `rawMetadataText(from:)`. They forward to the best-effort forms.

### Typed metadata patches

```swift
static func applyMetadataPatch(
    _ patch: MetadataPatch,
    to url: URL,
    expectedVersion: MetadataFileVersion? = nil
) throws -> MetadataWriteResult

static func applyMetadataPatch(
    _ patch: MetadataPatch,
    to url: URL,
    expectedVersion: MetadataFileVersion,
    expectedAudioContent: MetadataAudioContentIdentity
) throws -> MetadataWriteResult
```

The guarded overload requires both guards: `expectedVersion` binds the merge decision to an exact revision, and `expectedAudioContent` requires the encoded audio to match the baseline. Availability is limited to WAV, AIFF/AIFF-C, and native FLAC; see [Audio-content continuity](AUDIO_CONTENT_CONTINUITY.md).

An empty patch is a no-op and returns an empty result without validating a version, audio identity, or format. A non-empty patch is validated before staging:

- field/value kinds come from `MetadataFieldRegistry`;
- track/disc components accept `1...Int32.max`; BPM and movement numbering accept `0...Int32.max`;
- `.artwork`, `.custom`, and `.explicitContent` must use dedicated patch properties;
- role-qualified fields (`.performer`, `.involvedPeople`, `.musicianCredits`) require a raw or structured API;
- known custom keys, aliases, case variants, and typed/custom collisions are rejected;
- `numberText` cannot be combined with typed track/disc components;
- empty text and value lists are rejected after trimming; `.remove` is the deletion marker;
- a native pair's first component cannot be removed while retaining an unrepresentable total.

The deprecated overload `applyMetadataPatch(_:to:expectedVersion:failurePolicy:)` forwards to the unguarded typed patch. `VerificationFailurePolicy.warn` is deprecated and does not bypass verification.

### Basic writes

```swift
static func replaceBasicMetadata(
    _ metadata: BasicMetadata,
    to url: URL,
    expectedVersion: MetadataFileVersion? = nil
) throws -> MetadataWriteResult

static func updateBasicMetadata(
    at url: URL,
    _ update: (inout BasicMetadata) throws -> Void
) throws -> MetadataWriteResult
```

`replaceBasicMetadata` has replacement semantics for the fields `BasicMetadata` explicitly models: empty strings and zero numbers clear those fields where the container allows it. It preserves untouched raw fields, multi-value cardinality, documented aliases, qualified people keys, and unchanged native comment/lyric collections on supported ID3-backed formats. It does not treat the input as a partial patch.

`updateBasicMetadata` reads a `BasicMetadataSnapshot`, applies the closure in memory, reconciles single-field MP4 year/release-date intent, and calls `replaceBasicMetadata` with the captured file version. It is the recommended Basic read/modify/write convenience.

Deprecated wrappers: `writeMetadata(_:to:)`, `writeMetadata(_:to:expectedVersion:)`, and `writeMetadataWithVerification(_:to:failurePolicy:)`.

### Raw property-map writes

```swift
static func writeRawMetadataPropertyMapWithVerification(
    _ properties: [String: String],
    to url: URL,
    mode: RawPropertyMapWriteMode = .replace,
    verifyAfterWrite: Bool = true,
    expectedVersion: MetadataFileVersion? = nil
) throws -> MetadataWriteResult

static func writeRawMetadataPropertyMapValuesWithVerification(
    _ properties: [String: [String]],
    to url: URL,
    mode: RawPropertyMapWriteMode = .replace,
    verifyAfterWrite: Bool = true,
    expectedVersion: MetadataFileVersion? = nil
) throws -> MetadataWriteResult

static func writeRawMetadataPropertyMap(
    _ properties: [String: String],
    to url: URL,
    mode: RawPropertyMapWriteMode = .replace,
    expectedVersion: MetadataFileVersion? = nil
) throws -> Bool
```

- `.replace` owns the complete visible `PropertyMap`. Omitted keys are removed from the visible map. It does not reconstruct native data that TagLib does not expose through `properties()`. On WAV, RIFF INFO is a separate surface and is not removed by this call; omitted INFO keys can remain and cause verification to fail. Use a structured `.id3v2Only` write to remove INFO, or delete both surfaces explicitly.
- `.merge` applies a delta to the visible map, preserves omitted keys and native structures, and treats an empty value or empty array as an explicit removal.
- Both verified writers compare the requested result before commit unless `verifyAfterWrite` is `false`.
- The flat writer trims keys/values and drops empty values. The multi-value writer preserves array boundaries but trims and drops empty elements.
- Keys are TagLib `PropertyMap` keys. Native MP4 `----:` atom identifiers are rejected; use `StructuredMetadata.mp4Atoms`.

```swift
static func applyRawMetadataPatch(
    _ patch: RawMetadataPatch,
    to url: URL,
    expectedVersion: MetadataFileVersion? = nil
) throws -> MetadataWriteResult

static func applyRawMetadataPatch(
    _ patch: RawMetadataPatch,
    to url: URL,
    expectedVersion: MetadataFileVersion,
    expectedAudioContent: MetadataAudioContentIdentity
) throws -> MetadataWriteResult
```

`RawMetadataPatch` is the preservation-oriented delta. Keys omitted from both `valuesToSet` and `removingKeys` are unchanged. Values and array boundaries are not normalized: duplicate values, empty strings, and whitespace are significant. An empty array is invalid; use `removingKeys`. Keys are normalized to uppercase, must not contain surrounding whitespace or NULs, and conflicts after normalization are rejected. The complete visible `PropertyMap` is verified after the delta. An empty patch is a no-op.

Deprecated failure-policy overloads exist for both raw writer families and forward without a bypass.

### Structured writes

```swift
static func writeStructuredMetadataWithVerification(
    _ metadata: StructuredMetadata,
    to url: URL,
    riffPolicy: RIFFMetadataWritePolicy = .preserveInfo,
    includeProperties: Bool = false,
    replacingCollections: Set<StructuredMetadataReplaceableCollection> = [],
    verifyAfterWrite: Bool = true,
    expectedVersion: MetadataFileVersion? = nil
) throws -> MetadataWriteResult
```

Only collections present in the payload are edited. `includeProperties` controls whether `StructuredMetadata.properties` participates: when `false`, a non-empty properties array is rejected by the Swift facade; when `true`, non-empty properties are applied as a delta and an empty `values` array removes that key. `artwork`, `lyrics`, and `comments` use replace-all semantics when non-empty; include an empty collection in `replacingCollections` to remove the last entries.

`riffPolicy` is meaningful for WAV: `.preserveInfo` keeps RIFF INFO, `.id3v2Only` removes it after writing ID3v2, and `.syncBasicFieldsToInfo` is reserved and rejects with `unsupportedWritePolicy`. AIFF/AIFF-C writes use ID3v2; `.preserveInfo` and `.id3v2Only` have no RIFF INFO effect there, while `.syncBasicFieldsToInfo` still rejects as unsupported.

The deprecated overload with `failurePolicy:` forwards without a bypass.

### Formatted number text

```swift
static func writeTrackNumberText(
    _ trackNumberText: String,
    discNumberText: String?,
    to url: URL,
    verifyAfterWrite: Bool = true,
    expectedVersion: MetadataFileVersion? = nil
) throws -> MetadataWriteResult
```

`nil` leaves that pair unchanged; a non-empty string sets it; an empty string removes it. The text must contain at most one `/` and unsigned decimal components no greater than `Int32.max`. Verification checks numeric equivalence and exact text where the container preserves it. `writeTrackNumberText` intentionally writes formatted text; ordinary numeric Basic/Patch writes may normalize padding.

### Low-level bridge-model write

```swift
static func writeTagMetadata(
    _ metadata: TagLibAudioMetadata,
    to url: URL,
    verification: MetadataWriteVerificationContext = .none,
    expectedVersion: MetadataFileVersion? = nil
) throws -> MetadataWriteResult
```

This writes the bridge model through the transactional coordinator. The context defaults to `.none`, which performs no semantic readback. The facade transaction also does not add a staged-file readability readback for this API; supply verification expectations or use a typed/structured API when confirmation matters. The model is a full writer payload for the fields the bridge maps, not an omission-safe patch. Requires `import CTagLibBridge` to name the parameter type.

### Erase

```swift
static func eraseAllMetadataWithVerification(
    from url: URL,
    expectedVersion: MetadataFileVersion? = nil
) throws -> MetadataWriteResult

static func eraseAllMetadata(from url: URL) throws -> Bool
```

Verified erase writes an empty bridge model, clears the visible property map, wipes the native metadata container where supported, and re-reads the staged file. Detected residual fields throw `verificationFailed` before commit. The erase is bounded by the metadata surfaces the parser exposes; it is not a forensic scrub of every container byte. The `Bool` convenience discards the richer result but still throws on verification failure.

### Capability discovery

```swift
static var formatCapabilities: [FormatCapability]
static func capability(forExtension fileExtension: String) -> FormatCapability?
static func probeFile(at url: URL) throws -> FormatCapability
static func formatSupportLevel(for fileExtension: String) -> FormatSupportLevel
static func isReadableExtension(_ fileExtension: String) -> Bool
static func isWritableExtension(_ fileExtension: String) -> Bool
static var readableExtensions: [String]
static var writableExtensions: [String]
```

`capability(forExtension:)` and the extension booleans are declared-metadata lookups; they do not open a file. Extension matching is case-insensitive. `probeFile` parses a concrete file before returning the declared family capability. `formatSupportLevel` returns the requested extension's configured level or `.unsupported`.

Deprecated: `formatCapability(for:)`, `isReadableFormat(_:)`, `isWritableFormat(_:)`.

### Nested manager types

#### `ArtworkVerificationExpectation`

```swift
enum ArtworkVerificationExpectation: Sendable {
    case skip
    case present
    case absent
    @available(*, deprecated, renamed: "skip") case unchanged
}
```

`skip` is the default. `present` and `absent` are presence checks; use `expectedArtworkData` and `expectedArtworkMIMEType` in `MetadataWriteVerificationContext` for exact comparisons.

#### `MetadataWriteVerificationContext`

```swift
struct MetadataWriteVerificationContext: Equatable, Sendable {
    var expectedTrackNumber: Int?
    var expectedTrackTotal: Int?
    var expectedTrackNumberText: String?
    var expectedDiscNumber: Int?
    var expectedDiscTotal: Int?
    var expectedDiscNumberText: String?
    var expectedExplicitContent: Bool?
    var expectedExplicitAdvisory: ExplicitAdvisory?
    var artworkExpectation: ArtworkVerificationExpectation
    var expectedArtworkData: Data?
    var expectedArtworkMIMEType: String?
    var customFieldKeys: [String]
    var customFieldValues: [String: String]
    var expectedTextFields: [String: String]

    static let none: MetadataWriteVerificationContext
}
```

The initializer requires the first nine parameters in the order shown by the source; `expectedTextFields`, `expectedExplicitAdvisory`, and `customFieldValues` have defaults. `expectedTextFields` keys are camel-case `BasicMetadata` names such as `title`, `albumArtist`, and `encodedBy`, not `PropertyMap` keys. `customFieldValues` compares values; `customFieldKeys` checks key presence. `expectedArtworkData`/`expectedArtworkMIMEType` add exact artwork checks independent of `artworkExpectation`.

#### `MetadataCommitStatus` and `MetadataWriteResult`

```swift
enum MetadataCommitStatus: Equatable, Sendable {
    case durable
    case durabilityUncertain(String)
}

struct MetadataWriteResult: Sendable {
    var warnings: [String]
    var commitStatus: MetadataCommitStatus

    init(warnings: [String], commitStatus: MetadataCommitStatus = .durable)
}
```

`.durable` means the requested file and parent-directory flushes completed; it is not a hardware or power-loss guarantee. `.durabilityUncertain` means the rename already committed but the final directory sync failed. Do not retry as though nothing happened.

#### `RawPropertyMapWriteMode`

```swift
enum RawPropertyMapWriteMode: Sendable {
    case replace
    case merge
}
```

#### `VerificationFailurePolicy` (deprecated)

```swift
enum VerificationFailurePolicy: Sendable {
    case warn
    case `throw`
}
```

Retained only for source compatibility. Verification mismatches always abort; `.warn` cannot permit a commit.

## Core value models

### Construction notes

- `BasicMetadata` has no public memberwise initializer. Start from `BasicMetadata.empty` and mutate properties, or obtain a value from a read.
- `MetadataFileVersion` and `MetadataAudioContentIdentity` are opaque: no public initializer, and their stored fields are private.
- `MetadataSnapshot` and `BasicMetadataSnapshot` have public initializers for constructing values in tests and tools; a value-version of `nil` is allowed only by the `MetadataSnapshot` initializer.
- `MetadataPatch`, `RawMetadataPatch`, `MetadataWriteVerificationContext`, `MetadataWriteResult`, `MetadataNumberTextPatch`, and the schema/value model structs have public memberwise-style initializers where shown in the source. Model initializers do not perform container validation; use the manager APIs for validated writes.

### `BasicMetadata`

`BasicMetadata` is a normalized projection for display and common editing, not a lossless document. It stores text as `String`, numbers as `Int`, flags as `Bool`, and artwork as `Data?`.

| Group | Members |
| --- | --- |
| Core | `title`, `artist`, `album`, `albumArtist`, `composer`, `genre`, `comment`, `lyrics` |
| Numbering | `track`, `trackTotal`, `disc`, `discTotal`, `trackNumberText`, `discNumberText`, `movementNumber`, `movementCount` |
| Dates | `year` (recording-date/year projection), `releaseDate`, `originalReleaseDate` |
| People | `conductor`, `remixer`, `producer`, `engineer`, `lyricist`, `originalArtist` |
| Sorting | `sortTitle`, `sortArtist`, `sortAlbum`, `sortAlbumArtist`, `sortComposer` |
| Identifiers | `isrc`, `barcode`, `asin`, `catalogNumber`, `musicBrainzArtistID`, `musicBrainzAlbumID`, `musicBrainzAlbumArtistID`, `musicBrainzTrackID`, `musicBrainzReleaseGroupID`, `musicBrainzReleaseTrackID`, `musicBrainzWorkID`, `acoustID`, `acoustIDFingerprint`, `musicIPPUID` |
| Release/work | `publisher` (maps to TagLib `label`), `copyright`, `releaseType`, `releaseStatus`, `releaseCountry`, `artistType`, `originalAlbum`, `discSubtitle`, `work`, `movement`, `subtitle`, `grouping`, `mood`, `language`, `musicalKey` |
| Technical | `encodedBy`, `encoderSettings`, `replayGainTrack`, `replayGainAlbum`, `mediaType`, `bpm`, `isCompilation` |
| Advisory | `explicitAdvisory`; `isExplicit` is a lossy computed Boolean whose setter is deprecated |
| iTunes | `itunesAlbumID`, `itunesArtistID`, `itunesCatalogID`, `itunesGenreID`, `itunesMediaType`, `itunesPurchaseDate`, `itunesNorm`, `itunesSMPB` |
| Audio properties | `duration`, `bitrate`, `sampleRate`, `channels`, `bitDepth`, `format` |
| Artwork | `artworkData`, `artworkMIMEType` |
| Custom | `customFields`, plus read-only `customFieldValues` and original-projection bookkeeping |
| Provenance | `provenance: MetadataFieldProvenance` |

Read-only provenance properties are `customFieldValues`, `originalCustomFieldProjection`, `originalStandardFieldValues`, and `originalStandardFieldProjection`. They record read-time cardinality and projections for preservation decisions; callers cannot mutate them.

`BasicMetadata.empty` is a value with empty strings, zero numbers, no artwork, and no custom fields. It is a complete replacement value, not a partial patch.

Multi-value text is flattened into display strings. ID3 generally joins with `", "`; MP4 artist/genre and generic/Xiph use `"; "` in some projections, while native MP4 fields/freeforms may use `", "`. Do not split these strings to reconstruct arrays; use `RawMetadataDump` or `StructuredMetadata`.

`MetadataFieldProvenance` contains `trackNumberText`, `discNumberText`, `explicitContent`, and `artwork` values of type `MetadataValueSource`. Its public initializer takes those four values in that order.

```swift
struct MetadataFieldProvenance: Hashable, Sendable {
    var trackNumberText: MetadataValueSource
    var discNumberText: MetadataValueSource
    var explicitContent: MetadataValueSource
    var artwork: MetadataValueSource
    static let unknown: MetadataFieldProvenance
}
```

```swift
enum MetadataValueSource: String, Hashable, Sendable {
    case nativeTag
    case propertyMap
    case id3v2Frame
    case rawFallback
    case derivedNumeric
    case none
}
```

`MetadataFieldProvenance.unknown` is the all-`.none` value.

### `ExplicitAdvisory`

```swift
enum ExplicitAdvisory: String, Hashable, Sendable {
    case unspecified
    case notExplicit
    case clean
    case explicit
}
```

`unspecified` means no advisory field exists. `notExplicit` means a field is present and marked not explicit. `clean` and `explicit` are explicit positive states. The Boolean `BasicMetadata.isExplicit` is `explicitAdvisory == .explicit`; assigning `false` records `.clean`, so it cannot represent absence or not-explicit.

### `MetadataSnapshot` and `BasicMetadataSnapshot`

```swift
struct MetadataSnapshot: Sendable {
    var basic: BasicMetadata
    var raw: RawMetadataDump
    var structured: StructuredMetadata
    let fileVersion: MetadataFileVersion?
    let audioContentIdentity: MetadataAudioContentIdentity?
}

struct BasicMetadataSnapshot: Sendable {
    var metadata: BasicMetadata
    let fileVersion: MetadataFileVersion
    let audioContentIdentity: MetadataAudioContentIdentity?
}

// MetadataSnapshot
init(basic: BasicMetadata, raw: RawMetadataDump, structured: StructuredMetadata,
     fileVersion: MetadataFileVersion? = nil)
init(basic: BasicMetadata, raw: RawMetadataDump, structured: StructuredMetadata,
     fileVersion: MetadataFileVersion? = nil,
     audioContentIdentity: MetadataAudioContentIdentity?)

// BasicMetadataSnapshot
init(metadata: BasicMetadata, fileVersion: MetadataFileVersion)
init(metadata: BasicMetadata, fileVersion: MetadataFileVersion,
     audioContentIdentity: MetadataAudioContentIdentity?)
```

`MetadataSnapshot` has two initializers: one without an audio identity and one with an explicit optional identity. `BasicMetadataSnapshot` similarly has an initializer with and without an audio identity. A `readSnapshot` result always carries a file version in practice; the public initializer allows `nil` for constructed values. `audioContentIdentity` is `nil` unless explicitly requested and supported; two `nil` identities never prove continuity.

`MetadataFileVersion` is an opaque `Hashable, Sendable` value. It has no public initializer. It records device, inode, size, link count, modification time, and status-change time for an observed regular file.

### Raw models

```swift
struct RawMetadataDump: Hashable, Sendable {
    var properties: [RawPropertyEntry]
    var id3v2Frames: [RawID3v2FrameEntry]
    static let empty: RawMetadataDump
}

struct RawPropertyEntry: Identifiable, Hashable, Sendable {
    var id: UUID
    var key: String
    var value: String
    var values: [String]
    var count: Int
    var schema: MetadataFieldSchema?
    var shouldDisplayAsMultiValue: Bool
}

struct RawID3v2FrameEntry: Identifiable, Hashable, Sendable {
    var id: UUID
    var frameID: String
    var value: String
    var description: String?
    var language: String?
}
```

`value` is the joined display projection; `values` is authoritative for cardinality. `count` is the bridge-reported count (or `values.count` when absent). `id` is an ephemeral UI identity excluded from semantic equality and hashing.

Raw ID3v2 frame summaries are available for the ID3-backed formats whose extraction path requests them (MPEG/ID3, WAV, AIFF, TTA). Other containers expose structured collections instead; do not assume `id3v2Frames` is populated for every file.

### Structured models

```swift
struct StructuredMetadata: Hashable, Sendable {
    var properties: [StructuredPropertyEntry]
    var id3v2Frames: [StructuredID3v2Frame]
    var mp4Atoms: [StructuredMP4Atom]
    var asfAttributes: [StructuredASFAttribute]
    var artwork: [StructuredArtwork]
    var lyrics: [StructuredLyrics]
    var comments: [StructuredComment]
    var warnings: [String]
}

struct StructuredPropertyEntry: Identifiable, Hashable, Sendable {
    var key: String
    var values: [String]
}

struct StructuredID3v2Frame: Identifiable, Hashable, Sendable {
    var frameID: String
    var type: String
    var value: String
    var values: [String]
    var description: String?
    var language: String?
    var url: String?
    var owner: String?
    var data: Data?
    var fields: [String: String]      // reserved; currently ignored
    var elementID: String?
    var startTimeMilliseconds: Int?
    var endTimeMilliseconds: Int?
    var startOffset: Int?
    var endOffset: Int?
    var isTopLevel: Bool?
    var isOrdered: Bool?
    var children: [String]
    var embeddedFrameCount: Int?
}

struct StructuredMP4Atom: Identifiable, Hashable, Sendable {
    var key: String
    var type: String
    var value: String
    var values: [String]
    var first: Int?
    var second: Int?
    var freeformDescription: String?
}

struct StructuredASFAttribute: Identifiable, Hashable, Sendable {
    var key: String
    var type: String
    var value: String
    var data: Data?
    var pictureType: String?
    var mimeType: String?
    var description: String?
    var language: Int
    var stream: Int
}

struct StructuredArtwork: Identifiable, Hashable, Sendable {
    var container: String
    var pictureType: String?
    var pictureTypeCode: Int?
    var mimeType: String
    var description: String?
    var data: Data
}

struct StructuredLyrics: Identifiable, Hashable, Sendable {
    var language: String
    var description: String
    var text: String
}

struct StructuredComment: Identifiable, Hashable, Sendable {
    var language: String
    var description: String
    var text: String
}
```

Structured write support is container-specific:

| Collection | Written types/containers |
| --- | --- |
| `properties` | Prefixless `PropertyMap` keys on writable formats. Empty `values` removes the key. |
| `id3v2Frames` | `text`, `userText`, `url`, `ufid`, `chapter`, `tableOfContents`, `podcast` on ID3-backed formats. `APIC`, `COMM`, and `USLT` belong in the dedicated collections. `unknown` is read-only and rejected on write. |
| `mp4Atoms` | `stringList`, `bool`, `int`, `uint`, `byte`, `longLong`, and `intPair` on MP4. Other read types such as `coverArtList` are inspection-only; readback verification fails if they are supplied (with `verifyAfterWrite: true`). |
| `asfAttributes` | `string`, `bool`, `int`, `int64`, and `binary` on ASF. `guid` is inspection-only and rejected on write. Attributes are upserts by key/language/stream/type. |
| `artwork` | ID3v2, MP4, ASF, FLAC/Xiph, and APE-family (one front image). `container` is informational; the writer selects the container from the file format. |
| `lyrics`, `comments` | ID3v2-backed formats and TrueAudio; replace-all collections. |

```swift
enum StructuredMetadataReplaceableCollection: String, Hashable, Sendable {
    case artwork
    case lyrics
    case comments
}

enum RIFFMetadataWritePolicy: String, Hashable, Sendable {
    case id3v2Only
    case preserveInfo
    case syncBasicFieldsToInfo // reserved; rejects before staging
}
```

`StructuredMetadataReplaceableCollection` names the collections that use replace-all semantics and can be empty to remove their final entries. `RIFFMetadataWritePolicy` applies to structured WAV writes; `.syncBasicFieldsToInfo` is reserved and rejects with `unsupportedWritePolicy`.

`StructuredArtwork.pictureTypeCode == 0` is valid (`Other`); an omitted type defaults to Front Cover (`3`). MP4 `covr` artwork is returned both as an artwork entry and as an MP4 `coverArtList` atom; use the artwork collection to replace it.

`StructuredLyrics.language` and `StructuredComment.language` default to `"eng"`. Empty text is skipped by the writer and cannot be verified as a present entry.

### `MetadataPatch` and related types

```swift
enum MetadataPatchValue: Hashable, Sendable {
    case text(String)
    case integer(Int)
    case boolean(Bool)
    case values([String])
    case remove
}

enum MetadataArtworkPatch: Hashable, Sendable {
    case unchanged
    case replace([StructuredArtwork])
    case removeAll
}

struct MetadataNumberTextPatch: Hashable, Sendable {
    var trackNumberText: String?
    var discNumberText: String?
    var isEmpty: Bool { get }
}

struct MetadataPatch: Hashable, Sendable {
    var fields: [MetadataFieldKey: MetadataPatchValue]
    var customFields: [String: MetadataPatchValue]
    var explicitAdvisory: ExplicitAdvisory?
    var artwork: MetadataArtworkPatch
    var numberText: MetadataNumberTextPatch?
    var isEmpty: Bool { get }
}
```

`.text` and `.values` are trimmed once during validation. Empty text, empty value arrays, and empty elements are errors. Track/disc and movement values obey the schema constraints above. `.boolean(false)` encodes `"0"`; it is not deletion. `.remove` is the field-value deletion marker; artwork and formatted number text have their own removal forms.

`MetadataNumberTextPatch` uses three-way optional intent per pair: `nil` leaves it unchanged, a non-empty value sets it, and an empty string removes it.

`RawMetadataPatch` is defined in the raw-write section:

```swift
struct RawMetadataPatch: Sendable {
    var valuesToSet: [String: [String]]
    var removingKeys: Set<String>
}
```

### Format and schema models

```swift
enum FormatSupportLevel: String, Hashable, Sendable {
    case fixtureCovered
    case experimental
    case upstreamSupported
    case readOnly
    case unsupported
    @available(*, deprecated) case verified
}

enum StructuredMetadataSupport: String, Hashable, Sendable {
    case none
    case propertyMap
    case container
}
```

`FormatCapability` is `Hashable, Sendable, Identifiable`:

| Member | Meaning |
| --- | --- |
| `id` / `identifier` | Stable family identifier, e.g. `mp4`, `flac`, `mpeg-id3`. |
| `displayName`, `codecName` | Human-readable family/codec names. |
| `primaryExtension`, `extensions` | Primary extension and all aliases, lowercased. |
| `containers` | TagLib/container surfaces such as `tag`, `propertyMap`, `id3v2`, `mp4`, `xiph`, `ape`, `asf`, `riffInfo`. |
| `isReadable`, `isWritable` | Declared operation availability. |
| `canReadArtwork`, `canWriteArtwork` | Artwork availability for the family. |
| `preservesMultiValueProperties` | Family-level repeated-value support, not a per-field promise. |
| `structuredReadSupport`, `structuredWriteSupport` | Non-artwork structured inspection/mutation level. |
| `readOnlyReason`, `notes` | Configured caveats. |
| `supportLevel` | Evidence level for the capability's requested/primary extension. |
| `extensionSupportLevels` | Per-extension evidence levels. |
| `readableFields`, `writableFields` | Optional explicit allowlists; `nil` means infer from mappings. |

```swift
func supportLevel(forExtension fileExtension: String) -> FormatSupportLevel
func readSupport(for field: MetadataFieldKey) -> FormatSupportLevel
func writeSupport(for field: MetadataFieldKey) -> FormatSupportLevel
var metadataFieldFormats: Set<MetadataFieldFormat> { get }
```

`readSupport`/`writeSupport` combine `isReadable`/`isWritable`, the field schema's mappings, artwork flags, explicit allowlists, and the MP4 single-date rule. `supportLevel` comes from the capability value; to query a different alias, use `supportLevel(forExtension:)` or fetch that extension's capability.

`FormatCapability` has a public initializer for tools and tests. In application code, treat values returned by `formatCapabilities` and `capability(forExtension:)` as the authoritative registry data.

#### Field schema types

```swift
enum MetadataFieldCategory: String, CaseIterable, Hashable, Sendable {
    case basic, numbering, artwork, lyricsAndComments, dates, people,
         peopleRoles, sorting, identifiers, release, replayGain, itunes,
         technical, custom
}

enum MetadataFieldFormat: String, CaseIterable, Hashable, Sendable {
    case tagLibPropertyMap, id3v2, mp4, xiph, ape, asf, flac
    case matroska // reserved; no family is registered
}

enum MetadataFieldStorageKind: String, Hashable, Sendable {
    case nativeTag, propertyMap, textFrame, userTextFrame,
         mp4Atom, mp4Freeform, complexProperty, binary
    case pattern // reserved; no schema currently uses it
}

enum MetadataPatchValueKind: String, CaseIterable, Hashable, Sendable {
    case text, integer, boolean, values
}

struct MetadataIntegerConstraint: Hashable, Sendable {
    var minimum: Int
    var maximum: Int
}

struct MetadataFormatMapping: Hashable, Sendable {
    var format: MetadataFieldFormat
    var storageKind: MetadataFieldStorageKind
    var keys: [String]
    var note: String?
}

struct MetadataFieldSchema: Identifiable, Hashable, Sendable {
    var id: MetadataFieldKey { key }
    var key: MetadataFieldKey
    var displayName: String
    var category: MetadataFieldCategory
    var propertyMapKeys: [String]
    var mappings: [MetadataFormatMapping]
    var isMultiValue: Bool
    var isPeopleField: Bool
    var isRoleQualified: Bool
    var isArtworkField: Bool
    var acceptedPatchValueKinds: Set<MetadataPatchValueKind> { get }
    var integerConstraint: MetadataIntegerConstraint? { get }
}
```

`acceptedPatchValueKinds` is the typed-patch contract: integer-only for track/disc/movement/BPM, boolean-only for compilation, empty for artwork/explicit/custom, and text/values (values only when multi-value) for ordinary fields. `integerConstraint` supplies the minimum and maximum enforced by typed patches.

#### `MetadataFieldKey`

The enum has these cases (grouped here by their schema category; the source is authoritative for order and mapping details):

| Category | Cases |
| --- | --- |
| `basic` | `title`, `album`, `genre`, `work`, `movement`, `discSubtitle`, `subtitle`, `grouping`, `mood`, `language`, `musicalKey` |
| `numbering` | `track`, `trackTotal`, `disc`, `discTotal`, `movementNumber`, `movementCount` |
| `artwork` | `artwork` |
| `lyricsAndComments` | `lyrics`, `comment` |
| `dates` | `date`, `releaseDate`, `originalReleaseDate` |
| `people` | `artist`, `albumArtist`, `composer`, `conductor`, `remixer`, `producer`, `engineer`, `lyricist`, `originalArtist` |
| `peopleRoles` | `performer`, `involvedPeople`, `musicianCredits` |
| `sorting` | `sortTitle`, `sortArtist`, `sortAlbum`, `sortAlbumArtist`, `sortComposer` |
| `identifiers` | `isrc`, `barcode`, `asin`, `musicBrainzArtistID`, `musicBrainzAlbumID`, `musicBrainzAlbumArtistID`, `musicBrainzTrackID`, `musicBrainzReleaseGroupID`, `musicBrainzReleaseTrackID`, `musicBrainzWorkID`, `acoustID`, `acoustIDFingerprint`, `musicIPPUID` |
| `release` | `publisher`, `copyright`, `catalogNumber`, `releaseType`, `releaseStatus`, `releaseCountry`, `mediaType`, `compilation`, `originalAlbum`, `artistType` |
| `replayGain` | `replayGainTrackGain`, `replayGainAlbumGain` |
| `itunes` | `explicitContent`, `itunesAlbumID`, `itunesArtistID`, `itunesCatalogID`, `itunesGenreID`, `itunesMediaType`, `itunesPurchaseDate`, `itunesNorm`, `itunesSMPB` |
| `technical` | `encodedBy`, `encoderSettings`, `bpm`, `trackerName` |
| `custom` | `custom` |

`trackerName` is a schema key used by tracker formats; `BasicMetadata` has no property for it. Use `MetadataPatch(fields: [.trackerName: ...])` or a structured/raw API where the capability allows it.

#### `MetadataFieldRegistry`

```swift
enum MetadataFieldRegistry {
    static let allSchemas: [MetadataFieldSchema]
    static let schemasByKey: [MetadataFieldKey: MetadataFieldSchema]
    static let canonicalPropertyMapKeys: Set<String>
    static let multiValuePropertyMapKeys: Set<String>
    static let peoplePropertyMapKeys: Set<String>
    static let sharedPropertyMapKeyOwners: [String: Set<MetadataFieldKey>]
    static let preferredSharedPropertyMapKeyOwner: [String: MetadataFieldKey]
    static let propertyMapKeyOwners: [String: Set<MetadataFieldKey>]

    static func schema(for key: MetadataFieldKey) -> MetadataFieldSchema?
    static func schema(forPropertyMapKey key: String) -> MetadataFieldSchema?
    static func schemas(withMappingsFor format: MetadataFieldFormat) -> [MetadataFieldSchema]
    static func schemas(storableIn capability: FormatCapability) -> [MetadataFieldSchema]
    static func schema(_ key: MetadataFieldKey, hasMappingFor format: MetadataFieldFormat) -> Bool
    static func shouldDisplayRawPropertyAsMultiValue(_ key: String) -> Bool
    static func normalizePropertyMapKey(_ key: String) -> String
}
```

`schema(forPropertyMapKey:)` recognizes common qualified prefixes (`PERFORMER:`, `INVOLVEDPEOPLE:`, `MUSICIANCREDITS:`, `COMMENT:`, `LYRICS:`). `normalizePropertyMapKey` trims whitespace and uppercases. `schemas(storableIn:)` returns an empty list for read-only capabilities and excludes the MP4 `.date` field and unsupported artwork.

### Audio-content models

```swift
struct MetadataAudioContentIdentity: Hashable, Sendable { /* opaque digest */ }

enum MetadataAudioContentError: Error, Equatable, Sendable, LocalizedError {
    case unavailable
    case changed
}
```

`MetadataAudioContentIdentity` has no public initializer or accessors. Compare values for equality; do not persist them as recording identifiers across package versions. `.unavailable` means the layout is unsupported or ambiguous; `.changed` means the encoded audio or its interpretation parameters differ from the baseline. See [Audio-content continuity](AUDIO_CONTENT_CONTINUITY.md).

### Internal-identity helper

```swift
@propertyWrapper
struct SemanticIdentityExcluded: Hashable, Sendable {
    var wrappedValue: UUID
    init(wrappedValue: UUID)
}
```

Used by model types to keep ephemeral UI identifiers out of synthesized semantic equality and hashing. Two entries with different `id` values can still be equal when their semantic fields match.

## Errors

All error types conform to `Error`, `Sendable`, and `LocalizedError`; the model errors that represent validation values are also `Equatable`.

### `TagLibManagerError`

| Case | Meaning |
| --- | --- |
| `invalidFile` | The URL is not an existing regular file, or a final symlink was rejected. |
| `fileChanged` | The optimistic version or destination identity changed. |
| `hardLinkedFile` | Atomic replacement would split a hard-linked file identity. |
| `unsupportedFormat` | The extension is missing or not supported for the requested operation. |
| `unsupportedWritePolicy(String)` | The selected structured write policy is not implemented for that container. |
| `failedToReadWithUnderlying(String)` | The bridge or parser failed while reading. |
| `verificationFailed([String])` | A verified write could not confirm requested values; nothing was committed. |
| `operationFailed(String)` | Message-only compatibility case; no longer emitted for native/filesystem failures. |
| `operationFailedWithUnderlying(NSError)` | Pre-commit bridge/filesystem failure with a typed cause; inspect `underlyingError`. |
| `committedButDurabilityUncertain(String)` | Low-level transaction helper committed the rename but the final directory sync failed. High-level writes report this through `MetadataWriteResult.commitStatus`. |
| `failedToRead` | Deprecated. Use `failedToReadWithUnderlying(_:)`. |

`underlyingError` returns the associated `NSError` for `operationFailedWithUnderlying` and `nil` otherwise.

### `MetadataPatchValidationError`

`unsupportedField`, `unsupportedFieldForFormat(field:format:)`, `incompatibleValue(field:expected:actual:)`, `integerOutOfRange(field:minimum:maximum:actual:)`, `knownFieldRequiresTypedAPI(customKey:field:)`, `conflictingFieldRepresentations(field:customKey:)`, `duplicateCustomField(normalizedKey:)`, `invalidCustomFieldKey(_:)`, `emptyText(location:)`, `emptyValueList(location:)`, `emptyValue(location:index:)`, `conflictingNumberRepresentations`, `roleQualifiedFieldRequiresRawAPI(_:)`, and `unsupportedPartialPairRemoval(field:format:)`.

### `MetadataValidationError`

`propertiesRequireIncludeProperties`, `embeddedNull(location:)`, `unsupportedID3v2FrameType(_:)`, `knownFieldRequiresRawAPI(_:)`, `invalidCustomFieldKey(_:)`, and `conflictingMP4Date(year:releaseDate:)`.

### `RawMetadataPatchError`

`invalidKey(_:)`, `emptyArray(_:)`, `conflictingKey(_:)`, `embeddedNull(_:)`, and `nativeKeyRequiresStructuredAPI(_:)`.

### `MetadataAudioContentError`

`unavailable` and `changed`.

## Public Objective-C bridge

Header: `Sources/CTagLibBridge/include/TagLibMetadataExtractor.h`. It exposes Foundation and Objective-C types only; no C++ declarations cross the boundary.

### Classes and constants

| Declaration | Purpose |
| --- | --- |
| `TagLibAudioMetadata` | Objective-C model used by `extractMetadata`, `writeMetadata`, and `writeTagMetadata`. Properties are nullable `NSString *` unless marked numeric/Boolean. It also has `artworkData`, `artworkMimeType`, `removeArtwork`, `customFields`, numeric numbering, audio properties, release fields, and `explicitAdvisory`/`explicitContent`. |
| `TagLibMetadataExtractor` | Class with the read, write, inspection, and capability selectors below. All selectors that enter TagLib are serialized internally. |
| `TagLibMetadataErrorDomain` | `"TagLibMetadataExtractor"`. |
| `TagLibMetadataTransactionErrorCodeCommittedButDurabilityUncertain` | `9110`; the bridge's post-rename durability-uncertain outcome. |
| `TagLibExplicitAdvisory` | `Unspecified = 0`, `Clean = 1`, `Explicit = 2`, `NotExplicit = 3`. |
| `TagLibMetadataExtractionOptions` | `Basic`, `Raw`, `Structured`, `PropertyMap`, `RawFrames`, `All`. |

`TagLibAudioMetadata` property groups:

| Group | Properties |
| --- | --- |
| Core | `title`, `artist`, `album`, `albumArtist`, `composer`, `genre`, `year`, `comment` |
| Numbering | `trackNumber`, `totalTracks`, `discNumber`, `totalDiscs`, `trackNumberText`, `discNumberText` |
| Audio | `duration`, `bitrate`, `sampleRate`, `channels`, `bitDepth`, `codec` |
| Artwork | `artworkData`, `artworkMimeType`, `removeArtwork` |
| Additional | `bpm`, `compilation`, `explicitAdvisory`, `explicitContent`, `copyright`, `lyrics`, `label`, `isrc`, `encodedBy`, `encoderSettings` |
| Sorting | `sortTitle`, `sortArtist`, `sortAlbum`, `sortAlbumArtist`, `sortComposer` |
| Dates | `releaseDate`, `originalReleaseDate` |
| Personnel | `conductor`, `remixer`, `producer`, `engineer`, `lyricist` |
| Descriptive | `subtitle`, `grouping`, `movement`, `mood`, `language`, `musicalKey` |
| MusicBrainz/IDs | `musicBrainzArtistId`, `musicBrainzAlbumId`, `musicBrainzAlbumArtistId`, `musicBrainzTrackId`, `musicBrainzReleaseGroupId`, `musicBrainzReleaseTrackId`, `musicBrainzWorkId`, `acoustId`, `acoustIdFingerprint`, `musicIpPuid` |
| ReplayGain | `replayGainTrack`, `replayGainAlbum` |
| Media type | `mediaType` |
| iTunes | `itunesAlbumId`, `itunesArtistId`, `itunesCatalogId`, `itunesGenreId`, `itunesMediaType`, `itunesPurchaseDate`, `itunesNorm`, `itunesSmpb` |
| Release | `releaseType`, `releaseStatus`, `catalogNumber`, `barcode`, `releaseCountry`, `artistType`, `asin`, `originalAlbum`, `originalArtist`, `discSubtitle`, `work`, `movementNumber`, `movementCount` |
| Custom | `customFields` |

`explicitContent` is a Boolean compatibility projection: reading `YES` means `.explicit`; setting `NO` records `.clean`. Use `explicitAdvisory` for lossless state.

### Selectors

| Swift name | Objective-C selector | Purpose |
| --- | --- | --- |
| `extractMetadata(from:)` | `extractMetadataFromURL:error:` | Basic bridge model read. |
| `metadataProjections(for:)` | `metadataProjectionsForURL:error:` | Basic, raw, and structured projections from one parser session. |
| `metadataProjections(for:options:)` | `metadataProjectionsForURL:options:error:` | Selective projections. |
| `writeMetadata(_:to:)` | `writeMetadata:toURL:error:` | Transactional bridge-model write; no facade semantic verification. |
| `writeTrackNumberText(_:discNumberText:to:)` | `writeTrackNumberText:discNumberText:toURL:error:` | Formatted track/disc text write. |
| `writeTrackNumber(_:totalTracks:padWidth:to:)` | `writeTrackNumber:totalTracks:padWidth:toURL:error:` | Number write with optional zero padding. |
| `writeRawPropertyMap(_:to:)` | `writeRawPropertyMap:toURL:error:` | Whole-map visible `PropertyMap` replacement (single values). |
| `writeRawPropertyMapValues(_:to:)` | `writeRawPropertyMapValues:toURL:error:` | Whole-map replacement with value arrays. |
| `structuredMetadata(for:)` | `structuredMetadataForURL:error:` | Structured projection. |
| `writeStructuredMetadata(_:to:)` | `writeStructuredMetadata:toURL:error:` | Structured mutation; omitted collections are preserved. |
| `wipeMetadata(from:)` | `wipeMetadataFromURL:error:` | Native metadata container wipe where supported. |
| `rawMetadata(for:)` | `rawMetadataForURL:error:` | Raw property/frame dictionary. |
| `dumpMetadataText(from:)` | `dumpMetadataTextFromURL:error:` | Human-readable diagnostic dump. |
| `isSupportedFormat(_:)` | `isSupportedFormat:` | Declared readable-extension lookup. |
| `isWritableFormat(_:)` | `isWritableFormat:` | Declared writable-extension lookup. |
| `supportedExtensions()` | `supportedExtensions` | All registered extensions. |
| `writableExtensions()` | `writableExtensions` | Extensions of writable families. |
| `formatCapability(for:)` | `formatCapabilityForExtension:` | Capability dictionary for an extension. |
| `formatCapabilities()` | `formatCapabilities` | Capability dictionaries for all families. |
| `knownMetadataPropertyKeys()` | `knownMetadataPropertyKeys` | Bridge schema property keys. |
| `metadataFieldMappings()` | `metadataFieldMappings` | Bridge canonical/alias/container mappings. |

The bridge mutators are transactional but do not run the facade's semantic readback. They validate that the staged file remains readable. `writeMetadata(_:to:)` reports a committed-but-durability-uncertain state through error code `9110`; the high-level Swift APIs report it through `MetadataWriteResult.commitStatus`.

`metadataProjections(for:options:)` returns a dictionary whose stable top-level keys are `basic`, `raw`, and `structured`. `raw` contains `properties` and `id3v2Frames`; `structured` contains `properties`, `id3v2Frames`, `mp4Atoms`, `asfAttributes`, `artwork`, `lyrics`, `comments`, and `warnings`. Requesting `.propertyMap` or `.rawFrames` alone returns a `raw` projection; requesting `.raw` includes both.

## Deprecated API map

| Deprecated declaration | Replacement |
| --- | --- |
| `readMetadata(from:)` | `bestEffortMetadata(from:)` or `readMetadataResult(from:)` |
| `rawMetadata(from:)` | `bestEffortRawMetadata(from:)` or `rawMetadataResult(from:)` |
| `readStructuredMetadata(from:)` | `bestEffortStructuredMetadata(from:)` or `readStructuredMetadataResult(from:)` |
| `rawMetadataText(from:)` | `bestEffortRawMetadataText(from:)` |
| `writeMetadata(_:to:)`, `writeMetadata(_:to:expectedVersion:)` | `replaceBasicMetadata` or `updateBasicMetadata` |
| `writeMetadataWithVerification(_:to:failurePolicy:)` | `replaceBasicMetadata` |
| `isReadableFormat(_:)` | `isReadableExtension(_:)` |
| `isWritableFormat(_:)` | `isWritableExtension(_:)` |
| `formatCapability(for:)` | `capability(forExtension:)` |
| `failurePolicy:` overloads | Omit the parameter; mismatches always throw |
| `VerificationFailurePolicy` | No replacement needed; `.warn` has no bypass effect |
| `FormatSupportLevel.verified` | `fixtureCovered` or a concrete `probeFile` |
| `ArtworkVerificationExpectation.unchanged` | `.skip` |
| `BasicMetadata.isExplicit` setter | `explicitAdvisory` |
| `TagLibManagerError.failedToRead` | `failedToReadWithUnderlying(_:)` |
| `TagLibManagerError.operationFailed` emission | `operationFailedWithUnderlying(_:)`; the case remains for compatibility |

See [Compatibility and migration](MIGRATION.md) for behavioral changes and a migration checklist.
