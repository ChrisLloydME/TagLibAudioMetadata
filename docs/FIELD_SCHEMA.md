# Metadata field schema

This is the canonical reference for the public metadata field registry. It describes `MetadataFieldKey`, `MetadataFieldSchema`, and `MetadataFieldRegistry` in `Sources/TagLibAudioMetadata/MetadataFieldSchema.swift`. The Swift declarations and the generated tables below are checked against each other by `scripts/check-docs.py`.

The registry answers three different questions:

1. **Semantics.** What is the display name and category of a field, and is it multi-value, people-oriented, role-qualified, or artwork?
2. **Storage.** Which TagLib `PropertyMap` keys, ID3v2 frames, MP4 item/freeform keys, and generic container surfaces can carry the field?
3. **Editing.** Which typed-patch value kinds are accepted, and what numeric range applies?

It does **not** answer whether a particular file or format actually stores a field. Use `FormatCapability.readSupport(for:)` and `FormatCapability.writeSupport(for:)` for that, and validate a concrete file with `probeFile(at:)`.

## How to query the registry

```swift
import TagLibAudioMetadata

let title = MetadataFieldRegistry.schema(for: .title)
let byPropertyKey = MetadataFieldRegistry.schema(forPropertyMapKey: "MUSICBRAINZ_TRACKID")
let id3Fields = MetadataFieldRegistry.schemas(withMappingsFor: .id3v2)
let writable = MetadataFieldRegistry.schemas(storableIn: capability)
```

| API | Behavior |
| --- | --- |
| `schema(for:)` | Returns the one schema for a `MetadataFieldKey`, or `nil`. |
| `schema(forPropertyMapKey:)` | Normalizes the key, recognizes qualified prefixes, and resolves the owning schema. |
| `schemas(withMappingsFor:)` | Returns every schema with at least one mapping for a `MetadataFieldFormat`. |
| `schemas(storableIn:)` | Returns `[]` for read-only capabilities; otherwise filters by the capability's container formats, explicit `writableFields` allowlist, MP4 single-date rule, and artwork support. |
| `schema(_:hasMappingFor:)` | Convenience check for one format mapping. |
| `shouldDisplayRawPropertyAsMultiValue(_:)` | UI hint for raw `PropertyMap` keys; true for multi-value schemas and the qualified prefixes below. |
| `normalizePropertyMapKey(_:)` | Trims whitespace and uppercases. Use it before comparing raw keys. |

`schemas(storableIn:)` is a preflight filter, not a guarantee. A field can be listed for a format and still fail for a specific file because of container state, tag version, native width, or a preservation conflict.

## Field registry

The reference currently defines 79 fields. The tables are generated from `MetadataFieldSchema.swift`; run `python3 scripts/generate-field-schema.py --write` after changing the registry.

Column meanings:

- **PropertyMap keys** are the prefixless keys used by `RawMetadataDump`, `RawMetadataPatch`, and the raw writers. The same key list is also used for generic Xiph, APE, and ASF PropertyMap surfaces where the format supports it.
- **ID3v2** lists the native text frame or `TXXX:<description>` user-text frame. `—` means the schema has no direct ID3v2 mapping.
- **MP4** lists native item keys and `----:com.apple.iTunes:<description>` freeform keys. MP4 freeform descriptions are case-sensitive in the bridge's structured API, but typed and raw APIs normalize their own comparison keys.
- **Flags** identify `multi` (multi-value), `people`, `role` (role-qualified key required), and `artwork`.

<!-- BEGIN GENERATED FIELD TABLES -->
<!-- Generated from `MetadataFieldSchema.swift`. 79 fields. -->

### Basic and descriptive

