# Architecture

## Dependency boundary

Application code normally imports the `TagLibAudioMetadata` Swift facade. The
facade calls stable Objective-C declarations in `CTagLibBridge`; C++ types remain
private to Objective-C++ translation units. The bridge dynamically links the
`TagLibAudioMetadataTagLib` binary target.

`TagLibAudioMetadataLowLevel` makes direct bridge use intentional. The facade's
legacy re-export remains for source compatibility, with migration to the
low-level product recommended before a future major release removes it.

The framework name, Mach-O install name, bundle identifier, headers, and module
map are namespaced. This prevents a generic `TagLib.framework` from being
mistaken for this package's artifact. It cannot fully isolate C++ ABI: TagLib
symbols are still exported, so a process that also loads an incompatible TagLib
build risks symbol interposition. A stable C/Objective-C shim or hidden/private
C++ exports would be required for stronger isolation.

## Read pipeline

`readSnapshot(from:)` opens one TagLib `FileRef` and extracts basic, raw, and
structured projections during the same locked parser session. Swift then owns
copies of all returned strings, arrays, dictionaries, and data. An identity
check rejects a file changed during extraction.

Legacy basic, raw, and structured entry points remain available. The unified
snapshot eliminates three independent parses when an editor needs all views.
`BasicMetadata` is normalized for convenience and is deliberately not a
lossless round-trip representation. Raw and structured projections retain
semantic multi-value and supported container-specific information, but unknown
or opaque native payloads may be represented only by type/display summaries.
`MetadataSnapshot` is therefore a comprehensive semantic snapshot, not a native
byte-for-byte serialization.

Selective extraction avoids building unrequested projections. Basic reads ask
for Basic+PropertyMap because cardinality and provenance are needed for safe
Basic round trips; they do not enumerate raw ID3 frame summaries. Raw reads ask
for PropertyMap+raw frames, structured reads ask only for structured metadata,
and a full snapshot asks for every projection in one session.

## Write pipeline

The facade transaction coordinator creates one same-directory copy, takes one
initial snapshot where needed, performs in-place bridge mutations on that copy,
reads a verification snapshot, flushes the file, rechecks original identity,
renames atomically, and flushes the parent directory. Public bridge mutators use
the same transaction principles when called directly.

`MetadataPatch` expresses omission explicitly: absent fields are unchanged,
`.remove` clears a property, `explicitAdvisory` retains its three-state meaning,
and artwork distinguishes unchanged, replacement, and removal. Typed fields are
validated for kind and numeric range against `MetadataFieldRegistry` before
staging. Schema-known keys are rejected from `customFields`, including aliases
and case variants. Text-backed booleans encode false as `"0"`, while `.remove`
makes the field absent. Most property changes are applied as a bridge delta to
the current `PropertyMap`; MP4 track/disc pairs and advisory data use native
`trkn`, `disk`, and `rtng` mutation, while ID3 advisory uses the supported TXXX
representation. TagLib still saves the affected native tag, so the guarantee is
semantic omission rather than byte-for-byte container preservation.

`BasicMetadata` has replacement semantics only for fields it explicitly
models. Schema-known non-Basic fields and custom fields absent from its
projection are restored from read provenance. Removing a custom dictionary key
does not request deletion; callers use `MetadataPatchValue.remove`. Preservation
bookkeeping is publicly readable for compatibility but writable only inside the
module.

Atomic rename provides a pathname-level all-or-nothing commit on one volume. It
does not preserve inode identity or update sibling hard links. FileManager's
copy preserves the metadata the platform preserves for an ordinary copy, but
clients with strict ACL, extended-attribute, quarantine, immutable-flag, or
security-scoped requirements must validate those properties in their deployment
environment. The caller needs read access to the file and create/rename access
in its parent directory.

If rename succeeds but the final parent-directory `fsync` fails, the new file is
already committed. The Swift facade throws
`committedButDurabilityUncertain`; it does not attempt rollback, and blind retry
may repeat the operation.

## Schema and capabilities

`MetadataFieldRegistry` is the Swift source of public field semantics. The
bridge exposes its mapping tables to consistency tests, which verify that every
public schema key and container mapping agrees across the language boundary.
The tables are not generated from a single machine-readable file yet; adding a
generator remains a maintainability improvement rather than an unverified claim
of completion.

`FormatCapability` separates read/write mechanics from evidence through
`FormatSupportLevel`. UI code should query the extension and field being edited,
because aliases and container fields can have different evidence levels.

## Performance and concurrency

The migration removes ineffective generic-read fallback parsing and avoids
nested facade transactions. A facade edit uses one staging copy rather than the
former nested two-copy path; a complete snapshot uses one parser session rather
than three. Basic post-write verification now derives Basic and PropertyMap
checks from one extraction instead of two, without enumerating raw ID3 frames.
No synthetic percentage speedup is claimed because file size, storage,
container, and tag density dominate elapsed time.

A process-wide recursive mutex covers TagLib object lifetimes and Objective-C
objects populated while traversing them. Swift model conversion and filesystem
copy, flush, and rename work are outside the lock. See
[THREAD_SAFETY.md](THREAD_SAFETY.md).

## Source layout

- `TagLibMetadataExtractor.mm`: parsing, projections, and format-specific bridge
  work.
- `TagLibAudioMetadata.m`: Objective-C model and compatibility implementation.
- `TLBridgeTransactions.mm`: low-level mutation transaction coordinator.
- `Internal/*.hpp`: private Objective-C++ declarations and TagLib header
  compatibility.
- `Sources/TagLibAudioMetadata/*.swift`: public models, schemas, facade reads,
  writes, structured conversion, patches, and verification.

Public headers do not expose internal C++ declarations.
