# Public API reference

This is the complete index of the public Swift surface of `TagLibAudioMetadata`. It describes the code at the current revision; the source declarations remain authoritative for exact syntax and default arguments. The public Objective-C surface is documented separately in [Bridge reference](BRIDGE.md), and field-to-container mappings live in [Metadata field schema](FIELD_SCHEMA.md).

Access modifiers and `nonisolated` annotations are omitted in the declaration blocks for readability. All manager members are `nonisolated static`; all model types are `Sendable` unless noted.

## Products and availability

| Item | Value |
| --- | --- |
| Swift tools | 6.4 |
| Minimum platforms | macOS 13, iOS 16 |
| Swift product | `TagLibAudioMetadata` (module `TagLibAudioMetadata`) |
| Low-level product | `TagLibAudioMetadataLowLevel` (module `CTagLibBridge`) |
| Internal target | `CTagLibBridgeInternalAPI`; not a library product and not supported for external use |
| Binary dependency | TagLib 2.3.1 dynamic XCFramework, pinned by URL and checksum |

`import TagLibAudioMetadata` exposes the facade. Import `CTagLibBridge` and declare the low-level product only when naming bridge types such as `TagLibAudioMetadata` or `TagLibMetadataExtractor`.

## `TagLibMetadataManager`

`TagLibMetadataManager` is a public struct used as a namespace for the facade's static reads, writes, capability queries, and nested result types. It has no public state or instance API. All members documented below are `nonisolated static` and synchronous. The nested types are listed under [Nested manager types](#nested-manager-types).

`URL` parameters must be file URLs for mutation. Read APIs validate the URL through their format/parser path and reject a non-file URL or a missing regular file.

## Reading metadata

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

| API | Result | Behavior |
| --- | --- | --- |
| `readMetadataResult` | Basic metadata | Reads the Basic projection and visible `PropertyMap` in one extraction. Does not build structured inspector models. Rejects a file whose observed contents change during the read. |
| `readBasicSnapshot` | Basic metadata plus a non-optional `MetadataFileVersion` | Focused loader for editors. The `includingAudioContent` overload also returns an optional audio identity. |
| `readSnapshot` | Basic, raw, and structured projections plus the captured file version | One coherent extraction call. The `includingAudioContent` overload also streams the audio identity. Throws `fileChanged` if the file changes during extraction. |
| `rawMetadataResult` | Visible `PropertyMap` entries and raw ID3v2 frame summaries | The frame summaries are populated only by extraction paths that request them. |
| `readStructuredMetadataResult` | Container-specific structured projection | ID3v2 frames, MP4 atoms, ASF attributes, artwork, lyrics, comments, and warnings. |
| `fileVersion` | Opaque `MetadataFileVersion` | Captures an existing regular file without following a final symbolic link. |

Optional readers collapse every failure to `nil`:

```swift
static func bestEffortMetadata(from url: URL) -> BasicMetadata?
static func bestEffortRawMetadata(from url: URL) -> RawMetadataDump?
static func bestEffortRawMetadataText(from url: URL) -> String?
static func bestEffortStructuredMetadata(from url: URL) -> StructuredMetadata?
```

`bestEffortRawMetadataText` prefers the bridge's text dump and falls back to a deterministic formatted dump of `RawMetadataDump`. It is diagnostic text, not a stable serialization format.

Deprecated read names: `readMetadata(from:)`, `rawMetadata(from:)`, `readStructuredMetadata(from:)`, and `rawMetadataText(from:)`. They forward to the best-effort forms.

## Typed metadata patches

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

`applyMetadataPatch` is the recommended partial-edit API. Only explicitly supplied fields, custom fields, advisory state, artwork intent, and formatted number text are changed. The patch is validated before staging; an empty patch returns an empty result without validating the version, audio identity, or format.

Validation rules:

- Value kinds come from `MetadataFieldRegistry.schema(for:)`. Track/disc components are integers in `1...Int32.max`; BPM and movement numbering are integers in `0...Int32.max`; compilation is Boolean; ordinary fields accept text and, when the schema is multi-value, an array.
- `.artwork`, `.custom`, and `.explicitContent` cannot be used as `fields`; use `artwork`, `customFields`, and `explicitAdvisory` on `MetadataPatch`.
- Role-qualified fields (`performer`, `involvedPeople`, `musicianCredits`) require a raw or structured API because their keys carry a role.
- Custom keys are normalized to uppercase; known schema keys, aliases, case variants, duplicate normalized keys, and a typed/custom collision are rejected.
- `.text` and `.values` are trimmed once; empty text, empty arrays, and empty elements are errors. `.remove` is the deletion marker.
- `numberText` cannot be combined with typed `track`, `trackTotal`, `disc`, or `discTotal`.
- A track/disc first component cannot be removed while retaining a total on formats that cannot represent a missing number with a total. Remove both components to clear the pair.
- A capability with an explicit `writableFields` allowlist is checked before staging.

The guarded overload requires both `expectedVersion` and `expectedAudioContent`. Availability is limited to WAV, AIFF/AIFF-C, and native FLAC; see [Audio-content continuity](AUDIO_CONTENT_CONTINUITY.md).

The deprecated overload `applyMetadataPatch(_:to:expectedVersion:failurePolicy:)` forwards to the unguarded path. `VerificationFailurePolicy.warn` is deprecated and cannot bypass verification.

## Basic replacement and update

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

`replaceBasicMetadata` replaces the complete modeled Basic projection. Empty strings and zero numbers clear those fields where the container allows it. It preserves metadata that `BasicMetadata` cannot represent — untouched multi-value arrays, documented aliases, full recording dates, qualified people keys, unchanged native comment/lyric collections on tested ID3-backed formats, and omitted custom fields — by restoring them from the current raw state. It is not an omission-safe patch.

