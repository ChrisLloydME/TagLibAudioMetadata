# Troubleshooting

This document covers common problems encountered when using `TagLibAudioMetadata` and how to diagnose them.

---

## 1. Metadata writes successfully but does not appear in another app

### Symptoms
- `writeMetadataWithVerification` completes without errors and `warnings` is empty.
- The change is visible when re-read with `readMetadataResult`, but another app (e.g., Apple Music, VLC, Finder tags) shows old or no values.

### Likely causes and remedies

**The other app caches metadata in its own database.**  
Most media players maintain an internal database that is separate from the file's on-disk tags. After writing, re-import or rescan the file in the other app, or remove it from the library and re-add it.

For Apple Music specifically, after modifying a file's tags externally:
1. Right-click the track in Music.app → Get Info to force a re-read, or
2. Remove the track from the library and re-add it.

**The file was written to a copy but the player is watching the original.**  
Verify that `url` points to the file that the player has indexed.

**The container uses a different tag chunk than the player prefers.**  
For WAV files, Apple Music and many players prefer RIFF INFO over ID3v2. This bridge writes to the ID3v2 chunk and preserves RIFF INFO (`StripNone`). If the player shows the RIFF INFO values but ignores the ID3v2 chunk, you may see stale values. Use `rawMetadataText(from: url)` or `readStructuredMetadataResult(from: url)` to inspect both containers.

**The field is format-specific and the player maps it differently.**  
Confirm that the player and this bridge agree on which PropertyMap key or atom carries the field. Use `rawMetadataResult(from:)` to see what was actually written.

---

## 2. Some fields are missing after reading

### Symptoms
- `BasicMetadata.albumArtist` is `""` even though the file has an album artist tag.
- A MusicBrainz ID read from one tool appears empty in `BasicMetadata`.

### Diagnosis

```swift
let dump = try TagLibMetadataManager.rawMetadataResult(from: url)
for prop in dump.properties {
    print("\(prop.key) = \(prop.value)")
}
for frame in dump.id3v2Frames {
    print("\(frame.frameID) [\(frame.description ?? "")] = \(frame.value)")
}
```

If the field appears in the raw dump but not in `BasicMetadata`, the bridge may be using a different key alias than what is stored in the file.

For MusicBrainz fields, Picard and other taggers may use the space-separated form (`MUSICBRAINZ ARTIST ID`) while the bridge also recognizes the underscore form (`MUSICBRAINZ_ARTISTID`). Both aliases are in `MetadataFieldRegistry`. If neither appears in `rawMetadataResult`, the tagger may be writing the field under a non-standard key.

For album artist specifically:
- ID3v2: `TPE2`
- MP4: `aART`
- Xiph/APE/ASF: `ALBUMARTIST` or `ALBUM ARTIST`

If the raw dump shows `ALBUM ARTIST` (with a space), `BasicMetadata.albumArtist` should still be populated because the bridge recognizes both forms. If not, enable debug logging (`AUDIOMATOR_TAGLIB_DEBUG=1`) and check whether TagLib is reading the field.

### Known normalization gap

TagLib normalizes some field names when building the PropertyMap. Fields written by other tools using non-standard keys may appear in the raw ID3v2 frames list but not in the PropertyMap. Check both `dump.properties` and `dump.id3v2Frames`.

---

## 3. Artwork fails for certain formats

### Symptoms
- `BasicMetadata.artworkData` is `nil` after reading a file that visually shows artwork in another app.
- `writeMetadataWithVerification` reports an artwork verification warning even though artwork was provided.

### Check format capability

```swift
let cap = TagLibMetadataManager.formatCapability(for: url.pathExtension)
print(cap?.canReadArtwork)   // false for shn, mod, s3m, it, xm
print(cap?.canWriteArtwork)  // false for shn, mod, s3m, it, xm
```

Tracker formats (MOD, S3M, IT, XM) and Shorten do not support artwork. The capability table is the authoritative source.

### FLAC — PICTURE blocks versus embedded ID3v2

FLAC files can contain both a native PICTURE metadata block and an embedded ID3v2 block (if the file was incorrectly tagged by some tools). The bridge reads artwork from the native FLAC PICTURE block first. If artwork appears in another app but `artworkData` is nil, the file may have artwork only in an embedded ID3v2 block.

Use `readStructuredMetadataResult(from:)` to inspect both:

```swift
let structured = try TagLibMetadataManager.readStructuredMetadataResult(from: url)
for art in structured.artwork {
    print("Container: \(art.container), MIME: \(art.mimeType), Size: \(art.data.count)")
}
```

### MP4 — cover art atom

MP4 cover art is stored in the `covr` atom. If the `covr` atom is absent but the file shows artwork in iTunes, the artwork may be stored in an older metadata format or a non-standard freeform atom. `rawMetadataResult(from:)` will show the raw PropertyMap but may not expose non-standard atoms; use `readStructuredMetadataResult(from:)` to inspect the MP4 item map.

### ASF / WMA — WM/Picture

WMA artwork is stored in the `WM/Picture` ASF attribute. `readStructuredMetadataResult(from:)` exposes this in both `StructuredMetadata.asfAttributes` and `StructuredMetadata.artwork`. If `artworkData` is nil but `WM/Picture` appears in `asfAttributes`, the MIME type or picture data may have been stored in a format that the basic read path did not recognize.

### Artwork write verification warning

If writing artwork produces a warning like "Artwork was not confirmed after write":
- The format may report artwork through the structured path but not the basic read path.
- The file may be read-only at the file system level (check file permissions).
- The bridge performs artwork verification by checking whether `artworkData` is non-nil after re-reading. It does not compare image content byte-by-byte.

---

## 4. MP4 / M4A atom behavior

### Fields stored as freeform atoms

Many fields in MP4/M4A files that do not have a standard iTunes atom are stored as freeform atoms: `----:com.apple.iTunes:<KEY>`. MusicBrainz IDs, ReplayGain values, ISRC, and many custom fields use this form.

When reading raw metadata, these appear as keys like `----:com.apple.iTunes:MusicBrainz Artist Id`. The bridge normalizes these through `MetadataFieldRegistry` and populates the corresponding `BasicMetadata` fields.

When writing custom fields via `BasicMetadata.customFields`, the bridge writes them as `----:com.apple.iTunes:<key>`. The verification layer normalizes `----:COM.APPLE.ITUNES:<key>` ↔ `<key>` when checking whether a field was written successfully.

### Unknown freeform atoms are preserved

The structured write path (`writeStructuredMetadataWithVerification`) preserves freeform atoms that are not part of the write payload. If you write only `properties` and `mp4Atoms` but leave `id3v2Frames` empty, any existing `TXXX` frames (if present in an embedded ID3v2 block) are preserved.

### `rtng` (explicit content) integer normalization

The MP4 `rtng` atom is a typed integer. Values: `4` = explicit, `2` = clean/non-explicit, `0` = unset. Other apps may use `1` for explicit. The bridge treats `4` and `1` as `true` (explicit); `2` as `false` (non-explicit). If a file has `rtng = 1` and is re-read, `BasicMetadata.isExplicit` will be `true`. If the bridge then writes the field with `4`, a subsequent read by another tool expecting `1` may display it differently. This is implementation-dependent behavior across apps.

---

## 5. ID3v1 vs ID3v2 priority

### How TagLib handles both

TagLib reads ID3v1 and ID3v2 from the same MP3 file. For fields exposed through the standard `TagLib::Tag` interface, ID3v2 takes priority. For fields exposed through the `PropertyMap`, ID3v2 again takes priority. `RawMetadataDump.id3v2Frames` exposes ID3v2 frames directly.

### ID3v1 field limits

ID3v1 fields are truncated to fixed lengths (title/artist/album: 30 characters, year: 4 characters, comment: 28–30 characters, track: 1 byte). If `BasicMetadata.title` is longer than 30 characters and the file only has ID3v1 tags, it will be truncated. Always prefer ID3v2 for MP3 files.

### Removing ID3v1

The bridge does not currently expose a dedicated API to strip only the ID3v1 tag. `eraseAllMetadataWithVerification(from:)` clears both ID3v1 and ID3v2 content where TagLib's wipe path supports it.

### After writing, ID3v1 shows different data from ID3v2

If you write a long title via `BasicMetadata` and then open the file in an app that reads ID3v1 only, it will show the truncated version. This is expected behavior. If the value is critical, verify by checking `dump.id3v2Frames` rather than the native tag.

---

## 6. Sandbox and file permission issues

