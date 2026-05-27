# Metadata Fields

This document lists every semantic metadata field supported by the `TagLibAudioMetadata` package. Fields are derived from `MetadataFieldRegistry.allSchemas` in `Sources/TagLibAudioMetadata/MetadataFieldSchema.swift` and the corresponding bridge code in `Sources/CTagLibBridge/TagLibMetadataExtractor.mm`.

---

## How to look up field information programmatically

```swift
// By field key
let schema = MetadataFieldRegistry.schema(for: .albumArtist)
print(schema?.propertyMapKeys ?? [])   // ["ALBUMARTIST", "ALBUM ARTIST"]
print(schema?.isMultiValue ?? false)   // true

// By raw PropertyMap key (case-insensitive)
let schema = MetadataFieldRegistry.schema(forPropertyMapKey: "MUSICBRAINZ_ARTISTID")

// All fields storable in a given format
let cap = TagLibMetadataManager.formatCapability(for: "flac")!
let fields = MetadataFieldRegistry.schemas(storableIn: cap)

// Whether a PropertyMap key is multi-value for display
MetadataFieldRegistry.shouldDisplayRawPropertyAsMultiValue("ARTIST")  // → true
```

---

## Field table

The **BasicMetadata field** column shows the Swift property name on `BasicMetadata`. Fields that exist only on `TagLibAudioMetadata` (the Objective-C bridge model) are noted separately.

The **PropertyMap keys** column shows the TagLib `PropertyMap` key names used by this bridge.

The **ID3v2** column shows the primary ID3v2 frame ID(s) or `TXXX:<desc>` for user-text frames.

The **MP4** column shows the iTunes atom key or `----:com.apple.iTunes:<desc>` for freeform atoms.

**R** = readable, **W** = writable. Unless noted, all fields are R/W on formats that support the relevant container.

### Basic fields

| Field Key | BasicMetadata field | Display Name | PropertyMap Keys | ID3v2 | MP4 | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `title` | `title` | Title | `TITLE` | `TIT2` | `©nam` | Core track title. |
| `artist` | `artist` | Artist | `ARTIST`, `ARTISTS` | `TPE1` | `©ART` | Multi-value. May contain multiple artist names. |
| `album` | `album` | Album | `ALBUM` | `TALB` | `©alb` | Release title. |
| `albumArtist` | `albumArtist` | Album Artist | `ALBUMARTIST`, `ALBUM ARTIST` | `TPE2` | `aART` | Multi-value. Artist credited for the release as a whole. |
| `genre` | `genre` | Genre | `GENRE` | `TCON` | `©gen`, `gnre` | Multi-value. `TCON` supports both free text and ID3v1 numeric genre codes. |
| `comment` | `comment` | Comment | `COMMENT` | `COMM` | `©cmt` | In ID3v2, `COMM` has language and description fields. The basic API reads the first comment. Use structured API for multiple comments. |
| `subtitle` | `subtitle` | Subtitle | `SUBTITLE` | `TIT3` | `----:com.apple.iTunes:SUBTITLE` | Track subtitle or movement title. |
| `discSubtitle` | `discSubtitle` | Disc Subtitle | `DISCSUBTITLE` | `TSST` | `----:com.apple.iTunes:DISCSUBTITLE` | Subtitle for the disc within a multi-disc release. |
| `grouping` | `grouping` | Grouping | `GROUPING` | `TIT1` | `©grp` | Multi-value. Content group description. |
| `mood` | `mood` | Mood | `MOOD` | `TMOO` | `----:com.apple.iTunes:MOOD` | Multi-value. |
| `language` | `language` | Language | `LANGUAGE` | `TLAN` | `----:com.apple.iTunes:LANGUAGE` | Multi-value. ISO 639 language code. |
| `musicalKey` | `musicalKey` | Musical Key | `INITIALKEY`, `KEY` | `TKEY` | `----:com.apple.iTunes:INITIALKEY` | Initial musical key. |
| `work` | `work` | Work | `WORK` | `TXXX:WORK` | `----:com.apple.iTunes:WORK` | Classical work title. |
| `movement` | `movement` | Movement | `MOVEMENT`, `MOVEMENTNAME` | `MVNM` | `----:com.apple.iTunes:MOVEMENT` | Movement name within a work. |