| Key | Display name | PropertyMap keys | ID3v2 | MP4 | Flags |
| --- | --- | --- | --- | --- | --- |
| `title` | Title | `TITLE` | `TIT2` | `©nam` | — |
| `album` | Album | `ALBUM` | `TALB` | `©alb` | — |
| `genre` | Genre | `GENRE` | `TCON` | `©gen`, `gnre` | multi |
| `work` | Work | `WORK` | `TXXX:WORK` | `----:com.apple.iTunes:WORK` | — |
| `movement` | Movement | `MOVEMENT`, `MOVEMENTNAME` | `MVNM` | `----:com.apple.iTunes:MOVEMENT` | — |
| `discSubtitle` | Disc Subtitle | `DISCSUBTITLE` | `TSST` | `----:com.apple.iTunes:DISCSUBTITLE` | — |
| `subtitle` | Subtitle | `SUBTITLE` | `TIT3` | `----:com.apple.iTunes:SUBTITLE` | — |
| `grouping` | Grouping | `GROUPING` | `TIT1` | `©grp` | multi |
| `mood` | Mood | `MOOD` | `TMOO` | `----:com.apple.iTunes:MOOD` | multi |
| `language` | Language | `LANGUAGE` | `TLAN` | `----:com.apple.iTunes:LANGUAGE` | multi |
| `musicalKey` | Musical Key | `INITIALKEY`, `KEY` | `TKEY` | `----:com.apple.iTunes:INITIALKEY` | — |

### Numbering

| Key | Display name | PropertyMap keys | ID3v2 | MP4 | Flags |
| --- | --- | --- | --- | --- | --- |
| `track` | Track Number | `TRACKNUMBER`, `TRACK` | `TRCK` | `trkn` | — |
| `trackTotal` | Track Total | `TRACKTOTAL`, `TOTALTRACKS` | `TRCK` | `trkn` | — |
| `disc` | Disc Number | `DISCNUMBER`, `DISC` | `TPOS` | `disk` | — |
| `discTotal` | Disc Total | `DISCTOTAL`, `TOTALDISCS` | `TPOS` | `disk` | — |
| `movementNumber` | Movement Number | `MOVEMENTNUMBER` | `MVIN` | `----:com.apple.iTunes:MOVEMENTNUMBER` | — |
| `movementCount` | Movement Count | `MOVEMENTCOUNT` | `MVIN` | `----:com.apple.iTunes:MOVEMENTCOUNT` | — |

### Dates

| Key | Display name | PropertyMap keys | ID3v2 | MP4 | Flags |
| --- | --- | --- | --- | --- | --- |
| `date` | Recording Date | `DATE`, `YEAR` | `TDRC`, `TYER` | — | — |
| `releaseDate` | Release Date | `RELEASEDATE` | `TDRL` | `©day` | — |
| `originalReleaseDate` | Original Release Date | `ORIGINALDATE`, `ORIGINAL YEAR` | `TDOR` | `----:com.apple.iTunes:ORIGINAL YEAR` | — |

### People

| Key | Display name | PropertyMap keys | ID3v2 | MP4 | Flags |
| --- | --- | --- | --- | --- | --- |
| `artist` | Artist | `ARTIST`, `ARTISTS` | `TPE1` | `©ART` | multi, people |
| `albumArtist` | Album Artist | `ALBUMARTIST`, `ALBUM ARTIST` | `TPE2` | `aART` | multi, people |
| `composer` | Composer | `COMPOSER` | `TCOM` | `©wrt` | multi, people |
| `conductor` | Conductor | `CONDUCTOR` | `TPE3` | `----:com.apple.iTunes:CONDUCTOR` | multi, people |
| `remixer` | Remixer | `REMIXER` | `TPE4` | `----:com.apple.iTunes:REMIXER` | multi, people |
| `producer` | Producer | `PRODUCER` | `TXXX:PRODUCER` | `----:com.apple.iTunes:PRODUCER` | multi, people |
| `engineer` | Engineer | `ENGINEER` | `TXXX:ENGINEER` | `----:com.apple.iTunes:ENGINEER` | multi, people |
| `lyricist` | Lyricist | `LYRICIST` | `TEXT` | `----:com.apple.iTunes:LYRICIST` | multi, people |
| `originalArtist` | Original Artist | `ORIGINALARTIST` | `TOPE` | `----:com.apple.iTunes:ORIGINALARTIST` | multi, people |

### Role-qualified people

