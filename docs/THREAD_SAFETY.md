# Thread safety

## Public contract

`TagLibMetadataManager` and `TagLibMetadataExtractor` may be called from
multiple threads. A process-wide recursive mutex covers each interval that
creates or uses TagLib C++ parser, tag, property-map, or file objects. Foundation
collections and `NSData` populated directly while traversing live TagLib objects
are currently constructed inside that interval. After the bridge returns,
Swift value-model conversion, sibling-file copying, `fsync`, and atomic rename
run outside the lock, so slow filesystem work does not unnecessarily block
parsing another file.

Operations on independent files are safe. The package does not promise ordering
for concurrent mutations of the same canonical pathname; callers must serialize
those operations when ordering matters. Destination identity checks reject a
stale transaction when another actor changes the original before commit, but
they do not choose which writer should win.

This contract assumes the client does not concurrently mutate TagLib global
hooks through another direct linkage. Loading another TagLib C++ implementation
in the same process can also cause symbol interposition and is unsupported.

## Why the mutex remains

TagLib 2.3.1 improved thread-safety behavior, but still exposes process-global
configuration hooks and has format-specific static initialization paths. The
bridge keeps one recursive lock as a conservative boundary around upstream
objects. Recursion supports validation paths that re-enter package readers on
the same thread.

The lock does not protect arbitrary external access to the file. Snapshot reads
compare device, inode, size, modification time, and status-change time before
and after extraction. Transactions compare the same identity immediately before
rename.

## Sanitizer coverage

```sh
swift test --sanitize=address
swift test --sanitize=thread
```

The current 94-test suite passes both commands and includes concurrent
cross-format reads and writes plus repeated M4A stress. These commands instrument
the Swift and Objective-C++ targets. The distributed Release XCFramework is
precompiled and is not internally sanitizer-instrumented; fully instrumented
upstream diagnosis requires a separate diagnostic TagLib build.
