# Format capability and limitations

This is the canonical reference for declared format coverage. It describes the capability registry in `Sources/CTagLibBridge/TLFormatRegistry.mm`, the container masks in `Sources/CTagLibBridge/Internal/TLMetadataCore.inc`, the evidence labels and field allowlists in `Sources/CTagLibBridge/Internal/TLRawInspection.inc`, and the field schema in `Sources/TagLibAudioMetadata/MetadataFieldSchema.swift`.

Version `0.7.2` is the latest published tag; it finalized the audit and native-mapping repairs that followed `0.7.1`. The current branch adds unreleased native-owner state preservation and applies the same capability registry. The package side of mapping contract `AM-TLAM-MAPPING-2.2` was introduced in `0.7.0`. The matrix below is generated from the source registry. A declared label is not proof that every file, field, codec variant, or platform works: query the capability API for the extension and field in question, then validate a concrete file.

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
| `supportLevel` | Evidence level for the capability's requested extension, or the primary extension for `formatCapabilities`. |
| `supportLevel(forExtension:)` | Evidence level for another alias in the same family. |
| `readSupport(for:)` / `writeSupport(for:)` | Family flags, field mappings, artwork flags, explicit allowlists, schema-level withholding, and primary-native-family capability. A secondary readable tag surface does not authorize a semantic write. This is a declared capability, not a typed-write promise; `.rate` is read-only despite having a readable mapping, and a concrete ID3v2.3 tag must be checked for date editability. |
| `canWriteArtwork` | Artwork write availability; separate from `structuredWriteSupport`. |
| `structuredReadSupport` / `structuredWriteSupport` | Non-artwork structured frames, atoms, and attributes. A `.propertyMap` level can still support structured artwork. |
| `preservesMultiValueProperties` | Family-level repeated-`PropertyMap` support, not a per-field guarantee. |
| `readableFields` / `writableFields` | Optional explicit allowlists; `nil` means infer from schema mappings. Currently used by tracker formats. |
| `metadataFieldFormats` | Derived from declared containers: always includes `.tagLibPropertyMap`; adds `.id3v2`, `.mp4`, `.xiph`, `.ape`, and `.asf` when those container names are present; adds `.flac` for the FLAC family. It does not add `.riffInfo` or `.matroska`, so RIFF INFO and Matroska query paths require the raw/structured APIs. |

### Evidence levels

| Level | Meaning |
| --- | --- |
| `fixtureCovered` | The repository contains a fixture and regression tests for this extension. Not every alias, field, or codec variant is tested. |
| `experimental` | Available for evaluation, but container-specific behavior is incomplete. |
| `upstreamSupported` | TagLib exposes the format, but this package has no round-trip fixture for it. Treat it as an unverified parser path. |
| `readOnly` | Readable by the package, with no supported save path. |
| `unsupported` | No supported parser or field mapping exists. |
| `verified` | Deprecated spelling; never returned by capability lookup. Use `fixtureCovered` or a concrete probe. |

The level is configured per extension. For a capability from `capability(forExtension:)`, `supportLevel` is the level of that extension; `formatCapabilities` uses the primary extension. Use `extensionSupportLevels` or `supportLevel(forExtension:)` to compare aliases.

## Format matrix

<!-- BEGIN GENERATED FORMAT MATRIX -->
<!-- Generated from TLFormatRegistry.mm, TLMetadataCore.inc, and TLRawInspection.inc. -->

The registry contains 22 families and 37 extensions. R/W means a declared save path exists; it does not promise every metadata surface or every file layout. Artwork R/W is independent of non-artwork structured support.

| Evidence level | Families |
| --- | --- |
| `fixtureCovered` | 16 |
| `experimental` | 2 |
| `upstreamSupported` | 2 |
| `readOnly` | 2 |