| Key | Display name | PropertyMap keys | ID3v2 | MP4 | Flags |
| --- | --- | --- | --- | --- | --- |
| `performer` | Performer | `PERFORMER` | `TMCL` | `----:com.apple.iTunes:PERFORMER` | multi, people, role |
| `involvedPeople` | Involved People | `INVOLVEDPEOPLE` | `TIPL` | `----:com.apple.iTunes:INVOLVEDPEOPLE` | multi, people, role |
| `musicianCredits` | Musician Credits | `MUSICIANCREDITS` | `TMCL` | `----:com.apple.iTunes:MUSICIANCREDITS` | multi, people, role |

### Lyrics and comments

| Key | Display name | PropertyMap keys | ID3v2 | MP4 | Flags |
| --- | --- | --- | --- | --- | --- |
| `lyrics` | Lyrics | `LYRICS` | `USLT` | `©lyr` | — |
| `comment` | Comment | `COMMENT` | `COMM` | `©cmt` | — |

### Artwork

| Key | Display name | PropertyMap keys | ID3v2 | MP4 | Flags |
| --- | --- | --- | --- | --- | --- |
| `artwork` | Artwork | `PICTURE` | `APIC` | `covr` | artwork |

### Sorting

| Key | Display name | PropertyMap keys | ID3v2 | MP4 | Flags |
| --- | --- | --- | --- | --- | --- |
| `sortTitle` | Sort Title | `TITLESORT` | `TSOT` | `sonm` | — |
| `sortArtist` | Sort Artist | `ARTISTSORT` | `TSOP` | `soar` | — |
| `sortAlbum` | Sort Album | `ALBUMSORT` | `TSOA` | `soal` | — |
| `sortAlbumArtist` | Sort Album Artist | `ALBUMARTISTSORT` | `TSO2` | `soaa` | — |
| `sortComposer` | Sort Composer | `COMPOSERSORT` | `TSOC` | `soco` | — |

### Identifiers

| Key | Display name | PropertyMap keys | ID3v2 | MP4 | Flags |
| --- | --- | --- | --- | --- | --- |
| `isrc` | ISRC | `ISRC` | `TSRC` | `----:com.apple.iTunes:ISRC` | — |
| `barcode` | Barcode | `BARCODE`, `UPC`, `EAN` | `TXXX:BARCODE` | `----:com.apple.iTunes:BARCODE` | — |
| `asin` | ASIN | `ASIN` | `TXXX:ASIN` | `----:com.apple.iTunes:ASIN` | — |
| `musicBrainzArtistID` | MusicBrainz Artist ID | `MUSICBRAINZ_ARTISTID`, `MUSICBRAINZ ARTISTID`, `MUSICBRAINZ ARTIST ID` | `TXXX:MusicBrainz Artist Id` | `----:com.apple.iTunes:MusicBrainz Artist Id` | — |
| `musicBrainzAlbumID` | MusicBrainz Album ID | `MUSICBRAINZ_ALBUMID`, `MUSICBRAINZ ALBUMID`, `MUSICBRAINZ ALBUM ID` | `TXXX:MusicBrainz Album Id` | `----:com.apple.iTunes:MusicBrainz Album Id` | — |
| `musicBrainzAlbumArtistID` | MusicBrainz Album Artist ID | `MUSICBRAINZ_ALBUMARTISTID`, `MUSICBRAINZ ALBUMARTISTID`, `MUSICBRAINZ ALBUM ARTIST ID` | `TXXX:MusicBrainz Album Artist Id` | `----:com.apple.iTunes:MusicBrainz Album Artist Id` | — |
| `musicBrainzTrackID` | MusicBrainz Track ID | `MUSICBRAINZ_TRACKID`, `MUSICBRAINZ TRACKID`, `MUSICBRAINZ TRACK ID` | `TXXX:MusicBrainz Track Id` | `----:com.apple.iTunes:MusicBrainz Track Id` | — |
| `musicBrainzReleaseGroupID` | MusicBrainz Release Group ID | `MUSICBRAINZ_RELEASEGROUPID`, `MUSICBRAINZ RELEASEGROUPID`, `MUSICBRAINZ RELEASE GROUP ID` | `TXXX:MusicBrainz Release Group Id` | `----:com.apple.iTunes:MusicBrainz Release Group Id` | — |
| `musicBrainzReleaseTrackID` | MusicBrainz Release Track ID | `MUSICBRAINZ_RELEASETRACKID`, `MUSICBRAINZ RELEASETRACKID`, `MUSICBRAINZ RELEASE TRACK ID` | `TXXX:MusicBrainz Release Track Id` | `----:com.apple.iTunes:MusicBrainz Release Track Id` | — |
| `musicBrainzWorkID` | MusicBrainz Work ID | `MUSICBRAINZ_WORKID`, `MUSICBRAINZ WORKID`, `MUSICBRAINZ WORK ID` | `TXXX:MusicBrainz Work Id` | `----:com.apple.iTunes:MusicBrainz Work Id` | — |
| `acoustID` | AcoustID | `ACOUSTID_ID`, `ACOUSTID ID` | `TXXX:Acoustid Id` | `----:com.apple.iTunes:Acoustid Id` | — |
| `acoustIDFingerprint` | AcoustID Fingerprint | `ACOUSTID_FINGERPRINT`, `ACOUSTID FINGERPRINT` | `TXXX:Acoustid Fingerprint` | `----:com.apple.iTunes:Acoustid Fingerprint` | — |
| `musicIPPUID` | MusicIP PUID | `MUSICIP_PUID`, `MUSICIP PUID` | `TXXX:MusicIP PUID` | `----:com.apple.iTunes:MusicIP PUID` | — |

