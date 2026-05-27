# TagLibAudioMetadata

`TagLibAudioMetadata` is a Swift Package for reading, writing, erasing, and
inspecting audio metadata through a bundled TagLib bridge. App code works with a
Swift facade instead of TagLib C++ APIs.

Use it when an app needs:

- Common tags such as title, artist, album, track and disc numbers, dates,
  artwork, MusicBrainz and AcoustID identifiers, classical fields, ReplayGain,
  iTunes fields, and custom fields.
- Raw TagLib `PropertyMap` access for advanced metadata editors.
- Container-aware structured metadata for ID3v2 frames, MP4 atoms, ASF
  attributes, lyrics, comments, and artwork.
- Format capability checks before enabling read, write, artwork, or structured
  editing controls.
- Post-write verification warnings when a container normalizes or drops data.

## Requirements

- Swift tools version 6.0
- macOS 13+
- iOS 16+
- GNU C++20, configured by `Package.swift`

## Installation

Add the package to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ChrisLloydME/TagLibAudioMetadata.git", branch: "main")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "TagLibAudioMetadata", package: "TagLibAudioMetadata")
        ]
    )
]
```

Then import the Swift facade:

```swift
import TagLibAudioMetadata
```

The Swift module re-exports the underlying `CTagLibBridge` target. Advanced
callers can reach `TagLibMetadataExtractor` and `TagLibAudioMetadata` after the
same import, but normal app code should start with `TagLibMetadataManager`.

## Quick Start

Read metadata with the throwing API:

```swift
let url = URL(fileURLWithPath: "/path/to/song.flac")

do {
    let metadata = try TagLibMetadataManager.readMetadataResult(from: url)
    print(metadata.title)
    print(metadata.artist)
    print(metadata.duration)
} catch TagLibManagerError.unsupportedFormat {
    print("Unsupported file format")
} catch {
    print("Could not read metadata: \(error)")
}
```

Write common metadata and inspect verification warnings:

```swift
var metadata = try TagLibMetadataManager.readMetadataResult(from: url)
metadata.title = "New Title"
metadata.artist = "New Artist"
metadata.track = 1
metadata.trackTotal = 12
metadata.trackNumberText = "01/12"

let result = try TagLibMetadataManager.writeMetadataWithVerification(
    metadata,
    to: url,
    failurePolicy: .warn
)

for warning in result.warnings {
    print("Metadata warning: \(warning)")
}
```

Check capabilities before showing editing controls:

```swift
if let capability = TagLibMetadataManager.formatCapability(for: url.pathExtension) {
    print(capability.isWritable)
    print(capability.canWriteArtwork)
    print(capability.structuredWriteSupport)
}
```

## Documentation

The current API guide lives in [docs/SUPPORT.md](docs/SUPPORT.md). It covers:

- Basic metadata reads and writes.
- Raw property map reads and writes.
- Structured metadata reads and writes.
- Format capability descriptors.
- Verification warnings and failure policies.
- Metadata erase behavior.
- Field registry usage.
- Low-level bridge APIs.
- Practical integration recipes.

License details for the vendored TagLib source are in
[docs/THIRD_PARTY_NOTICES.md](docs/THIRD_PARTY_NOTICES.md).

## Package Layout

| Target | Role |
| --- | --- |
| `TagLibAudioMetadata` | Swift facade for application code. |
| `CTagLibBridge` | Objective-C++ wrapper around vendored TagLib sources. |

The package vendors TagLib source directly inside `Sources/CTagLibBridge/taglib`.
No system TagLib installation or dynamic TagLib library is required.

## License

This package's Swift and Objective-C++ bridge code is released under the MIT
License. See [LICENSE](LICENSE).

The bundled TagLib library is dual-licensed under LGPL-2.1 and MPL-1.1. The
license texts are included at:

- `Sources/CTagLibBridge/taglib/COPYING.LGPL`
- `Sources/CTagLibBridge/taglib/COPYING.MPL`

Applications that distribute this package must comply with the MIT license for
the bridge code and either the LGPL-2.1 or MPL-1.1 terms for TagLib.