| Family (identifier) | Extensions | R/W | Declared containers | Structured read/write | Primary evidence | Artwork | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| MPEG Audio / ID3 (`mpeg-id3`) | `mp3`, `mp2` | R/W | tag, propertyMap, id3v1, id3v2, ape | container / container | fixtureCovered | R/W | ID3v2 is the preferred rich metadata container; ID3v1 is treated as a low-fidelity fallback. |
| Raw AAC (`mpeg-aac`) | `aac` | R/W | tag, propertyMap, id3v2 | container / container | fixtureCovered | R/W | Raw AAC uses MPEG ID3v2 frames, comments, lyrics, artwork, and PropertyMap deltas. |
| MP4 / MPEG-4 Audio (`mp4`) | `m4a`, `m4r`, `m4b`, `m4p`, `mp4`, `m4v`, `3g2` | R/W | tag, propertyMap, mp4 | container / container | fixtureCovered | R/W | MP4 atoms and iTunes freeform atoms are exposed for structured editing. |
| FLAC (`flac`) | `flac` | R/W | tag, propertyMap, xiph, id3v1, id3v2 | container / propertyMap | fixtureCovered | R/W | Structured reads expose FLAC pictures; structured writes support PropertyMap deltas and complex-property artwork. |
| Ogg Vorbis (`ogg-vorbis`) | `ogg` | R/W | propertyMap, xiph | container / propertyMap | fixtureCovered | R/W | Xiph comments preserve repeated PropertyMap values. |
| Ogg Opus (`ogg-opus`) | `opus` | R/W | propertyMap, xiph | container / propertyMap | fixtureCovered | R/W | Xiph comments preserve repeated PropertyMap values. |
| Ogg FLAC (`ogg-flac`) | `oga` | R/W | propertyMap, xiph | container / propertyMap | fixtureCovered | R/W | Xiph comments preserve repeated PropertyMap values. |
| Ogg Speex (`ogg-speex`) | `spx` | R/W | propertyMap, xiph | container / propertyMap | upstreamSupported | R/W | Xiph comments preserve repeated PropertyMap values. |
| Monkey's Audio (`ape`) | `ape` | R/W | tag, propertyMap, ape | propertyMap / propertyMap | fixtureCovered | R/W | APE item metadata is currently surfaced through PropertyMap values. |
| WavPack (`wavpack`) | `wv` | R/W | tag, propertyMap, ape | propertyMap / propertyMap | fixtureCovered | R/W | APE item metadata is currently surfaced through PropertyMap values. |
| Musepack (`musepack`) | `mpc` | R/W | tag, propertyMap, ape | propertyMap / propertyMap | fixtureCovered | R/W | APE item metadata is currently surfaced through PropertyMap values. |
| WAV / RIFF (`wav`) | `wav` | R/W | tag, propertyMap, id3v2, riffInfo | container / container | fixtureCovered | R/W | Structured writes use ID3v2; preserveInfo keeps RIFF INFO, id3v2Only removes it. |
| AIFF (`aiff`) | `aiff`, `aif`, `aifc`, `afc` | R/W | tag, propertyMap, id3v2, riffInfo | container / container | upstreamSupported | R/W | Structured writes use ID3v2. |
| TrueAudio (`trueaudio`) | `tta` | R/W | tag, propertyMap, id3v1, id3v2 | container / container | fixtureCovered | R/W | Structured reads and writes support ID3v2 frames, comments, lyrics, artwork, and PropertyMap deltas. |
| ASF / WMA (`asf`) | `wma`, `asf` | R/W | tag, propertyMap, asf | container / container | fixtureCovered | R/W | ASF attributes are exposed for structured editing. |
| DSF (`dsf`) | `dsf` | R/W | tag, propertyMap, id3v2 | container / container | fixtureCovered | R/W | DSF uses ID3v2 tags internally; structured editing supports ID3 frame upserts, PropertyMap deltas and artwork; comment/lyric collection replacement is unsupported. |
| DSDIFF (`dsdiff`) | `dff`, `dsdiff` | R/W | tag, propertyMap, id3v2 | container / container | fixtureCovered | R/W | DSDIFF uses ID3v2 tags internally; structured editing supports ID3 frame upserts, PropertyMap deltas and artwork; comment/lyric collection replacement is unsupported. |
| Shorten (`shorten`) | `shn` | read-only | tag, propertyMap | propertyMap / none | readOnly | — | Read-only format. |
| MOD Tracker Module (`mod`) | `mod`, `module`, `nst`, `wow` | read-only | tag, propertyMap | propertyMap / none | readOnly | — | Read allowlist: title, comment, trackerName. MOD metadata is limited to title, comment, and a format-derived tracker name. |
| Scream Tracker 3 Module (`s3m`) | `s3m` | R/W | tag, propertyMap | propertyMap / propertyMap | experimental | — | Read allowlist: title, comment, trackerName. Write allowlist: title, comment. Writes are limited to title and comment; fixed-width tracker storage may normalize text. |
| Impulse Tracker Module (`it`) | `it` | R/W | tag, propertyMap | propertyMap / propertyMap | experimental | — | Read allowlist: title, comment, trackerName. Write allowlist: title, comment. Writes are limited to title and comment; fixed-width tracker storage may normalize text. |
| FastTracker Module (`xm`) | `xm` | R/W | tag, propertyMap | propertyMap / propertyMap | fixtureCovered | — | Read allowlist: title, comment, trackerName. Write allowlist: title, comment, trackerName. Writes are limited to title, comment, and tracker name; fixed-width instrument/sample fields normalize comment text and may pad the tracker name. |
<!-- END GENERATED FORMAT MATRIX -->