### Release

| Key | Display name | PropertyMap keys | ID3v2 | MP4 | Flags |
| --- | --- | --- | --- | --- | --- |
| `publisher` | Publisher | `LABEL`, `PUBLISHER` | `TPUB` | `----:com.apple.iTunes:LABEL` | — |
| `copyright` | Copyright | `COPYRIGHT` | `TCOP` | `cprt` | — |
| `catalogNumber` | Catalog Number | `CATALOGNUMBER`, `CATALOG NUMBER`, `CATALOG` | `TXXX:CATALOGNUMBER` | `----:com.apple.iTunes:CATALOGNUMBER` | — |
| `releaseType` | Release Type | `RELEASETYPE`, `MUSICBRAINZ_ALBUMTYPE`, `MUSICBRAINZ ALBUM TYPE` | `TXXX:RELEASETYPE` | `----:com.apple.iTunes:RELEASETYPE`, `----:com.apple.iTunes:MusicBrainz Album Type` | — |
| `releaseStatus` | Release Status | `RELEASESTATUS`, `MUSICBRAINZ_ALBUMSTATUS`, `MUSICBRAINZ ALBUM STATUS` | `TXXX:RELEASESTATUS` | `----:com.apple.iTunes:RELEASESTATUS`, `----:com.apple.iTunes:MusicBrainz Album Status` | — |
| `releaseCountry` | Release Country | `RELEASECOUNTRY`, `MUSICBRAINZ_ALBUMRELEASECOUNTRY`, `MUSICBRAINZ ALBUM RELEASE COUNTRY` | `TXXX:RELEASECOUNTRY` | `----:com.apple.iTunes:MusicBrainz Album Release Country` | — |
| `mediaType` | Media Type | `MEDIATYPE`, `MEDIA`, `MEDIA TYPE` | `TMED` | `----:com.apple.iTunes:MEDIATYPE` | — |
| `compilation` | Compilation | `COMPILATION` | `TCMP` | `cpil` | — |
| `originalAlbum` | Original Album | `ORIGINALALBUM` | `TOAL` | `----:com.apple.iTunes:ORIGINALALBUM` | — |
| `artistType` | Artist Type | `MUSICBRAINZ_ARTISTTYPE`, `ARTISTTYPE`, `MUSICBRAINZ ARTIST TYPE` | `TXXX:ARTISTTYPE` | `----:com.apple.iTunes:ARTISTTYPE` | — |

### Technical