`updateBasicMetadata` reads a focused `BasicMetadataSnapshot`, applies the closure in memory, reconciles a single-field MP4 `year`/`releaseDate` intent, and calls `replaceBasicMetadata` with the captured version. It is the recommended Basic read/modify/write convenience.

Deprecated wrappers:

```swift
static func writeMetadata(_ metadata: BasicMetadata, to url: URL) throws -> Bool
static func writeMetadata(_ metadata: BasicMetadata, to url: URL, expectedVersion: MetadataFileVersion? = nil) throws -> Bool
static func writeMetadataWithVerification(
    _ metadata: BasicMetadata,
    to url: URL,
    failurePolicy: VerificationFailurePolicy = .throw
) throws -> MetadataWriteResult
```

## Raw `PropertyMap` writes

### Whole-map writers

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

- `.replace` owns the complete visible `PropertyMap`. Omitted keys are removed from the visible map. It does not reconstruct native structures that TagLib does not expose. On WAV, RIFF INFO is a separate surface: omitted INFO keys can survive the ID3v2 replacement and make verification fail. Use `.merge` or `RawMetadataPatch` for preservation, or a structured `.id3v2Only` write when INFO removal is intended.
- `.merge` applies a delta to the visible map, preserves omitted keys and native structures, and treats an empty value or empty array as an explicit removal.
- The flat writer trims keys and values and drops empty values. The values writer trims and drops empty elements while preserving non-empty array boundaries.
- Both verified writers compare the requested result on the staged copy before commit unless `verifyAfterWrite` is `false`.
- Keys are prefixless TagLib `PropertyMap` keys. Native MP4 `----:` atom identifiers are rejected; use `StructuredMetadata.mp4Atoms`.

### Preservation-oriented delta

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

`RawMetadataPatch` changes only `valuesToSet` and `removingKeys`. Keys omitted from both are unchanged. Array boundaries, duplicate values, empty strings, and whitespace are significant; an empty array is invalid and must be expressed with `removingKeys`. Keys are normalized to uppercase, must not have surrounding whitespace or NULs, and conflicting changes to the same normalized key are rejected. Native MP4 `----:` keys and hidden package formatting keys are rejected. The complete visible `PropertyMap` is verified after the delta.

An empty patch returns an empty result without staging. The guarded overload additionally requires the baseline audio identity and is available only for the same three container families as the typed guard.

Deprecated `failurePolicy:` overloads exist for the whole-map writers and forward without a bypass.

## Structured metadata writes

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

Only top-level collections present in the payload are edited. Omitted collections are preserved.

- `includeProperties == false` rejects a non-empty `properties` array. `includeProperties == true` applies non-empty properties as a delta; an empty `values` array removes that key.
- Non-empty `artwork`, `lyrics`, and `comments` replace their collection. Empty arrays are omitted by default; include the collection name in `replacingCollections` to remove its final entries.
- `riffPolicy` is meaningful for WAV. `.preserveInfo` keeps RIFF INFO and `.id3v2Only` removes it after writing ID3v2. AIFF/AIFF-C have no RIFF INFO surface, so those two values have no additional effect there. `.syncBasicFieldsToInfo` is reserved and is rejected for WAV and AIFF/AIFF-C before staging. Other formats ignore the policy value; passing `.syncBasicFieldsToInfo` to an MP4, ASF, or Xiph write is not a validation error, but no synchronization is performed.
- ID3v2 writable frame types are `text`, `userText`, `url`, `ufid`, `chapter`, `tableOfContents`, and `podcast`. `APIC`, `COMM`, and `USLT` belong in artwork, comments, and lyrics. `unknown` frames are inspection-only.
- MP4 writable atom types are `stringList`, `bool`, `int`, `uint`, `byte`, `longLong`, and `intPair`. Types such as `coverArtList`, `byteVectorList`, `void`, and `stem` are inspection-only; the bridge ignores them, so they cannot be confirmed as edits.
- ASF writable attribute types are `string`, `bool`, `int`, `int64`, and `binary`. `guid` is inspection-only and is rejected with a validation error. Attributes are upserts by key, language, stream, and type; there is no individual structured deletion operation.
- ID3v2 URL and UFID frames have no individual structured removal operation; empty URL/data payloads reject.

The deprecated overload with `failurePolicy:` forwards without a bypass.

## Formatted number text

```swift
static func writeTrackNumberText(
    _ trackNumberText: String,
    discNumberText: String?,
    to url: URL,
    verifyAfterWrite: Bool = true,
    expectedVersion: MetadataFileVersion? = nil
) throws -> MetadataWriteResult
```

`nil` leaves that pair unchanged; a non-empty string sets it; an empty string removes it. The text must contain at most one `/` and unsigned decimal components no greater than `Int32.max`. Verification accepts numeric-equivalent formatting and checks exact text where the container preserves it. Use this API only when formatted text is the authoritative input; ordinary numeric Basic and patch writes may normalize padding.

On MP4, the writer stores the formatted text in package-private `TAGLIBAUDIOMETADATA_*_TEXT` freeform atoms while native `trkn`/`disk` remain the numeric authority. Legacy `AUDIOMATOR_*_TEXT` values are migrated when the corresponding pair is edited.

## Low-level bridge-model write

```swift
static func writeTagMetadata(
    _ metadata: TagLibAudioMetadata,
    to url: URL,
    verification: MetadataWriteVerificationContext = .none,
    expectedVersion: MetadataFileVersion? = nil
) throws -> MetadataWriteResult
```

This writes the bridge model through the transactional coordinator. The model is a full writer payload for the fields the bridge maps, not an omission-safe patch. A sparse instance clears mapped fields where the format allows it; read current values first for a partial edit.

On MP4, a non-empty `year` and `releaseDate` must agree: `year` is the first four characters of `releaseDate`. A contradictory pair throws `MetadataValidationError.conflictingMP4Date` before staging.

