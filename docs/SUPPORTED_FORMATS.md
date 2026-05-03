# Supported Formats

This document lists every audio format supported by the `TagLibAudioMetadata` package. The table is derived from the capability descriptors defined in `Sources/CTagLibBridge/TagLibMetadataExtractor.mm`. Always query `TagLibMetadataManager.formatCapability(for:)` at runtime for authoritative values; this document reflects the state of **TagLib 2.1.1** as vendored in this package.

---

## How to query support programmatically

```swift
// Check one extension
let readable = TagLibMetadataManager.isReadableFormat(url.pathExtension)
let writable = TagLibMetadataManager.isWritableFormat(url.pathExtension)

// Capability descriptor for one extension (case-insensitive, alias-aware)
if let cap = TagLibMetadataManager.formatCapability(for: url.pathExtension) {
    print(cap.canWriteArtwork)
    print(cap.preservesMultiValueProperties)
    print(cap.structuredWriteSupport)
}

// All families
let families = TagLibMetadataManager.formatCapabilities
```

---

## Format table

| Family ID | Display Name | Extensions | Metadata Containers | Read | Write | Artwork Read | Artwork Write | Multi-Value | Structured Read | Structured Write | Notes |
| --- | --- | --- | --- | :---: | :---: | :---: | :---: | :---: | --- | --- | --- |
| `mpeg-id3` | MPEG Audio / ID3 | `mp3`, `mp2` | ID3v1, ID3v2, PropertyMap, APE | ✅ | ✅ | ✅ | ✅ | ❌ | container | container | ID3v2 is the preferred rich metadata container. ID3v1 is treated as a low-fidelity fallback. ID3v1 stores only basic text fields in fixed-size ASCII. |
| `mpeg-aac` | Raw AAC | `aac` | PropertyMap | ✅ | ✅ | ✅ | ✅ | ❌ | propertyMap | propertyMap | Raw AAC uses the generic TagLib PropertyMap path for textual metadata. |
| `mp4` | MP4 / MPEG-4 Audio | `m4a`, `m4r`, `m4b`, `m4p`, `mp4`, `m4v`, `3g2` | PropertyMap, MP4 ItemMap | ✅ | ✅ | ✅ | ✅ | ❌ | container | container | MP4 atoms and iTunes freeform atoms (`----:com.apple.iTunes:…`) are exposed for structured editing. Unknown freeform atoms are preserved by default. |
| `flac` | FLAC | `flac` | PropertyMap, Xiph/Vorbis Comment, ID3v1, ID3v2 | ✅ | ✅ | ✅ | ✅ | ✅ | container | propertyMap | Structured reads expose FLAC PICTURE blocks. Structured writes fall back to PropertyMap values unless artwork is written through the basic API. Multi-value Vorbis comment fields are preserved. |
| `ogg-vorbis` | Ogg Vorbis | `ogg` | PropertyMap, Xiph/Vorbis Comment | ✅ | ✅ | ✅ | ✅ | ✅ | container | propertyMap | Xiph comments preserve repeated PropertyMap values. Use `writeRawMetadataPropertyMapValuesWithVerification` for multi-value round-trips. |
| `ogg-opus` | Ogg Opus | `opus` | PropertyMap, Xiph/Vorbis Comment | ✅ | ✅ | ✅ | ✅ | ✅ | container | propertyMap | Same Xiph comment behavior as Ogg Vorbis. |
| `ogg-flac` | Ogg FLAC | `oga` | PropertyMap, Xiph/Vorbis Comment | ✅ | ✅ | ✅ | ✅ | ✅ | container | propertyMap | Same Xiph comment behavior as Ogg Vorbis. |
| `ogg-speex` | Ogg Speex | `spx` | PropertyMap, Xiph/Vorbis Comment | ✅ | ✅ | ✅ | ✅ | ✅ | container | propertyMap | Same Xiph comment behavior as Ogg Vorbis. |
| `ape` | Monkey's Audio | `ape` | PropertyMap, APE Items | ✅ | ✅ | ✅ | ✅ | ✅ | propertyMap | propertyMap | APE item metadata is currently surfaced through PropertyMap values. |
| `wavpack` | WavPack | `wv` | PropertyMap, APE Items | ✅ | ✅ | ✅ | ✅ | ✅ | propertyMap | propertyMap | APE item metadata is currently surfaced through PropertyMap values. |
| `musepack` | Musepack | `mpc` | PropertyMap, APE Items | ✅ | ✅ | ✅ | ✅ | ✅ | propertyMap | propertyMap | APE item metadata is currently surfaced through PropertyMap values. |
| `wav` | WAV / RIFF | `wav` | PropertyMap, ID3v2, RIFF INFO | ✅ | ✅ | ✅ | ✅ | ❌ | container | container | Structured writes target ID3v2 and preserve existing RIFF INFO fields (`StripNone` policy). |
| `aiff` | AIFF | `aiff`, `aif`, `aifc`, `afc` | PropertyMap, ID3v2, RIFF INFO | ✅ | ✅ | ✅ | ✅ | ❌ | container | container | Structured writes use ID3v2. `aifc` and `afc` are aliases for the same format family. |
| `trueaudio` | TrueAudio | `tta` | PropertyMap, ID3v1, ID3v2 | ✅ | ✅ | ✅ | ✅ | ❌ | container | container | ID3v2 is used for rich structured metadata. |
| `asf` | ASF / WMA | `wma`, `asf` | PropertyMap, ASF Attributes | ✅ | ✅ | ✅ | ✅ | ❌ | container | container | ASF attributes are exposed with type information (string, bool, integer, binary, `WM/Picture`). Unknown attributes are preserved unless the caller explicitly writes the `asfAttributes` collection. |
| `dsf` | DSF | `dsf` | PropertyMap, ID3v2 | ✅ | ✅ | ✅ | ✅ | ❌ | propertyMap | propertyMap | DSF uses ID3v2 tags internally, but structured editing is currently limited to PropertyMap values. |
| `dsdiff` | DSDIFF | `dff`, `dsdiff` | PropertyMap, ID3v2 | ✅ | ✅ | ✅ | ✅ | ❌ | propertyMap | propertyMap | DSDIFF uses ID3v2 tags internally, but structured editing is currently limited to PropertyMap values. |
| `shorten` | Shorten | `shn` | PropertyMap | ✅ | ❌ | ❌ | ❌ | ✅ | propertyMap | none | **Read-only.** TagLib 2.1.1 exposes Shorten metadata for reading but does not support saving it. Attempting to write throws `TagLibManagerError.unsupportedFormat`. |
| `mod` | MOD Tracker Module | `mod`, `module`, `nst`, `wow` | PropertyMap | ✅ | ✅ | ❌ | ❌ | ❌ | propertyMap | propertyMap | Tracker metadata uses the generic PropertyMap path. Writable field set is narrow and format-dependent. |
| `s3m` | Scream Tracker 3 Module | `s3m` | PropertyMap | ✅ | ✅ | ❌ | ❌ | ❌ | propertyMap | propertyMap | Tracker metadata uses the generic PropertyMap path. |
| `it` | Impulse Tracker Module | `it` | PropertyMap | ✅ | ✅ | ❌ | ❌ | ❌ | propertyMap | propertyMap | Tracker metadata uses the generic PropertyMap path. |
| `xm` | FastTracker Module | `xm` | PropertyMap | ✅ | ✅ | ❌ | ❌ | ❌ | propertyMap | propertyMap | Tracker metadata uses the generic PropertyMap path. |

