# Metadata field reference

This is the canonical reference for the public field registry: `MetadataFieldKey`, `MetadataFieldSchema`, and `MetadataFieldRegistry` in `Sources/TagLibAudioMetadata/MetadataFieldSchema.swift`, joined to the native target table in `MetadataMappingCatalog.swift`. Both are source code and remain authoritative. The tables in this page are generated from them by `scripts/generate-field-schema.py` and checked by `scripts/check-docs.py`.

The registry answers three different questions:

1. **Semantics.** What is the display name and category of a field, and is it multi-value, people-oriented, role-qualified, or artwork?
2. **Storage.** Which TagLib `PropertyMap` keys, ID3v2 frames, MP4 item/freeform keys, and generic container surfaces can carry the field?
3. **Editing.** Which typed-patch value kinds are accepted, and what numeric range applies?

It does **not** answer whether a particular file or format actually stores a field. Use `FormatCapability.readSupport(for:)` and `FormatCapability.writeSupport(for:)` for declared support, and `probeFile(at:)` to validate a concrete file. See [Capabilities](../guide/CAPABILITIES.md) and [Formats](FORMATS.md).

## Registry summary

<!-- BEGIN GENERATED FIELD SUMMARY -->
**100 fields** are declared in 14 categories: Basic and descriptive (12), Numbering (6), Dates (4), People (11), Role-qualified people (3), Lyrics and comments (2), Artwork (1), Sorting (5), Identifiers (13), Release (10), Technical (4), ReplayGain (4), iTunes (24), Custom (1).

100 canonical semantic owners. The tables below are generated from the Swift registry and catalog; do not edit them by hand.

Typed writes are withheld for: .rate — no verified native rating type or scale in this profile.
<!-- END GENERATED FIELD SUMMARY -->

`year` is the YEAR identity and `standaloneDate` is independent DATE. The ambiguous typed `date` alias has been removed; the serialized `date` token is rejected.

`BasicMetadata.date` carries standalone DATE (the same slot as `.standaloneDate`), while `BasicMetadata.year` carries YEAR. Use the typed or Basic field whose model you are actually editing.

The `.comment` and `.lyrics` rows list the qualified ID3 frames and the ordinary MP4 atoms they own. On MP4, typed edits use `©cmt`/`©lyr`; the structured `comments`/`lyrics` collections are not interchangeable with those typed fields and are ignored by the MP4 structured writer. On ASF, a semantic custom field is addressed through a native Unicode attribute even though the `customFields` API is keyed like a PropertyMap field.

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
| `canonicalSchema(forSemanticKey:)` | Resolves an uppercased semantic key to its canonical owner. |
| `schema(forPropertyMapKey:)` | Normalizes the key, recognizes qualified prefixes, and resolves the owning schema. |
| `schemas(withMappingsFor:)` | Returns every schema with at least one mapping for a `MetadataFieldFormat`. |
| `schemas(storableIn:)` | Returns `[]` for read-only capabilities; otherwise enumerates canonical semantic owners and filters by native target capability, explicit `writableFields` allowlist, and artwork support. `.date` remains addressable but is not a second canonical field. |
| `schema(_:hasMappingFor:)` | Convenience check for one format mapping. |
| `shouldDisplayRawPropertyAsMultiValue(_:)` | UI hint for raw `PropertyMap` keys; true for multi-value schemas and the qualified prefixes below. |
| `normalizePropertyMapKey(_:)` | Trims whitespace and uppercases. Use it before comparing raw keys. |

`schemas(storableIn:)` is a preflight filter, not a guarantee. A field can be listed for a format and still fail for a specific file because of container state, tag version, native width, or a preservation conflict. A schema mapping can also be read-only even when the family is writable; `.rate` is the current example.

## Field registry

Column meanings:

- **PropertyMap keys** are the prefixless keys used by `RawMetadataDump`, `RawMetadataPatch`, and the raw writers. They are also the generic Xiph, APE, and ASF PropertyMap surfaces where the format supports them.
- **ID3v2** lists the native text frame, `TXXX:<description>` user-text frame, `EXTFRAME:<frame>` versioned extension, or `UFID:<owner>` identifier frame. `—` means the schema has no direct ID3v2 target.
- **MP4** lists native atoms and `----:com.apple.iTunes:<description>` freeform keys. A `(read)` suffix marks a non-preferred target that is not a typed write destination.
- **Vorbis**, **APE**, **ASF**, and **RIFF** list the exact native key or attribute.
- **Flags** identify `multi` (multi-value), `people`, `role` (role-qualified key required), `artwork`.
- **Component** suffixes `(number)` and `(total)` identify the two components of a shared native pair. They are not independent native slots.

<!-- BEGIN GENERATED FIELD TABLES -->
<!-- Generated from MetadataFieldSchema.swift and MetadataMappingCatalog.swift. 100 fields. -->

### Basic and descriptive