The default `.none` context performs no semantic readback. The facade transaction also does not add a staged-file readability readback for this API: the bridge in-place primitive is called directly inside the staging transaction. Supply verification expectations or use a typed/structured API when confirmation matters. Naming the `TagLibAudioMetadata` parameter requires `import CTagLibBridge`.

## Erase

```swift
static func eraseAllMetadataWithVerification(
    from url: URL,
    expectedVersion: MetadataFileVersion? = nil
) throws -> MetadataWriteResult

static func eraseAllMetadata(from url: URL) throws -> Bool
```

Verified erase writes an empty bridge model, clears the visible property map, wipes the native metadata container where supported, and re-reads the staged file. Detected residual fields throw `TagLibManagerError.verificationFailed` before commit. The operation is bounded by the metadata surfaces the parser exposes; it is not a forensic scrub of every container byte. The `Bool` convenience discards the richer result but still throws on verification failure.

## Capability discovery

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

`capability(forExtension:)`, `formatSupportLevel(for:)`, `isReadableExtension(_:)`, `isWritableExtension(_:)`, and the extension arrays are declared-registry lookups. They do not open a file. Extension matching is case-insensitive.

`probeFile(at:)` parses a concrete file with the selected parser before returning its declared family capability. It does not test POSIX write permission, ACLs, disk space, or sandbox access.

Deprecated: `formatCapability(for:)`, `isReadableFormat(_:)`, and `isWritableFormat(_:)`.

## Compatibility overloads

These public overloads preserve source compatibility with pre-`expectedVersion` call sites. They are not separate behaviors; they forward to the version-aware implementations with `nil` or with the deprecated policy ignored.

| Overload | Status |
| --- | --- |
| `writeRawMetadataPropertyMap(_:to:mode:)` | Compatibility; forwards with `expectedVersion: nil`. |
| `writeRawMetadataPropertyMapWithVerification(_:to:mode:verifyAfterWrite:)` | Compatibility; forwards with `expectedVersion: nil`. |
| `writeRawMetadataPropertyMapValuesWithVerification(_:to:mode:verifyAfterWrite:)` | Compatibility; forwards with `expectedVersion: nil`. |
| `writeStructuredMetadataWithVerification(_:to:riffPolicy:includeProperties:replacingCollections:verifyAfterWrite:)` | Compatibility; forwards with `expectedVersion: nil`. |
| `writeTagMetadata(_:to:verification:)` | Compatibility; forwards with `expectedVersion: nil`. |
| `writeMetadata(_:to:)` | Deprecated; forwards to `replaceBasicMetadata`. |
| `writeRawMetadataPropertyMapWithVerification(...failurePolicy:)` | Deprecated; policy ignored. |
| `writeRawMetadataPropertyMapValuesWithVerification(...failurePolicy:)` | Deprecated; policy ignored. |
| `writeStructuredMetadataWithVerification(...failurePolicy:)` | Deprecated; policy ignored. |
| `writeTagMetadata(...failurePolicy:)` | Deprecated; policy ignored. |
| `writeTrackNumberText(...failurePolicy:expectedVersion:)` | Deprecated; policy ignored. |
| `eraseAllMetadataWithVerification(...failurePolicy:)` | Deprecated; policy ignored. |
| `applyMetadataPatch(...failurePolicy:)` | Deprecated; forwards to the unguarded path. |

`VerificationFailurePolicy.warn` is retained only so old source compiles. Every verification mismatch still aborts the transaction.

## Nested manager types

### `ArtworkVerificationExpectation`

```swift
enum ArtworkVerificationExpectation: Sendable {
    case skip
    case present
    case absent
    @available(*, deprecated, renamed: "skip") case unchanged
}
```

`skip` is the default. `present` and `absent` are presence checks. For exact bytes and MIME type, set `expectedArtworkData` and `expectedArtworkMIMEType` on `MetadataWriteVerificationContext`.

