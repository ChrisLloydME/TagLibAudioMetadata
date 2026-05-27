# Integration Guide

This document describes how to use the `TagLibAudioMetadata` package safely in a macOS or iOS/iPadOS application.

---

## 1. Adding the package

In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ChrisLloydME/TagLibAudioMetadata.git", branch: "main"),
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "TagLibAudioMetadata", package: "TagLibAudioMetadata"),
        ]
    ),
]
```

In Xcode: **File → Add Package Dependencies**, paste the repository URL, and add `TagLibAudioMetadata` to your target.

Then import:

```swift
import TagLibAudioMetadata
```

---

## 2. Threading

**Rule: never call any `TagLibMetadataManager` or `TagLibMetadataExtractor` API on the main thread in a UI application.**

All APIs perform synchronous file I/O through the TagLib C++ library. The bridge does not dispatch internally, serialize across threads, or provide any async interface. Every read or write call blocks the calling thread for the duration of the operation.

Concurrent calls targeting the same file URL from different threads are not safe. The bridge does not hold a file lock during a write-verify cycle, so two callers targeting the same file can interleave. Callers are responsible for serializing access to any given file path.

### Recommended pattern — Swift Concurrency

Use `Task.detached` or a background actor to keep all file I/O off the main thread:

```swift
func readMetadataAsync(url: URL) async throws -> BasicMetadata {
    try await Task.detached(priority: .userInitiated) {
        try TagLibMetadataManager.readMetadataResult(from: url)
    }.value
}

func writeMetadataAsync(_ metadata: BasicMetadata, url: URL) async throws {
    try await Task.detached(priority: .userInitiated) {
        let result = try TagLibMetadataManager.writeMetadataWithVerification(metadata, to: url)
        if !result.warnings.isEmpty {
            // Handle warnings — log, surface to user, etc.
        }
    }.value
}
```

If your app targets Swift 6 strict concurrency, wrap the calls in a non-isolated context or use `@Sendable` closures and ensure that `BasicMetadata` values are not mutated concurrently (they are value types, so copies are safe).

### Recommended pattern — Grand Central Dispatch

```swift
let queue = DispatchQueue(label: "com.yourapp.metadata", qos: .userInitiated)

queue.async {
    do {
        let metadata = try TagLibMetadataManager.readMetadataResult(from: url)
        DispatchQueue.main.async {
            self.model = metadata
        }
    } catch {
        DispatchQueue.main.async {
            self.handleError(error)
        }
    }
}
```

### Verified writes add one extra I/O pass

`writeMetadataWithVerification`, `writeRawMetadataPropertyMapWithVerification`, and similar APIs perform a read-back after every write to detect container normalization. Each verified write costs approximately twice the I/O of an unverified write. For batch operations, consider passing `verifyAfterWrite: false` and running a separate verification pass after the batch completes.

---

## 3. Checking format support before use

Always check format support before attempting to read or write. An unsupported extension throws `TagLibManagerError.unsupportedFormat` from all throwing APIs and returns `nil` or `false` from all optional/Bool APIs.

```swift
guard TagLibMetadataManager.isReadableFormat(url.pathExtension) else {
    // Show "unsupported format" UI or skip the file
    return
}

// Before showing write controls:
let cap = TagLibMetadataManager.formatCapability(for: url.pathExtension)
let canWrite = cap?.isWritable ?? false
let canWriteArtwork = cap?.canWriteArtwork ?? false
let supportsMultiValue = cap?.preservesMultiValueProperties ?? false
```

`formatCapability(for:)` is case-insensitive and alias-aware: `"M4A"`, `"m4a"`, `"MP4"`, and `"mp4"` all return the same `FormatCapability` with `identifier == "mp4"`.

---

## 4. Reading metadata

For new code, use the throwing API:

```swift
do {
    let metadata = try TagLibMetadataManager.readMetadataResult(from: url)
    // Use metadata.title, metadata.artist, metadata.artworkData, etc.
} catch TagLibManagerError.unsupportedFormat {
    // Unsupported extension
} catch TagLibManagerError.failedToReadWithUnderlying(let message) {
    // TagLib could open the file but could not read metadata
    logger.error("Read failed: \(message)")
}
```

For code that does not need to distinguish error cases:

```swift
let metadata = TagLibMetadataManager.readMetadata(from: url) ?? BasicMetadata.empty
```

---

## 5. Writing metadata

### 5.1 Simple write with verification warnings

```swift
var metadata = try TagLibMetadataManager.readMetadataResult(from: url)
metadata.title = "New Title"
metadata.artist = "New Artist"
metadata.artworkData = imageData  // nil → leave existing artwork unchanged

