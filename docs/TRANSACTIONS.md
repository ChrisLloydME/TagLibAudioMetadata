# Transactions, durability, and concurrency

This is the canonical contract for metadata writes: staging, atomicity, durability, preconditions, rollback, thread safety, and process-local coordination. It describes the Swift facade and the public Objective-C bridge at the current revision.

The short version: a write stages a sibling copy, mutates and (for verified facade APIs) verifies that copy, flushes it, rechecks the destination identity, atomically renames it, and syncs the parent directory. Failures before rename leave the original path and bytes unchanged. Coordination is process-local, not a cross-process lock.

## Mutation pipeline

### Swift facade

`TagLibMetadataManager.withAtomicMetadataWriteMutation` runs:

1. **Coordinate.** Acquire the same-entry mutation coordinator for the destination (`TagLibMetadataExtractor.coordinateMutation(at:)`).
2. **Validate the destination.**
   - Require a file URL.
   - `lstat` the URL; require a regular file and reject a final symbolic link.
   - Reject setuid/setgid permission bits.
   - Reject hard-linked files (`st_nlink != 1`).
   - If `expectedVersion` was supplied, compare it to the current identity and throw `fileChanged` on mismatch.
   - Confirm `isRegularFile == true` and `isSymbolicLink != true` through `URLResourceValues`.
   - Open the file with the selected parser; an unreadable or invalid audio file fails before staging.
3. **Stage.** Create one sibling temporary file in the same directory with `copyfile(COPYFILE_CLONE | COPYFILE_ACL)`.
   - `COPYFILE_CLONE` requests a copy-on-write clone and falls back to an ordinary copy when cloning is unavailable.
   - `COPYFILE_ACL` requests ACL preservation.
   - The temporary file must be a regular file.
4. **Mutate.** Run the write operation on the temporary file. Nested in-place bridge operations detect the active transaction depth and do not create a second staging copy.
5. **Verify.** Verified facade APIs compare requested metadata and preservation expectations on the temporary file. Direct bridge mutators validate that the staged file remains readable; they do not perform semantic readback.
6. **Flush.** Open the temporary file and request `F_FULLFSYNC`; on `EINVAL`, `ENOTSUP`, or `ENOTTY`, fall back to `fsync`. Other failures abort before rename.
7. **Final identity check.** Compare the destination identity to the captured identity. A change throws `fileChanged` and leaves the staged copy unpublished.
8. **Rename.** Atomically rename the temporary file over the destination.
9. **Directory sync.** Open the parent directory with `O_RDONLY | O_DIRECTORY` and flush it. A failure here means the rename already committed and durability is uncertain.

The transaction returns a `MetadataWriteResult` with `commitStatus`:

- `.durable`: the requested file and parent-directory flushes completed.
- `.durabilityUncertain(detail)`: the rename committed, but the final directory flush failed. Do not retry as though nothing happened.

The internal helper `withAtomicFileMutation` throws `TagLibManagerError.committedButDurabilityUncertain` for the same post-rename condition. The public bridge reports error code `9110` (`TagLibMetadataTransactionErrorCodeCommittedButDurabilityUncertain`).

### Public bridge

`TagLibMetadataExtractor` mutators use `PerformAtomicTagLibMutation`, which follows the same preconditions, sibling copy, readability validation, file flush, identity check, rename, and directory flush sequence. Differences:

- The bridge does not run facade semantic verification.
- The bridge reports durability uncertainty through its `NSError` contract.
- In-place primitives live in `CTagLibBridgeInternalAPI`, which is not a library product.

The bridge transaction also validates the staged file after mutation, so a direct bridge write checks readability even though it does not compare requested values. See [Bridge reference](BRIDGE.md).

## Preconditions and rejection cases

| Condition | Result |
| --- | --- |
| Non-file URL | Rejected before staging. |
| Missing path, directory, or other non-regular file | Rejected before staging. |
| Final symbolic link | Rejected; the target is not followed. |
| Hard-linked file (`st_nlink > 1`) | `TagLibManagerError.hardLinkedFile` or bridge error `9111`; replacement would split the link identity. |
| setuid or setgid bit set | Rejected before staging; clone/copy may not preserve privilege bits safely. Clear the bits explicitly if editing is intended. |
| Unreadable or invalid audio | Rejected before staging with an operation/read error. |
| Stale `expectedVersion` | `fileChanged`; no staging. |
| Copy, mutation, verification, or file flush failure | Temporary file removed; original pathname and bytes unchanged. |
| Destination changes before final rename | `fileChanged`; temporary file removed; original unchanged. |
| Rename failure | Temporary file removed; original unchanged. |
| Parent-directory flush failure after rename | Committed; durability uncertain. |

The final directory flush failure is the only normal path where a caller sees an error after the destination has already changed. `commitStatus`/error code `9110` exists to prevent a blind retry from duplicating an edit.

## What atomic replacement does and does not preserve