### `MetadataWriteVerificationContext`

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

    init(
        expectedTrackNumber: Int?,
        expectedTrackTotal: Int?,
        expectedTrackNumberText: String?,
        expectedDiscNumber: Int?,
        expectedDiscTotal: Int?,
        expectedDiscNumberText: String?,
        expectedExplicitContent: Bool?,
        artworkExpectation: ArtworkVerificationExpectation,
        customFieldKeys: [String],
        expectedTextFields: [String: String] = [:],
        expectedExplicitAdvisory: ExplicitAdvisory? = nil,
        customFieldValues: [String: String] = [:]
    )
}
```

The initializer requires the first nine parameters. `expectedTextFields` keys are camel-case `BasicMetadata` property names such as `title`, `albumArtist`, and `encodedBy`, not `PropertyMap` keys. `customFieldValues` compares values; `customFieldKeys` checks key presence. `expectedArtworkData` and `expectedArtworkMIMEType` are mutable properties that add exact artwork checks independent of `artworkExpectation`.

`expectedExplicitAdvisory` takes precedence over `expectedExplicitContent` when both are set. `expectedExplicitContent` is the lossy Boolean compatibility check.

### `MetadataCommitStatus` and `MetadataWriteResult`

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

`.durable` means the requested file and parent-directory flushes completed. It is not a hardware or power-loss guarantee. `.durabilityUncertain(detail)` means the rename already committed but the final directory sync failed; do not retry as though nothing happened. Mismatch warnings are thrown as `verificationFailed` by the verified writers, so a successful result normally carries only residual advisories.

### `RawPropertyMapWriteMode`

```swift
enum RawPropertyMapWriteMode: Sendable {
    case replace
    case merge
}
```

See [Raw `PropertyMap` writes](#raw-propertymap-writes) for the exact map semantics.

### `VerificationFailurePolicy` (deprecated)

```swift
@available(*, deprecated, message: "Verification mismatches always abort the transaction. Omit the obsolete failurePolicy parameter.")
enum VerificationFailurePolicy: Sendable {
    case warn
    case `throw`
}
```

Retained only for source compatibility. `.warn` cannot permit a commit.

## Core value models

### Construction rules

- `BasicMetadata` has no public memberwise initializer. Start from `BasicMetadata.empty` and mutate properties, or obtain a value from a read.
- `MetadataFileVersion` and `MetadataAudioContentIdentity` are opaque: no public initializer, and their stored fields are private.
- `MetadataSnapshot` and `BasicMetadataSnapshot` have public initializers for tools and tests. `MetadataSnapshot` accepts an optional file version; `BasicMetadataSnapshot` requires a non-optional one.
- `RawMetadataDump`, `RawPropertyEntry`, `RawID3v2FrameEntry`, the structured model types, `MetadataPatch`, `RawMetadataPatch`, `MetadataWriteVerificationContext`, `MetadataWriteResult`, and the schema/value structs have public memberwise-style initializers as shown below.
- Model initializers do not perform container validation. Use the manager APIs for validated writes.

### `BasicMetadata`

Property declarations are grouped by type below for readability; the source declares each property separately.

```swift
struct BasicMetadata: Sendable {
    // Text
    var title, artist, album, composer, genre, comment, lyrics: String
    var year, albumArtist, releaseDate, originalReleaseDate: String
    var isrc, barcode: String
    var musicBrainzArtistID, musicBrainzAlbumID, musicBrainzAlbumArtistID: String
    var musicBrainzTrackID, musicBrainzReleaseGroupID, musicBrainzReleaseTrackID: String
    var musicBrainzWorkID, acoustID, acoustIDFingerprint, musicIPPUID: String
    var publisher, copyright, encodedBy, encoderSettings: String
    var sortTitle, sortArtist, sortAlbum, sortAlbumArtist, sortComposer: String
    var conductor, remixer, producer, engineer, lyricist: String
    var subtitle, grouping, movement, mood, language, musicalKey: String
    var replayGainTrack, replayGainAlbum, mediaType: String
    var itunesAlbumID, itunesArtistID, itunesCatalogID, itunesGenreID: String
    var itunesMediaType, itunesPurchaseDate, itunesNorm, itunesSMPB: String
    var releaseType, releaseStatus, catalogNumber, releaseCountry, artistType: String
    var asin, originalAlbum, originalArtist, discSubtitle, work: String

    // Numbers and flags
    var track, trackTotal, disc, discTotal: Int
    var trackNumberText, discNumberText: String
    var movementNumber, movementCount, bpm: Int
    var isCompilation: Bool
    var explicitAdvisory: ExplicitAdvisory
    var isExplicit: Bool { get set } // setter deprecated

    // Audio properties
    var duration: Double
    var bitrate: Int
    var sampleRate: Double
    var channels: Int
    var bitDepth: Int
    var format: String

    // Artwork
    var artworkData: Data?
    var artworkMIMEType: String?

    // Custom fields and provenance
    var customFields: [String: String]
    var customFieldValues: [String: [String]] { get }
    var originalCustomFieldProjection: [String: String] { get }
    var originalStandardFieldValues: [String: [String]] { get }
    var originalStandardFieldProjection: [String: String] { get }
    var provenance: MetadataFieldProvenance

    static let empty: BasicMetadata
}
```

Notes:

- `BasicMetadata` is a normalized display/editing projection, not a lossless document. Multi-value fields are display strings whose separator is format-dependent. Do not split them to reconstruct arrays; use `RawMetadataDump` or `StructuredMetadata`.
- `customFieldValues`, `originalCustomFieldProjection`, `originalStandardFieldValues`, and `originalStandardFieldProjection` are read-only to callers (`internal(set)`). They preserve read-time cardinality and projections for `replaceBasicMetadata`.
- `isExplicit` is a lossy Boolean computed property. Its getter is `explicitAdvisory == .explicit`; its setter is deprecated and assigns `.clean` for `false`.
- `BasicMetadata.empty` is a complete replacement value with empty strings, zero numbers, no artwork, and no custom fields.

### `MetadataFieldProvenance` and `MetadataValueSource`

```swift
struct MetadataFieldProvenance: Hashable, Sendable {
    var trackNumberText: MetadataValueSource
    var discNumberText: MetadataValueSource
    var explicitContent: MetadataValueSource
    var artwork: MetadataValueSource

    static let unknown: MetadataFieldProvenance

    init(
        trackNumberText: MetadataValueSource,
        discNumberText: MetadataValueSource,
        explicitContent: MetadataValueSource,
        artwork: MetadataValueSource
    )
}

enum MetadataValueSource: String, Hashable, Sendable {
    case nativeTag
    case propertyMap
    case id3v2Frame
    case rawFallback
    case derivedNumeric
    case none
}
```

`unknown` is the all-`.none` value.

### `ExplicitAdvisory`

```swift
enum ExplicitAdvisory: String, Hashable, Sendable {
    case unspecified
    case notExplicit
    case clean
    case explicit
}
```

`unspecified` means no advisory representation exists. `notExplicit` means a field is present and marked not explicit. `clean` and `explicit` are explicit positive states. Assigning `BasicMetadata.isExplicit = false` records `.clean`, not absence or `.notExplicit`.

### Snapshots and file versions

```swift
struct MetadataSnapshot: Sendable {
    var basic: BasicMetadata
    var raw: RawMetadataDump
    var structured: StructuredMetadata
    let fileVersion: MetadataFileVersion?
    let audioContentIdentity: MetadataAudioContentIdentity?

    init(basic: BasicMetadata, raw: RawMetadataDump, structured: StructuredMetadata,
         fileVersion: MetadataFileVersion? = nil)
    init(basic: BasicMetadata, raw: RawMetadataDump, structured: StructuredMetadata,
         fileVersion: MetadataFileVersion? = nil,
         audioContentIdentity: MetadataAudioContentIdentity?)
}

