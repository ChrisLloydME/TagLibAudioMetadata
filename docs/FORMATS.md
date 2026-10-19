# Format support and limitations

This is the canonical reference for declared format coverage. It describes the capability registry in `Sources/CTagLibBridge/TLFormatRegistry.mm` and the field schema in `MetadataFieldSchema.swift` at the current HEAD.

A declared label is not proof that every file, field, codec variant, or platform works. Query the public capability API for the extension and field in question, then validate the concrete file.

## How to read capability evidence

```swift
let extensionCapability = TagLibMetadataManager.capability(forExtension: url.pathExtension)
let concreteCapability = try TagLibMetadataManager.probeFile(at: url)
let fieldSupport = concreteCapability.writeSupport(for: .artwork)
```

- `capability(forExtension:)` returns the declared family without opening a file.
- `probeFile(at:)` opens and parses the concrete file, then returns the same declared family capability. It does **not** test POSIX write permission, ACLs, disk space, or sandbox access.
- `readSupport(for:)` and `writeSupport(for:)` combine the family flags, the field's schema mappings, artwork flags, and any explicit field allowlist.
- `structuredWriteSupport` describes non-artwork structured data. A `.propertyMap` level can still support structured artwork when `canWriteArtwork` is true.
- `preservesMultiValueProperties` is a family-level statement about repeated PropertyMap values, not a guarantee for every field.

### Support levels

| Level | Meaning |
| --- | --- |
| `fixtureCovered` | The repository contains a fixture and regression tests for this extension. It does not mean every alias or container-specific field is tested. |
| `experimental` | The format is available for evaluation, but container-specific field behavior is incomplete or not expected to round-trip fully. |
| `upstreamSupported` | TagLib exposes the format, but this package has no round-trip fixture for it. This is an unverified parser path, not evidence of correctness. |
| `readOnly` | Readable by the package, with no supported save path. |
| `unsupported` | No supported parser or field mapping exists. |
| `verified` | Deprecated; never returned by capability lookup. Use `fixtureCovered` or a concrete probe. |

The level is configured per extension. A family's `supportLevel` is derived from its primary extension, while `extensionSupportLevels` records each alias. For example, `m4a` is fixture-covered while `m4b`, `m4p`, and `mp4` are upstream-supported.

## Format matrix

The registry contains 22 families and 37 extensions. R/W means a save path exists; it does not mean every metadata surface is writable.

| Family | Extensions | R/W | Metadata containers | Structured read/write | Primary evidence | Notes |
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
| AIFF / AIFF-C | `aiff`, `aif`, `aifc`, `afc` | R/W | tag, PropertyMap, ID3v2, RIFF INFO | container / container | upstream-supported, with a generated PCM fixture and selected tests | Structured writes use ID3v2. The configured evidence label remains upstream-supported because the family lacks broad runtime coverage. |
| TrueAudio | `tta` | R/W | tag, PropertyMap, ID3v1, ID3v2 | container / container | fixture-covered | ID3v2 frames, comments, lyrics, artwork, and PropertyMap deltas. Mixed unmodeled APEv2 surfaces reject; see below. |
| ASF / WMA | `wma`, `asf` | R/W | tag, PropertyMap, ASF | container / container | `wma` fixture-covered; `asf` upstream-supported | ASF attributes preserve name, type, language, and stream identity. GUID attributes are inspection-only. |
| DSF | `dsf` | R/W | tag, PropertyMap, ID3v2 | container / propertyMap | fixture-covered | Structured reads expose native ID3 collections; structured writes are limited to PropertyMap deltas and artwork. |
| DSDIFF | `dff`, `dsdiff` | R/W | tag, PropertyMap, ID3v2 | container / propertyMap | `dff` fixture-covered; `dsdiff` upstream-supported | Same writer boundary as DSF. Uncompressed DSDIFF is tested; DST compression is not. |
| Shorten | `shn` | Read-only | tag, PropertyMap | propertyMap / none | read-only label | TagLib exposes metadata but has no save path. |
| MOD Tracker Module | `mod`, `module`, `nst`, `wow` | Read-only | tag, PropertyMap | propertyMap / none | read-only label | Metadata is limited to title, comment, and a format-derived tracker name. |
| Scream Tracker 3 | `s3m` | R/W (title, comment) | tag, PropertyMap | propertyMap / propertyMap | experimental | No runtime fixture. Fixed-width tracker storage can normalize text. |
| Impulse Tracker | `it` | R/W (title, comment) | tag, PropertyMap | propertyMap / propertyMap | experimental | No runtime fixture. Fixed-width tracker storage can normalize text. |
| FastTracker Module | `xm` | R/W (title, comment, tracker name) | tag, PropertyMap | propertyMap / propertyMap | fixture-covered | Fixed-width instrument/sample fields can normalize comments and pad the tracker name. |

