# Format support and limitations

This is the canonical reference for declared format coverage. It describes the capability registry in `Sources/CTagLibBridge/TLFormatRegistry.mm`, the container masks in `Sources/CTagLibBridge/Internal/TLMetadataCore.inc`, and the field schema in `Sources/TagLibAudioMetadata/MetadataFieldSchema.swift`.

A declared label is not proof that every file, field, codec variant, or platform works. Query the public capability API for the extension and field in question, then validate a concrete file.

## How to read capability evidence

```swift
let family = TagLibMetadataManager.capability(forExtension: "m4a")
let concrete = try TagLibMetadataManager.probeFile(at: url)
let fieldSupport = concrete.writeSupport(for: .artwork)
```

| API | What it answers |
| --- | --- |
| `capability(forExtension:)` | Declared family metadata for an extension. Does not open a file. |
| `probeFile(at:)` | Opens and parses a concrete file, then returns its declared family capability. Does not test POSIX write permission, ACLs, disk space, or sandbox access. |
| `supportLevel` | Evidence level for the capability's requested extension (or primary extension for `formatCapabilities`). |
| `supportLevel(forExtension:)` | Evidence level for another alias in the same family. |
| `readSupport(for:)` / `writeSupport(for:)` | Combines family flags, field mappings, artwork flags, explicit allowlists, and the MP4 date rule. |
| `canWriteArtwork` | Artwork write availability; separate from `structuredWriteSupport`. |
| `structuredReadSupport` / `structuredWriteSupport` | Non-artwork structured frames/atoms/attributes. A `.propertyMap` level can still support structured artwork. |
| `preservesMultiValueProperties` | Family-level repeated-`PropertyMap` support, not a per-field guarantee. |
| `readableFields` / `writableFields` | Optional explicit allowlists; `nil` means infer from mappings. Currently used by tracker formats. |

### Evidence levels

| Level | Meaning |
| --- | --- |
| `fixtureCovered` | The repository contains a fixture and regression tests for this extension. Not every alias, field, or codec variant is tested. |
| `experimental` | Available for evaluation, but container-specific behavior is incomplete. |
| `upstreamSupported` | TagLib exposes the format, but this package has no round-trip fixture for it. Treat it as an unverified parser path. |
| `readOnly` | Readable by the package, with no supported save path. |
| `unsupported` | No supported parser or field mapping exists. |
| `verified` | Deprecated; never returned by capability lookup. Use `fixtureCovered` or a concrete probe. |

The level is configured per extension. For a capability obtained from `capability(forExtension:)`, `supportLevel` is the level of that extension; `formatCapabilities` entries use the primary extension. Use `extensionSupportLevels` or `supportLevel(forExtension:)` to compare aliases.

## Format matrix

The registry contains 22 families and 37 extensions. R/W means a save path exists; it does not mean every metadata surface is writable.