---

## Column definitions

| Column | Meaning |
| --- | --- |
| **Family ID** | Stable identifier returned by `FormatCapability.identifier`. Use this to identify a format family in code, not the primary extension. |
| **Extensions** | All file extensions that map to this format family. Lookups are case-insensitive. |
| **Metadata Containers** | The native metadata containers that TagLib parses for this format. |
| **Read** | `TagLibMetadataManager.isReadableFormat(_:)` returns `true`. |
| **Write** | `TagLibMetadataManager.isWritableFormat(_:)` returns `true`. |
| **Artwork Read** | `FormatCapability.canReadArtwork` is `true`. Embedded artwork will populate `BasicMetadata.artworkData` when present. |
| **Artwork Write** | `FormatCapability.canWriteArtwork` is `true`. Artwork in `BasicMetadata.artworkData` will be written to the file. |
| **Multi-Value** | `FormatCapability.preservesMultiValueProperties` is `true`. The container natively supports multiple values for the same key (Xiph/Vorbis comment fields, APE items). Use `writeRawMetadataPropertyMapValuesWithVerification` for these formats when multi-value fidelity matters. |
| **Structured Read** | `FormatCapability.structuredReadSupport`. `container` = container-native typed data is exposed; `propertyMap` = only PropertyMap-level data is available. |
| **Structured Write** | `FormatCapability.structuredWriteSupport`. `container` = container-native typed write is supported; `propertyMap` = write falls back to PropertyMap path. |

