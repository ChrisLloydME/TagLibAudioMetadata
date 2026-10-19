# Public API reference

This is a symbol-level index of the stable public surface. It complements [USAGE](USAGE.md), which explains semantics and shows complete examples. The source declarations remain authoritative; this list omits forwarding overloads unless they affect migration.

## Products and modules

| Product | Module | Use |
| --- | --- | --- |
| `TagLibAudioMetadata` | `TagLibAudioMetadata` | Swift facade and application models. |
| `TagLibAudioMetadataLowLevel` | `CTagLibBridge` | Public Objective-C bridge for advanced transactional access. |

`CTagLibBridgeInternalAPI` is a package-internal target, not a library product. It is not supported for external use.

## Reads

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

Optional convenience readers collapse errors to `nil`:

```swift
static func bestEffortMetadata(from url: URL) -> BasicMetadata?
static func bestEffortRawMetadata(from url: URL) -> RawMetadataDump?
static func bestEffortRawMetadataText(from url: URL) -> String?
static func bestEffortStructuredMetadata(from url: URL) -> StructuredMetadata?
```

Deprecated read names forward to the best-effort or throwing forms: `readMetadata(from:)`, `rawMetadata(from:)`, `readStructuredMetadata(from:)`, `rawMetadataText(from:)`.

`readSnapshot` and `readBasicSnapshot` capture a `MetadataFileVersion` (and an optional `MetadataAudioContentIdentity`). Pass the version to a later write to reject a stale edit.

## Patches

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

The deprecated `failurePolicy:` overloads forward to the unguarded patches. `VerificationFailurePolicy` remains only for source compatibility; `.warn` does not bypass verification.

## Basic writes

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

`replaceBasicMetadata` replaces the complete modeled Basic projection. `updateBasicMetadata` captures a focused snapshot version and applies an in-memory edit.

Deprecated writers: `writeMetadata`, `writeMetadataWithVerification`.

## Raw writes

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

`.replace` owns the visible PropertyMap; `.merge` applies a delta. Prefer `RawMetadataPatch` for exact array preservation.

## Structured writes

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

The deprecated `failurePolicy:` overload forwards without a bypass.

## Number text and low-level writes

```swift
static func writeTrackNumberText(
    _ trackNumberText: String,
    discNumberText: String?,
    to url: URL,
    verifyAfterWrite: Bool = true,
    expectedVersion: MetadataFileVersion? = nil
) throws -> MetadataWriteResult

static func writeTagMetadata(
    _ metadata: TagLibAudioMetadata,           // requires import CTagLibBridge
    to url: URL,
    verification: MetadataWriteVerificationContext = .none,
    expectedVersion: MetadataFileVersion? = nil
) throws -> MetadataWriteResult
```

`writeTagMetadata` performs only the checks supplied in its verification context; the default `.none` checks no metadata values. `expectedTextFields` keys are camel-case Basic field names such as `title` and `encodedBy`, not PropertyMap keys such as `TITLE`; passing a raw key produces a false mismatch. Prefer the typed patch, raw patch, or Basic verified APIs for normal editing.

## Erase

```swift
static func eraseAllMetadataWithVerification(
    from url: URL,
    expectedVersion: MetadataFileVersion? = nil
) throws -> MetadataWriteResult

static func eraseAllMetadata(from url: URL) throws -> Bool
```

The `Bool` convenience discards warnings; new code should use the verified form. Erase is limited to the metadata surfaces the parser exposes.

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

Deprecated: `formatCapability(for:)`, `isReadableFormat(_:)`, `isWritableFormat(_:)`.

## Core models

| Type | Purpose |
| --- | --- |
| `BasicMetadata` | Normalized common-field projection: text, numbers, dates, identifiers, people, artwork, custom fields, audio properties, provenance. |
| `MetadataSnapshot` | `basic`, `raw`, `structured`, `fileVersion`, optional `audioContentIdentity`. |
| `BasicMetadataSnapshot` | `metadata`, `fileVersion`, optional `audioContentIdentity`. |
| `MetadataFileVersion` | Opaque filesystem revision token for optimistic writes. |
| `MetadataAudioContentIdentity` | Opaque SHA-256 identity of encoded audio and interpretation parameters for supported containers. |
| `RawMetadataDump` | `properties: [RawPropertyEntry]` and `id3v2Frames: [RawID3v2FrameEntry]`. |
| `RawMetadataPatch` | `valuesToSet: [String: [String]]` plus `removingKeys: Set<String>`. |
| `StructuredMetadata` | Properties, ID3v2 frames, MP4 atoms, ASF attributes, artwork, lyrics, comments, warnings. |
| `StructuredArtwork` | Container hint, picture type/code, MIME type, description, data. |
| `MetadataWriteResult` | `warnings: [String]`, `commitStatus: MetadataCommitStatus`. |
| `FormatCapability` | Family, extensions, flags, containers, support levels, field-level support queries. |

### Patch value types