## Cross-format behavior

### Number pairs

| Storage family | Track/disc representation |
| --- | --- |
| ID3-backed: MPEG/MP2, raw AAC, WAV, AIFF/AIFF-C, TrueAudio, DSF, DSDIFF | Combined `TRCK` / `TPOS`; movement number/count uses `MVIN`. Standalone `TXXX:TRACKTOTAL`, `TXXX:TOTALTRACKS`, `TXXX:DISCTOTAL`, and `TXXX:TOTALDISCS` are readable legacy aliases. |
| MP4 | Native `trkn` / `disk` integer pairs. `----:com.apple.iTunes:TRACKTOTAL` and sibling freeforms are legacy aliases, never the write target. |
| MP4 movement | Independent integer atoms `©mvi` / `©mvc`; movement is not a shared `trkn`-style pair. |
| FLAC, Ogg Vorbis/Opus/FLAC/Speex | Separate `TRACKNUMBER` / `TRACKTOTAL` and `DISCNUMBER` / `DISCTOTAL` keys. |
| APE, WavPack, Musepack | Separate `TRACK` / `TRACKTOTAL` and `DISC` / `DISCTOTAL` keys. |
| ASF | `WM/TrackNumber` and `WM/PartOfSet` text pairs; normalized writers combine `number/total` in the native attribute. |

- Track and disc components begin at one. `.remove` unsets a component; BPM and movement numbering begin at zero. MP4 track/disc native pairs accept components through the full unsigned 16-bit maximum `65535`, with `0` reserved for a retained-total sentinel; a present component starts at one. MP4 movement values are bounded to `0...32767` and reject before staging when outside the range.
- Removing a first component while retaining a total is supported on MP4 (`0/total` sentinel), ID3-backed formats (`/total` text), and separate-key Xiph/APE layouts. **ASF rejects a number-zero-plus-total request** because its number codec has no verified total-only representation. Remove both components to clear an ASF pair.
- Native positive components are authoritative. A sole valid orphan total is exposed as `.recoveredLegacy` by `numberingInventory(at:)`; contradictory or malformed aliases are `.ambiguous`/`.invalid`.
- A typed pair edit resolves the untouched component, writes the native pair, and retires only the touched group's recognized aliases. Unrelated Basic edits preserve orphan totals and private provenance.
- Exact MP4 text padding has no standard portable representation. `numberText` and `writeTrackNumberText` write the native pair and report the normalized display; they never create private atoms.

### Dates

| Semantic field | ID3v2.3 | ID3v2.4 | MP4 | Xiph/APE | ASF | RIFF INFO |
| --- | --- | --- | --- | --- | --- | --- |
| `.year` (canonical YEAR) | `TYER (read)` | `TDRC` | `©day` | `YEAR` | `WM/Year` | `ICRD` |
| `.date` (legacy YEAR spelling) | `TYER (read)` | `TDRC` | `©day` | `YEAR` | `WM/Year` | `ICRD` |
| `.standaloneDate` | `TDAT (read)` | `TXXX(DATE)` | `DATE` freeform | `DATE` | `DATE` extension | — |
| `.releaseDate` | `EXTFRAME(TDRL) (read)` | `TDRL` | `RELEASEDATE` freeform | `RELEASEDATE` | — | — |
| `.originalReleaseDate` | `TORY` (read; year only) | `TDOR` | `ORIGINALDATE` freeform | `ORIGINALDATE` | `WM/OriginalReleaseYear` | — |

YEAR, DATE, RELEASEDATE, and ORIGINALDATE are independent. `BasicMetadata.year` is complete stored text, not a four-character projection. MP4 `©day` is the YEAR slot; a release date lives in the `RELEASEDATE` freeform, never `©day`. Changing or clearing one date field never rewrites another. `MetadataValidationError.conflictingMP4Date` remains only for source compatibility and is not thrown by current writers.