The fixture-covered set is exactly: `mp3`, `m4a`, `flac`, `ogg`, `oga`, `wav`, `aac`, `xm`, `tta`, `wv`, `wma`, `ape`, `mpc`, `dsf`, `dff`, `opus`. The experimental set is `s3m` and `it`. `shn` and the MOD family are read-only. Everything else that the registry lists is upstream-supported.

## Cross-format behavior

### Number pairs

- ID3-backed formats (MPEG/MP2, AAC, WAV, AIFF, TTA, DSF, DSDIFF) write combined `TRCK`/`TPOS`; movement number/count uses `MVIN`.
- MP4 uses native `trkn` and `disk` pairs.
- Generic PropertyMap and Xiph formats store separate `TRACKNUMBER`/`TRACKTOTAL` and `DISCNUMBER`/`DISCTOTAL` values.
- Track and disc components begin at one; `.remove` unsets a component. Removing a first component while retaining a total is rejected where the container cannot represent it (MPEG/ID3, AAC, MP4, WAV, AIFF, TrueAudio, DSF, DSDIFF, ASF). Remove both components to clear the pair.
- On generic/Xiph formats, `BasicMetadata` number text displays the first component and normalizes total padding. The numeric pair and raw values remain authoritative; do not require a slash display there.
- Exact ID3 text writes preserve both components' padding where the native pair supports it. Numeric writers may normalize padding.

### Dates

| Semantic field | ID3v2 | Xiph/PropertyMap | MP4 |
| --- | --- | --- | --- |
| `.date` (recording date or year) | `TDRC`; legacy `TYER` is read-compatible | `DATE`; `YEAR` is an alias | Unsupported for typed writes |
| `.releaseDate` | `TDRL` | `RELEASEDATE` | `©day` |
| `.originalReleaseDate` | `TDOR` | `ORIGINALDATE` / `ORIGINAL YEAR` | `ORIGINAL YEAR` freeform |

MP4 has one standard date atom. A typed `.date` patch for MP4 fails before staging. `BasicMetadata.year` is a compatibility projection; `updateBasicMetadata` reconciles single-field year/releaseDate edits, while a full replacement must provide consistent projections or it throws `MetadataValidationError.conflictingMP4Date`.

### Advisory

`ExplicitAdvisory` has four states: absent, not explicit, explicit, and clean. MP4 uses absent / `rtng = 0` / `1` / `2`. ID3 and generic PropertyMap formats use `ITUNESADVISORY` with `0`, `1`, and `2`. Legacy MP4 value `4` and legacy text forms remain readable; high-level writes emit canonical values.

### Multi-value fields

`BasicMetadata` scalar text fields are display projections. ID3 generally joins values with `", "`; MP4 artist/genre and generic/Xiph projections use `"; "`, while some native MP4 fields and freeforms use `", "`. Use raw or structured metadata when arrays are authoritative.

## Format-specific limitations

### ID3v2 and mixed tag surfaces

- `APIC`, `COMM`, and `USLT` are not exposed as editable entries in `id3v2Frames`. Use the dedicated artwork, comments, and lyrics collections instead.
- Typed Patch edits to `.comment` and `.lyrics` own the complete represented scalar collection, including qualified descriptions and languages. Raw patches remain key-specific.
- Creating the first preferred ID3v2 tag on an ID3v1-only MPEG or TrueAudio file promotes the visible legacy fields before saving. Secondary on-disk tags remain intact.
- A mixed TrueAudio file with unmodeled APEv2 fields rejects before commit because the pinned handler cannot reconcile both surfaces. Encoder-only APEv2 provenance is preserved. Reconcile the secondary tag with an APE-aware tool before editing.

### MP4

- Raw PropertyMap APIs accept prefixless TagLib keys, not native `----:` atom identifiers. Use `StructuredMetadata.mp4Atoms` for exact, case-sensitive freeform keys.
- Native `trkn`/`disk` are authoritative. Recognized number aliases are cleaned up when the corresponding pair changes; unrelated Basic edits preserve them.
- Native advisory is `rtng`; recognized freeform aliases (`ITUNESADVISORY`, `ADVISORY`, `EXPLICITCONTENT`, `EXPLICIT`) are removed when the advisory changes.
- `.date` is unsupported for typed writes. Use `.releaseDate` or `updateBasicMetadata`.