```swift
enum MetadataPatchValue {
    case text(String)
    case integer(Int)
    case boolean(Bool)
    case values([String])
    case remove
}

enum MetadataArtworkPatch {
    case unchanged
    case replace([StructuredArtwork])
    case removeAll
}

struct MetadataNumberTextPatch {
    var trackNumberText: String?
    var discNumberText: String?
}
```

### Status and policy types

```swift
enum MetadataCommitStatus {
    case durable
    case durabilityUncertain(String)
}

enum RawPropertyMapWriteMode {
    case replace
    case merge
}

enum RIFFMetadataWritePolicy {
    case id3v2Only
    case preserveInfo
    case syncBasicFieldsToInfo   // reserved; rejects before staging
}

enum FormatSupportLevel {
    case fixtureCovered
    case verified                // deprecated
    case experimental
    case upstreamSupported
    case readOnly
    case unsupported
}

enum StructuredMetadataSupport {
    case none
    case propertyMap
    case container
}
```

## Field schema

`MetadataFieldRegistry` is the public source of field semantics:

```swift
static let allSchemas: [MetadataFieldSchema]
static func schema(for key: MetadataFieldKey) -> MetadataFieldSchema?
static func schema(forPropertyMapKey key: String) -> MetadataFieldSchema?
static func schemas(withMappingsFor format: MetadataFieldFormat) -> [MetadataFieldSchema]
static func schemas(storableIn capability: FormatCapability) -> [MetadataFieldSchema]
static func schema(_ key: MetadataFieldKey, hasMappingFor format: MetadataFieldFormat) -> Bool
static func shouldDisplayRawPropertyAsMultiValue(_ key: String) -> Bool
static func normalizePropertyMapKey(_ key: String) -> String
```

`MetadataFieldSchema` exposes `key`, `displayName`, `category`, `propertyMapKeys`, `mappings`, `isMultiValue`, `isPeopleField`, `isRoleQualified`, `isArtworkField`, `acceptedPatchValueKinds`, and `integerConstraint`. `MetadataFormatMapping` exposes `format`, `storageKind`, `keys`, and `note`.

## Errors

| Error | Used for |
| --- | --- |
| `TagLibManagerError` | File, version, format, verification, operation, and durability failures. |
| `MetadataValidationError` | Structured properties outside `includeProperties`, embedded NULs, unsupported ID3 frame types, schema-known Basic custom keys, conflicting MP4 date projections. |
| `MetadataPatchValidationError` | Typed patch kind/range/custom-key/role-qualified/partial-pair validation. |
| `RawMetadataPatchError` | Invalid/empty/conflicting raw keys, embedded NULs, native MP4 keys. |
| `MetadataAudioContentError` | `.unavailable` or `.changed` for opt-in audio continuity. |

`TagLibManagerError` cases:

```swift
case invalidFile
case fileChanged
case hardLinkedFile
case unsupportedFormat
case unsupportedWritePolicy(String)
case failedToReadWithUnderlying(String)
case verificationFailed([String])
case operationFailed(String)                 // compatibility constructor
case operationFailedWithUnderlying(NSError)  // emitted for bridge/filesystem failures
case committedButDurabilityUncertain(String) // lower-level/internal helper
case failedToRead                           // deprecated
```

`underlyingError` returns the associated `NSError` for `operationFailedWithUnderlying`.

## Low-level Objective-C bridge

The public header is `Sources/CTagLibBridge/include/TagLibMetadataExtractor.h`. It exposes no C++ types. Key selectors:

| Selector | Purpose |
| --- | --- |
| `extractMetadata(from:)` | Basic bridge model read. |
| `metadataProjections(for:)`, `metadataProjections(for:options:)` | One-session Basic/raw/structured projections. |
| `writeMetadata(_:to:)` | Transactional bridge-model write; no facade semantic verification. |
| `writeTrackNumber(_:totalTracks:padWidth:to:)` | Low-level track number write. |
| `writeTrackNumberText(_:discNumberText:to:)` | Low-level formatted number write. |
| `writeRawPropertyMap(_:to:)`, `writeRawPropertyMapValues(_:to:)` | Whole-map replacement. |
| `structuredMetadata(for:)`, `writeStructuredMetadata(_:to:)` | Structured projection/write. |
| `wipeMetadata(from:)` | Native metadata container wipe where supported. |
| `rawMetadata(for:)`, `dumpMetadataText(from:)` | Raw inspection. |
| `isSupportedFormat(_:)`, `isWritableFormat(_:)`, `supportedExtensions()`, `writableExtensions()` | Extension discovery. |
| `formatCapability(for:)`, `formatCapabilities()` | Capability dictionaries. |
| `knownMetadataPropertyKeys()`, `metadataFieldMappings()` | Schema parity helpers. |

Bridge mutators are transactional but do not compare requested metadata after save. `writeMetadata` throws the typed committed-but-durability-uncertain error code when the final directory flush fails after rename.

## Availability

- Swift tools 6.0
- macOS 13+
- iOS 16+
- GNU C++20
- Pinned dynamic TagLib 2.3.1 XCFramework

See [INSTALLATION](INSTALLATION.md) for embedding, signing, and binary identity.