| Key | Display name | PropertyMap keys | ID3v2 | MP4 | Flags |
| --- | --- | --- | --- | --- | --- |
| `encodedBy` | Encoded By | `ENCODEDBY`, `ENCODING` | `TENC` | `©too` | — |
| `encoderSettings` | Encoder Settings | `ENCODERSETTINGS` | `TSSE` | `----:com.apple.iTunes:ENCODERSETTINGS` | — |
| `bpm` | BPM | `BPM` | `TBPM` | `tmpo` | — |
| `trackerName` | Tracker Name | `TRACKERNAME` | — | — | — |

### ReplayGain

| Key | Display name | PropertyMap keys | ID3v2 | MP4 | Flags |
| --- | --- | --- | --- | --- | --- |
| `replayGainTrackGain` | ReplayGain Track Gain | `REPLAYGAIN_TRACK_GAIN` | `TXXX:REPLAYGAIN_TRACK_GAIN` | `----:com.apple.iTunes:REPLAYGAIN_TRACK_GAIN` | — |
| `replayGainAlbumGain` | ReplayGain Album Gain | `REPLAYGAIN_ALBUM_GAIN` | `TXXX:REPLAYGAIN_ALBUM_GAIN` | `----:com.apple.iTunes:REPLAYGAIN_ALBUM_GAIN` | — |

### iTunes

| Key | Display name | PropertyMap keys | ID3v2 | MP4 | Flags |
| --- | --- | --- | --- | --- | --- |
| `explicitContent` | Explicit Content | `ITUNESADVISORY`, `ADVISORY`, `EXPLICITCONTENT`, `EXPLICIT` | `TXXX:ITUNESADVISORY` | `rtng`, `----:com.apple.iTunes:ITUNESADVISORY` | — |
| `itunesAlbumID` | iTunes Album ID | `ITUNESALBUMID` | `TXXX:ITUNESALBUMID` | `----:com.apple.iTunes:ITUNESALBUMID` | — |
| `itunesArtistID` | iTunes Artist ID | `ITUNESARTISTID` | `TXXX:ITUNESARTISTID` | `----:com.apple.iTunes:ITUNESARTISTID` | — |
| `itunesCatalogID` | iTunes Catalog ID | `ITUNESCATALOGID` | `TXXX:ITUNESCATALOGID` | `----:com.apple.iTunes:ITUNESCATALOGID` | — |
| `itunesGenreID` | iTunes Genre ID | `ITUNESGENREID` | `TXXX:ITUNESGENREID` | `----:com.apple.iTunes:ITUNESGENREID` | — |
| `itunesMediaType` | iTunes Media Type | `ITUNESMEDIATYPE` | `TXXX:ITUNESMEDIATYPE` | `----:com.apple.iTunes:ITUNESMEDIATYPE` | — |
| `itunesPurchaseDate` | iTunes Purchase Date | `ITUNESPURCHASEDATE` | `TXXX:ITUNESPURCHASEDATE` | `----:com.apple.iTunes:ITUNESPURCHASEDATE` | — |
| `itunesNorm` | iTunNORM | `ITUNNORM` | `TXXX:ITUNNORM` | `----:com.apple.iTunes:ITUNNORM` | — |
| `itunesSMPB` | iTunSMPB | `ITUNSMPB` | `TXXX:ITUNSMPB` | `----:com.apple.iTunes:ITUNSMPB` | — |

### Custom

| Key | Display name | PropertyMap keys | ID3v2 | MP4 | Flags |
| --- | --- | --- | --- | --- | --- |
| `custom` | Custom Field | — | — | — | — |

<!-- END GENERATED FIELD TABLES -->

### Mappings outside the table

- **Artwork** is not a single native item on every format. ID3v2 uses `APIC`; MP4 uses `covr`; FLAC, Xiph, APE, and ASF use complex-property pictures (`PICTURE`, or `WM/Picture` for ASF). The `artwork` schema row lists the generic `PICTURE` PropertyMap key, not a promise that every container exposes it the same way.
- **Custom fields** have no fixed mapping. ID3v2 uses `TXXX:<description>`, MP4 uses `----:com.apple.iTunes:<description>`, and generic containers use the caller's prefixless key. Schema-known names are rejected in `MetadataPatch.customFields` so one semantic field cannot be written through two representations.
- **Qualified comments and lyrics** (`COMMENT:<description>`, `LYRICS:<description>`) are recognized by `schema(forPropertyMapKey:)` and resolve to the scalar `.comment` or `.lyrics` schema. The bridge may also expose language-qualified forms in structured metadata.
- **Shared keys.** `sharedPropertyMapKeyOwners` and `preferredSharedPropertyMapKeyOwner` are currently empty because the registry has no intentionally shared scalar keys. The lookup code still supports them if a future schema introduces one.