| Family | Extensions | R/W | Metadata containers | Structured R/W | Primary evidence | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| MPEG Audio / ID3 | `mp3`, `mp2` | R/W | tag, PropertyMap, ID3v1, ID3v2, APE | container / container | `mp3` fixture-covered; `mp2` upstream-supported | ID3v2 is the preferred rich container; ID3v1 is a low-fidelity fallback. Mixed tags are preserved on save. |
| Raw AAC | `aac` | R/W | tag, PropertyMap, ID3v2 | container / container | fixture-covered | Uses MPEG ID3v2 frames, comments, lyrics, artwork, and PropertyMap deltas. |
| MP4 / MPEG-4 Audio | `m4a`, `m4r`, `m4b`, `m4p`, `mp4`, `m4v`, `3g2` | R/W | tag, PropertyMap, MP4 item map | container / container | `m4a` fixture-covered; other aliases upstream-supported | Native atoms and iTunes freeform atoms are exposed through structured metadata. One interoperable date atom, `©day`. |
| FLAC | `flac` | R/W | tag, PropertyMap, Xiph, ID3v1, ID3v2 | container / propertyMap | fixture-covered | Structured reads expose pictures; structured writes are PropertyMap deltas plus artwork. |
| Ogg Vorbis | `ogg` | R/W | PropertyMap, Xiph | container / propertyMap | fixture-covered | Repeated Xiph values are preserved. Codec detection uses the identification packet, not only the extension. |
| Ogg Opus | `opus` | R/W | PropertyMap, Xiph | container / propertyMap | fixture-covered | Codec detection uses the Opus identification packet. |
| Ogg FLAC | `oga` | R/W | PropertyMap, Xiph | container / propertyMap | fixture-covered | An Ogg FLAC file named `.ogg` is detected by its identification packet. |
| Ogg Speex | `spx` | R/W | PropertyMap, Xiph | container / propertyMap | upstream-supported | No repository fixture or runtime round trip. Treat as unverified. |
| Monkey's Audio | `ape` | R/W | tag, PropertyMap, APE | propertyMap / propertyMap | fixture-covered | APE items are surfaced through PropertyMap. One front-cover image can be written; existing back artwork is preserved on unrelated edits. |
| WavPack | `wv` | R/W | tag, PropertyMap, APE | propertyMap / propertyMap | fixture-covered | APE item metadata is surfaced through PropertyMap. |
| Musepack | `mpc` | R/W | tag, PropertyMap, APE | propertyMap / propertyMap | fixture-covered | APE item metadata is surfaced through PropertyMap. |
| WAV / RIFF | `wav` | R/W | tag, PropertyMap, ID3v2, RIFF INFO | container / container | fixture-covered | Structured writes use ID3v2. `preserveInfo` keeps RIFF INFO; `id3v2Only` removes it. |
| AIFF / AIFF-C | `aiff`, `aif`, `aifc`, `afc` | R/W | tag, PropertyMap, ID3v2 | container / container | upstream-supported, with a generated PCM fixture and selected tests | Structured writes use ID3v2. The shared WAV/AIFF container mask also reports `riffInfo`; the AIFF writer has no RIFF INFO surface, so treat that entry as WAV-specific. |
| TrueAudio | `tta` | R/W | tag, PropertyMap, ID3v1, ID3v2 | container / container | fixture-covered | ID3v2 frames, comments, lyrics, artwork, and PropertyMap deltas. Mixed unmodeled APEv2 surfaces reject; see below. |
| ASF / WMA | `wma`, `asf` | R/W | tag, PropertyMap, ASF | container / container | `wma` fixture-covered; `asf` upstream-supported | ASF attributes preserve name, type, language, and stream identity. GUID attributes are inspection-only. |
| DSF | `dsf` | R/W | tag, PropertyMap, ID3v2 | container / propertyMap | fixture-covered | Structured reads expose native ID3 collections; structured writes are limited to PropertyMap deltas and artwork. |
| DSDIFF | `dff`, `dsdiff` | R/W | tag, PropertyMap, ID3v2 | container / propertyMap | `dff` fixture-covered; `dsdiff` upstream-supported | Same writer boundary as DSF. Uncompressed DSDIFF is tested; DST compression is not. |
| Shorten | `shn` | Read-only | tag, PropertyMap | propertyMap / none | read-only label | TagLib exposes metadata but has no save path. |
| MOD Tracker Module | `mod`, `module`, `nst`, `wow` | Read-only | tag, PropertyMap | propertyMap / none | read-only label | Metadata is limited to title, comment, and a format-derived tracker name. |
| Scream Tracker 3 | `s3m` | R/W (title, comment) | tag, PropertyMap | propertyMap / propertyMap | experimental | No runtime fixture. Fixed-width tracker storage can normalize text. |
| Impulse Tracker | `it` | R/W (title, comment) | tag, PropertyMap | propertyMap / propertyMap | experimental | No runtime fixture. Fixed-width tracker storage can normalize text. |
| FastTracker Module | `xm` | R/W (title, comment, tracker name) | tag, PropertyMap | propertyMap / propertyMap | fixture-covered | Fixed-width instrument/sample fields can normalize comments and pad the tracker name. |

The fixture-covered set is exactly `mp3`, `m4a`, `flac`, `ogg`, `oga`, `wav`, `aac`, `xm`, `tta`, `wv`, `wma`, `ape`, `mpc`, `dsf`, `dff`, and `opus`. The experimental set is `s3m` and `it`. `shn` and `mod` (with `module`, `nst`, and `wow`) are read-only. Every other registered extension is `upstreamSupported`.

## Cross-format behavior

### Number pairs

| Storage family | Track/disc representation |
| --- | --- |
| ID3-backed: MPEG/MP2, AAC, WAV, AIFF/AIFF-C, TrueAudio, DSF, DSDIFF | Combined `TRCK` / `TPOS`; movement number/count uses `MVIN`. |
| MP4 | Native `trkn` / `disk` integer pairs. |
| FLAC, Ogg Vorbis/Opus/FLAC/Speex, APE, WavPack, Musepack | Separate `TRACKNUMBER` / `TRACKTOTAL`, `DISCNUMBER` / `DISCTOTAL`. |
| ASF | `WM/TrackNumber` and `WM/PartOfSet` text pairs; normalized writers combine `number/total` in the native attribute. |