| Key | Display name | Semantic key | PropertyMap keys | ID3v2.3 | ID3v2.4 | MP4 | Vorbis | APE | ASF | RIFF | Flags |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `title` | Title | `TITLE` | `TITLE` | `TIT2` | `TIT2` | `©nam` | `TITLE` | `TITLE` | `Title` | `INAM` | — |
| `album` | Album | `ALBUM` | `ALBUM` | `TALB` | `TALB` | `©alb` | `ALBUM` | `ALBUM` | `WM/AlbumTitle` | `IPRD` | — |
| `genre` | Genre | `GENRE` | `GENRE` | `TCON` | `TCON` | `©gen` | `GENRE` | `GENRE` | `WM/Genre` | `IGNR` | multi |
| `work` | Work | `WORK` | `WORK` | `TXXX:WORK` | `TXXX:WORK` | `©wrk` | `WORK` | `WORK` | — | — | — |
| `movement` | Movement | `MOVEMENTNAME` | `MOVEMENT`, `MOVEMENTNAME` | `EXTFRAME:MVNM` | `EXTFRAME:MVNM` | `©mvn` | `MOVEMENTNAME` | `MOVEMENTNAME` | — | — | — |
| `discSubtitle` | Disc Subtitle | `DISCSUBTITLE` | `DISCSUBTITLE` | `TXXX:DISCSUBTITLE` | `TSST` | `----:com.apple.iTunes:DISCSUBTITLE` | `DISCSUBTITLE` | `DISCSUBTITLE` | `WM/SetSubTitle` | — | — |
| `subtitle` | Subtitle | `SUBTITLE` | `SUBTITLE` | `TIT3` | `TIT3` | `----:com.apple.iTunes:SUBTITLE` | `SUBTITLE` | `SUBTITLE` | `WM/SubTitle` | — | — |
| `grouping` | Grouping | `GROUPING` | `GROUPING` | `EXTFRAME:GRP1` | `EXTFRAME:GRP1` | `----:com.apple.iTunes:GROUPING` | `GROUPING` | `GROUPING` | — | — | multi |
| `contentGroup` | Content Group | `CONTENTGROUP` | `CONTENTGROUP` | `TIT1` | `TIT1` | `©grp` | `CONTENTGROUP` | `CONTENTGROUP` | `WM/ContentGroupDescription` | — | — |
| `mood` | Mood | `MOOD` | `MOOD` | `TXXX:MOOD` | `TMOO` | `----:com.apple.iTunes:MOOD` | `MOOD` | `MOOD` | `WM/Mood` | — | multi |
| `language` | Language | `LANGUAGE` | `LANGUAGE` | `TLAN` | `TLAN` | `----:com.apple.iTunes:LANGUAGE` | `LANGUAGE` | `LANGUAGE` | `WM/Language` | `ILNG` | multi |
| `musicalKey` | Musical Key | `INITIALKEY` | `INITIALKEY`, `KEY` | `TKEY` | `TKEY` | `----:com.apple.iTunes:INITIALKEY` | `INITIALKEY` | `INITIALKEY` | `WM/InitialKey` | — | — |

### Numbering

| Key | Display name | Semantic key | PropertyMap keys | ID3v2.3 | ID3v2.4 | MP4 | Vorbis | APE | ASF | RIFF | Flags |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `track` | Track Number | `TRACKNUMBER` | `TRACKNUMBER`, `TRACK` | `TRCK (number)` | `TRCK (number)` | `trkn (number)` | `TRACKNUMBER` | `TRACK` | `WM/TrackNumber (number)` | `ITRK` | — |
| `trackTotal` | Track Total | `TRACKTOTAL` | `TRACKTOTAL`, `TOTALTRACKS` | `TRCK (total)` | `TRCK (total)` | `trkn (total)` | `TRACKTOTAL` | `TRACKTOTAL` | `WM/TrackNumber (total)` | — | — |
| `disc` | Disc Number | `DISCNUMBER` | `DISCNUMBER`, `DISC` | `TPOS (number)` | `TPOS (number)` | `disk (number)` | `DISCNUMBER` | `DISC` | `WM/PartOfSet (number)` | — | — |
| `discTotal` | Disc Total | `DISCTOTAL` | `DISCTOTAL`, `TOTALDISCS` | `TPOS (total)` | `TPOS (total)` | `disk (total)` | `DISCTOTAL` | `DISCTOTAL` | `WM/PartOfSet (total)` | — | — |
| `movementNumber` | Movement Number | `MOVEMENTNUMBER` | `MOVEMENTNUMBER` | `EXTFRAME:MVIN (number)` | `EXTFRAME:MVIN (number)` | `©mvi` | `MOVEMENTNUMBER` | `MOVEMENTNUMBER` | — | — | — |
| `movementCount` | Movement Count | `MOVEMENTCOUNT` | `MOVEMENTCOUNT` | `EXTFRAME:MVIN (total)` | `EXTFRAME:MVIN (total)` | `©mvc` | `MOVEMENTCOUNT` | `MOVEMENTCOUNT` | — | — | — |

### Dates

| Key | Display name | Semantic key | PropertyMap keys | ID3v2.3 | ID3v2.4 | MP4 | Vorbis | APE | ASF | RIFF | Flags |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `year` | Year | `YEAR` | `YEAR`, `DATE` | `TYER (read)` | `TDRC` | `©day` | `YEAR` | `YEAR` | `WM/Year` | `ICRD` | — |
| `standaloneDate` | Date | `DATE` | `STANDALONEDATE` | `TDAT (read)` | `TXXX:DATE` | `----:com.apple.iTunes:DATE` | `DATE` | `DATE` | `DATE` | — | — |
| `releaseDate` | Release Date | `RELEASEDATE` | `RELEASEDATE` | `EXTFRAME:TDRL (read)` | `TDRL` | `----:com.apple.iTunes:RELEASEDATE` | `RELEASEDATE` | `RELEASEDATE` | — | — | — |
| `originalReleaseDate` | Original Release Date | `ORIGINALDATE` | `ORIGINALDATE`, `ORIGINAL YEAR` | `TORY (read)` | `TDOR` | `----:com.apple.iTunes:ORIGINALDATE` | `ORIGINALDATE` | `ORIGINALDATE` | `WM/OriginalReleaseYear` | — | — |