### Numbering

| Field Key | BasicMetadata field | Display Name | PropertyMap Keys | ID3v2 | MP4 | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `track` | `track` | Track Number | `TRACKNUMBER`, `TRACK` | `TRCK` | `trkn` | Numeric. `0` = absent/unset. Parsed from the text form (e.g., `"3/12"` → `3`). |
| `trackTotal` | `trackTotal` | Track Total | `TRACKTOTAL`, `TOTALTRACKS` | `TRCK` | `trkn` | Numeric. `0` = absent/unset. ID3v2 stores both track and total in the same `TRCK` frame as `"track/total"`. |
| `disc` | `disc` | Disc Number | `DISCNUMBER`, `DISC` | `TPOS` | `disk` | Numeric. `0` = absent/unset. |
| `discTotal` | `discTotal` | Disc Total | `DISCTOTAL`, `TOTALDISCS` | `TPOS` | `disk` | Numeric. `0` = absent/unset. |
| `movementNumber` | `movementNumber` | Movement Number | `MOVEMENTNUMBER` | `MVIN` | `----:com.apple.iTunes:MOVEMENTNUMBER` | Classical movement index. |
| `movementCount` | `movementCount` | Movement Count | `MOVEMENTCOUNT` | `MVC` | `----:com.apple.iTunes:MOVEMENTCOUNT` | Total number of movements. |

The `trackNumberText` and `discNumberText` fields on `BasicMetadata` are not separate PropertyMap keys. They carry the preferred text form (e.g., `"01/12"`) and are written by the bridge to the same frame/atom that carries the numeric form. Use these when zero-padding or the explicit total separator matters.

### Artwork

| Field Key | BasicMetadata field | Display Name | PropertyMap Key | ID3v2 | MP4 | FLAC/Xiph | ASF | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `artwork` | `artworkData` | Artwork | `PICTURE` | `APIC` | `covr` | `PICTURE` | `WM/Picture` | Binary. `BasicMetadata.artworkData` carries the raw image bytes. `artworkMimeType` is populated on read; the bridge infers the MIME type when writing. Setting `artworkData = nil` leaves existing artwork unchanged. Use `TagLibAudioMetadata.removeArtwork = true` to explicitly remove. |

### Lyrics and comments

| Field Key | BasicMetadata field | Display Name | PropertyMap Keys | ID3v2 | MP4 | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `lyrics` | `lyrics` | Lyrics | `LYRICS` | `USLT` | `©lyr` | In ID3v2, `USLT` has language and description fields. The basic API reads the first unsynchronized lyrics frame. Use the structured API for multiple lyric entries. |

### Dates

| Field Key | BasicMetadata field | Display Name | PropertyMap Keys | ID3v2 | MP4 | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `date` | `year` | Date | `DATE`, `YEAR` | `TDRC`, `TYER` | `©day` | `TDRC` is the preferred ID3v2.4 recording time frame. `TYER` is the legacy ID3v2.3 year frame. TagLib normalizes both to the `DATE`/`YEAR` PropertyMap key. |
| `releaseDate` | `releaseDate` | Release Date | `RELEASEDATE`, `DATE` | `TDRC`, `TDRL` | `©day` | Release date. Preferred over `year` when writing normalized properties. |
| `originalReleaseDate` | `originalReleaseDate` | Original Release Date | `ORIGINALDATE`, `ORIGINAL YEAR` | `TDOR` | `----:com.apple.iTunes:ORIGINAL YEAR` | Original release date for remasters/reissues. |

### People