struct BasicMetadataSnapshot: Sendable {
    var metadata: BasicMetadata
    let fileVersion: MetadataFileVersion
    let audioContentIdentity: MetadataAudioContentIdentity?

    init(metadata: BasicMetadata, fileVersion: MetadataFileVersion)
    init(metadata: BasicMetadata, fileVersion: MetadataFileVersion,
         audioContentIdentity: MetadataAudioContentIdentity?)
}

struct MetadataFileVersion: Hashable, Sendable { /* opaque */ }
```

`readSnapshot` and `readBasicSnapshot` always supply a version. The `MetadataSnapshot` initializer allows `nil` for tools that construct a value without a filesystem observation. `audioContentIdentity` is `nil` unless explicitly requested and supported; two `nil` identities never prove continuity.

`MetadataFileVersion` records device, inode, size, link count, modification time, and status-change time for an observed regular file. It is not a content hash and not a cross-process lock.

### Raw models

```swift
struct RawMetadataDump: Hashable, Sendable {
    var properties: [RawPropertyEntry]
    var id3v2Frames: [RawID3v2FrameEntry]

    static let empty: RawMetadataDump
}

struct RawPropertyEntry: Identifiable, Hashable, Sendable {
    @SemanticIdentityExcluded var id: UUID
    var key: String
    var value: String
    var values: [String]
    var count: Int
    var schema: MetadataFieldSchema? { get }
    var shouldDisplayAsMultiValue: Bool { get }
}

struct RawID3v2FrameEntry: Identifiable, Hashable, Sendable {
    @SemanticIdentityExcluded var id: UUID
    var frameID: String
    var value: String
    var description: String?
    var language: String?
}
```

`value` is the joined display projection; `values` is authoritative for cardinality. `count` is the bridge-reported count or `values.count` when absent. Raw properties are sorted case-insensitively by key. `id` is an ephemeral UI identity excluded from semantic equality and hashing.

Raw ID3v2 frame summaries are populated for the extraction paths that request them: MPEG/ID3, WAV, AIFF, and TrueAudio. Raw AAC, MP4, ASF, FLAC, Ogg, APE-family, DSD, and tracker formats expose structured collections instead; do not assume `id3v2Frames` is populated for every file.

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

    init(properties: [StructuredPropertyEntry] = [],
         id3v2Frames: [StructuredID3v2Frame] = [],
         mp4Atoms: [StructuredMP4Atom] = [],
         asfAttributes: [StructuredASFAttribute] = [],
         artwork: [StructuredArtwork] = [],
         lyrics: [StructuredLyrics] = [],
         comments: [StructuredComment] = [],
         warnings: [String] = [])
}

struct StructuredPropertyEntry: Identifiable, Hashable, Sendable {
    @SemanticIdentityExcluded var id: UUID
    var key: String
    var values: [String]
    init(key: String, values: [String])
}

struct StructuredID3v2Frame: Identifiable, Hashable, Sendable {
    @SemanticIdentityExcluded var id: UUID
    var frameID: String
    var type: String
    var value: String
    var values: [String]
    var description: String?
    var language: String?
    var url: String?
    var owner: String?
    var data: Data?
    var fields: [String: String] // reserved; currently ignored
    var elementID: String?
    var startTimeMilliseconds: Int?
    var endTimeMilliseconds: Int?
    var startOffset: Int?
    var endOffset: Int?
    var isTopLevel: Bool?
    var isOrdered: Bool?
    var children: [String]
    var embeddedFrameCount: Int?

    init(frameID: String,
         type: String,
         value: String = "",
         values: [String] = [],
         description: String? = nil,
         language: String? = nil,
         url: String? = nil,
         owner: String? = nil,
         data: Data? = nil,
         fields: [String: String] = [:],
         elementID: String? = nil,
         startTimeMilliseconds: Int? = nil,
         endTimeMilliseconds: Int? = nil,
         startOffset: Int? = nil,
         endOffset: Int? = nil,
         isTopLevel: Bool? = nil,
         isOrdered: Bool? = nil,
         children: [String] = [],
         embeddedFrameCount: Int? = nil)
}

struct StructuredMP4Atom: Identifiable, Hashable, Sendable {
    @SemanticIdentityExcluded var id: UUID
    var key: String
    var type: String
    var value: String
    var values: [String]
    var first: Int?
    var second: Int?
    var freeformDescription: String?

    init(key: String, type: String, value: String = "", values: [String] = [],
         first: Int? = nil, second: Int? = nil, freeformDescription: String? = nil)
}

struct StructuredASFAttribute: Identifiable, Hashable, Sendable {
    @SemanticIdentityExcluded var id: UUID
    var key: String
    var type: String
    var value: String
    var data: Data?
    var pictureType: String?
    var mimeType: String?
    var description: String?
    var language: Int
    var stream: Int

    init(key: String, type: String, value: String = "", data: Data? = nil,
         pictureType: String? = nil, mimeType: String? = nil,
         description: String? = nil, language: Int = 0, stream: Int = 0)
}

struct StructuredArtwork: Identifiable, Hashable, Sendable {
    @SemanticIdentityExcluded var id: UUID
    var container: String
    var pictureType: String?
    var pictureTypeCode: Int?
    var mimeType: String
    var description: String?
    var data: Data

    init(container: String = "", pictureType: String? = nil, pictureTypeCode: Int? = nil,
         mimeType: String, description: String? = nil, data: Data)
}

struct StructuredLyrics: Identifiable, Hashable, Sendable {
    @SemanticIdentityExcluded var id: UUID
    var language: String
    var description: String
    var text: String
    init(language: String = "eng", description: String = "", text: String)
}

struct StructuredComment: Identifiable, Hashable, Sendable {
    @SemanticIdentityExcluded var id: UUID
    var language: String
    var description: String
    var text: String
    init(language: String = "eng", description: String = "", text: String)
}
```