### People

| Key | Display name | Semantic key | PropertyMap keys | ID3v2.3 | ID3v2.4 | MP4 | Vorbis | APE | ASF | RIFF | Flags |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `artist` | Artist | `ARTIST` | `ARTIST` | `TPE1` | `TPE1` | `©ART` | `ARTIST` | `ARTIST` | `Author` | `IART` | multi, people |
| `albumArtist` | Album Artist | `ALBUMARTIST` | `ALBUMARTIST`, `ALBUM ARTIST` | `TPE2` | `TPE2` | `aART` | `ALBUMARTIST` | `ALBUM ARTIST` | `WM/AlbumArtist` | — | multi, people |
| `composer` | Composer | `COMPOSER` | `COMPOSER` | `TCOM` | `TCOM` | `©wrt` | `COMPOSER` | `COMPOSER` | `WM/Composer` | `IMUS` | multi, people |
| `conductor` | Conductor | `CONDUCTOR` | `CONDUCTOR` | `TPE3` | `TPE3` | `©con` | `CONDUCTOR` | `CONDUCTOR` | `WM/Conductor` | — | multi, people |
| `remixer` | Remixer | `REMIXER` | `REMIXER` | `TPE4` | `TPE4` | `----:com.apple.iTunes:REMIXER` | `REMIXER` | `MIXARTIST` | `WM/ModifiedBy` | — | multi, people |
| `producer` | Producer | `PRODUCER` | `PRODUCER` | `TXXX:PRODUCER` | `TXXX:PRODUCER` | `----:com.apple.iTunes:PRODUCER` | `PRODUCER` | `PRODUCER` | `WM/Producer` | — | multi, people |
| `engineer` | Engineer | `ENGINEER` | `ENGINEER` | `TXXX:ENGINEER` | `TXXX:ENGINEER` | `----:com.apple.iTunes:ENGINEER` | `ENGINEER` | `ENGINEER` | — | — | multi, people |
| `lyricist` | Lyricist | `LYRICIST` | `LYRICIST` | `TEXT` | `TEXT` | `----:com.apple.iTunes:LYRICIST` | `LYRICIST` | `LYRICIST` | `WM/Writer` | — | multi, people |
| `artists` | Artists | `ARTISTS` | `ARTISTS` | `TXXX:ARTISTS` | `TXXX:ARTISTS` | `----:com.apple.iTunes:ARTISTS` | `ARTISTS` | `ARTISTS` | `WM/ARTISTS` | — | multi, people |
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
| `sortTitle` | Sort Title | `TITLESORT` | `TITLESORT` | `EXTFRAME:TSOT` | `TSOT` | `sonm` | `TITLESORT` | `TITLESORT` | `WM/TitleSortOrder` | — | — |
| `sortArtist` | Sort Artist | `ARTISTSORT` | `ARTISTSORT` | `EXTFRAME:TSOP` | `TSOP` | `soar` | `ARTISTSORT` | `ARTISTSORT` | `WM/ArtistSortOrder` | — | — |
| `sortAlbum` | Sort Album | `ALBUMSORT` | `ALBUMSORT` | `EXTFRAME:TSOA` | `TSOA` | `soal` | `ALBUMSORT` | `ALBUMSORT` | `WM/AlbumSortOrder` | — | — |
| `sortAlbumArtist` | Sort Album Artist | `ALBUMARTISTSORT` | `ALBUMARTISTSORT` | `EXTFRAME:TSO2` | `EXTFRAME:TSO2` | `soaa` | `ALBUMARTISTSORT` | `ALBUMARTISTSORT` | `WM/AlbumArtistSortOrder` | — | — |
| `sortComposer` | Sort Composer | `COMPOSERSORT` | `COMPOSERSORT` | `EXTFRAME:TSOC` | `EXTFRAME:TSOC` | `soco` | `COMPOSERSORT` | `COMPOSERSORT` | — | — | — |

### Identifiers

