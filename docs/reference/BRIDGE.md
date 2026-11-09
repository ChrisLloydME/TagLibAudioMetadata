# Public Objective-C bridge

The `TagLibAudioMetadataLowLevel` product exposes `CTagLibBridge`, a Foundation-only Objective-C surface implemented in Objective-C++. Use it when an application needs a bridge capability that the Swift facade does not wrap, or when building a non-Swift consumer. For normal Swift editing, prefer the facade: it adds validation, semantic readback verification, and the omitting patch APIs.

The public header is `Sources/CTagLibBridge/include/TagLibMetadataExtractor.h`. C++ types, TagLib headers, in-place mutation primitives, and the same-entry coordinator are not part of this product. `CTagLibBridgeInternalAPI` is an internal target used by the facade and tests; it is not a library product.

## Product and import

```swift
// Package.swift target dependency
.product(name: "TagLibAudioMetadataLowLevel", package: "TagLibAudioMetadata")
```

```swift
import CTagLibBridge
```

The facade product does **not** re-export bridge declarations. A target that names `TagLibAudioMetadata`, `TagLibMetadataExtractor`, `TagLibExplicitAdvisory`, or `TagLibMetadataExtractionOptions` must also depend on the low-level product.

## Transaction behavior

Every public bridge mutator follows the same staging transaction as the facade:

1. resolve and validate the destination without following a final symbolic link;
2. reject a non-regular file, a setuid/setgid file, and a hard-linked file;
3. validate that the original is a readable audio file;
4. copy it to a sibling temporary file with `copyfile(COPYFILE_CLONE | COPYFILE_ACL)`;
5. run the mutation on the temporary file;
6. validate that the temporary file is still readable;
7. request `F_FULLFSYNC` (or `fsync` where the filesystem rejects it);
8. recheck the destination identity, open the parent directory, and atomically rename;
9. sync the already-open parent directory.

A failure before rename leaves the destination untouched and removes the temporary file. A parent-directory sync failure after rename is reported as `TagLibMetadataTransactionErrorCodeCommittedButDurabilityUncertain` (`9110`) in the `TagLibMetadataExtractor` domain. Other transaction failures use implementation error codes in `TLBridgeTransactions.mm` (`9111` hard link, `9112` privilege bit or invalid coordination input, `9113` Objective-C exception); only `9110` is a public enum constant. The mutation is already visible for `9110`; do not blindly retry it.

The bridge does not perform the facade's semantic readback comparison. It validates staged readability only. A public bridge write with no facade verification cannot prove that a requested value persisted, that an omitted field was preserved, or that a native tag round-tripped byte for byte. See [Transactions](../explanation/TRANSACTIONS.md).

## `TagLibAudioMetadata` model

`TagLibAudioMetadata` is the writer/reader model used by `extractMetadata(from:)`, `writeMetadata(_:to:)`, and `writeTagMetadata(_:to:verification:expectedVersion:)`. It is a full writer payload for the fields the bridge maps, not an omission-safe patch. A sparse instance clears mapped fields where the container permits it; read the current values first if a partial edit is intended.

Properties are nullable `NSString *` unless marked numeric or Boolean.

| Group | Properties |
| --- | --- |
| Core | `title`, `artist`, `album`, `albumArtist`, `composer`, `genre`, `year`, `standaloneDate`, `contentGroup`, `artists`, `comment` |
| Numbering | `trackNumber`, `totalTracks`, `discNumber`, `totalDiscs`, `trackNumberText`, `discNumberText` |
| Audio properties | `duration`, `bitrate`, `sampleRate`, `channels`, `bitDepth`, `codec` |
| Artwork | `artworkData`, `artworkMimeType`, `removeArtwork` |
| Advisory | `explicitAdvisory`, `explicitAdvisoryRawValue`, `explicitContent` |
| Additional | `bpm`, `compilation`, `copyright`, `lyrics`, `label`, `isrc`, `encodedBy`, `encoderSettings` |
| Sorting | `sortTitle`, `sortArtist`, `sortAlbum`, `sortAlbumArtist`, `sortComposer` |
| Dates | `releaseDate`, `originalReleaseDate` |
| Personnel | `conductor`, `remixer`, `producer`, `engineer`, `lyricist` |
| Descriptive | `subtitle`, `grouping`, `movement`, `mood`, `language`, `musicalKey` |
| MusicBrainz and identifiers | `musicBrainzArtistId`, `musicBrainzAlbumId`, `musicBrainzAlbumArtistId`, `musicBrainzTrackId`, `musicBrainzReleaseGroupId`, `musicBrainzReleaseTrackId`, `musicBrainzWorkId`, `acoustId`, `acoustIdFingerprint`, `musicIpPuid` |
| ReplayGain | `replayGainTrack`, `replayGainAlbum`, `replayGainTrackPeak`, `replayGainAlbumPeak` |
| Media type | `mediaType` |
| iTunes | `itunesAlbumId`, `itunesArtistId`, `itunesCatalogId`, `itunesGenreId`, `itunesMediaType`, `itunesPurchaseDate`, `itunesNorm`, `itunesSmpb` |
| Release | `releaseType`, `releaseStatus`, `catalogNumber`, `barcode`, `releaseCountry`, `artistType`, `asin`, `originalAlbum`, `originalArtist`, `discSubtitle`, `work`, `movementNumber`, `movementCount` |
| Custom | `customFields` (`NSDictionary<NSString *, NSString *> *`) |