Structured write support is container-specific:

| Collection | Writable forms |
| --- | --- |
| `properties` | Prefixless `PropertyMap` keys on writable formats. Empty `values` removes the key. Requires `includeProperties: true`. |
| `id3v2Frames` | `text`, `userText`, `url`, `ufid`, `chapter`, `tableOfContents`, `podcast` on ID3-backed formats. `APIC`, `COMM`, and `USLT` belong in the dedicated collections. `unknown` is read-only. |
| `mp4Atoms` | `stringList`, `bool`, `int`, `uint`, `byte`, `longLong`, `intPair` on MP4. Other inspected types are ignored by the writer, so they cannot be confirmed as edits. |
| `asfAttributes` | `string`, `bool`, `int`, `int64`, `binary` on ASF. `guid` is inspection-only and rejected. Attributes are upserts by key/language/stream/type. |
| `artwork` | ID3v2, MP4, ASF, FLAC/Xiph, and APE-family (one front image). `container` is informational; the writer selects the container from the file format. |
| `lyrics`, `comments` | ID3v2-backed formats and TrueAudio; replace-all collections. Empty text is skipped and cannot be verified as present. |

`StructuredArtwork.pictureTypeCode == 0` is valid (`Other`); an omitted type defaults to Front Cover (`3`). MP4 `covr` artwork is returned both as an artwork entry and as a `coverArtList` MP4 atom; use the artwork collection to replace it. Verification compares bytes and MIME type everywhere, plus picture type and description for containers that serialize them (MP4 does not).

```swift
enum StructuredMetadataReplaceableCollection: String, Hashable, Sendable {
    case artwork
    case lyrics
    case comments
}

enum RIFFMetadataWritePolicy: String, Hashable, Sendable {
    case id3v2Only
    case preserveInfo
    case syncBasicFieldsToInfo // reserved; rejects for WAV/AIFF before staging
}
```

`StructuredMetadataReplaceableCollection` names the collections that use replace-all semantics and can be empty to remove their final entries. `RIFFMetadataWritePolicy` is meaningful only for structured WAV and AIFF/AIFF-C writes; `.syncBasicFieldsToInfo` is reserved and rejected for those extensions.

### Patch models

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

    init(trackNumberText: String? = nil, discNumberText: String? = nil)
    var isEmpty: Bool { get }
}

struct MetadataPatch: Hashable, Sendable {
    var fields: [MetadataFieldKey: MetadataPatchValue]
    var customFields: [String: MetadataPatchValue]
    var explicitAdvisory: ExplicitAdvisory?
    var artwork: MetadataArtworkPatch
    var numberText: MetadataNumberTextPatch?

    init(fields: [MetadataFieldKey: MetadataPatchValue] = [:],
         customFields: [String: MetadataPatchValue] = [:],
         explicitAdvisory: ExplicitAdvisory? = nil,
         artwork: MetadataArtworkPatch = .unchanged,
         numberText: MetadataNumberTextPatch? = nil)
    var isEmpty: Bool { get }
}

struct RawMetadataPatch: Sendable {
    var valuesToSet: [String: [String]]
    var removingKeys: Set<String>

    init(valuesToSet: [String: [String]] = [:], removingKeys: Set<String> = [])
}
```

`.text` and `.values` are trimmed once during validation. Empty text, empty value arrays, and empty elements are errors. `.boolean(false)` encodes `"0"`; it is not deletion. `.remove` is the field-value deletion marker; artwork and formatted number text have their own removal forms.

`MetadataNumberTextPatch` uses three-way optional intent per pair: `nil` leaves it unchanged, a non-empty value sets it, and an empty string removes it.

`RawMetadataPatch` has no `Hashable` or `Equatable` conformance; compare the two stored collections yourself if needed.

## Extraction options

```swift
struct MetadataExtractionOptions: OptionSet, Sendable {
    let rawValue: UInt
    init(rawValue: UInt)

    static let basic: MetadataExtractionOptions        // 1 << 0
    static let raw: MetadataExtractionOptions          // 1 << 1
    static let structured: MetadataExtractionOptions   // 1 << 2
    static let propertyMap: MetadataExtractionOptions  // 1 << 3
    static let rawFrames: MetadataExtractionOptions    // 1 << 4
    static let all: MetadataExtractionOptions          // union of all five
}
```

This option set mirrors the bridge's `TagLibMetadataExtractionOptions` bits. The facade read methods select their own options; direct bridge clients pass the imported value to `metadataProjections(for:options:)`. Requesting `.propertyMap` or `.rawFrames` alone returns a `raw` projection; requesting `.raw` includes both.

## Format and capability models

```swift
enum StructuredMetadataSupport: String, Hashable, Sendable {
    case none
    case propertyMap
    case container
}

enum FormatSupportLevel: String, Hashable, Sendable {
    case fixtureCovered
    case experimental
    case upstreamSupported
    case readOnly
    case unsupported
    @available(*, deprecated, message: "...") case verified
}

struct FormatCapability: Hashable, Sendable, Identifiable {
    var id: String { identifier }
    var identifier: String
    var displayName: String
    var codecName: String
    var primaryExtension: String
    var extensions: [String]
    var containers: [String]
    var isReadable: Bool
    var isWritable: Bool
    var canReadArtwork: Bool
    var canWriteArtwork: Bool
    var preservesMultiValueProperties: Bool
    var structuredReadSupport: StructuredMetadataSupport
    var structuredWriteSupport: StructuredMetadataSupport
    var readOnlyReason: String?
    var notes: String?
    var supportLevel: FormatSupportLevel
    var extensionSupportLevels: [String: FormatSupportLevel]
    var readableFields: Set<MetadataFieldKey>?
    var writableFields: Set<MetadataFieldKey>?
    var metadataFieldFormats: Set<MetadataFieldFormat> { get }