| Key | Display name | Semantic key | PropertyMap keys | ID3v2.3 | ID3v2.4 | MP4 | Vorbis | APE | ASF | RIFF | Flags |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `isrc` | ISRC | `ISRC` | `ISRC` | `TSRC` | `TSRC` | `----:com.apple.iTunes:ISRC` | `ISRC` | `ISRC` | `WM/ISRC` | — | — |
| `barcode` | Barcode | `BARCODE` | `BARCODE`, `UPC`, `EAN` | `TXXX:BARCODE` | `TXXX:BARCODE` | `----:com.apple.iTunes:BARCODE` | `BARCODE` | `BARCODE` | `WM/Barcode` | — | — |
| `asin` | ASIN | `ASIN` | `ASIN` | `TXXX:ASIN` | `TXXX:ASIN` | `----:com.apple.iTunes:ASIN` | `ASIN` | `ASIN` | — | — | — |
| `musicBrainzArtistID` | MusicBrainz Artist ID | `MUSICBRAINZ_ARTISTID` | `MUSICBRAINZ_ARTISTID`, `MUSICBRAINZ ARTISTID`, `MUSICBRAINZ ARTIST ID` | `TXXX:MusicBrainz Artist Id` | `TXXX:MusicBrainz Artist Id` | `----:com.apple.iTunes:MusicBrainz Artist Id` | `MUSICBRAINZ_ARTISTID` | `MUSICBRAINZ_ARTISTID` | `MusicBrainz/Artist Id` | — | — |
| `musicBrainzAlbumID` | MusicBrainz Album ID | `MUSICBRAINZ_ALBUMID` | `MUSICBRAINZ_ALBUMID`, `MUSICBRAINZ ALBUMID`, `MUSICBRAINZ ALBUM ID` | `TXXX:MusicBrainz Album Id` | `TXXX:MusicBrainz Album Id` | `----:com.apple.iTunes:MusicBrainz Album Id` | `MUSICBRAINZ_ALBUMID` | `MUSICBRAINZ_ALBUMID` | `MusicBrainz/Album Id` | — | — |
| `musicBrainzAlbumArtistID` | MusicBrainz Album Artist ID | `MUSICBRAINZ_ALBUMARTISTID` | `MUSICBRAINZ_ALBUMARTISTID`, `MUSICBRAINZ ALBUMARTISTID`, `MUSICBRAINZ ALBUM ARTIST ID` | `TXXX:MusicBrainz Album Artist Id` | `TXXX:MusicBrainz Album Artist Id` | `----:com.apple.iTunes:MusicBrainz Album Artist Id` | `MUSICBRAINZ_ALBUMARTISTID` | `MUSICBRAINZ_ALBUMARTISTID` | `MusicBrainz/Album Artist Id` | — | — |
| `musicBrainzTrackID` | MusicBrainz Track ID | `MUSICBRAINZ_TRACKID` | `MUSICBRAINZ_TRACKID`, `MUSICBRAINZ TRACKID`, `MUSICBRAINZ TRACK ID` | `UFID:http://musicbrainz.org` | `UFID:http://musicbrainz.org` | `----:com.apple.iTunes:MusicBrainz Track Id` | `MUSICBRAINZ_TRACKID` | `MUSICBRAINZ_TRACKID` | `MusicBrainz/Track Id` | — | — |
| `musicBrainzReleaseGroupID` | MusicBrainz Release Group ID | `MUSICBRAINZ_RELEASEGROUPID` | `MUSICBRAINZ_RELEASEGROUPID`, `MUSICBRAINZ RELEASEGROUPID`, `MUSICBRAINZ RELEASE GROUP ID` | `TXXX:MusicBrainz Release Group Id` | `TXXX:MusicBrainz Release Group Id` | `----:com.apple.iTunes:MusicBrainz Release Group Id` | `MUSICBRAINZ_RELEASEGROUPID` | `MUSICBRAINZ_RELEASEGROUPID` | `MusicBrainz/Release Group Id` | — | — |
| `musicBrainzReleaseTrackID` | MusicBrainz Release Track ID | `MUSICBRAINZ_RELEASETRACKID` | `MUSICBRAINZ_RELEASETRACKID`, `MUSICBRAINZ RELEASETRACKID`, `MUSICBRAINZ RELEASE TRACK ID` | `TXXX:MusicBrainz Release Track Id` | `TXXX:MusicBrainz Release Track Id` | `----:com.apple.iTunes:MusicBrainz Release Track Id` | `MUSICBRAINZ_RELEASETRACKID` | `MUSICBRAINZ_RELEASETRACKID` | `MusicBrainz/Release Track Id` | — | — |
| `musicBrainzWorkID` | MusicBrainz Work ID | `MUSICBRAINZ_WORKID` | `MUSICBRAINZ_WORKID`, `MUSICBRAINZ WORKID`, `MUSICBRAINZ WORK ID` | `TXXX:MusicBrainz Work Id` | `TXXX:MusicBrainz Work Id` | `----:com.apple.iTunes:MusicBrainz Work Id` | `MUSICBRAINZ_WORKID` | `MUSICBRAINZ_WORKID` | `MusicBrainz/Work Id` | — | — |
| `acoustID` | AcoustID | `ACOUSTID_ID` | `ACOUSTID_ID`, `ACOUSTID ID` | `TXXX:Acoustid Id` | `TXXX:Acoustid Id` | `----:com.apple.iTunes:Acoustid Id` | `ACOUSTID_ID` | `ACOUSTID_ID` | `Acoustid/Id` | — | — |
| `acoustIDFingerprint` | AcoustID Fingerprint | `ACOUSTID_FINGERPRINT` | `ACOUSTID_FINGERPRINT`, `ACOUSTID FINGERPRINT` | `TXXX:Acoustid Fingerprint` | `TXXX:Acoustid Fingerprint` | `----:com.apple.iTunes:Acoustid Fingerprint` | `ACOUSTID_FINGERPRINT` | `ACOUSTID_FINGERPRINT` | `Acoustid/Fingerprint` | — | — |
| `musicIPPUID` | MusicIP PUID | `MUSICIP_PUID` | `MUSICIP_PUID`, `MUSICIP PUID` | `TXXX:MusicIP PUID` | `TXXX:MusicIP PUID` | `----:com.apple.iTunes:MusicIP PUID` | `MUSICIP_PUID` | `MUSICIP_PUID` | `MusicIP/PUID` | — | — |