`artworkMimeType` is the declared media type for `artworkData`; readers normalize common values and may infer a type from magic bytes when the container omits it. `removeArtwork` is a write instruction, not a readable property: set it to clear the picture collection.

`explicitContent` is a Boolean compatibility projection. Reading `YES` means `.explicit`; setting `NO` records `.clean`. It cannot represent absence or not-explicit. Use `explicitAdvisory` for the four-state model.

The bridge model does not expose the MP4-exclusive facade properties (`director`, store IDs, TV fields, and related Booleans). They are available through `BasicMetadata` reads and `MetadataPatch`/structured writes, not through `writeTagMetadata`.

`year` is complete stored text and may contain a date. `standaloneDate` is the independent DATE slot; `releaseDate` and `originalReleaseDate` are separate. The bridge selects the version-appropriate ID3 date frame and writes MP4 `©day`; it never truncates Year to four characters. `explicitAdvisoryRawValue` carries an unknown native advisory code while `explicitAdvisory` remains `.unspecified`.

The package-internal `CTagLibBridgeInternalAPI` additionally exposes `applyNativeTextKeyValuesInPlace(_:removingKeys:to:)` for exact Xiph/APE text keys and versioned structured ID3 frame writes. These are not part of the public low-level product.

## Constants and options

| Declaration | Values |
| --- | --- |
| `TagLibMetadataErrorDomain` | `"TagLibMetadataExtractor"` |
| `TagLibMetadataTransactionErrorCodeCommittedButDurabilityUncertain` | `9110` |
| `TagLibExplicitAdvisory` | `TagLibExplicitAdvisoryUnspecified = 0`, `TagLibExplicitAdvisoryClean = 1`, `TagLibExplicitAdvisoryExplicit = 2`, `TagLibExplicitAdvisoryNotExplicit = 3` |
| `TagLibMetadataExtractionOptions` | `TagLibMetadataExtractionOptionBasic = 1 << 0`, `TagLibMetadataExtractionOptionRaw = 1 << 1`, `TagLibMetadataExtractionOptionStructured = 1 << 2`, `TagLibMetadataExtractionOptionPropertyMap = 1 << 3`, `TagLibMetadataExtractionOptionRawFrames = 1 << 4`, `TagLibMetadataExtractionOptionAll = NSUIntegerMax` |

`TagLibMetadataExtractionOptions` is an `NS_OPTIONS` mask. Passing a mask with no recognized bits yields an empty result dictionary; it does not throw. The Swift facade mirrors the five known bits as `MetadataExtractionOptions`; its `.all` is the union of those bits, while the bridge's `All` is `NSUIntegerMax`.

## Selectors

The table uses the Swift-imported names; the Objective-C selector column is the ABI spelling declared in the header.