let result = try TagLibMetadataManager.writeMetadataWithVerification(metadata, to: url)

for warning in result.warnings {
    logger.warning("Metadata write warning: \(warning)")
}
```

### 5.2 Strict write — treat warnings as failures

```swift
do {
    try TagLibMetadataManager.writeMetadataWithVerification(
        metadata,
        to: url,
        failurePolicy: .throw
    )
} catch TagLibManagerError.verificationFailed(let warnings) {
    // Write completed but re-read did not match expectations
    showVerificationError(warnings)
}
```

### 5.3 Removing artwork

`BasicMetadata.artworkData = nil` leaves existing artwork unchanged. To explicitly remove artwork:

```swift
let tag = TagLibAudioMetadata()
tag.removeArtwork = true

try TagLibMetadataManager.writeTagMetadata(
    tag,
    to: url,
    verification: .init(
        expectedTrackNumber: nil,
        expectedTrackTotal: nil,
        expectedTrackNumberText: nil,
        expectedDiscNumber: nil,
        expectedDiscTotal: nil,
        expectedDiscNumberText: nil,
        expectedExplicitContent: nil,
        artworkExpectation: .absent,
        customFieldKeys: []
    )
)
```

Alternatively, `eraseAllMetadataWithVerification(from:)` removes all metadata including artwork.

---

## 6. Batch processing

When editing many files in a loop, keep these points in mind:

1. **Run off the main thread.** Wrap the entire batch in a background task.
2. **Serialize access to each file.** Do not dispatch concurrent writes to the same file path.
3. **Consider disabling per-write verification for large batches.** Collect results and verify in a separate pass.
4. **Work on copies for destructive operations.** Copy the original file to a temp location, write to the copy, verify, then replace the original on success.

```swift
// Recommended batch pattern
Task.detached(priority: .userInitiated) {
    var failures: [(URL, Error)] = []
    var warnings: [(URL, [String])] = []

    for url in urls {
        guard TagLibMetadataManager.isWritableFormat(url.pathExtension) else {
            failures.append((url, TagLibManagerError.unsupportedFormat))
            continue
        }

        do {
            var metadata = try TagLibMetadataManager.readMetadataResult(from: url)
            applyEdits(&metadata)

            let result = try TagLibMetadataManager.writeMetadataWithVerification(
                metadata,
                to: url,
                failurePolicy: .warn   // collect warnings; don't stop the batch
            )

            if !result.warnings.isEmpty {
                warnings.append((url, result.warnings))
            }
        } catch {
            failures.append((url, error))
        }
    }

    await MainActor.run {
        self.presentBatchResults(failures: failures, warnings: warnings)
    }
}
```

### Skip-write optimization

If the values you intend to write are already present in the file, skip the write to avoid unnecessary I/O:

```swift
let current = try TagLibMetadataManager.readMetadataResult(from: url)
if current.title == desired.title && current.artist == desired.artist {
    return  // already up to date
}
try TagLibMetadataManager.writeMetadataWithVerification(desired, to: url)
```

---

## 7. Verification strategy

Post-write verification is built into all `WithVerification` APIs. The bridge re-reads the file after every write and compares key fields. Verification warnings are informational: the write succeeded at the file system level, but container normalization may have changed the value.

### When to use `.warn` (default)

Use `.warn` when container normalization is acceptable (e.g., `"01/12"` normalizing to `"1/12"` for a format that does not support padding). Log the warnings for diagnostics.

### When to use `.throw`

Use `.throw` when you must guarantee exact round-trip fidelity (e.g., writing a track number text for a batch renumbering feature where the user specified a zero-padded format). Catch `TagLibManagerError.verificationFailed([String])` and surface it to the user.

### Disabling verification

Pass `verifyAfterWrite: false` when:
- You are processing a large batch and will verify separately.
- You are writing to a format where you know normalization will occur and have already accounted for it.

```swift
let result = try TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification(
    properties,
    to: url,
    verifyAfterWrite: false
)
// result.warnings will be empty because no verification was performed
```

### Manual verification

```swift
let before = try TagLibMetadataManager.readMetadataResult(from: url)
try TagLibMetadataManager.writeMetadataWithVerification(metadata, to: url, failurePolicy: .warn)
let after = try TagLibMetadataManager.readMetadataResult(from: url)