### Release

| Key | Display name | Semantic key | PropertyMap keys | ID3v2.3 | ID3v2.4 | MP4 | Vorbis | APE | ASF | RIFF | Flags |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `publisher` | Publisher | `LABEL` | `LABEL`, `PUBLISHER` | `TPUB` | `TPUB` | `©pub` | `LABEL` | `LABEL` | `WM/Publisher` | — | — |
| `copyright` | Copyright | `COPYRIGHT` | `COPYRIGHT` | `TCOP` | `TCOP` | `cprt` | `COPYRIGHT` | `COPYRIGHT` | `Copyright` | `ICOP` | — |
| `catalogNumber` | Catalog Number | `CATALOGNUMBER` | `CATALOGNUMBER`, `CATALOG NUMBER`, `CATALOG` | `TXXX:CATALOGNUMBER` | `TXXX:CATALOGNUMBER` | `----:com.apple.iTunes:CATALOGNUMBER` | `CATALOGNUMBER` | `CATALOGNUMBER` | `WM/CatalogNo` | — | — |
| `releaseType` | Release Type | `RELEASETYPE` | `RELEASETYPE`, `MUSICBRAINZ_ALBUMTYPE`, `MUSICBRAINZ ALBUM TYPE` | `TXXX:MusicBrainz Album Type` | `TXXX:MusicBrainz Album Type` | `----:com.apple.iTunes:MusicBrainz Album Type` | `RELEASETYPE` | `MUSICBRAINZ_ALBUMTYPE` | `MusicBrainz/Album Type` | — | — |
| `releaseStatus` | Release Status | `RELEASESTATUS` | `RELEASESTATUS`, `MUSICBRAINZ_ALBUMSTATUS`, `MUSICBRAINZ ALBUM STATUS` | `TXXX:MusicBrainz Album Status` | `TXXX:MusicBrainz Album Status` | `----:com.apple.iTunes:MusicBrainz Album Status` | `RELEASESTATUS` | `MUSICBRAINZ_ALBUMSTATUS` | `MusicBrainz/Album Status` | — | — |
| `releaseCountry` | Release Country | `RELEASECOUNTRY` | `RELEASECOUNTRY`, `MUSICBRAINZ_ALBUMRELEASECOUNTRY`, `MUSICBRAINZ ALBUM RELEASE COUNTRY` | `TXXX:MusicBrainz Album Release Country` | `TXXX:MusicBrainz Album Release Country` | `----:com.apple.iTunes:MusicBrainz Album Release Country` | `RELEASECOUNTRY` | `RELEASECOUNTRY` | `MusicBrainz/Album Release Country` | — | — |
| `mediaType` | Media Type | `MEDIA` | `MEDIATYPE`, `MEDIA`, `MEDIA TYPE` | `TMED` | `TMED` | `----:com.apple.iTunes:MEDIA` | `MEDIA` | `MEDIA` | `WM/Media` | — | — |
| `compilation` | Compilation | `COMPILATION` | `COMPILATION` | `EXTFRAME:TCMP` | `EXTFRAME:TCMP` | `cpil` | `COMPILATION` | `COMPILATION` | — | — | — |
| `originalAlbum` | Original Album | `ORIGINALALBUM` | `ORIGINALALBUM` | `TOAL` | `TOAL` | `----:com.apple.iTunes:ORIGINALALBUM` | `ORIGINALALBUM` | `ORIGINALALBUM` | `WM/OriginalAlbumTitle` | — | — |
| `artistType` | Artist Type | `MUSICBRAINZ_ARTISTTYPE` | `MUSICBRAINZ_ARTISTTYPE`, `ARTISTTYPE`, `MUSICBRAINZ ARTIST TYPE` | `TXXX:MusicBrainz Artist Type` | `TXXX:MusicBrainz Artist Type` | `----:com.apple.iTunes:MusicBrainz Artist Type` | `MUSICBRAINZ_ARTISTTYPE` | `MUSICBRAINZ_ARTISTTYPE` | — | — | — |

### Technical

| Key | Display name | Semantic key | PropertyMap keys | ID3v2.3 | ID3v2.4 | MP4 | Vorbis | APE | ASF | RIFF | Flags |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `encodedBy` | Encoded By | `ENCODEDBY` | `ENCODEDBY` | `TENC` | `TENC` | `©enc` | `ENCODEDBY` | `ENCODEDBY` | `WM/EncodedBy` | — | — |
| `encoderSettings` | Encoder Settings | `ENCODING` | `ENCODING`, `ENCODERSETTINGS` | `TSSE` | `TSSE` | `©too` | `ENCODING` | `ENCODING` | `WM/EncodingSettings` | — | — |
| `bpm` | BPM | `BPM` | `BPM` | `TBPM` | `TBPM` | `tmpo` | `BPM` | `BPM` | `WM/BeatsPerMinute` | — | — |
| `trackerName` | Tracker Name | `TRACKERNAME` | `TRACKERNAME` | — | — | — | — | — | — | — | — |

### ReplayGain