- Track and disc components begin at one. `.remove` unsets a component; BPM and movement numbering begin at zero.
- Removing a first component while retaining a total is rejected where the container cannot represent the combination: MPEG/ID3, AAC, MP4, WAV, AIFF, TrueAudio, DSF, DSDIFF, and ASF. Remove both components to clear the pair.
- On generic/Xiph formats, `BasicMetadata` number text displays the first component and normalizes total padding. The numeric pair and raw values remain authoritative; a slash display is not promised there.
- Exact ID3 text writes preserve both components' padding where the native pair supports it. Numeric writers may normalize padding.

### Dates

| Semantic field | ID3v2 | Xiph/PropertyMap | MP4 |
| --- | --- | --- | --- |
| `.date` (recording date/year) | `TDRC`; legacy `TYER` is read-compatible | `DATE`; `YEAR` is an alias | Unsupported for typed writes |
| `.releaseDate` | `TDRL` | `RELEASEDATE` | `©day` |
| `.originalReleaseDate` | `TDOR` | `ORIGINALDATE` / `ORIGINAL YEAR` | `ORIGINAL YEAR` freeform |

MP4 has one standard date atom. A typed `.date` patch for MP4 fails before staging. `BasicMetadata.year` is a compatibility projection; `updateBasicMetadata` reconciles single-field year/releaseDate edits, while a full replacement with inconsistent non-empty projections throws `MetadataValidationError.conflictingMP4Date`.

### Advisory

`ExplicitAdvisory` has four states: absent (`unspecified`), not explicit, explicit, and clean. MP4 uses absent / `rtng = 0` / `1` / `2`. ID3 and generic PropertyMap formats use `ITUNESADVISORY` with `0`, `1`, and `2`. Legacy MP4 value `4` and legacy text forms remain readable; high-level writes emit canonical values. The Boolean `isExplicit` is a lossy read projection.

### Multi-value fields

`BasicMetadata` scalar text fields are display projections. ID3 generally joins values with `", "`; MP4 artist/genre and generic/Xiph projections use `"; "`, while some native MP4 fields and freeforms use `", "`. Use raw or structured metadata when arrays are authoritative.

## Format-specific limitations

### ID3v2 and mixed tag surfaces

- `APIC`, `COMM`, and `USLT` are not exposed as editable entries in `id3v2Frames`. Use the dedicated artwork, comments, and lyrics collections.
- Typed Patch edits to `.comment` and `.lyrics` own the complete represented scalar collection, including qualified descriptions and languages. Raw patches remain key-specific.
- Creating the first preferred ID3v2 tag on an ID3v1-only MPEG or TrueAudio file promotes the visible legacy fields before saving. Secondary on-disk tags remain intact.
- A mixed TrueAudio file with unmodeled APEv2 fields rejects before commit because the pinned handler cannot reconcile both surfaces. Encoder-only APEv2 provenance is preserved. Reconcile the secondary tag with an APE-aware tool before editing.
- Opaque/unknown ID3 frames are inspection-only. Omit them from structured writes; omitted frames remain on disk.

### MP4

- Raw PropertyMap APIs accept prefixless TagLib keys, not native `----:` atom identifiers. Use `StructuredMetadata.mp4Atoms` for exact, case-sensitive freeform keys.
- Native `trkn`/`disk` are authoritative. Recognized number aliases are cleaned up when the corresponding pair changes; unrelated Basic edits preserve them.
- Native advisory is `rtng`; recognized freeform aliases (`ITUNESADVISORY`, `ADVISORY`, `EXPLICITCONTENT`, `EXPLICIT`) are removed when the advisory changes.
- `.date` is unsupported for typed writes. Use `.releaseDate` or `updateBasicMetadata`.
- `covr` is returned both as an artwork entry and as a `coverArtList` MP4 atom. Use the artwork collection to replace it; `coverArtList` is inspection-only for direct atom writes.
- Structured atom writing supports `stringList`, `bool`, `int`, `uint`, `byte`, `longLong`, and `intPair`. Other item types should be omitted.

### WAV, AIFF, and RIFF INFO

- Basic and typed Patch WAV writes target ID3v2 and leave RIFF INFO untouched. Structured WAV writes use the `riffPolicy`: `.preserveInfo` (default) keeps INFO, `.id3v2Only` removes it after writing ID3v2, and `.syncBasicFieldsToInfo` is reserved and rejects before staging.
- Raw PropertyMap edits on WAV follow key ownership: existing INFO keys update INFO, ID3v2 keys update ID3v2, and new keys go to ID3v2.
- A verified deletion that would expose a retained INFO fallback is rejected; use a raw deletion to clear both surfaces.
- AIFF/AIFF-C structured writes use ID3v2. They have no RIFF INFO surface, so `.id3v2Only` has no additional effect there; `.syncBasicFieldsToInfo` still rejects as unsupported. The shared capability container mask still lists `riffInfo`; treat that entry as WAV-specific.
- AIFF/AIFF-C have a generated PCM fixture and focused tests, but the family label remains `upstreamSupported`.