    func supportLevel(forExtension fileExtension: String) -> FormatSupportLevel
    func readSupport(for field: MetadataFieldKey) -> FormatSupportLevel
    func writeSupport(for field: MetadataFieldKey) -> FormatSupportLevel

    init(identifier: String,
         displayName: String,
         codecName: String,
         primaryExtension: String,
         extensions: [String],
         containers: [String],
         isReadable: Bool,
         isWritable: Bool,
         canReadArtwork: Bool,
         canWriteArtwork: Bool,
         preservesMultiValueProperties: Bool,
         structuredReadSupport: StructuredMetadataSupport,
         structuredWriteSupport: StructuredMetadataSupport,
         readOnlyReason: String? = nil,
         notes: String? = nil,
         supportLevel: FormatSupportLevel = .upstreamSupported,
         extensionSupportLevels: [String: FormatSupportLevel] = [:],
         readableFields: Set<MetadataFieldKey>? = nil,
         writableFields: Set<MetadataFieldKey>? = nil)
}
```

| Member | Meaning |
| --- | --- |
| `identifier` / `id` | Stable family identifier such as `mp4`, `flac`, or `mpeg-id3`. |
| `displayName`, `codecName` | Human-readable family and codec names. |
| `primaryExtension`, `extensions` | Primary extension and all aliases, lowercase. |
| `containers` | Declared container surfaces: `tag`, `propertyMap`, `id3v1`, `id3v2`, `ape`, `mp4`, `xiph`, `asf`, `riffInfo`. |
| `isReadable`, `isWritable` | Declared operation availability. |
| `canReadArtwork`, `canWriteArtwork` | Artwork availability. `canWriteArtwork` is false when the family is read-only. |
| `preservesMultiValueProperties` | Family-level repeated-value support, not a per-field promise. |
| `structuredReadSupport`, `structuredWriteSupport` | Non-artwork structured inspection/mutation level. A `.propertyMap` level can still support structured artwork. |
| `readOnlyReason`, `notes` | Configured caveats. |
| `supportLevel` | Evidence level for the capability's requested or primary extension. |
| `extensionSupportLevels` | Per-extension evidence levels. |
| `readableFields`, `writableFields` | Optional explicit allowlists; `nil` means infer from schema mappings. Currently used by tracker families. |
| `metadataFieldFormats` | Formats implied by `containers` (plus `.flac` for the native FLAC family). |

`readSupport` and `writeSupport` combine `isReadable`/`isWritable`, the field schema's mappings, artwork flags, explicit allowlists, and the MP4 single-date rule. `supportLevel(forExtension:)` takes a case-insensitive extension and returns `.unsupported` when the family does not register it.

The format matrix and per-family limitations are in [Formats](FORMATS.md).

### Field schema types

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
    init(minimum: Int, maximum: Int)
}

struct MetadataFormatMapping: Hashable, Sendable {
    var format: MetadataFieldFormat
    var storageKind: MetadataFieldStorageKind
    var keys: [String]
    var note: String?
    init(format: MetadataFieldFormat, storageKind: MetadataFieldStorageKind,
         keys: [String], note: String? = nil)
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

    init(key: MetadataFieldKey,
         displayName: String,
         category: MetadataFieldCategory,
         propertyMapKeys: [String],
         mappings: [MetadataFormatMapping] = [],
         isMultiValue: Bool = false,
         isPeopleField: Bool = false,
         isRoleQualified: Bool = false,
         isArtworkField: Bool = false)
}
```

`acceptedPatchValueKinds` is the typed-patch contract: integer-only for track/disc/movement/BPM, Boolean-only for compilation, empty for artwork/explicit/custom, and text/values for ordinary fields. `integerConstraint` supplies the range enforced by typed patches. The complete field list and mappings are in [Metadata field schema](FIELD_SCHEMA.md).

### `MetadataFieldKey`

```swift
enum MetadataFieldKey: String, CaseIterable, Hashable, Sendable {
    case title, artist, album, albumArtist, date, releaseDate, originalReleaseDate
    case track, trackTotal, disc, discTotal
    case artwork, lyrics, comment, genre, composer, conductor, remixer, performer
    case producer, engineer, lyricist, involvedPeople, musicianCredits
    case publisher, copyright, encodedBy, encoderSettings, isrc, barcode
    case catalogNumber, asin, releaseType, releaseStatus, releaseCountry, mediaType
    case work, movement, movementNumber, movementCount, discSubtitle, subtitle
    case grouping, mood, language, musicalKey, bpm, compilation, explicitContent
    case sortTitle, sortArtist, sortAlbum, sortAlbumArtist, sortComposer
    case musicBrainzArtistID, musicBrainzAlbumID, musicBrainzAlbumArtistID
    case musicBrainzTrackID, musicBrainzReleaseGroupID, musicBrainzReleaseTrackID
    case musicBrainzWorkID, acoustID, acoustIDFingerprint, musicIPPUID
    case replayGainTrackGain, replayGainAlbumGain
    case itunesAlbumID, itunesArtistID, itunesCatalogID, itunesGenreID
    case itunesMediaType, itunesPurchaseDate, itunesNorm, itunesSMPB
    case originalAlbum, originalArtist, artistType, trackerName, custom
}
```

The enum has 79 cases. `trackerName` is a schema key used by tracker formats; `BasicMetadata` has no property for it. Use `MetadataPatch(fields: [.trackerName: ...])` or a structured/raw API where the capability allows it.

### `MetadataFieldRegistry`

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