| Key | Display name | Semantic key | PropertyMap keys | ID3v2.3 | ID3v2.4 | MP4 | Vorbis | APE | ASF | RIFF | Flags |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `replayGainTrackGain` | ReplayGain Track Gain | `REPLAYGAIN_TRACK_GAIN` | `REPLAYGAIN_TRACK_GAIN` | `TXXX:REPLAYGAIN_TRACK_GAIN` | `TXXX:REPLAYGAIN_TRACK_GAIN` | `----:com.apple.iTunes:REPLAYGAIN_TRACK_GAIN` | `REPLAYGAIN_TRACK_GAIN` | `REPLAYGAIN_TRACK_GAIN` | — | — | — |
| `replayGainAlbumGain` | ReplayGain Album Gain | `REPLAYGAIN_ALBUM_GAIN` | `REPLAYGAIN_ALBUM_GAIN` | `TXXX:REPLAYGAIN_ALBUM_GAIN` | `TXXX:REPLAYGAIN_ALBUM_GAIN` | `----:com.apple.iTunes:REPLAYGAIN_ALBUM_GAIN` | `REPLAYGAIN_ALBUM_GAIN` | `REPLAYGAIN_ALBUM_GAIN` | — | — | — |
| `replayGainTrackPeak` | ReplayGain Track Peak | `REPLAYGAIN_TRACK_PEAK` | `REPLAYGAIN_TRACK_PEAK` | `TXXX:REPLAYGAIN_TRACK_PEAK` | `TXXX:REPLAYGAIN_TRACK_PEAK` | `----:com.apple.iTunes:REPLAYGAIN_TRACK_PEAK` | `REPLAYGAIN_TRACK_PEAK` | `REPLAYGAIN_TRACK_PEAK` | — | — | — |
| `replayGainAlbumPeak` | ReplayGain Album Peak | `REPLAYGAIN_ALBUM_PEAK` | `REPLAYGAIN_ALBUM_PEAK` | `TXXX:REPLAYGAIN_ALBUM_PEAK` | `TXXX:REPLAYGAIN_ALBUM_PEAK` | `----:com.apple.iTunes:REPLAYGAIN_ALBUM_PEAK` | `REPLAYGAIN_ALBUM_PEAK` | `REPLAYGAIN_ALBUM_PEAK` | — | — | — |

### iTunes

| Key | Display name | Semantic key | PropertyMap keys | ID3v2.3 | ID3v2.4 | MP4 | Vorbis | APE | ASF | RIFF | Flags |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `explicitContent` | Explicit Content | `ITUNESADVISORY` | `ITUNESADVISORY`, `ADVISORY`, `EXPLICITCONTENT`, `EXPLICIT` | `TXXX:ITUNESADVISORY` | `TXXX:ITUNESADVISORY` | `rtng` | `ITUNESADVISORY` | `ITUNESADVISORY` | — | — | — |
| `itunesAlbumID` | iTunes Album ID | `ITUNESALBUMID` | `ITUNESALBUMID` | `TXXX:ITUNESALBUMID` | `TXXX:ITUNESALBUMID` | `plID` | `ITUNESALBUMID` | `ITUNESALBUMID` | — | — | — |
| `itunesArtistID` | iTunes Artist ID | `ITUNESARTISTID` | `ITUNESARTISTID` | `TXXX:ITUNESARTISTID` | `TXXX:ITUNESARTISTID` | `atID` | `ITUNESARTISTID` | `ITUNESARTISTID` | — | — | — |
| `itunesCatalogID` | iTunes Catalog ID | `ITUNESCATALOGID` | `ITUNESCATALOGID` | `TXXX:ITUNESCATALOGID` | `TXXX:ITUNESCATALOGID` | `cnID` | `ITUNESCATALOGID` | `ITUNESCATALOGID` | — | — | — |
| `itunesGenreID` | iTunes Genre ID | `ITUNESGENREID` | `ITUNESGENREID` | `TXXX:ITUNESGENREID` | `TXXX:ITUNESGENREID` | `geID` | `ITUNESGENREID` | `ITUNESGENREID` | — | — | — |
| `itunesMediaType` | iTunes Media Type | `ITUNESMEDIATYPE` | `ITUNESMEDIATYPE` | `TXXX:ITUNESMEDIATYPE` | `TXXX:ITUNESMEDIATYPE` | `stik` | `ITUNESMEDIATYPE` | `ITUNESMEDIATYPE` | — | — | — |
| `itunesPurchaseDate` | iTunes Purchase Date | `ITUNESPURCHASEDATE` | `ITUNESPURCHASEDATE` | `TXXX:ITUNESPURCHASEDATE` | `TXXX:ITUNESPURCHASEDATE` | `purd` | `ITUNESPURCHASEDATE` | `ITUNESPURCHASEDATE` | — | — | — |
| `itunesNorm` | iTunNORM | `ITUNNORM` | `ITUNNORM` | `TXXX:iTunNORM` | `TXXX:iTunNORM` | `----:com.apple.iTunes:iTunNORM` | `ITUNNORM` | `ITUNNORM` | — | — | — |
| `itunesSMPB` | iTunSMPB | `ITUNSMPB` | `ITUNSMPB` | `TXXX:iTunSMPB` | `TXXX:iTunSMPB` | `----:com.apple.iTunes:iTunSMPB` | `ITUNSMPB` | `ITUNSMPB` | — | — | — |
| `itunesAccount` | iTunes Account | `ITUNESACCOUNT` | `ITUNESACCOUNT` | — | — | `apID` | — | — | — | — | — |
| `itunesComposerID` | iTunes Composer ID | `ITUNESCOMPOSERID` | `ITUNESCOMPOSERID` | — | — | `cmID` | — | — | — | — | — |
| `itunesCountryID` | iTunes Storefront ID | `ITUNESCOUNTRYID` | `ITUNESCOUNTRYID` | — | — | `sfID` | — | — | — | — | — |
| `itunesGapless` | Gapless Playback | `ITUNESGAPLESS` | `ITUNESGAPLESS`, `GAPLESSPLAYBACK` | — | — | `pgap` | — | — | — | — | — |
| `itunesHDVideo` | HD Video | `ITUNESHDVIDEO` | `ITUNESHDVIDEO`, `HDVIDEO` | — | — | `hdvd` | — | — | — | — | — |
| `itunesOwner` | Owner | `OWNER` | `ITUNESOWNER`, `OWNER` | — | — | `ownr` | — | — | — | — | — |
| `rate` | Rating | `RATE` | `RATE` | — | — | `rate (read)` | — | — | — | — | — |
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
| `custom` | Custom Field | `<explicit key>` | — | `TXXX:<description>` | `TXXX:<description>` | `----:com.apple.iTunes:<description>` | `<explicit key>` | `<explicit key>` | — | — | multi |

