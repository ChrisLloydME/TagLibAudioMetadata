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

Operations on independent files are safe. Mutations of the same canonical
directory entry are serialized inside this process by a coordinator shared by
the Swift facade and public bridge transaction paths. The lock key uses parent
directory identity plus entry name, so it survives destination inode replacement
and parent-directory symlink aliases. Acquisition order and fairness are not
part of the public contract, so callers must still provide their own ordering
when a particular writer must win. Destination identity checks reject a stale
transaction when an external actor changes the original before commit.

Snapshot reads do not hold the same-entry mutation lock for their full duration.
They capture and compare file identity around extraction. Passing the returned
`MetadataFileVersion` to a later patch or replacement causes the transaction to
recheck that exact version after acquiring its same-entry lock and before
staging.

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

The sanitizer matrix includes concurrent cross-format reads and writes plus
repeated M4A stress. These commands instrument the Swift and Objective-C++
targets. The distributed Release XCFramework is precompiled and is not
internally sanitizer-instrumented; fully instrumented upstream diagnosis
requires a separate diagnostic TagLib build.