`schema(forPropertyMapKey:)` recognizes the qualified prefixes `PERFORMER:`, `INVOLVEDPEOPLE:`, `MUSICIANCREDITS:`, `COMMENT:`, and `LYRICS:`. `normalizePropertyMapKey` trims whitespace and uppercases. `schemas(storableIn:)` returns an empty list for read-only capabilities and excludes the MP4 `.date` field and unsupported artwork.

## Audio-content models

```swift
struct MetadataAudioContentIdentity: Hashable, Sendable { /* opaque digest */ }

enum MetadataAudioContentError: Error, Equatable, Sendable, LocalizedError {
    case unavailable
    case changed

    var errorDescription: String? { get }
}
```

`MetadataAudioContentIdentity` has no public initializer or accessors. Compare values for equality; do not persist them as recording identifiers across package versions. `.unavailable` means the layout is unsupported or ambiguous; `.changed` means the encoded audio or its interpretation parameters differ from the baseline. See [Audio-content continuity](AUDIO_CONTENT_CONTINUITY.md).

## Semantic identity helper

```swift
@propertyWrapper
struct SemanticIdentityExcluded: Hashable, Sendable {
    var wrappedValue: UUID
    init(wrappedValue: UUID)
    static func == (lhs: Self, rhs: Self) -> Bool
    func hash(into hasher: inout Hasher)
}
```

Used by model types to keep ephemeral UI identifiers out of synthesized semantic equality and hashing. Two entries with different `id` values can still be equal when their semantic fields match.

## Errors

All error types conform to `Error`, `Sendable`, and `LocalizedError`; validation-value errors are also `Equatable`.

### `TagLibManagerError`

```swift
enum TagLibManagerError: Error, Sendable, LocalizedError {
    case invalidFile
    case fileChanged
    case hardLinkedFile
    case unsupportedFormat
    case unsupportedWritePolicy(String)
    @available(*, deprecated, message: "Use failedToReadWithUnderlying(_:) for throwing read failures.")
    case failedToRead
    case failedToReadWithUnderlying(String)
    case verificationFailed([String])
    case operationFailed(String)
    case operationFailedWithUnderlying(NSError)
    case committedButDurabilityUncertain(String)

    var underlyingError: NSError? { get }
    var errorDescription: String? { get }
}
```

| Case | Meaning |
| --- | --- |
| `invalidFile` | The URL is not an existing regular file, or a final symbolic link was rejected. |
| `fileChanged` | The optimistic version or destination identity changed. |
| `hardLinkedFile` | Atomic replacement would split a hard-linked file identity. No metadata was committed. |
| `unsupportedFormat` | The extension is missing or not supported for the requested operation. |
| `unsupportedWritePolicy(String)` | The selected structured write policy is not implemented for that container. |
| `failedToRead` | Deprecated; no longer emitted. |
| `failedToReadWithUnderlying(String)` | The bridge or parser failed while reading. |
| `verificationFailed([String])` | A verified write could not confirm requested values; nothing was committed. |
| `operationFailed(String)` | Message-only compatibility case; native/filesystem failures use `operationFailedWithUnderlying`. |
| `operationFailedWithUnderlying(NSError)` | Pre-commit bridge/filesystem failure with a typed cause; inspect `underlyingError`. |
| `committedButDurabilityUncertain(String)` | The low-level transaction helper committed the rename but the final directory sync failed. High-level writes report this through `MetadataWriteResult.commitStatus`. |

`underlyingError` returns the associated `NSError` for `operationFailedWithUnderlying` and `nil` otherwise.

### `MetadataPatchValidationError`

```swift
enum MetadataPatchValidationError: Error, Equatable, Sendable, LocalizedError {
    case unsupportedField(MetadataFieldKey)
    case unsupportedFieldForFormat(field: MetadataFieldKey, format: String)
    case incompatibleValue(field: MetadataFieldKey,
                           expected: Set<MetadataPatchValueKind>,
                           actual: MetadataPatchValueKind)
    case integerOutOfRange(field: MetadataFieldKey,
                           minimum: Int, maximum: Int, actual: Int)
    case knownFieldRequiresTypedAPI(customKey: String, field: MetadataFieldKey)
    case conflictingFieldRepresentations(field: MetadataFieldKey, customKey: String)
    case duplicateCustomField(normalizedKey: String)
    case invalidCustomFieldKey(String)
    case emptyText(location: String)
    case emptyValueList(location: String)
    case emptyValue(location: String, index: Int)
    case conflictingNumberRepresentations
    case roleQualifiedFieldRequiresRawAPI(MetadataFieldKey)
    case unsupportedPartialPairRemoval(field: MetadataFieldKey, format: String)
}
```

### `MetadataValidationError`

```swift
enum MetadataValidationError: Error, Equatable, Sendable, LocalizedError {
    case propertiesRequireIncludeProperties
    case embeddedNull(location: String)
    case unsupportedID3v2FrameType(String)
    case knownFieldRequiresRawAPI(String)
    case invalidCustomFieldKey(String)
    case conflictingMP4Date(year: String, releaseDate: String)
}
```

### `RawMetadataPatchError`

```swift
enum RawMetadataPatchError: Error, Equatable, Sendable, LocalizedError {
    case invalidKey(String)
    case emptyArray(String)
    case conflictingKey(String)
    case embeddedNull(String)
    case nativeKeyRequiresStructuredAPI(String)
}
```

### `MetadataAudioContentError`

`unavailable` and `changed`; see [Audio-content continuity](AUDIO_CONTENT_CONTINUITY.md).

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

## Related references

- [Bridge reference](BRIDGE.md) — public Objective-C surface.
- [Metadata field schema](FIELD_SCHEMA.md) — all field mappings and patch constraints.
- [Formats](FORMATS.md) — capability matrix and container limits.
- [Write semantics](PRESERVATION.md) — preservation and verification scope.
- [Transactions](TRANSACTIONS.md) — staging, durability, and concurrency.