| Field Key | BasicMetadata field | Display Name | PropertyMap Keys | ID3v2 | MP4 | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `composer` | `composer` | Composer | `COMPOSER` | `TCOM` | `©wrt` | Multi-value, people field. |
| `conductor` | `conductor` | Conductor | `CONDUCTOR` | `TPE3` | `----:com.apple.iTunes:CONDUCTOR` | Multi-value, people field. |
| `remixer` | `remixer` | Remixer | `REMIXER` | `TPE4` | `----:com.apple.iTunes:REMIXER` | Multi-value, people field. |
| `performer` | *(custom fields)* | Performer | `PERFORMER` | `TMCL` | `----:com.apple.iTunes:PERFORMER` | Multi-value, people field, role-qualified. Key form: `PERFORMER:<instrument>`. |
| `producer` | `producer` | Producer | `PRODUCER` | `TXXX:PRODUCER` | `----:com.apple.iTunes:PRODUCER` | Multi-value, people field. |
| `engineer` | `engineer` | Engineer | `ENGINEER` | `TXXX:ENGINEER` | `----:com.apple.iTunes:ENGINEER` | Multi-value, people field. |
| `lyricist` | `lyricist` | Lyricist | `LYRICIST` | `TEXT` | `----:com.apple.iTunes:LYRICIST` | Multi-value, people field. |
| `involvedPeople` | *(custom fields)* | Involved People | `INVOLVEDPEOPLE` | `TIPL` | `----:com.apple.iTunes:INVOLVEDPEOPLE` | Multi-value, people field, role-qualified. |
| `musicianCredits` | *(custom fields)* | Musician Credits | `MUSICIANCREDITS` | `TMCL` | `----:com.apple.iTunes:MUSICIANCREDITS` | Multi-value, people field, role-qualified. |
| `originalArtist` | `originalArtist` | Original Artist | `ORIGINALARTIST` | `TOPE` | `----:com.apple.iTunes:ORIGINALARTIST` | Multi-value, people field. Artist for original release. |

### Sorting

| Field Key | BasicMetadata field | Display Name | PropertyMap Keys | ID3v2 | MP4 | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `sortTitle` | `sortTitle` | Sort Title | `TITLESORT` | `TSOT` | `sonm` | |
| `sortArtist` | `sortArtist` | Sort Artist | `ARTISTSORT` | `TSOP` | `soar` | |
| `sortAlbum` | `sortAlbum` | Sort Album | `ALBUMSORT` | `TSOA` | `soal` | |
| `sortAlbumArtist` | `sortAlbumArtist` | Sort Album Artist | `ALBUMARTISTSORT` | `TSO2` | `soaa` | |
| `sortComposer` | `sortComposer` | Sort Composer | `COMPOSERSORT` | `TSOC` | `soco` | |

### Identifiers