- Atomic rename provides pathname-level all-or-nothing commit on one volume.
- It does not preserve inode identity and does not update sibling hard links. Hard-linked files are rejected instead.
- The staging copy requests ACL preservation; clone/copy semantics include data, stat, and extended attributes on the tested macOS filesystem.
- The transaction does not rely on clone/copy preserving setuid/setgid bits: it rejects those files before staging rather than silently dropping or restoring privilege bits.
- Production does not run a separate deployment-specific metadata-preservation audit. Quarantine, immutable flags, security-scoped URLs, and sandbox behavior remain integration responsibilities.
- The caller needs read access to the file and create/rename access in its parent directory. Sibling-copy creation requires write access to the parent directory.

## Durability semantics

`.durable` means the package requested and completed an OS-level flush (`F_FULLFSYNC`, or `fsync` where the filesystem rejects the stronger request) for the staged file and for the parent directory. It is not:

- a hardware cache-flush guarantee;
- a power-loss guarantee;
- a guarantee about the storage device's write cache;
- a substitute for application-level replication or backup.

If the final directory sync fails, the new pathname is already visible. Consumers should surface a committed-but-durability-uncertain state and avoid automatic retries.

## Concurrency and thread safety

### Process-wide TagLib mutex

`TagLibMetadataManager` and `TagLibMetadataExtractor` may be called from multiple threads. A process-wide **recursive** mutex covers each interval that creates or uses TagLib C++ parser, tag, property-map, or file objects.

- Foundation collections and `NSData` populated while traversing live TagLib objects are constructed inside that interval.
- Swift value-model conversion, sibling copying, `fsync`, and atomic rename run outside the lock, so slow filesystem work does not unnecessarily block parsing another file.
- Recursion is required because validation paths re-enter package readers on the same thread.
- Operations on independent files are safe, but their parser intervals still serialize through this one mutex.

### Same-entry coordinator

Facade and public bridge transactions share a per-directory-entry lock:

- The key is parent-directory device and inode plus the case-folded, canonically normalized entry name.
- It survives destination inode replacement because it locks the entry, not the file inode.
- It converges parent-directory symlink aliases through the resolved parent identity.
- It serializes the whole transaction, including staging, mutation, verification, flush, and rename.
- Acquisition order and fairness are not part of the public contract. If a particular writer must win, the caller must provide ordering.

### Reads

Snapshot reads do not hold the same-entry mutation lock for their full duration. They capture a `MetadataFileVersion`, extract metadata, and compare the identity again before returning. Passing that version to a later write makes the transaction recheck it after acquiring the same-entry lock and before staging.

`MetadataFileVersion` includes device, inode, size, link count, modification time, and status-change time. It is an observed filesystem revision, not a content hash or a cross-process lock. It cannot, by itself, prove that encoded audio belongs to the recording the user originally opened; the opt-in audio-content identity exists for that question. See [Audio-content continuity](AUDIO_CONTENT_CONTINUITY.md).

### Audio-content checks

Opt-in audio identities are streamed outside the TagLib global mutex. Exact path and descriptor version checks bind the bytes to the snapshot revision. Typed/raw audio-guarded write overloads compare the transactional copy under the same-entry coordinator and retain the final destination version check. They do not close the external check/rename race.

The second audio scan occurs while the same-entry coordinator is held, so concurrent writers to the same entry wait for an O(audio) hashing pass. Readers and independent files are unaffected.

### Process-local, not cross-process

This is the most important limitation:

- The mutex and coordinator exist inside one process.
- Another process can change the file between the final identity check and rename.
- Another process can replace or rename the parent directory; that is not protected.
- The package does not create lock files, advisory file locks, or distributed coordination.

Callers that need cross-process exclusion must add it at the application or filesystem layer. The package does not claim that two processes editing the same path are serialized.

### TagLib global state

The contract assumes the client does not concurrently mutate TagLib global hooks through another direct linkage. Loading another incompatible TagLib C++ implementation into the same process can cause symbol interposition and is unsupported, even though the framework is namespaced.

## Sanitizer coverage

The repository's sanitizer jobs are:

```sh
swift test --sanitize=address
swift test --sanitize=thread
```

They instrument the package's Swift and Objective-C++ code. The distributed Release XCFramework is precompiled and is not internally sanitizer-instrumented; fully instrumented upstream diagnosis requires a separate diagnostic TagLib build. Sanitizer success in this package does not establish safety inside the dependency.

The CI matrix also covers strict warnings-as-errors, release tests, minimum-platform compilation, consumers, and a dynamic-link audit. See [Testing](TESTING.md) for the exact jobs and limitations.

## Client guidance

- Use the throwing, verified facade APIs for normal editing.
- Pass `expectedVersion` when the edit is based on an earlier snapshot.
- Use the guarded typed/raw delta overloads when automatic conflict rebasing depends on unchanged audio.
- Treat `.durabilityUncertain` as committed.
- Do not assume a successful compile, an empty warnings array, or a readable staged file proves semantic correctness.
- Do not rely on the package for cross-process locking or hardware durability.