<!-- END GENERATED FIELD TABLES -->
## Container-specific numeric limits

Global typed integer constraints are not a guarantee of native precision for every format. MP4 Track/Disc pairs accept components through 65535; this codec's independent Movement Number/Count atoms accept 0...32767. Semantic and Basic writes reject values outside those native limits before staging, rather than clamping or creating freeform duplicates. See [writing semantics](../guide/WRITING.md#native-ownership-and-integer-bounds).

## Typed-patch value contract

`MetadataFieldSchema.acceptedPatchValueKinds` and `integerConstraint` are the validation tables used by `MetadataPatch` before staging. The table below is generated from those Swift properties and the catalog's `writeUnsupportedReason`.

<!-- BEGIN GENERATED PATCH CONTRACT -->
| Field | Accepted `.MetadataPatchValue` kinds | Numeric range | Typed-write note |
| --- | --- | --- | --- |
| `.title` | `.text` | — | — |
| `.artist` | `.text`, `.values` | — | — |
| `.album` | `.text` | — | — |
| `.albumArtist` | `.text`, `.values` | — | — |
| `.year` | `.text` | — | — |
| `.standaloneDate` | `.text` | — | — |
| `.releaseDate` | `.text` | — | — |
| `.originalReleaseDate` | `.text` | — | — |
| `.track` | `.integer` | `1...Int32.max` | — |
| `.trackTotal` | `.integer` | `1...Int32.max` | — |
| `.disc` | `.integer` | `1...Int32.max` | — |
| `.discTotal` | `.integer` | `1...Int32.max` | — |
| `.artwork` | none | — | use `MetadataPatch.artwork` |
| `.lyrics` | `.text` | — | — |
| `.comment` | `.text` | — | — |
| `.genre` | `.text`, `.values` | — | — |
| `.composer` | `.text`, `.values` | — | — |
| `.conductor` | `.text`, `.values` | — | — |
| `.remixer` | `.text`, `.values` | — | — |
| `.performer` | `.text`, `.values` | — | role-qualified: typed patch rejects; use raw/structured |
| `.producer` | `.text`, `.values` | — | — |
| `.engineer` | `.text`, `.values` | — | — |
| `.lyricist` | `.text`, `.values` | — | — |
| `.involvedPeople` | `.text`, `.values` | — | role-qualified: typed patch rejects; use raw/structured |
| `.musicianCredits` | `.text`, `.values` | — | role-qualified: typed patch rejects; use raw/structured |
| `.publisher` | `.text` | — | — |
| `.copyright` | `.text` | — | — |
| `.encodedBy` | `.text` | — | — |
| `.encoderSettings` | `.text` | — | — |
| `.isrc` | `.text` | — | — |
| `.barcode` | `.text` | — | — |
| `.catalogNumber` | `.text` | — | — |
| `.asin` | `.text` | — | — |
| `.releaseType` | `.text` | — | — |
| `.releaseStatus` | `.text` | — | — |
| `.releaseCountry` | `.text` | — | — |
| `.mediaType` | `.text` | — | — |
| `.work` | `.text` | — | — |
| `.movement` | `.text` | — | — |
| `.movementNumber` | `.integer` | `0...Int32.max` | — |
| `.movementCount` | `.integer` | `0...Int32.max` | — |
| `.discSubtitle` | `.text` | — | — |
| `.subtitle` | `.text` | — | — |
| `.grouping` | `.text`, `.values` | — | — |
| `.contentGroup` | `.text` | — | — |
| `.artists` | `.text`, `.values` | — | — |
| `.mood` | `.text`, `.values` | — | — |
| `.language` | `.text`, `.values` | — | — |
| `.musicalKey` | `.text` | — | — |
| `.bpm` | `.integer` | `0...Int32.max` | — |
| `.compilation` | `.boolean` | — | — |
| `.explicitContent` | none | — | use `MetadataPatch.explicitAdvisory` |
| `.sortTitle` | `.text` | — | — |
| `.sortArtist` | `.text` | — | — |
| `.sortAlbum` | `.text` | — | — |
| `.sortAlbumArtist` | `.text` | — | — |
| `.sortComposer` | `.text` | — | — |
| `.musicBrainzArtistID` | `.text` | — | — |
| `.musicBrainzAlbumID` | `.text` | — | — |
| `.musicBrainzAlbumArtistID` | `.text` | — | — |
| `.musicBrainzTrackID` | `.text` | — | — |
| `.musicBrainzReleaseGroupID` | `.text` | — | — |
| `.musicBrainzReleaseTrackID` | `.text` | — | — |
| `.musicBrainzWorkID` | `.text` | — | — |
| `.acoustID` | `.text` | — | — |
| `.acoustIDFingerprint` | `.text` | — | — |
| `.musicIPPUID` | `.text` | — | — |
| `.replayGainTrackGain` | `.text` | — | — |
| `.replayGainAlbumGain` | `.text` | — | — |
| `.replayGainTrackPeak` | `.text` | — | — |
| `.replayGainAlbumPeak` | `.text` | — | — |
| `.itunesAlbumID` | `.integer` | `0...UInt32.max` | — |
| `.itunesArtistID` | `.integer` | `0...UInt32.max` | — |
| `.itunesCatalogID` | `.integer` | `0...UInt32.max` | — |
| `.itunesGenreID` | `.integer` | `0...UInt32.max` | — |
| `.itunesMediaType` | `.integer` | `0...255` | — |
| `.itunesPurchaseDate` | `.text` | — | — |
| `.itunesNorm` | `.text` | — | — |
| `.itunesSMPB` | `.text` | — | — |
| `.originalAlbum` | `.text` | — | — |
| `.originalArtist` | `.text`, `.values` | — | — |
| `.artistType` | `.text` | — | — |
| `.trackerName` | `.text` | — | — |
| `.director` | `.text`, `.values` | — | — |
| `.itunesAccount` | `.text` | — | — |
| `.itunesComposerID` | `.integer` | `0...UInt32.max` | — |
| `.itunesCountryID` | `.integer` | `0...UInt32.max` | — |
| `.itunesGapless` | `.boolean` | — | — |
| `.itunesHDVideo` | `.boolean` | — | — |
| `.itunesOwner` | `.text` | — | — |
| `.rate` | `.integer` | `0...Int32.max` | typed write withheld: no verified native rating type or scale in this profile |
| `.showMovement` | `.boolean` | — | — |
| `.storeDescription` | `.text` | — | — |
| `.tvEpisode` | `.integer` | `0...UInt32.max` | — |
| `.tvEpisodeID` | `.text` | — | — |
| `.tvNetwork` | `.text` | — | — |
| `.tvSeason` | `.integer` | `0...UInt32.max` | — |
| `.tvShow` | `.text` | — | — |
| `.tvShowSort` | `.text` | — | — |
| `.custom` | none | — | use `MetadataPatch.customFields` |