## Typed-patch value contract

`MetadataFieldSchema.acceptedPatchValueKinds` is the validation table for `MetadataPatch`. It is derived from the field key and the multi-value flag, not stored separately in every schema literal.

| Field group | Accepted `MetadataPatchValue` kinds | Numeric range |
| --- | --- | --- |
| `track`, `trackTotal`, `disc`, `discTotal` | `.integer` | `1...Int32.max` |
| `movementNumber`, `movementCount`, `bpm` | `.integer` | `0...Int32.max` |
| `compilation` | `.boolean` | — |
| `artwork`, `explicitContent`, `custom` | none; use the dedicated patch property | — |
| Multi-value schema fields | `.text`, `.values` | — |
| Other scalar schema fields | `.text` | — |

`MetadataPatchValue.remove` is accepted for every typed field that passes the kind and range checks; it is the explicit unset form and is not represented by an empty string or empty array. Role-qualified fields (`performer`, `involvedPeople`, `musicianCredits`) are rejected by the typed patch API even though they have schemas, because their keys carry a role suffix. Use `RawMetadataPatch` or `StructuredMetadata` for those.

Bridge number-text parsing uses the same `Int32.max` upper bound, and structured MP4/ASF value validation enforces the declared native widths. Direct model writes do not run the typed-patch validator; use the facade or validate your values before calling the bridge.

## Lookup and ownership rules

`MetadataFieldRegistry` builds `propertyMapKeyOwners` by normalizing every schema's `propertyMapKeys`. Most keys have exactly one owner. When a key has multiple owners, `schema(forPropertyMapKey:)` returns the schema named by `preferredSharedPropertyMapKeyOwner`; if there is no preferred owner, it returns `nil` rather than guessing.

The lookup recognizes these qualified prefixes before the general owner table:

| Prefix | Owning schema |
| --- | --- |
| `PERFORMER:` | `.performer` |
| `INVOLVEDPEOPLE:` | `.involvedPeople` |
| `MUSICIANCREDITS:` | `.musicianCredits` |
| `COMMENT:` | `.comment` |
| `LYRICS:` | `.lyrics` |

`normalizePropertyMapKey` trims whitespace and uppercases but does not remove a prefix. `schema(forHighLevelCustomKey:)` is internal; it strips `----:com.apple.iTunes:` or `TXXX:` before resolving a custom key, which is how the typed patch rejects a custom key that is really a schema-known field.

## Cross-language parity

The Objective-C++ bridge has its own ordered mapping table exposed by `TagLibMetadataExtractor.metadataFieldMappings()` and `knownMetadataPropertyKeys()`. Tests in `Tests/TagLibAudioMetadataTests/Capabilities/FormatCapabilityTests.swift` check that:

- every public `MetadataFieldKey` has exactly one schema;
- every schema property key is known to the bridge, after excluding the four hidden internal formatting keys;
- bridge canonical/alias keys map to exactly one Swift schema owner;
- ID3v2 frames, user-text descriptions, MP4 items/freeforms, and multi-value/people/role flags agree across the boundary;
- no two schemas own the same key unless both shared-owner maps declare it.

The Swift registry is the public semantic source. If the two tables disagree, the tests fail; do not "fix" the documentation by describing the bridge table as authoritative.

## Related references

- [Formats](FORMATS.md) — capability and container evidence.
- [Write semantics](PRESERVATION.md) — omission, replacement, and verification.
- [API reference](API_REFERENCE.md) — `MetadataFieldKey`, `MetadataPatch`, and registry signatures.
- [Bridge reference](BRIDGE.md) — raw mapping dictionaries and the low-level model.