`.date` writes the same YEAR targets as `.year` where that target is writable; it is a legacy API spelling, not a standalone DATE and not an `@available`-deprecated enum case. Do not supply both in one patch. Existing ID3v2.3 tags are read-only for all independent date writes: typed patches reject before staging, and a Basic replacement rejects when a date value changes. Read `StructuredMetadata.id3v2MajorVersion` before presenting date editability for a concrete file; an extension-level ID3v2 capability may reflect the verified v2.4 codec. RIFF INFO has no native DATE key; WAV and AIFF/AIFF-C can still write `.standaloneDate` through their ID3v2 surface, but the value is not stored in INFO.

### Advisory

`ExplicitAdvisory` has four semantic states: absent (`unspecified`), present `0` (not explicit), present `1` (explicit), and present `2` (clean). Zero is a present value, not absence. MP4 uses native `rtng`; ID3 and generic text surfaces use `ITUNESADVISORY`. Unknown existing codes (for example MP4 `4`) are retained as `explicitAdvisoryRawValue` with `.unspecified` semantics; they are not recoded as explicit. The Boolean `explicitContent` projection is lossy and is not an instruction to rewrite an unknown source.

### Multi-value fields

`BasicMetadata` scalar text fields are display projections. ID3 generally joins values with `", "`; MP4 artist/genre and generic/Xiph projections use `"; "`, while some native MP4 fields and freeforms use `", "`. Use raw or structured metadata when arrays are authoritative. `RawPropertyEntry.values` and structured collection entries retain cardinality.

## Structured write surfaces

The capability level is not enough to know which structured collections a format accepts. The bridge dispatches by format:

| Format family | Properties | ID3v2 frames | MP4 atoms | ASF attributes | Lyrics/comments | Artwork |
| --- | --- | --- | --- | --- | --- | --- |
| MPEG/ID3, raw AAC | Yes | Yes (ID3 types) | — | — | Yes | Yes |
| MP4 | Yes | — | Yes | — | Structured collections are ignored; typed `.comment`/`.lyrics` patches use `©cmt`/`©lyr` | Yes (`covr`) |
| WAV, AIFF/AIFF-C | Yes | Yes | — | — | Yes | Yes |
| TrueAudio | Yes | Yes | — | — | Yes | Yes |
| ASF/WMA | Yes | — | — | Yes | — | Yes |
| FLAC, Ogg Vorbis/Opus/FLAC/Speex | Yes | — | — | — | Structured `comments`/`lyrics` are rejected | Yes (complex pictures) |
| APE, WavPack, Musepack | Yes | — | — | — | Structured `comments`/`lyrics` are rejected | One front image |
| DSF, DSDIFF | Yes | Yes (upserts) | — | — | Rejected | Yes (ID3 picture path) |
| Shorten, MOD, S3M, IT, XM | Read-only or PropertyMap-only; no structured collections beyond the fallback delta | — | — | — | — | — |

For DSD, the descriptor reports `container` structured write support: native ID3 frame upserts, PropertyMap deltas and artwork are supported. Comment/lyric collection replacement remains unsupported. On MP4, a non-empty structured `comments` or `lyrics` array is not written; verification then fails if the caller expected those entries to persist. This does not limit the typed `.comment` and `.lyrics` fields, which use the native `©cmt` and `©lyr` atoms.

## Format-specific limitations

### ID3v2 and mixed tag surfaces

- `APIC`, `COMM`, and `USLT` are not exposed as editable entries in `id3v2Frames`. Use the dedicated artwork, comments, and lyrics collections.
- Typed Patch edits to `.comment` and `.lyrics` own the complete represented scalar collection, including qualified descriptions and languages. Raw patches remain key-specific.
- Creating the first preferred ID3v2 tag on an ID3v1-only MPEG or TrueAudio file promotes the visible legacy fields before saving. Secondary on-disk tags remain intact.
- A mixed TrueAudio file with unmodeled APEv2 fields rejects before commit because the pinned handler cannot reconcile both surfaces. Encoder-only APEv2 provenance is preserved. Reconcile the secondary tag with an APE-aware tool before editing.
- Opaque/unknown ID3 frames are inspection-only. Omit them from structured writes; omitted frames remain on disk.

### MP4