### APE-family (APE, WavPack, Musepack)

- Structured writes support one front-cover image. Existing back artwork is read and preserved during unrelated edits; `removeAll` clears both roles.
- APE items are surfaced through PropertyMap; there is no separate item-level structured mutation API.
- Unchanged native `Date`/`Year` spelling is preserved through number, Basic, and raw delta replay.
- Structured writes reject frames, MP4 atoms, ASF attributes, lyrics, and comments; only PropertyMap values and artwork are supported.

### ASF/WMA

- Structured attributes preserve name, type, language, and stream identity.
- Common ASF fields duplicated as custom attributes are treated as semantic aliases and cleared only when the corresponding common field changes. Unrelated attributes such as `PUBLISHER` are preserved.
- `int` projects WORD and DWORD. An update retains an existing unambiguous native width; a new attribute uses DWORD. A WORD overflow or an ambiguous same-identity WORD/DWORD update rejects.
- GUID attributes are inspection-only with the pinned encoder. Omit them from write payloads to preserve them; they are never silently encoded as binary.
- ASF structured attributes are upserts, not replace-all collections, and have no individual deletion operation. Verified full erase clears the complete native attribute and picture map.
- Normalized number writers persist totals inside `WM/TrackNumber` and `WM/PartOfSet` text pairs.

### DSD (DSF, DSDIFF)

- Structured reads expose native ID3v2 frames, comments, lyrics, artwork, and opaque frames.
- Structured writes are PropertyMap deltas and artwork. Replacing native ID3 frame/comment/lyric collections through the structured writer is unsupported.
- A Basic edit that would require replaying existing DSD comments or lyrics rejects safely rather than normalizing them. Use a raw delta for an unrelated field.
- DSDIFF tests cover uncompressed DSD; DST-compressed DSDIFF is not verified.

### Tracker modules

- MOD is read-only. S3M and IT are experimental and limited to title/comment; XM is fixture-covered and additionally supports tracker name through the field schema.
- `BasicMetadata` has no `trackerName` property; use `MetadataPatch(fields: [.trackerName: ...])` or structured properties where the capability allows it.
- Fixed-width storage can normalize text; no artwork path exists.
- These labels are not runtime proof for arbitrary tracker files.

### Audio properties

`BasicMetadata` reports duration, bitrate, sample rate, channels, bit depth, and format from TagLib's available properties. Zero or an empty value means the parser did not expose it. Bit depth is a declared/available sample width, not evidence that a codec is lossless; this is especially important for compressed ASF audio. Ogg FLAC, APE, WavPack, and ASF project available bits-per-sample where TagLib exposes them.

### Source-only or unverified families

Speex, S3M, IT, Shorten, MOD, uncommon aliases, minimum-OS runtime, device runtime, and x86_64 runtime lack runtime verification in this repository. Do not present their configured labels as tested behavior.

## Audio-content identity availability

`MetadataAudioContentIdentity` is available only for native FLAC and single-data-chunk RIFF WAVE / AIFF / AIFF-C layouts. It is unavailable for MP3, MP4/M4A, raw AAC, Ogg/Opus, ASF, APE, WavPack, Musepack, TrueAudio, DSD, tracker formats, RF64, RIFX, leading-ID3 FLAC, and ambiguous chunk layouts. See [Audio-content continuity](AUDIO_CONTENT_CONTINUITY.md).

## Fixtures and independent evidence

Fixture provenance, hashes, and licensing are in [Tests/TagLibAudioMetadataTests/Audio/README.md](../Tests/TagLibAudioMetadataTests/Audio/README.md). Highlights:

- Generated PCM tones cover AAC, FLAC, M4A (AAC and ALAC), MP3, Ogg Vorbis, Opus, WAV, ASF/WMA, TrueAudio, WavPack, XM, and AIFF.
- Pinned upstream files cover DSF, DSDIFF, APE, Musepack, Ogg FLAC, and XM.
- `info-only.wav` protects RIFF INFO visibility after ID3v2 creation.
- `clean-room.aiff` is generated PCM with one `COMM` and one `SSND` chunk.
- Independent oracles include bounded RIFF INFO, ID3v2, MP4 atom, APEv2, and ASF parsers. Fixture acquisition and historical verification campaigns used FFprobe/FFmpeg; those tools are not invoked by the current test suite. See [Testing](TESTING.md) and the historical verification records.

Fixture coverage is finite. It does not establish universal codec conformance, every metadata variant, or every platform runtime.
