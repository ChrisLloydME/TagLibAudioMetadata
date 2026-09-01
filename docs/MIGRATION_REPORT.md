# Correctness and TagLib 2.3.1 migration report

Date: 2026-09-01

## Outcome

The package now consumes a published, checksum-pinned, namespaced TagLib 2.3.1
dynamic XCFramework. It also has a comprehensive semantic editing path based on
unified snapshots and explicit patches, one-copy atomic transactions, evidence-based
format capabilities, a defined low-level product, synchronized schema tests,
and expanded fixture and concurrency coverage.

The previous public facade remains source-compatible. Compatibility wrappers
and the bridge re-export remain available, while new integrations have clearer
products and semantics.

## Dependency and ABI migration

| Property | Previous artifact | Current artifact |
| --- | --- | --- |
| TagLib | 2.1.1 | 2.3.1 (`54ae7d8ac45755e286a5c574280f48d5bef93aef`) |
| utf8cpp | `df857efc…` | `819011bb01628fe1aa2f1da9f2c842a48fd5680b` |
| Framework | `TagLib.framework` | `TagLibAudioMetadataTagLib.framework` |
| Install name | `@rpath/TagLib.framework/TagLib` | `@rpath/TagLibAudioMetadataTagLib.framework/TagLibAudioMetadataTagLib` |
| Binary release | `taglib-binary-2.1.1-r1` | `taglib-binary-2.3.1-r2` |
| SwiftPM checksum | old release checksum | `d7a36b2492266a17fcd97bd776cd841d9fc85275270bc0c3cb9621395b3178c7` |

All three slices retain macOS 13 and iOS 16 minimums and the original
architecture matrix. The bridge accepts both the new namespaced header layout
and the legacy TagLib module layout, which allowed compatibility testing against
both 2.1.1 and 2.3.1 during migration.

Namespacing prevents framework-name, install-name, bundle-ID, and module-map
collisions. It does not hide the TagLib C++ symbols exported by the dynamic
binary. A process that loads another incompatible TagLib remains a residual ABI
risk documented in `ARCHITECTURE.md`.

## API and behavior changes

- `MetadataSnapshot` returns basic, raw, and structured views from one parser
  session and rejects concurrent file changes. It is not described as a lossless
  native serialization because opaque or unsupported payloads may be summarized.
- `MetadataPatch` changes only explicitly supplied fields, retains raw
  multi-values, validates typed and custom keys plus numeric constraints against
  the field schema, distinguishes false from removal, distinguishes artwork
  omission/replacement/removal, and preserves the advisory states
  unspecified/clean/explicit. MP4 number pairs and advisory values mutate native
  `trkn`/`disk`/`rtng` items; ID3 advisory uses its supported TXXX representation.
  Generic PropertyMap formats keep separate number and total keys. MP4 patches
  remove every recognized advisory alias and do not inject private AudioMator
  number-formatting atoms unless such provenance already exists.
- Patch text and arrays are trimmed once and verified against that normalized
  form. Empty text, empty arrays, and empty array elements are rejected in favor
  of explicit `.remove` deletion.
- `BasicMetadata` remains a normalized editing model. Its explicitly represented
  fields use replacement semantics, while untouched multi-value fields,
  schema-known non-Basic fields, and custom fields are restored from its raw
  baseline during facade writes. Removing a custom projection entry is not a
  deletion request; callers
  needing precise multi-value or container edits should use snapshot/patch or
  the specialized APIs.
- Semantic `Hashable`/`Equatable` behavior no longer changes because ephemeral
  UI identifiers were regenerated.
- Numeric parsing and structured write boundaries reject overflow instead of
  truncating or crossing signed/unsigned domains.
- `FormatSupportLevel` separates verified, experimental, upstream-supported,
  read-only, and unsupported behavior at family and extension level.
- `TagLibAudioMetadataLowLevel` is the explicit product for direct
  `CTagLibBridge` use. The facade re-export is retained as a compatibility shim.

No public C++ type is exposed. Existing Objective-C error domains and selectors
remain available. The facade adds a distinct transaction error when rename has
succeeded but the parent-directory flush fails, so callers are not told that
the original is intact after a committed rename.

## Transaction and performance migration

Nested facade-to-bridge transactions were removed. A facade mutation now makes
one sibling copy, mutates it in place through internal bridge entry points,
verifies it, flushes it, checks the original identity, atomically renames it,
and flushes the directory. Copy, flush, and rename are outside the TagLib mutex.

The unified projection reader avoids separate basic/raw/structured parses and
now skips unrequested projections. Basic editing and verification request only
Basic+PropertyMap data, avoiding raw ID3 frame enumeration. Post-write Basic and
PropertyMap verification is derived from one extraction instead of two, and the
ineffective generic fallback parse was removed. These are structural
improvements; no hardware-independent elapsed-time percentage is claimed.

The bridge transaction coordinator moved into its own Objective-C++ translation
unit. Private shared declarations and dual-version header selection live under
`Sources/CTagLibBridge/Internal`, reducing the size and coupling of the parser
implementation without changing public headers.

## Format evidence

Fixture-backed verified extensions now include `mp3`, `m4a`, `flac`, `ogg`,
`oga`, `wav`, `aac`, and `xm`. S3M and IT are experimental; MOD-family files and
Shorten are advertised read-only; all remaining parser routes are marked
upstream-supported until licensed fixtures prove package round trips.

Ogg FLAC and XM use upstream TagLib 2.3.1 fixtures whose origin, license, and
SHA-256 values are recorded beside the test resources. Ogg FLAC preservation
tests cover raw multi-values and audio payload survival. XM tests cover read,
save, clear, and tracker capability behavior. Both fixtures also passed the
compatibility suite against TagLib 2.1.1 before the final artifact switch.

## Acceptance evidence

The final manifest resolves the public 2.3.1 release asset anonymously and has
passed:

| Check | Result |
| --- | --- |
| Strict clean build | Passed with Swift and C-family warnings as errors |
| Unit tests | 79 passed |
| Address Sanitizer | 79 passed, no findings |
| Thread Sanitizer | 79 passed, no findings |
| Facade consumer | Built using the facade product |
| Low-level consumer | Built using the explicit product |
| Dynamic audit | Namespaced install name, module map, bundle ID, licenses, and absence of generic install name verified |
| macOS | arm64 and x86_64 builds passed |
| iOS device | arm64 build passed |
| iOS Simulator | arm64 and x86_64 builds passed |

The binary-release workflow for `taglib-binary-2.3.1-r2` completed successfully
and published the immutable asset. The tag-triggered source CI run used the tag
commit, which intentionally predates adoption of the newly published URL; its
manifest-publication assertion failed for that reason, while sanitizer and all
five platform jobs passed. The current manifest was then tested locally against
the public asset as recorded above.

## Residual risks and deferred work

- The precompiled TagLib binary is not internally ASan/TSan-instrumented; the
  sanitizer runs instrument the Swift and Objective-C++ consumer targets.
- Untested formats and aliases must not be treated as verified merely because
  upstream exposes a parser.
- Same-path mutation ordering remains the caller's responsibility.
- Atomic replacement changes inode identity and hard-link behavior, and strict
  ACL/xattr/quarantine/flag preservation needs deployment-specific validation.
- Security-scoped URL acquisition, app embedding/signing, and sandbox policy are
  application responsibilities.
- Swift and bridge field tables are consistency-tested but not generated from a
  single schema source yet.
- Fully isolating alternate TagLib C++ versions requires a stronger binary ABI
  boundary than framework namespacing.
- Removal of the compatibility bridge re-export is deferred to a major release.