- Raw PropertyMap APIs accept prefixless TagLib keys, not native `----:` atom identifiers. Use `StructuredMetadata.mp4Atoms` for exact, case-sensitive freeform keys.
- Native `trkn`/`disk` are authoritative. Recognized number aliases are cleaned up when the corresponding pair changes; unrelated Basic edits preserve them. Movement Number/Count use independent `©mvi`/`©mvc` atoms and are bounded to `0...32767`; track/disc components accept the unsigned 16-bit maximum `65535`, with `0` reserved for a retained-total sentinel.
- Content Group (`©grp`), Grouping (`----:com.apple.iTunes:GROUPING`) and Work (`©wrk`) are independent; a missing Content Group does not fall back to Grouping. Encoded By (`©enc`) and Encoder Settings (`©too`) are independent native owners.
- Typed `.comment` and `.lyrics` patches use the ordinary `©cmt` and `©lyr` atoms; they are not routed through the ID3 qualified-comment path. Structured `comments`/`lyrics` collections remain a separate, unsupported surface on MP4.
- Unedited native date items are retained exactly through PropertyMap replay. A scalar engine `DATE` projection does not authorize creating, changing, or removing an independent `©day`, `DATE`, `RELEASEDATE`, or `ORIGINALDATE` owner.
- `.date` and `.year` both write `©day` (YEAR); `.standaloneDate` and `.releaseDate` use their freeform extensions. Supplying `.date` and `.year` together is rejected before staging.
- Native advisory is `rtng`; recognized freeform aliases (`ITUNESADVISORY`, `ADVISORY`, `EXPLICITCONTENT`, `EXPLICIT`) are removed when the advisory changes. `BasicMetadata` replacement also runs the canonical advisory writer, so MP4 freeform advisory aliases can be retired even when the caller did not edit the advisory projection.
- `covr` is returned both as an artwork entry and as a `coverArtList` MP4 atom. Use the artwork collection to replace it; `coverArtList` is inspection-only for direct atom writes.
- Structured atom writing supports `stringList`, `bool`, `int`, `uint`, `byte`, `longLong`, and `intPair`. Other item types are ignored by the writer; they are inspection-only.
- The `rate` atom is readable and preserved, but `.rate` has no preferred typed write target because no verified native rating type and scale are registered.

### WAV, AIFF, and RIFF INFO

- Basic and typed Patch WAV writes target ID3v2 and leave RIFF INFO untouched. Structured WAV writes use the `riffPolicy`: `.preserveInfo` (default) keeps INFO, `.id3v2Only` removes it after writing ID3v2, and `.syncBasicFieldsToInfo` is reserved and rejects before staging.
- Raw PropertyMap edits on WAV follow key ownership: existing INFO keys update INFO, ID3v2 keys update ID3v2, and new keys go to ID3v2.
- A verified deletion that would expose a retained INFO fallback is rejected; use a raw deletion to clear both surfaces.
- AIFF/AIFF-C structured writes use ID3v2. They have no RIFF INFO surface, so `.id3v2Only` has no additional effect there; `.syncBasicFieldsToInfo` still rejects as unsupported. The shared capability container mask still lists `riffInfo`; treat that entry as WAV-specific.
- `RIFFMetadataWritePolicy` is ignored by formats other than WAV and AIFF/AIFF-C. Passing `.syncBasicFieldsToInfo` to MP4, ASF, or Xiph does not throw, but it also does not synchronize anything.
- AIFF/AIFF-C have a generated PCM fixture and focused tests, but the family label remains `upstreamSupported`.

### APE-family (APE, WavPack, Musepack)

- Structured writes support one front-cover image. Existing back artwork is read and preserved during unrelated edits; `removeAll` clears both roles.
- APE items are surfaced through PropertyMap; there is no separate item-level structured mutation API.
- Unchanged native `Date`/`Year` spelling is preserved through number, Basic, and raw delta replay.
- Structured writes reject frames, MP4 atoms, ASF attributes, lyrics, and comments; only PropertyMap values and artwork are supported.

### ASF/WMA

- Structured attributes preserve name, type, language, and stream identity.
- Semantic custom fields use native Unicode attributes because TagLib's ASF PropertyMap cannot represent arbitrary attributes. A set, replace, or remove reconciles only the edited field's case aliases; unchanged attributes, Content Description fields, and the packet tail remain intact.
- Common ASF fields duplicated as custom attributes are treated as semantic aliases and cleared only when the corresponding common field changes. Unrelated attributes such as `PUBLISHER` are preserved.
- `int` projects WORD and DWORD. An update retains an existing unambiguous native width; a new attribute uses DWORD. A WORD overflow or an ambiguous same-identity WORD/DWORD update rejects.
- GUID attributes are inspection-only with the pinned encoder. Omit them from write payloads to preserve them; they are never silently encoded as binary.
- ASF structured attributes are upserts, not replace-all collections, and have no individual deletion operation. Verified full erase clears the complete native attribute and picture map.
- Normalized number writers persist totals inside `WM/TrackNumber` and `WM/PartOfSet` text pairs.
- A total-only ASF number pair (`number = 0`, `total > 0`) is unsupported and rejects before staging; remove both components to clear it.