| Field Key | BasicMetadata field | Display Name | PropertyMap Keys | ID3v2 | MP4 | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `isrc` | `isrc` | ISRC | `ISRC` | `TSRC` | `----:com.apple.iTunes:ISRC` | International Standard Recording Code. |
| `barcode` | `barcode` | Barcode | `BARCODE`, `UPC`, `EAN` | `TXXX:BARCODE` | `----:com.apple.iTunes:BARCODE` | UPC or EAN barcode. |
| `asin` | `asin` | ASIN | `ASIN` | `TXXX:ASIN` | `----:com.apple.iTunes:ASIN` | Amazon Standard Identification Number. |
| `musicBrainzArtistID` | `musicBrainzArtistID` | MusicBrainz Artist ID | `MUSICBRAINZ_ARTISTID`, `MUSICBRAINZ ARTISTID`, `MUSICBRAINZ ARTIST ID` | `TXXX:MusicBrainz Artist Id` | `----:com.apple.iTunes:MusicBrainz Artist Id` | |
| `musicBrainzAlbumID` | `musicBrainzAlbumID` | MusicBrainz Album ID | `MUSICBRAINZ_ALBUMID`, `MUSICBRAINZ ALBUMID`, `MUSICBRAINZ ALBUM ID` | `TXXX:MusicBrainz Album Id` | `----:com.apple.iTunes:MusicBrainz Album Id` | |
| `musicBrainzAlbumArtistID` | `musicBrainzAlbumArtistID` | MusicBrainz Album Artist ID | `MUSICBRAINZ_ALBUMARTISTID`, `MUSICBRAINZ ALBUMARTISTID`, `MUSICBRAINZ ALBUM ARTIST ID` | `TXXX:MusicBrainz Album Artist Id` | `----:com.apple.iTunes:MusicBrainz Album Artist Id` | |
| `musicBrainzTrackID` | `musicBrainzTrackID` | MusicBrainz Track ID | `MUSICBRAINZ_TRACKID`, `MUSICBRAINZ TRACKID`, `MUSICBRAINZ TRACK ID` | `TXXX:MusicBrainz Track Id` | `----:com.apple.iTunes:MusicBrainz Track Id` | |
| `musicBrainzReleaseGroupID` | `musicBrainzReleaseGroupID` | MusicBrainz Release Group ID | `MUSICBRAINZ_RELEASEGROUPID`, `MUSICBRAINZ RELEASEGROUPID`, `MUSICBRAINZ RELEASE GROUP ID` | `TXXX:MusicBrainz Release Group Id` | `----:com.apple.iTunes:MusicBrainz Release Group Id` | |
| `musicBrainzReleaseTrackID` | `musicBrainzReleaseTrackID` | MusicBrainz Release Track ID | `MUSICBRAINZ_RELEASETRACKID`, `MUSICBRAINZ RELEASETRACKID`, `MUSICBRAINZ RELEASE TRACK ID` | `TXXX:MusicBrainz Release Track Id` | `----:com.apple.iTunes:MusicBrainz Release Track Id` | |
| `musicBrainzWorkID` | `musicBrainzWorkID` | MusicBrainz Work ID | `MUSICBRAINZ_WORKID`, `MUSICBRAINZ WORKID`, `MUSICBRAINZ WORK ID` | `TXXX:MusicBrainz Work Id` | `----:com.apple.iTunes:MusicBrainz Work Id` | |
| `acoustID` | `acoustID` | AcoustID | `ACOUSTID_ID`, `ACOUSTID ID` | `TXXX:Acoustid Id` | `----:com.apple.iTunes:Acoustid Id` | |
| `acoustIDFingerprint` | `acoustIDFingerprint` | AcoustID Fingerprint | `ACOUSTID_FINGERPRINT`, `ACOUSTID FINGERPRINT` | `TXXX:Acoustid Fingerprint` | `----:com.apple.iTunes:Acoustid Fingerprint` | |
| `musicIPPUID` | `musicIPPUID` | MusicIP PUID | `MUSICIP_PUID` | `TXXX:MusicIP PUID` | `----:com.apple.iTunes:MusicIP PUID` | Legacy MusicIP identifier. |

### Release information

| Field Key | BasicMetadata field | Display Name | PropertyMap Keys | ID3v2 | MP4 | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `publisher` | `publisher` | Publisher | `LABEL`, `PUBLISHER` | `TPUB` | `----:com.apple.iTunes:LABEL` | Also known as label. The `BasicMetadata.publisher` field maps to the bridge `label` property. |
| `copyright` | `copyright` | Copyright | `COPYRIGHT` | `TCOP` | `cprt` | |
| `mediaType` | `mediaType` | Media Type | `MEDIATYPE`, `MEDIA`, `MEDIA TYPE` | `TMED` | `----:com.apple.iTunes:MEDIATYPE` | Release media type (e.g., CD, Vinyl). |
| `releaseType` | `releaseType` | Release Type | `RELEASETYPE`, `MUSICBRAINZ_ALBUMTYPE`, `MUSICBRAINZ ALBUM TYPE` | `TXXX:RELEASETYPE` | `----:com.apple.iTunes:RELEASETYPE`, `----:com.apple.iTunes:MusicBrainz Album Type` | Album, EP, Single, etc. |
| `releaseStatus` | `releaseStatus` | Release Status | `RELEASESTATUS`, `MUSICBRAINZ_ALBUMSTATUS`, `MUSICBRAINZ ALBUM STATUS` | `TXXX:RELEASESTATUS` | `----:com.apple.iTunes:RELEASESTATUS`, `----:com.apple.iTunes:MusicBrainz Album Status` | Official, Promotion, Bootleg, etc. |
| `releaseCountry` | `releaseCountry` | Release Country | `RELEASECOUNTRY`, `MUSICBRAINZ_ALBUMRELEASECOUNTRY`, `MUSICBRAINZ ALBUM RELEASE COUNTRY` | `TXXX:RELEASECOUNTRY` | `----:com.apple.iTunes:MusicBrainz Album Release Country` | ISO country code. |
| `catalogNumber` | `catalogNumber` | Catalog Number | `CATALOGNUMBER`, `CATALOG NUMBER`, `CATALOG` | `TXXX:CATALOGNUMBER` | `----:com.apple.iTunes:CATALOGNUMBER` | |
| `artistType` | `artistType` | Artist Type | `ARTISTTYPE`, `MUSICBRAINZ_ARTISTTYPE`, `MUSICBRAINZ ARTIST TYPE` | `TXXX:ARTISTTYPE` | `----:com.apple.iTunes:ARTISTTYPE` | Person, Group, Orchestra, etc. |
| `originalAlbum` | `originalAlbum` | Original Album | `ORIGINALALBUM` | `TOAL` | `----:com.apple.iTunes:ORIGINALALBUM` | Original album title for remasters/reissues. |
| `compilation` | `isCompilation` | Compilation | `COMPILATION` | `TCMP` | `cpil` | Boolean. |