| Swift name | Objective-C selector | Result |
| --- | --- | --- |
| `extractMetadata(from:)` | `extractMetadataFromURL:error:` | Basic `TagLibAudioMetadata` model. |
| `metadataProjections(for:)` | `metadataProjectionsForURL:error:` | Basic, raw, and structured projections from one extraction call (equivalent to `All`). |
| `metadataProjections(for:options:)` | `metadataProjectionsForURL:options:error:` | Requested subset of `basic`, `raw`, and `structured`. |
| `writeMetadata(_:to:)` | `writeMetadata:toURL:error:` | Transactional full-model write. |
| `writeTrackNumberText(_:discNumberText:to:)` | `writeTrackNumberText:discNumberText:toURL:error:` | Formatted track/disc text write. |
| `writeTrackNumber(_:totalTracks:padWidth:to:)` | `writeTrackNumber:totalTracks:padWidth:toURL:error:` | Numeric track write with optional zero padding. |
| `writeRawPropertyMap(_:to:)` | `writeRawPropertyMap:toURL:error:` | Whole-map visible `PropertyMap` replacement with single values. |
| `writeRawPropertyMapValues(_:to:)` | `writeRawPropertyMapValues:toURL:error:` | Whole-map replacement with value arrays. |
| `structuredMetadata(for:)` | `structuredMetadataForURL:error:` | Container-aware structured projection. |
| `writeStructuredMetadata(_:to:)` | `writeStructuredMetadata:toURL:error:` | Structured mutation; omitted collections are preserved. |
| `wipeMetadata(from:)` | `wipeMetadataFromURL:error:` | Native metadata-container wipe where TagLib supports stripping. |
| `rawMetadata(for:)` | `rawMetadataForURL:error:` | Property-map/frame dictionary. |
| `dumpMetadataText(from:)` | `dumpMetadataTextFromURL:error:` | Human-readable diagnostic text. |
| `isSupportedFormat(_:)` | `isSupportedFormat:` | Declared readable-extension lookup. |
| `isWritableFormat(_:)` | `isWritableFormat:` | Declared writable-extension lookup. |
| `supportedExtensions()` | `supportedExtensions` | All registered extensions in registry order. |
| `writableExtensions()` | `writableExtensions` | Extensions of writable families in registry order. |
| `formatCapability(for:)` | `formatCapabilityForExtension:` | Capability dictionary for an extension. |
| `formatCapabilities()` | `formatCapabilities` | Capability dictionaries for every family. |
| `knownMetadataPropertyKeys()` | `knownMetadataPropertyKeys` | Prefixless property keys known to the bridge schema. |
| `metadataFieldMappings()` | `metadataFieldMappings` | Ordered canonical/alias/container mapping dictionaries. |

### Projection keys

`metadataProjections(for:options:)` returns a dictionary whose keys depend on the requested mask:

| Requested bits | Top-level keys |
| --- | --- |
| `.basic` | `basic` |
| `.raw`, `.propertyMap`, or `.rawFrames` | `raw` |
| `.structured` | `structured` |
| Any combination | The union of the applicable keys |

Requesting `.propertyMap` alone returns `raw` with `properties` and an empty `id3v2Frames` array. Requesting `.rawFrames` alone returns `raw` with `id3v2Frames` and an empty `properties` array. Requesting `.raw` includes both. `.structured` also requests the visible property map internally, but its result is reported under `structured.properties`.

The bridge also exposes `TagLibMetadataExtractionOptionAll = NSUIntegerMax`. A request with no recognized bits returns an empty dictionary after opening the file, so do not use it as a validation path.

```text
properties:   NSArray<NSDictionary<NSString *, NSObject *> *>
              keys: key, value (joined display), values (authoritative array), count
id3v2Frames:  NSArray<NSDictionary<NSString *, NSObject *> *>
              keys: id, value, optional description, optional language
```

`structured` contains `properties`, `id3v2Frames`, `mp4Atoms`, `asfAttributes`, `artwork`, `lyrics`, `comments`, and `warnings`. The exact dictionaries are the ones consumed by `StructuredMetadata` in the facade; see the [model reference](MODELS.md).

## Thread safety and process boundaries

All selectors that enter TagLib are serialized internally by a process-wide recursive mutex. Calls are safe from multiple threads, including for different files, but parser/mutation intervals execute one at a time. Foundation objects populated while traversing live TagLib objects are constructed inside that interval.

Transaction filesystem work (copy, flush, rename) runs outside the TagLib mutex. Same-entry transactions are serialized by a per-directory-entry lock shared with the facade. Coordination is process-local: an external process can still change the destination between the final identity check and rename. The package does not create lock files or advisory file locks. See [Transactions](../explanation/TRANSACTIONS.md).

The framework is namespaced, but TagLib C++ symbols are still exported. Do not load another incompatible TagLib implementation into the same process.

## Diagnostics

Set `TAGLIBAUDIOMETADATA_DEBUG` to `1`, `true`, `yes`, or `on` before the process starts to enable bridge logging. The output is troubleshooting output, not a stable format.

## Related references

- [manager API](API.md) — Swift surface and model types.
- [field reference](FIELDS.md) — property and container mappings.
- [Transactions](../explanation/TRANSACTIONS.md) — staging, durability, and concurrency.
- [Installation](../operations/INSTALLATION.md) — low-level product and framework embedding.
