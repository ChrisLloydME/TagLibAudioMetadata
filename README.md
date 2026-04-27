# TagLibAudioMetadata

Swift Package wrapper for the AudioMator TagLib metadata bridge.

## Usage

Add this package to a Swift project and import the Swift facade:

```swift
import TagLibAudioMetadata

let url = URL(fileURLWithPath: "/path/to/song.flac")

if let metadata = TagLibMetadataManager.readMetadata(from: url) {
    print(metadata.title)
}

do {
    let metadata = try TagLibMetadataManager.readMetadataResult(from: url)
    print(metadata.title)
} catch {
    print("Could not read metadata: \(error)")
}

var metadata = BasicMetadata.empty
metadata.title = "New title"
try TagLibMetadataManager.writeMetadata(metadata, to: url)
```

`readMetadata(from:)` is the compatibility API: it returns `nil` for unsupported
formats and read failures. Use `readMetadataResult(from:)` when callers need to
distinguish unsupported formats from actual read errors.

Raw property-map writes are replace-by-default:

```swift
try TagLibMetadataManager.writeRawMetadataPropertyMap(
    ["TITLE": "Replacement title"],
    to: url
)
```

Use merge mode when updating a subset of keys. Empty values remove matching keys.

```swift
let result = try TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification(
    ["TITLE": "Merged title", "COMMENT": ""],
    to: url,
    mode: .merge,
    failurePolicy: .throw
)

print(result.warnings)
```

The package exposes:

- `TagLibMetadataManager`: Swift read/write facade.
- `BasicMetadata`, `RawMetadataDump`, and related Swift value models.
- `TagLibMetadataExtractor` and `TagLibAudioMetadata` through the underlying ObjC++ bridge module.