### ReplayGain

| Field Key | BasicMetadata field | Display Name | PropertyMap Keys | ID3v2 | MP4 | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `replayGainTrackGain` | `replayGainTrack` | ReplayGain Track Gain | `REPLAYGAIN_TRACK_GAIN` | `TXXX:REPLAYGAIN_TRACK_GAIN` | `----:com.apple.iTunes:REPLAYGAIN_TRACK_GAIN` | String form, e.g. `"-3.45 dB"`. |
| `replayGainAlbumGain` | `replayGainAlbum` | ReplayGain Album Gain | `REPLAYGAIN_ALBUM_GAIN` | `TXXX:REPLAYGAIN_ALBUM_GAIN` | `----:com.apple.iTunes:REPLAYGAIN_ALBUM_GAIN` | String form. |

### iTunes-specific fields

| Field Key | BasicMetadata field | Display Name | PropertyMap Keys | ID3v2 | MP4 | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `explicitContent` | `isExplicit` | Explicit Content | `ITUNESADVISORY`, `ADVISORY`, `EXPLICITCONTENT`, `EXPLICIT` | `TXXX:ITUNESADVISORY` | `rtng` (typed integer) | Boolean. `rtng` is a typed MP4 integer; the bridge normalizes it to `true`/`false`. |
| `itunesAlbumID` | `itunesAlbumID` | iTunes Album ID | `ITUNESALBUMID` | `TXXX:ITUNESALBUMID` | `----:com.apple.iTunes:ITUNESALBUMID` | Purchase metadata. |
| `itunesArtistID` | `itunesArtistID` | iTunes Artist ID | `ITUNESARTISTID` | `TXXX:ITUNESARTISTID` | `----:com.apple.iTunes:ITUNESARTISTID` | Purchase metadata. |
| `itunesCatalogID` | `itunesCatalogID` | iTunes Catalog ID | `ITUNESCATALOGID` | `TXXX:ITUNESCATALOGID` | `----:com.apple.iTunes:ITUNESCATALOGID` | |
| `itunesGenreID` | `itunesGenreID` | iTunes Genre ID | `ITUNESGENREID` | `TXXX:ITUNESGENREID` | `----:com.apple.iTunes:ITUNESGENREID` | |
| `itunesMediaType` | `itunesMediaType` | iTunes Media Type | `ITUNESMEDIATYPE` | `TXXX:ITUNESMEDIATYPE` | `----:com.apple.iTunes:ITUNESMEDIATYPE` | |
| `itunesPurchaseDate` | `itunesPurchaseDate` | iTunes Purchase Date | `ITUNESPURCHASEDATE` | `TXXX:ITUNESPURCHASEDATE` | `----:com.apple.iTunes:ITUNESPURCHASEDATE` | |
| `itunesNorm` | `itunesNorm` | iTunNORM | `ITUNNORM` | `TXXX:ITUNNORM` | `----:com.apple.iTunes:ITUNNORM` | iTunes sound check normalization data. |
| `itunesSMPB` | `itunesSMPB` | iTunSMPB | `ITUNSMPB` | `TXXX:ITUNSMPB` | `----:com.apple.iTunes:ITUNSMPB` | iTunes gapless playback data. |