`.remove` is accepted by every field that passes the kind check; it is not a value kind. Empty text and empty arrays are validation errors, not deletion aliases.
<!-- END GENERATED PATCH CONTRACT -->
Role-qualified fields (`performer`, `involvedPeople`, `musicianCredits`) have schemas but are rejected by the typed patch API because their native keys carry a role. Use `RawMetadataPatch` or `StructuredMetadata` for those. `.artwork`, `.custom`, and `.explicitContent` use dedicated `MetadataPatch` properties. `rate` accepts an integer at the schema layer but is read-only for typed writes because no verified native rating type and scale are registered.

The generated `.year`, `.standaloneDate`, `.releaseDate`, and `.originalReleaseDate` rows describe schema-level kinds and ranges, not a concrete file's editability. Existing ID3v2.3 tags are read-only for independent date writes: typed patches reject before staging and a Basic replacement rejects only when a date changes. Read `StructuredMetadata.id3v2MajorVersion` before presenting that edit. See [Formats](FORMATS.md#dates).

Empty text, empty arrays, and array elements that are empty after trimming are validation errors; `.remove` is the explicit deletion request. Do not use `.text("")` or `.values([])` as an implicit deletion alias.

## Lookup and ownership rules

`schema(forPropertyMapKey:)` uses a private, single-owner index of normalized engine keys. Registry construction rejects duplicate owners; there is no preferred-owner override or public field alias flag.

No public fields currently share a PropertyMap key. Engine `DATE` and `YEAR` resolve to the YEAR schema; independent DATE uses `STANDALONEDATE`. These engine spellings are not native storage targets: use the catalog for native ownership.

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
- every schema property key is known to the bridge, after excluding the hidden internal formatting keys;
- bridge canonical/alias keys map to exactly one Swift schema owner;
- ID3v2 frames, user-text descriptions, MP4 items/freeforms, and multi-value/people/role flags agree across the boundary;
- no two schemas own the same key unless the shared-owner maps declare it.

The Swift registry is the public semantic source. The bridge table cannot express a separate ID3v2.3 and ID3v2.4 target in one row; version-specific catalog targets remain authoritative for typed writes. If the two tables disagree, the tests fail; do not "fix" the documentation by describing the bridge table as authoritative.

## Related references

- [Formats](FORMATS.md) — capability matrix and container limits.
- [Bridge reference](BRIDGE.md) — raw mapping dictionaries and the low-level model.
- [Manager API](API.md) and [model reference](MODELS.md) — signatures and types.
- [Write semantics](../explanation/PRESERVATION.md) — omission, replacement, and verification.
- [Writing guide](../guide/WRITING.md) — task-based editing recipes.