if before.title != after.title {
    logger.warning("Title changed: \(before.title) → \(after.title)")
}
```

---

## 8. Handling partial failure in batch operations

Do not stop a batch operation on the first warning; warnings are non-fatal. Stop on errors (throws from the write call itself). Record failures and present them to the user after the batch completes.

```swift
struct BatchResult {
    var successes: [URL] = []
    var failures: [(URL, Error)] = []
    var warned: [(URL, [String])] = []
}

var batchResult = BatchResult()

for url in urls {
    do {
        let result = try TagLibMetadataManager.writeMetadataWithVerification(
            metadata, to: url, failurePolicy: .warn
        )
        if result.warnings.isEmpty {
            batchResult.successes.append(url)
        } else {
            batchResult.warned.append((url, result.warnings))
        }
    } catch {
        batchResult.failures.append((url, error))
        // Continue processing remaining files
    }
}
```

---

## 9. Preserving unsupported metadata

The bridge preserves unknown metadata by default:

- **ID3v2**: Unknown frames are not touched unless the caller explicitly replaces the `id3v2Frames` collection via the structured write path.
- **MP4**: Unknown freeform atoms (`----:com.apple.iTunes:…`) are preserved unless the caller explicitly replaces the `mp4Atoms` collection.
- **ASF**: Unknown ASF attributes are preserved unless the caller replaces the `asfAttributes` collection.
- **PropertyMap replace mode**: `writeRawMetadataPropertyMapWithVerification(_:to:mode:.replace)` replaces the **entire** PropertyMap. If you want to change only specific keys, use `.merge` mode.

To update a subset of fields while leaving everything else intact:

```swift
// Change only TITLE and ARTIST via merge
try TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification(
    ["TITLE": "New Title", "ARTIST": "New Artist"],
    to: url,
    mode: .merge
)
```

To remove a single field:

```swift
// Delete COMMENT, leave everything else
try TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification(
    ["COMMENT": ""],
    to: url,
    mode: .merge
)
```

---

## 10. Sandbox and security scope

The package performs file I/O through TagLib C++ file system calls using POSIX paths derived from `URL.path`. On macOS and iOS, sandboxed apps must hold an active security-scoped URL bookmark or an appropriate file-access entitlement before passing a file URL to any read or write API.

The package itself does not call `url.startAccessingSecurityScopedResource()` or `url.stopAccessingSecurityScopedResource()`. The calling app is responsible for starting access before calling any API and stopping access afterward.

```swift
let didStartAccess = url.startAccessingSecurityScopedResource()
defer {
    if didStartAccess { url.stopAccessingSecurityScopedResource() }
}

let metadata = try TagLibMetadataManager.readMetadataResult(from: url)
```

Files opened from the macOS Music.app library, iCloud Drive, or an external volume accessed via NSOpenPanel may require security-scoped bookmarks. Test this on device if you encounter permission errors.

---

## 11. Debug logging

Set the environment variable `AUDIOMATOR_TAGLIB_DEBUG=1` (or `true`, `yes`, `on`) to enable bridge-level debug logging via `NSLog`. In Xcode, add the variable to the scheme's Run environment variables.

```sh
AUDIOMATOR_TAGLIB_DEBUG=1 ./YourApp
```

---

## 12. Checking field support before displaying an editor

Use `MetadataFieldRegistry` to determine which fields are storable in a given format before building editor UI:

```swift
let cap = TagLibMetadataManager.formatCapability(for: url.pathExtension)!
let storableFields = MetadataFieldRegistry.schemas(storableIn: cap)

let supportsWork = storableFields.contains { $0.key == .work }
let supportsISRC = storableFields.contains { $0.key == .isrc }
```

This avoids presenting fields to the user that will silently be dropped or produce verification warnings.