### Technical / encoding

| Field Key | BasicMetadata field | Display Name | PropertyMap Keys | ID3v2 | MP4 | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `encodedBy` | `encodedBy` | Encoded By | `ENCODEDBY`, `ENCODING` | `TENC` | `©too` | |
| `encoderSettings` | `encoderSettings` | Encoder Settings | `ENCODERSETTINGS` | `TSSE` | `----:com.apple.iTunes:ENCODERSETTINGS` | |
| `bpm` | `bpm` | BPM | `BPM` | `TBPM` | `tmpo` | Integer (beats per minute). `0` = absent/unset. `tmpo` is a typed MP4 integer. |

### Audio properties (read-only)

These fields are populated from the audio codec properties and are not written by tag APIs.

| BasicMetadata field | Type | Description |
| --- | --- | --- |
| `duration` | `Double` | Track duration in seconds. |
| `bitrate` | `Int` | Bitrate in kbps. |
| `sampleRate` | `Double` | Sample rate in Hz. |
| `channels` | `Int` | Number of audio channels. |
| `bitDepth` | `Int` | Bits per sample (0 if not available from TagLib). |
| `format` | `String` | Codec name as reported by `TagLibAudioMetadata.codec`. |

### Custom fields

| Field Key | BasicMetadata field | Notes |
| --- | --- | --- |
| `custom` | `customFields: [String: String]` | Arbitrary application-defined key/value pairs. Stored as `TXXX:<description>` in ID3v2, `----:com.apple.iTunes:<description>` in MP4, or as a plain PropertyMap key for other containers. Empty keys are ignored; empty values clear the field during write. |

---

## PropertyMap key normalization

TagLib normalizes PropertyMap keys to uppercase. The bridge also normalizes keys to uppercase before lookup and comparison. Keys with spaces and underscores are treated as separate aliases; the registry maps both forms (e.g., `MUSICBRAINZ_ARTISTID` and `MUSICBRAINZ ARTIST ID`) to the same schema entry.

`PERFORMER:<instrument>` is a role-qualified key. Any key with the prefix `PERFORMER:` is recognized by `MetadataFieldRegistry.schema(forPropertyMapKey:)` as the `performer` schema and is flagged as multi-value.

## Format-specific behavior notes

- **ID3v1 truncation**: Title (30 chars), Artist (30 chars), Album (30 chars), Year (4 chars), Comment (28–30 chars), Track (1 byte), Genre (1-byte index). Fields exceeding these limits are silently truncated by TagLib's ID3v1 writer. Always prefer ID3v2 for MP3 files.
- **MP4 `trkn` / `disk` atom**: These are typed integer-pair atoms. They store (track, total) and (disc, total) as pairs. TagLib exposes both values from the same atom; the bridge sets both when track or disc total is non-zero.
- **MP4 `rtng` (explicit content)**: This is a typed integer atom. The bridge normalizes it to a boolean. Values of `4` or `1` are treated as explicit; `2` is clean; `0` is unset/unknown. The behavior of intermediate values is implementation-dependent.
- **Xiph comment multi-value**: Xiph/Vorbis comment fields support multiple values for the same key as separate entries. `RawPropertyEntry.values` exposes these as an array. `writeRawMetadataPropertyMapValuesWithVerification` preserves them; the single-value write path joins them with `"; "`.
- **ASF type coercion**: ASF attributes have native types (string, bool, integer). The bridge reads and writes them with correct types via the structured path. Via the PropertyMap path, values are stored as strings.