---

## Notes on specific formats

### MP3 / MPEG Audio — ID3v1 and ID3v2

TagLib reads both ID3v1 and ID3v2 when both are present in an MP3 file. ID3v2 takes priority for all fields exposed by `BasicMetadata` and `RawMetadataDump`. ID3v1 is a 128-byte fixed-size block that supports only: title (30 bytes), artist (30 bytes), album (30 bytes), year (4 bytes), comment (28–30 bytes), track number (1 byte in ID3v1.1), and genre (1-byte index). Any field that does not fit in these limits will be truncated by ID3v1 during a write. The bridge writes ID3v2 preferentially; ID3v1 is not updated by default.

### MP4 / M4A — atoms and freeform atoms

Standard iTunes atoms (e.g., `©nam`, `©ART`, `©alb`, `©day`) are stored as typed MP4 items. Fields that do not have a standard atom are stored as freeform atoms with the prefix `----:com.apple.iTunes:`. MusicBrainz IDs, AcoustID, ReplayGain, and many custom fields use freeform atoms when stored in M4A files. The structured write path preserves unknown freeform atoms by default unless the caller explicitly replaces the `mp4Atoms` collection.

### FLAC — PICTURE blocks

FLAC stores artwork as separate PICTURE metadata blocks alongside Vorbis comment fields. The structured read path (`readStructuredMetadataResult`) exposes PICTURE blocks in `StructuredMetadata.artwork`. Writing artwork through `BasicMetadata.artworkData` uses the basic write path. Structured writes fall back to PropertyMap values for textual metadata.

### WAV — ID3v2 and RIFF INFO coexistence

WAV files can contain both an ID3v2 chunk and RIFF INFO fields. The bridge writes metadata to the ID3v2 chunk and uses `StripNone` to leave existing RIFF INFO fields untouched. This means a WAV file may have different values in its ID3v2 chunk and its RIFF INFO block after a write that only targets ID3v2. Use `eraseAllMetadataWithVerification(from:)` if you need to clear both containers.

### ASF / WMA — typed attributes

ASF attributes have types (string, boolean, integer, binary, GUID). The structured read path exposes these types in `StructuredASFAttribute.type`. `WM/Picture` attributes are also surfaced in `StructuredMetadata.artwork`. Unknown ASF attributes are preserved unless the caller explicitly writes the `asfAttributes` collection.

### Shorten (`.shn`) — read-only

TagLib 2.1.1 can read Shorten file properties and a limited set of tags but does not support writing them. `TagLibMetadataManager.isWritableFormat("shn")` returns `false`. Any call to a write API with a `.shn` URL throws `TagLibManagerError.unsupportedFormat`.

### Tracker formats — limited field support

MOD, S3M, IT, and XM formats use the generic TagLib PropertyMap pipeline for write operations. The actual field set that TagLib preserves in these formats is narrow. Do not rely on round-trip fidelity for fields beyond basic title/artist/album text. There is no artwork support.

### DSF / DSDIFF — ID3v2 via PropertyMap

DSF and DSDIFF files store metadata in an embedded ID3v2 block. The bridge routes reads and writes through the TagLib PropertyMap path rather than exposing the ID3v2 structure directly. Structured metadata is limited to PropertyMap values for these formats.

---

## Matroska / WebM

Matroska/WebM support is not present in the vendored TagLib 2.1.1. It requires updating the vendored TagLib source before this bridge can expose it. `.mkv` and `.webm` are not in the supported extension list.
