# Metadata field schema

This is the canonical reference for the public metadata field registry. It describes `MetadataFieldKey`, `MetadataFieldSchema`, and `MetadataFieldRegistry` in `Sources/TagLibAudioMetadata/MetadataFieldSchema.swift`. The Swift declarations and the generated tables below are checked against each other by `scripts/check-docs.py`.

The package-side target is `AM-TLAM-MAPPING-2.2`; its per-section implementation status is in the [Metadata mapping specification](METADATA_MAPPING_SPEC.md#13-implementation-status). The tables below are generated from the current Swift registry and the generated native catalog.

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
| `schemas(storableIn:)` | Returns `[]` for read-only capabilities; otherwise enumerates canonical semantic owners and filters by native target capability, explicit `writableFields` allowlist, and artwork support. `.date` remains addressable but is not a second canonical field. |
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
<!-- Generated from `MetadataFieldSchema.swift`. 101 fields. -->

### Basic and descriptive

| Key | Display name | Semantic key | PropertyMap keys | ID3v2.3 | ID3v2.4 | MP4 | Vorbis | APE | ASF | RIFF | Flags |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `title` | Title | `TITLE` | `TITLE` | `TIT2` | `TIT2` | `©nam` | `TITLE` | `TITLE` | `Title` | `INAM` | — |
| `album` | Album | `ALBUM` | `ALBUM` | `TALB` | `TALB` | `©alb` | `ALBUM` | `ALBUM` | `WM/AlbumTitle` | `IPRD` | — |
| `genre` | Genre | `GENRE` | `GENRE` | `TCON` | `TCON` | `©gen` | `GENRE` | `GENRE` | `WM/Genre` | `IGNR` | multi |
| `work` | Work | `WORK` | `WORK` | `WORK` | `WORK` | `©wrk` | `WORK` | `WORK` | — | — | — |
| `movement` | Movement | `MOVEMENTNAME` | `MOVEMENT`, `MOVEMENTNAME` | `MVNM` | `MVNM` | `©mvn` | `MOVEMENTNAME` | `MOVEMENTNAME` | — | — | — |
| `discSubtitle` | Disc Subtitle | `DISCSUBTITLE` | `DISCSUBTITLE` | `DISCSUBTITLE` | `TSST` | `----:com.apple.iTunes:DISCSUBTITLE` | `DISCSUBTITLE` | `DISCSUBTITLE` | `WM/SetSubTitle` | — | — |
| `subtitle` | Subtitle | `SUBTITLE` | `SUBTITLE` | `TIT3` | `TIT3` | `----:com.apple.iTunes:SUBTITLE` | `SUBTITLE` | `SUBTITLE` | `WM/SubTitle` | — | — |
| `grouping` | Grouping | `GROUPING` | `GROUPING` | `GRP1` | `GRP1` | `----:com.apple.iTunes:GROUPING` | `GROUPING` | `GROUPING` | — | — | multi |
| `contentGroup` | Content Group | `CONTENTGROUP` | `CONTENTGROUP` | `TIT1` | `TIT1` | `©grp` | `CONTENTGROUP` | `CONTENTGROUP` | `WM/ContentGroupDescription` | — | — |
| `mood` | Mood | `MOOD` | `MOOD` | `MOOD` | `TMOO` | `----:com.apple.iTunes:MOOD` | `MOOD` | `MOOD` | `WM/Mood` | — | multi |
| `language` | Language | `LANGUAGE` | `LANGUAGE` | `TLAN` | `TLAN` | `----:com.apple.iTunes:LANGUAGE` | `LANGUAGE` | `LANGUAGE` | `WM/Language` | `ILNG` | multi |
| `musicalKey` | Musical Key | `INITIALKEY` | `INITIALKEY`, `KEY` | `TKEY` | `TKEY` | `----:com.apple.iTunes:INITIALKEY` | `INITIALKEY` | `INITIALKEY` | `WM/InitialKey` | — | — |

### Numbering

| Key | Display name | Semantic key | PropertyMap keys | ID3v2.3 | ID3v2.4 | MP4 | Vorbis | APE | ASF | RIFF | Flags |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `track` | Track Number | `TRACKNUMBER` | `TRACKNUMBER`, `TRACK` | `TRCK (number)` | `TRCK (number)` | `trkn (number)` | `TRACKNUMBER` | `TRACK` | `WM/TrackNumber (number)` | `ITRK` | — |
| `trackTotal` | Track Total | `TRACKTOTAL` | `TRACKTOTAL`, `TOTALTRACKS` | `TRCK (total)` | `TRCK (total)` | `trkn (total)` | `TRACKTOTAL` | `TRACKTOTAL` | `WM/TrackNumber (total)` | — | — |
| `disc` | Disc Number | `DISCNUMBER` | `DISCNUMBER`, `DISC` | `TPOS (number)` | `TPOS (number)` | `disk (number)` | `DISCNUMBER` | `DISC` | `WM/PartOfSet (number)` | — | — |
| `discTotal` | Disc Total | `DISCTOTAL` | `DISCTOTAL`, `TOTALDISCS` | `TPOS (total)` | `TPOS (total)` | `disk (total)` | `DISCTOTAL` | `DISCTOTAL` | `WM/PartOfSet (total)` | — | — |
| `movementNumber` | Movement Number | `MOVEMENTNUMBER` | `MOVEMENTNUMBER` | `MVIN (number)` | `MVIN (number)` | `©mvi` | `MOVEMENTNUMBER` | `MOVEMENTNUMBER` | — | — | — |
| `movementCount` | Movement Count | `MOVEMENTCOUNT` | `MOVEMENTCOUNT` | `MVIN (total)` | `MVIN (total)` | `©mvc` | `MOVEMENTCOUNT` | `MOVEMENTCOUNT` | — | — | — |

### Dates

| Key | Display name | Semantic key | PropertyMap keys | ID3v2.3 | ID3v2.4 | MP4 | Vorbis | APE | ASF | RIFF | Flags |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `date` | Recording Date (legacy YEAR spelling) | `YEAR` | `DATE`, `YEAR` | `TYER` | `TDRC` | `©day` | `YEAR` | `YEAR` | `WM/Year` | `ICRD` | — |
| `year` | Year | `YEAR` | `YEAR`, `DATE` | `TYER` | `TDRC` | `©day` | `YEAR` | `YEAR` | `WM/Year` | `ICRD` | — |
| `standaloneDate` | Date | `DATE` | `STANDALONEDATE` | `TDAT` | `DATE` | `----:com.apple.iTunes:DATE` | `DATE` | `DATE` | `DATE` | — | — |
| `releaseDate` | Release Date | `RELEASEDATE` | `RELEASEDATE` | `TDRL` | `TDRL` | `----:com.apple.iTunes:RELEASEDATE` | `RELEASEDATE` | `RELEASEDATE` | — | — | — |
| `originalReleaseDate` | Original Release Date | `ORIGINALDATE` | `ORIGINALDATE`, `ORIGINAL YEAR` | `TORY (year only)` | `TDOR` | `----:com.apple.iTunes:ORIGINALDATE` | `ORIGINALDATE` | `ORIGINALDATE` | `WM/OriginalReleaseYear` | — | — |

### People

| Key | Display name | Semantic key | PropertyMap keys | ID3v2.3 | ID3v2.4 | MP4 | Vorbis | APE | ASF | RIFF | Flags |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `artist` | Artist | `ARTIST` | `ARTIST` | `TPE1` | `TPE1` | `©ART` | `ARTIST` | `ARTIST` | `Author` | `IART` | multi, people |
| `albumArtist` | Album Artist | `ALBUMARTIST` | `ALBUMARTIST`, `ALBUM ARTIST` | `TPE2` | `TPE2` | `aART` | `ALBUMARTIST` | `ALBUM ARTIST` | `WM/AlbumArtist` | — | multi, people |
| `composer` | Composer | `COMPOSER` | `COMPOSER` | `TCOM` | `TCOM` | `©wrt` | `COMPOSER` | `COMPOSER` | `WM/Composer` | `IMUS` | multi, people |
| `conductor` | Conductor | `CONDUCTOR` | `CONDUCTOR` | `TPE3` | `TPE3` | `©con` | `CONDUCTOR` | `CONDUCTOR` | `WM/Conductor` | — | multi, people |
| `remixer` | Remixer | `REMIXER` | `REMIXER` | `TPE4` | `TPE4` | `----:com.apple.iTunes:REMIXER` | `REMIXER` | `MIXARTIST` | `WM/ModifiedBy` | — | multi, people |
| `producer` | Producer | `PRODUCER` | `PRODUCER` | `PRODUCER` | `PRODUCER` | `----:com.apple.iTunes:PRODUCER` | `PRODUCER` | `PRODUCER` | `WM/Producer` | — | multi, people |
| `engineer` | Engineer | `ENGINEER` | `ENGINEER` | `ENGINEER` | `ENGINEER` | `----:com.apple.iTunes:ENGINEER` | `ENGINEER` | `ENGINEER` | — | — | multi, people |
| `lyricist` | Lyricist | `LYRICIST` | `LYRICIST` | `TEXT` | `TEXT` | `----:com.apple.iTunes:LYRICIST` | `LYRICIST` | `LYRICIST` | `WM/Writer` | — | multi, people |
| `artists` | Artists | `ARTISTS` | `ARTISTS` | `ARTISTS` | `ARTISTS` | `----:com.apple.iTunes:ARTISTS` | `ARTISTS` | `ARTISTS` | `WM/ARTISTS` | — | multi, people |
| `originalArtist` | Original Artist | `ORIGINALARTIST` | `ORIGINALARTIST` | `TOPE` | `TOPE` | `----:com.apple.iTunes:ORIGINALARTIST` | `ORIGINALARTIST` | `ORIGINALARTIST` | `WM/OriginalArtist` | — | multi, people |
| `director` | Director | `DIRECTOR` | `DIRECTOR` | — | — | `©dir` | — | — | — | — | multi, people |

### Role-qualified people

| Key | Display name | Semantic key | PropertyMap keys | ID3v2.3 | ID3v2.4 | MP4 | Vorbis | APE | ASF | RIFF | Flags |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `performer` | Performer | `PERFORMER` | `PERFORMER` | `IPLS` | `TMCL` | `----:com.apple.iTunes:PERFORMER` | `PERFORMER` | `PERFORMER` | — | — | multi, people, role |
| `involvedPeople` | Involved People | `INVOLVEDPEOPLE` | `INVOLVEDPEOPLE` | `IPLS` | `TIPL` | `----:com.apple.iTunes:INVOLVEDPEOPLE` | `INVOLVEDPEOPLE` | `INVOLVEDPEOPLE` | — | — | multi, people, role |
| `musicianCredits` | Musician Credits | `MUSICIANCREDITS` | `MUSICIANCREDITS` | `IPLS` | `TMCL` | `----:com.apple.iTunes:MUSICIANCREDITS` | `MUSICIANCREDITS` | `MUSICIANCREDITS` | — | — | multi, people, role |

### Lyrics and comments

| Key | Display name | Semantic key | PropertyMap keys | ID3v2.3 | ID3v2.4 | MP4 | Vorbis | APE | ASF | RIFF | Flags |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `lyrics` | Lyrics | `LYRICS` | `LYRICS` | `USLT` | `USLT` | `©lyr` | `LYRICS` | `LYRICS` | `WM/Lyrics` | — | — |
| `comment` | Comment | `COMMENT` | `COMMENT` | `COMM` | `COMM` | `©cmt` | `COMMENT` | `COMMENT` | `Description` | `ICMT` | — |

### Artwork

| Key | Display name | Semantic key | PropertyMap keys | ID3v2.3 | ID3v2.4 | MP4 | Vorbis | APE | ASF | RIFF | Flags |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `artwork` | Artwork | `PICTURE` | `PICTURE` | `APIC` | `APIC` | `covr` | `PICTURE` | `COVER ART` | `WM/Picture` | — | artwork |

### Sorting

| Key | Display name | Semantic key | PropertyMap keys | ID3v2.3 | ID3v2.4 | MP4 | Vorbis | APE | ASF | RIFF | Flags |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `sortTitle` | Sort Title | `TITLESORT` | `TITLESORT` | `TSOT` | `TSOT` | `sonm` | `TITLESORT` | `TITLESORT` | `WM/TitleSortOrder` | — | — |
| `sortArtist` | Sort Artist | `ARTISTSORT` | `ARTISTSORT` | `TSOP` | `TSOP` | `soar` | `ARTISTSORT` | `ARTISTSORT` | `WM/ArtistSortOrder` | — | — |
| `sortAlbum` | Sort Album | `ALBUMSORT` | `ALBUMSORT` | `TSOA` | `TSOA` | `soal` | `ALBUMSORT` | `ALBUMSORT` | `WM/AlbumSortOrder` | — | — |
| `sortAlbumArtist` | Sort Album Artist | `ALBUMARTISTSORT` | `ALBUMARTISTSORT` | `TSO2` | `TSO2` | `soaa` | `ALBUMARTISTSORT` | `ALBUMARTISTSORT` | `WM/AlbumArtistSortOrder` | — | — |
| `sortComposer` | Sort Composer | `COMPOSERSORT` | `COMPOSERSORT` | `TSOC` | `TSOC` | `soco` | `COMPOSERSORT` | `COMPOSERSORT` | — | — | — |

### Identifiers

| Key | Display name | Semantic key | PropertyMap keys | ID3v2.3 | ID3v2.4 | MP4 | Vorbis | APE | ASF | RIFF | Flags |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `isrc` | ISRC | `ISRC` | `ISRC` | `TSRC` | `TSRC` | `----:com.apple.iTunes:ISRC` | `ISRC` | `ISRC` | `WM/ISRC` | — | — |
| `barcode` | Barcode | `BARCODE` | `BARCODE`, `UPC`, `EAN` | `BARCODE` | `BARCODE` | `----:com.apple.iTunes:BARCODE` | `BARCODE` | `BARCODE` | `WM/Barcode` | — | — |
| `asin` | ASIN | `ASIN` | `ASIN` | `ASIN` | `ASIN` | `----:com.apple.iTunes:ASIN` | `ASIN` | `ASIN` | — | — | — |
| `musicBrainzArtistID` | MusicBrainz Artist ID | `MUSICBRAINZ_ARTISTID` | `MUSICBRAINZ_ARTISTID`, `MUSICBRAINZ ARTISTID`, `MUSICBRAINZ ARTIST ID` | `MusicBrainz Artist Id` | `MusicBrainz Artist Id` | `----:com.apple.iTunes:MusicBrainz Artist Id` | `MUSICBRAINZ_ARTISTID` | `MUSICBRAINZ_ARTISTID` | `MusicBrainz/Artist Id` | — | — |
| `musicBrainzAlbumID` | MusicBrainz Album ID | `MUSICBRAINZ_ALBUMID` | `MUSICBRAINZ_ALBUMID`, `MUSICBRAINZ ALBUMID`, `MUSICBRAINZ ALBUM ID` | `MusicBrainz Album Id` | `MusicBrainz Album Id` | `----:com.apple.iTunes:MusicBrainz Album Id` | `MUSICBRAINZ_ALBUMID` | `MUSICBRAINZ_ALBUMID` | `MusicBrainz/Album Id` | — | — |
| `musicBrainzAlbumArtistID` | MusicBrainz Album Artist ID | `MUSICBRAINZ_ALBUMARTISTID` | `MUSICBRAINZ_ALBUMARTISTID`, `MUSICBRAINZ ALBUMARTISTID`, `MUSICBRAINZ ALBUM ARTIST ID` | `MusicBrainz Album Artist Id` | `MusicBrainz Album Artist Id` | `----:com.apple.iTunes:MusicBrainz Album Artist Id` | `MUSICBRAINZ_ALBUMARTISTID` | `MUSICBRAINZ_ALBUMARTISTID` | `MusicBrainz/Album Artist Id` | — | — |
| `musicBrainzTrackID` | MusicBrainz Track ID | `MUSICBRAINZ_TRACKID` | `MUSICBRAINZ_TRACKID`, `MUSICBRAINZ TRACKID`, `MUSICBRAINZ TRACK ID` | `http://musicbrainz.org` | `http://musicbrainz.org` | `----:com.apple.iTunes:MusicBrainz Track Id` | `MUSICBRAINZ_TRACKID` | `MUSICBRAINZ_TRACKID` | `MusicBrainz/Track Id` | — | — |
| `musicBrainzReleaseGroupID` | MusicBrainz Release Group ID | `MUSICBRAINZ_RELEASEGROUPID` | `MUSICBRAINZ_RELEASEGROUPID`, `MUSICBRAINZ RELEASEGROUPID`, `MUSICBRAINZ RELEASE GROUP ID` | `MusicBrainz Release Group Id` | `MusicBrainz Release Group Id` | `----:com.apple.iTunes:MusicBrainz Release Group Id` | `MUSICBRAINZ_RELEASEGROUPID` | `MUSICBRAINZ_RELEASEGROUPID` | `MusicBrainz/Release Group Id` | — | — |
| `musicBrainzReleaseTrackID` | MusicBrainz Release Track ID | `MUSICBRAINZ_RELEASETRACKID` | `MUSICBRAINZ_RELEASETRACKID`, `MUSICBRAINZ RELEASETRACKID`, `MUSICBRAINZ RELEASE TRACK ID` | `MusicBrainz Release Track Id` | `MusicBrainz Release Track Id` | `----:com.apple.iTunes:MusicBrainz Release Track Id` | `MUSICBRAINZ_RELEASETRACKID` | `MUSICBRAINZ_RELEASETRACKID` | `MusicBrainz/Release Track Id` | — | — |
| `musicBrainzWorkID` | MusicBrainz Work ID | `MUSICBRAINZ_WORKID` | `MUSICBRAINZ_WORKID`, `MUSICBRAINZ WORKID`, `MUSICBRAINZ WORK ID` | `MusicBrainz Work Id` | `MusicBrainz Work Id` | `----:com.apple.iTunes:MusicBrainz Work Id` | `MUSICBRAINZ_WORKID` | `MUSICBRAINZ_WORKID` | `MusicBrainz/Work Id` | — | — |
| `acoustID` | AcoustID | `ACOUSTID_ID` | `ACOUSTID_ID`, `ACOUSTID ID` | `Acoustid Id` | `Acoustid Id` | `----:com.apple.iTunes:Acoustid Id` | `ACOUSTID_ID` | `ACOUSTID_ID` | `Acoustid/Id` | — | — |
| `acoustIDFingerprint` | AcoustID Fingerprint | `ACOUSTID_FINGERPRINT` | `ACOUSTID_FINGERPRINT`, `ACOUSTID FINGERPRINT` | `Acoustid Fingerprint` | `Acoustid Fingerprint` | `----:com.apple.iTunes:Acoustid Fingerprint` | `ACOUSTID_FINGERPRINT` | `ACOUSTID_FINGERPRINT` | `Acoustid/Fingerprint` | — | — |
| `musicIPPUID` | MusicIP PUID | `MUSICIP_PUID` | `MUSICIP_PUID`, `MUSICIP PUID` | `MusicIP PUID` | `MusicIP PUID` | `----:com.apple.iTunes:MusicIP PUID` | `MUSICIP_PUID` | `MUSICIP_PUID` | `MusicIP/PUID` | — | — |

### Release

| Key | Display name | Semantic key | PropertyMap keys | ID3v2.3 | ID3v2.4 | MP4 | Vorbis | APE | ASF | RIFF | Flags |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `publisher` | Publisher | `LABEL` | `LABEL`, `PUBLISHER` | `TPUB` | `TPUB` | `©pub` | `LABEL` | `LABEL` | `WM/Publisher` | — | — |
| `copyright` | Copyright | `COPYRIGHT` | `COPYRIGHT` | `TCOP` | `TCOP` | `cprt` | `COPYRIGHT` | `COPYRIGHT` | `Copyright` | `ICOP` | — |
| `catalogNumber` | Catalog Number | `CATALOGNUMBER` | `CATALOGNUMBER`, `CATALOG NUMBER`, `CATALOG` | `CATALOGNUMBER` | `CATALOGNUMBER` | `----:com.apple.iTunes:CATALOGNUMBER` | `CATALOGNUMBER` | `CATALOGNUMBER` | `WM/CatalogNo` | — | — |
| `releaseType` | Release Type | `RELEASETYPE` | `RELEASETYPE`, `MUSICBRAINZ_ALBUMTYPE`, `MUSICBRAINZ ALBUM TYPE` | `MusicBrainz Album Type` | `MusicBrainz Album Type` | `----:com.apple.iTunes:MusicBrainz Album Type` | `RELEASETYPE` | `MUSICBRAINZ_ALBUMTYPE` | `MusicBrainz/Album Type` | — | — |
| `releaseStatus` | Release Status | `RELEASESTATUS` | `RELEASESTATUS`, `MUSICBRAINZ_ALBUMSTATUS`, `MUSICBRAINZ ALBUM STATUS` | `MusicBrainz Album Status` | `MusicBrainz Album Status` | `----:com.apple.iTunes:MusicBrainz Album Status` | `RELEASESTATUS` | `MUSICBRAINZ_ALBUMSTATUS` | `MusicBrainz/Album Status` | — | — |
| `releaseCountry` | Release Country | `RELEASECOUNTRY` | `RELEASECOUNTRY`, `MUSICBRAINZ_ALBUMRELEASECOUNTRY`, `MUSICBRAINZ ALBUM RELEASE COUNTRY` | `MusicBrainz Album Release Country` | `MusicBrainz Album Release Country` | `----:com.apple.iTunes:MusicBrainz Album Release Country` | `RELEASECOUNTRY` | `RELEASECOUNTRY` | `MusicBrainz/Album Release Country` | — | — |
| `mediaType` | Media Type | `MEDIA` | `MEDIATYPE`, `MEDIA`, `MEDIA TYPE` | `TMED` | `TMED` | `----:com.apple.iTunes:MEDIA` | `MEDIA` | `MEDIA` | `WM/Media` | — | — |
| `compilation` | Compilation | `COMPILATION` | `COMPILATION` | `TCMP` | `TCMP` | `cpil` | `COMPILATION` | `COMPILATION` | — | — | — |
| `originalAlbum` | Original Album | `ORIGINALALBUM` | `ORIGINALALBUM` | `TOAL` | `TOAL` | `----:com.apple.iTunes:ORIGINALALBUM` | `ORIGINALALBUM` | `ORIGINALALBUM` | `WM/OriginalAlbumTitle` | — | — |
| `artistType` | Artist Type | `MUSICBRAINZ_ARTISTTYPE` | `MUSICBRAINZ_ARTISTTYPE`, `ARTISTTYPE`, `MUSICBRAINZ ARTIST TYPE` | `MusicBrainz Artist Type` | `MusicBrainz Artist Type` | `----:com.apple.iTunes:MusicBrainz Artist Type` | `MUSICBRAINZ_ARTISTTYPE` | `MUSICBRAINZ_ARTISTTYPE` | — | — | — |

### Technical

| Key | Display name | Semantic key | PropertyMap keys | ID3v2.3 | ID3v2.4 | MP4 | Vorbis | APE | ASF | RIFF | Flags |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `encodedBy` | Encoded By | `ENCODEDBY` | `ENCODEDBY`, `ENCODING` | `TENC` | `TENC` | `©enc` | `ENCODEDBY` | `ENCODEDBY` | `WM/EncodedBy` | — | — |
| `encoderSettings` | Encoder Settings | `ENCODING` | `ENCODERSETTINGS` | `TSSE` | `TSSE` | `©too` | `ENCODING` | `ENCODING` | `WM/EncodingSettings` | — | — |
| `bpm` | BPM | `BPM` | `BPM` | `TBPM` | `TBPM` | `tmpo` | `BPM` | `BPM` | `WM/BeatsPerMinute` | — | — |
| `trackerName` | Tracker Name | `TRACKERNAME` | `TRACKERNAME` | — | — | — | — | — | — | — | — |

### ReplayGain

| Key | Display name | Semantic key | PropertyMap keys | ID3v2.3 | ID3v2.4 | MP4 | Vorbis | APE | ASF | RIFF | Flags |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `replayGainTrackGain` | ReplayGain Track Gain | `REPLAYGAIN_TRACK_GAIN` | `REPLAYGAIN_TRACK_GAIN` | `REPLAYGAIN_TRACK_GAIN` | `REPLAYGAIN_TRACK_GAIN` | `----:com.apple.iTunes:REPLAYGAIN_TRACK_GAIN` | `REPLAYGAIN_TRACK_GAIN` | `REPLAYGAIN_TRACK_GAIN` | — | — | — |
| `replayGainAlbumGain` | ReplayGain Album Gain | `REPLAYGAIN_ALBUM_GAIN` | `REPLAYGAIN_ALBUM_GAIN` | `REPLAYGAIN_ALBUM_GAIN` | `REPLAYGAIN_ALBUM_GAIN` | `----:com.apple.iTunes:REPLAYGAIN_ALBUM_GAIN` | `REPLAYGAIN_ALBUM_GAIN` | `REPLAYGAIN_ALBUM_GAIN` | — | — | — |
| `replayGainTrackPeak` | ReplayGain Track Peak | `REPLAYGAIN_TRACK_PEAK` | `REPLAYGAIN_TRACK_PEAK` | `REPLAYGAIN_TRACK_PEAK` | `REPLAYGAIN_TRACK_PEAK` | `----:com.apple.iTunes:REPLAYGAIN_TRACK_PEAK` | `REPLAYGAIN_TRACK_PEAK` | `REPLAYGAIN_TRACK_PEAK` | — | — | — |
| `replayGainAlbumPeak` | ReplayGain Album Peak | `REPLAYGAIN_ALBUM_PEAK` | `REPLAYGAIN_ALBUM_PEAK` | `REPLAYGAIN_ALBUM_PEAK` | `REPLAYGAIN_ALBUM_PEAK` | `----:com.apple.iTunes:REPLAYGAIN_ALBUM_PEAK` | `REPLAYGAIN_ALBUM_PEAK` | `REPLAYGAIN_ALBUM_PEAK` | — | — | — |

### iTunes

| Key | Display name | Semantic key | PropertyMap keys | ID3v2.3 | ID3v2.4 | MP4 | Vorbis | APE | ASF | RIFF | Flags |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `explicitContent` | Explicit Content | `ITUNESADVISORY` | `ITUNESADVISORY`, `ADVISORY`, `EXPLICITCONTENT`, `EXPLICIT` | `ITUNESADVISORY` | `ITUNESADVISORY` | `rtng` | `ITUNESADVISORY` | `ITUNESADVISORY` | — | — | — |
| `itunesAlbumID` | iTunes Album ID | `ITUNESALBUMID` | `ITUNESALBUMID` | `ITUNESALBUMID` | `ITUNESALBUMID` | `plID` | `ITUNESALBUMID` | `ITUNESALBUMID` | — | — | — |
| `itunesArtistID` | iTunes Artist ID | `ITUNESARTISTID` | `ITUNESARTISTID` | `ITUNESARTISTID` | `ITUNESARTISTID` | `atID` | `ITUNESARTISTID` | `ITUNESARTISTID` | — | — | — |
| `itunesCatalogID` | iTunes Catalog ID | `ITUNESCATALOGID` | `ITUNESCATALOGID` | `ITUNESCATALOGID` | `ITUNESCATALOGID` | `cnID` | `ITUNESCATALOGID` | `ITUNESCATALOGID` | — | — | — |
| `itunesGenreID` | iTunes Genre ID | `ITUNESGENREID` | `ITUNESGENREID` | `ITUNESGENREID` | `ITUNESGENREID` | `geID` | `ITUNESGENREID` | `ITUNESGENREID` | — | — | — |
| `itunesMediaType` | iTunes Media Type | `ITUNESMEDIATYPE` | `ITUNESMEDIATYPE` | `ITUNESMEDIATYPE` | `ITUNESMEDIATYPE` | `stik` | `ITUNESMEDIATYPE` | `ITUNESMEDIATYPE` | — | — | — |
| `itunesPurchaseDate` | iTunes Purchase Date | `ITUNESPURCHASEDATE` | `ITUNESPURCHASEDATE` | `ITUNESPURCHASEDATE` | `ITUNESPURCHASEDATE` | `purd` | `ITUNESPURCHASEDATE` | `ITUNESPURCHASEDATE` | — | — | — |
| `itunesNorm` | iTunNORM | `ITUNNORM` | `ITUNNORM` | `iTunNORM` | `iTunNORM` | `----:com.apple.iTunes:iTunNORM` | `ITUNNORM` | `ITUNNORM` | — | — | — |
| `itunesSMPB` | iTunSMPB | `ITUNSMPB` | `ITUNSMPB` | `iTunSMPB` | `iTunSMPB` | `----:com.apple.iTunes:iTunSMPB` | `ITUNSMPB` | `ITUNSMPB` | — | — | — |
| `itunesAccount` | iTunes Account | `ITUNESACCOUNT` | `ITUNESACCOUNT` | — | — | `apID` | — | — | — | — | — |
| `itunesComposerID` | iTunes Composer ID | `ITUNESCOMPOSERID` | `ITUNESCOMPOSERID` | — | — | `cmID` | — | — | — | — | — |
| `itunesCountryID` | iTunes Storefront ID | `ITUNESCOUNTRYID` | `ITUNESCOUNTRYID` | — | — | `sfID` | — | — | — | — | — |
| `itunesGapless` | Gapless Playback | `ITUNESGAPLESS` | `ITUNESGAPLESS`, `GAPLESSPLAYBACK` | — | — | `pgap` | — | — | — | — | — |
| `itunesHDVideo` | HD Video | `ITUNESHDVIDEO` | `ITUNESHDVIDEO`, `HDVIDEO` | — | — | `hdvd` | — | — | — | — | — |
| `itunesOwner` | Owner | `OWNER` | `ITUNESOWNER`, `OWNER` | — | — | `ownr` | — | — | — | — | — |
| `rate` | Rating | `RATE` | `RATE` | — | — | `rate` | — | — | — | — | — |
| `showMovement` | Show Work and Movement | `SHOWMOVEMENT` | `SHOWMOVEMENT`, `SHOWWORKMOVEMENT` | — | — | `shwm` | — | — | — | — | — |
| `storeDescription` | Store Description | `STOREDESCRIPTION` | `STOREDESCRIPTION` | — | — | `sdes` | — | — | — | — | — |
| `tvEpisode` | TV Episode | `TVEPISODE` | `TVEPISODE` | — | — | `tves` | — | — | — | — | — |
| `tvEpisodeID` | TV Episode ID | `TVEPISODEID` | `TVEPISODEID` | — | — | `tven` | — | — | — | — | — |
| `tvNetwork` | TV Network | `TVNETWORK` | `TVNETWORK` | — | — | `tvnn` | — | — | — | — | — |
| `tvSeason` | TV Season | `TVSEASON` | `TVSEASON` | — | — | `tvsn` | — | — | — | — | — |
| `tvShow` | TV Show | `TVSHOW` | `TVSHOW` | — | — | `tvsh` | — | — | — | — | — |
| `tvShowSort` | TV Show Sort | `SHOWSORT` | `TVSHOWSORT`, `SHOWSORT` | — | — | `sosn` | — | — | — | — | — |

### Custom

| Key | Display name | Semantic key | PropertyMap keys | ID3v2.3 | ID3v2.4 | MP4 | Vorbis | APE | ASF | RIFF | Flags |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `custom` | Custom Field | `<explicit key>` | — | `<description>` | `<description>` | `----:com.apple.iTunes:<description>` | `<explicit key>` | `<explicit key>` | — | — | — |

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