### DSD (DSF, DSDIFF)

- Structured reads expose native ID3v2 frames, comments, lyrics, artwork, and opaque frames.
- Structured writes accept native ID3 frame upserts, PropertyMap deltas and artwork. Whole native frame collection replacement and comment/lyric collection replacement are unsupported.
- A Basic edit that would require replaying existing DSD comments or lyrics rejects safely rather than normalizing them. Use a raw delta for an unrelated field.
- DSDIFF tests cover uncompressed DSD; DST-compressed DSDIFF is not verified.

### Tracker modules

- MOD is read-only. S3M and IT are experimental: readable fields are `title`, `comment`, and `trackerName`; writable fields are `title` and `comment` only. XM is fixture-covered and additionally allows `trackerName` writes.
- `BasicMetadata` has no `trackerName` property; use `MetadataPatch(fields: [.trackerName: ...])` or structured properties where the capability allows it.
- Fixed-width storage can normalize text; no artwork path exists.
- These labels are not runtime proof for arbitrary tracker files.

### Audio properties

`BasicMetadata` reports duration, bitrate, sample rate, channels, bit depth, and format from TagLib's available properties. Zero or an empty value means the parser did not expose it. Bit depth is a declared/available sample width, not evidence that a codec is lossless; this is especially important for compressed ASF audio. Ogg FLAC, APE, WavPack, and ASF project available bits-per-sample where TagLib exposes them.

### Source-only or unverified families

Speex, S3M, IT, Shorten, MOD, uncommon aliases, minimum-OS runtime, device runtime, and x86_64 runtime lack runtime verification in this repository. Do not present their configured labels as tested behavior. Shorten and MOD are additionally read-only.

## Audio-content identity availability

`MetadataAudioContentIdentity` is available only for native FLAC and single-data-chunk RIFF WAVE / AIFF / AIFF-C layouts. It is unavailable for MP3, MP4/M4A, raw AAC, Ogg/Opus, ASF, APE, WavPack, Musepack, TrueAudio, DSD, tracker formats, RF64, RIFX, leading-ID3 FLAC, and ambiguous chunk layouts. See [Audio-content continuity](../explanation/AUDIO_CONTENT_CONTINUITY.md).

## Fixtures and independent evidence

Fixture provenance, hashes, and licensing are in [Tests/TagLibAudioMetadataTests/Audio/README.md](../../Tests/TagLibAudioMetadataTests/Audio/README.md). Highlights:

- Generated PCM tones cover AAC, FLAC, M4A (AAC and ALAC), MP3, Ogg Vorbis, Opus, WAV, ASF/WMA, TrueAudio, WavPack, XM, and AIFF.
- Pinned upstream files cover DSF, DSDIFF, APE, Musepack, and Ogg FLAC.
- `info-only.wav` protects RIFF INFO visibility after ID3v2 creation.
- `clean-room.aiff` is generated PCM with one `COMM` and one `SSND` chunk.
- Independent oracles include bounded RIFF INFO, ID3v2, MP4 atom, APEv2, Ogg comment/packet, FLAC metadata-block, and ASF parsers, plus independent MP4/FLAC/ID3 lifecycle matrices. Fixture acquisition and historical verification campaigns used FFprobe/FFmpeg; those tools are not invoked by the current test suite. See [Testing](../operations/TESTING.md), [Mapping test acceptance](../operations/MAPPING_TEST_STRATEGY.md), and the historical verification records.

Fixture coverage is finite. It does not establish universal codec conformance, every metadata variant, or every platform runtime.

## Related references

- [Field reference](FIELDS.md) — semantic keys and exact native targets.
- [Mapping contract](MAPPING_SPEC.md) — native mapping policy and generated matrix.
- [Capabilities guide](../guide/CAPABILITIES.md) — querying support from application code.
- [Write semantics](../explanation/PRESERVATION.md) — preservation and verification.
- [Mapping test acceptance](../operations/MAPPING_TEST_STRATEGY.md) — lifecycle evidence and gate limits.