### Symptoms
- All APIs throw `TagLibManagerError.failedToReadWithUnderlying("...")` with a message about the file not being readable.
- Writes complete without error but the file on disk is unchanged.

### Diagnosis

Check that:
1. The file exists at the given URL.
2. The process has read (and for writes, write) permission to the file.
3. For sandboxed apps, a security-scoped URL bookmark has been started before calling the API.

```swift
// For sandboxed apps
let didStart = url.startAccessingSecurityScopedResource()
defer {
    if didStart { url.stopAccessingSecurityScopedResource() }
}

let metadata = try TagLibMetadataManager.readMetadataResult(from: url)
```

Enable debug logging (`AUDIOMATOR_TAGLIB_DEBUG=1`) to see whether TagLib attempts to open the file and what path it uses.

### macOS Music.app library files

Files inside the Music.app library folder may be protected by TCC (Transparency, Consent, and Control). The app requires the `com.apple.security.assets.music.read-write` entitlement or user permission via Privacy & Security settings to access them. Without it, open-panel-selected files via `NSOpenPanel` can be accessed with security-scoped bookmarks.

### iOS / iPadOS

On iOS, the package works with files in the app's Documents directory, iCloud Drive (with appropriate entitlements and security scope), or files provided through `UIDocumentPickerViewController` (which grants temporary security scope). Files in the system Music library are not directly accessible via file paths.

---

## 7. Code signing and binary linkage

### C++ standard library

The `CTagLibBridge` target uses C++20 (`gnucxx20`). The Swift Package Manager will compile the target with the appropriate toolchain. When integrating into an Xcode project, ensure that the deployment target is macOS 13+ or iOS 16+ as specified in `Package.swift`.

### No dynamic TagLib required

TagLib is statically compiled into the `CTagLibBridge` target. No separate TagLib dylib installation is needed. The package does not link against any system-provided TagLib.

### Linker settings

`CTagLibBridge` links `Foundation.framework` via the `linkerSettings` in `Package.swift`. No other external frameworks are required.

### App Store submission

The package uses standard C++ and Objective-C++ compiled from source. There are no precompiled binaries, no private APIs, and no dynamic libraries outside the Swift Package build. The package itself does not request any entitlements.

Compliance with the TagLib LGPL/MPL dual license is required. When distributing a compiled binary that includes TagLib source, review the LGPL-2.1 and MPL-1.1 requirements. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for a summary. When in doubt, consult legal counsel.

---

## 8. Verification warnings for expected behavior

Some verification warnings are expected and are not bugs:

| Warning text | Explanation |
| --- | --- |
| `"Track number formatting was normalized by the container"` | The container stored `01/12` as `1/12`. This is normal for formats that do not preserve zero padding in their native track frame (e.g., some MP4 atom implementations). |
| `"syncBasicFieldsToInfo is not yet implemented"` | The `RIFFMetadataWritePolicy.syncBasicFieldsToInfo` policy is defined but does not yet apply INFO sync. It will emit this warning and leave RIFF INFO unchanged. |
| `"Artwork was not confirmed after write"` | The bridge re-reads artwork by checking whether `artworkData` is non-nil. For some containers, artwork is written successfully but the basic read path does not expose it (e.g., it is in a structured PICTURE block). Use the structured read to confirm. |
| `"Custom field … was not found after write"` | The container may have renamed, normalized, or rejected the key. Use `rawMetadataResult(from:)` to inspect what was actually written. |

---

## 9. `RawPropertyMapWriteMode.replace` clears all existing tags

If you use `writeRawMetadataPropertyMapWithVerification(_:to:mode:.replace)` with a partial dictionary, all keys not in the dictionary are removed from the PropertyMap. This is the intended behavior of `.replace` mode.

To update only specific keys while leaving the rest intact, use `.merge` mode:

```swift
try TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification(
    ["TITLE": "New Title"],
    to: url,
    mode: .merge  // ARTIST, ALBUM, etc. are preserved
)
```

---

## 10. Enabling debug output

Set the environment variable `AUDIOMATOR_TAGLIB_DEBUG=1` in the process environment to enable bridge-level logging via `NSLog`. In Xcode:

1. Edit Scheme → Run → Arguments → Environment Variables.
2. Add `AUDIOMATOR_TAGLIB_DEBUG` with value `1`.

The debug output includes file open attempts, format detection, and write operation results.