### WAV, AIFF, and RIFF INFO

- Basic, typed Patch, and structured WAV writes target ID3v2 and leave RIFF INFO untouched unless `riffPolicy: .id3v2Only` is selected.
- Raw PropertyMap edits follow key ownership: existing INFO keys update INFO, ID3v2 keys update ID3v2, and new keys go to ID3v2.
- `.preserveInfo` is the default. `.id3v2Only` writes ID3v2 and then removes RIFF INFO. `.syncBasicFieldsToInfo` is reserved and rejects before staging.
- A verified deletion that would expose retained INFO fallback is rejected; use a raw deletion to clear both surfaces.
- AIFF/AIFF-C have a generated PCM fixture and focused tests, but the family label remains upstream-supported.

### APE-family (APE, WavPack, Musepack)

- Structured writes support one front-cover image. Existing back artwork is read and preserved during unrelated edits; `removeAll` clears both roles.
- APE items are surfaced through PropertyMap; there is no separate item-level structured mutation API.
- Unchanged native `Date`/`Year` spelling is preserved through number, Basic, and raw delta replay.

### ASF/WMA

- Structured attributes preserve name, type, language, and stream identity.
- Common ASF fields duplicated as custom attributes are treated as semantic aliases and cleared only when the corresponding common field changes. Unrelated attributes such as `PUBLISHER` are preserved.
- `int` projects WORD and DWORD. An update retains an existing unambiguous native width; a new attribute uses DWORD. A WORD overflow or ambiguous same-identity WORD/DWORD update rejects.
- GUID attributes are inspection-only with the pinned encoder. Omit them from write payloads to preserve them; they are never silently encoded as binary.
- ASF structured attributes are upserts, not replace-all collections, and have no individual deletion operation. Verified full erase clears the complete native attribute and picture map.
- Normalized number writers persist totals inside `WM/TrackNumber` and `WM/PartOfSet` text pairs.

### DSD (DSF, DSDIFF)

- Structured reads expose native ID3v2 frames, comments, lyrics, artwork, and opaque frames.
- Structured writes are PropertyMap deltas and artwork. Replacing native ID3 frame/comment/lyric collections through the structured writer is unsupported.
- A Basic edit that would require replaying existing DSD comments or lyrics rejects safely rather than normalizing them. Use a raw delta for an unrelated field.
- DSDIFF tests cover uncompressed DSD; DST-compressed DSDIFF is not verified.

### Tracker modules

- MOD is read-only. S3M and IT are experimental and limited to title/comment. XM is fixture-covered and limited to title/comment/tracker name.
- Fixed-width storage can normalize text; no artwork path exists.
- These labels are not runtime proof for arbitrary tracker files.

### Audio properties

`BasicMetadata` reports duration, bitrate, sample rate, channels, bit depth, and format from TagLib's available properties. Zero or an empty value means the parser did not expose it. Bit depth is a declared/available sample width, not evidence that a codec is lossless; this is especially important for compressed ASF audio. Ogg FLAC, APE, WavPack, and ASF project available bits-per-sample where TagLib exposes them.

### Source-only families

Speex, S3M, IT, Shorten, MOD, uncommon aliases, minimum-OS runtime, device runtime, and x86_64 runtime lack runtime verification in this repository. Do not present their configured labels as tested behavior.

## Fixtures and independent evidence

Fixture provenance, hashes, and licensing are in [Tests/TagLibAudioMetadataTests/Audio/README.md](../Tests/TagLibAudioMetadataTests/Audio/README.md). Highlights:

- Generated PCM tones cover AAC, FLAC, M4A (AAC and ALAC), MP3, Ogg Vorbis, Opus, WAV, ASF/WMA, TrueAudio, WavPack, XM, and AIFF.
- Pinned upstream files cover DSF, DSDIFF, APE, Musepack, Ogg FLAC, and XM.
- `info-only.wav` protects RIFF INFO visibility after ID3v2 creation.
- `clean-room.aiff` is generated PCM with one `COMM` and one `SSND` chunk.
- Independent oracles include a RIFF INFO parser, ID3v2 frame parser, MP4 atom parser, APEv2 parser, bounded ASF parser, FFprobe/FFmpeg packet comparison, and generated corpus checks. See [TESTING](TESTING.md) and the historical verification records.

Fixture coverage is finite. It does not establish universal codec conformance, every metadata variant, or every platform runtime.
