# Architecture

## Dependency boundary

```text
Application
    │
    ├── TagLibAudioMetadata (Swift facade)
    │       ├── CTagLibBridge (public Objective-C API)
    │       └── CTagLibBridgeInternalAPI (package-internal in-place/coordination API)
    │
    └── TagLibAudioMetadataLowLevel (optional)
            └── CTagLibBridge (public Objective-C API)

CTagLibBridge ──► TagLibAudioMetadataTagLib.xcframework (TagLib 2.3.1)
```

Application code normally imports `TagLibAudioMetadata`. The facade calls stable Objective-C declarations in `CTagLibBridge`; C++ types remain private to Objective-C++ translation units. The bridge dynamically links the checksum-pinned `TagLibAudioMetadataTagLib` binary target.

The low-level product makes direct bridge use intentional. The facade does not re-export bridge declarations, so direct bridge clients must declare `TagLibAudioMetadataLowLevel` and `import CTagLibBridge`. The public bridge header contains read, write, inspection, and capability APIs; unsafe in-place mutation and same-entry coordination declarations live in `CTagLibBridgeInternalAPI`, a package-internal target that is not a library product.

The framework name, Mach-O install name, bundle identifier, headers, and module map are namespaced. This prevents a generic `TagLib.framework` from being mistaken for this package's artifact. It cannot fully isolate the C++ ABI: TagLib symbols are still exported, so a process that also loads an incompatible TagLib build risks symbol interposition. A stable C shim or hidden/private C++ exports would be required for stronger isolation.

## Read pipeline

`readSnapshot(from:)` runs one locked extraction call and derives Basic, raw, and structured projections from the same extension-selected parser session:

```text
MetadataFileVersion
        │
        ▼
TagLib FileRef (serialized)
        │
        ├── Basic tag model + audio properties
        ├── visible PropertyMap (WAVE merges INFO + ID3v2)
        ├── raw ID3v2 frame summaries (formats that expose them)
        └── structured frames/atoms/attributes/artwork/lyrics/comments
            + observed primary ID3 major version
        │
        ▼
Swift value models (copies of strings, arrays, data)
        │
        ▼
final identity check ──► MetadataSnapshot
```

For Ogg families the extractor opens the extension-selected `FileRef` and then a concrete `TagLib::Ogg::*::File` to confirm the codec identification packet; both operations occur inside the same serialized extraction call. The public contract is one coherent read, not a guarantee of one C++ file object for every parser family.

An identity check rejects a file changed during extraction. The Swift models are copies; no TagLib object escapes the parser interval.

### Extraction options

The bridge supports five option bits: `basic`, `raw`, `structured`, `propertyMap`, and `rawFrames`. The facade's read methods select them as follows:

| Facade call | Bridge options | Returned projection |
| --- | --- | --- |
| `readSnapshot(from:)` | `.all` | Basic, raw, and structured. |
| `readMetadataResult(from:)` | `.all` | Basic only (raw and structured are derived internally). |
| `readBasicSnapshot(from:)` | `.all` | Basic plus version (structured is derived internally). |
| `rawMetadataResult(from:)` | `.raw` | Visible `PropertyMap` and raw frame summaries where exposed. |
| `readStructuredMetadataResult(from:)` | `.structured` | Structured collections only. |

`readMetadataResult` and `readBasicSnapshot` are lighter in returned model construction and public API surface, not in native extraction work: Basic metadata needs the structured projection to resolve exact MP4 and ID3 date/number identities. They do not return `StructuredMetadata`. Basic reads resolve MP4 Content Group, Movement Number/Count and unsigned pair components from their exact native owners rather than ambiguous engine projections.

The unified extractor also clears any engine-provided date projection before populating the bridge Basic model. ID3 reads clear all four date slots and repopulate them from `TDRC`/`TYER`, `TDAT`/`TXXX(DATE)`, `TDRL`, and `TDOR`/`TORY`; MP4 reads use the native atom map and preserve absence; ASF reads its Unicode attributes; and Xiph/APE read YEAR and DATE from their visible native properties. This keeps an inferred or cross-owner projection from becoming a low-level date value.

The unified bridge still constructs its internal Basic carrier during a structured-only traversal; removing that allocation requires a wider format-extractor split. This is an implementation detail, not a public contract.

`updateBasicMetadata(at:_:)` reads a focused Basic snapshot, applies the closure, and passes the captured version to the version-checked replacement.

Callers that split read and write across UI events should retain the token and pass it to `applyMetadataPatch`, `applyRawMetadataPatch`, `replaceBasicMetadata`, `writeStructuredMetadataWithVerification`, the whole-map raw writers, or `writeTagMetadata`. Without `expectedVersion`, a write intentionally targets the file state current when its transaction begins.

## Audio-content continuity

Snapshots can additionally stream an opt-in `MetadataAudioContentIdentity`, independently of supported metadata regions, while retaining the same revision checks. The scanner runs in Swift/CryptoKit outside the native parser lock, using bounded streaming reads without sample decoding. Typed and raw delta overloads require both the baseline token and the current `MetadataFileVersion`; they compare the staged copy's audio before mutation and retain the original final commit guard. Availability is limited to WAVE, AIFF/AIFF-C, and native FLAC; a missing token requires explicit reload. See [Audio-content continuity](AUDIO_CONTENT_CONTINUITY.md).

## Write pipeline

The facade transaction coordinator performs:

1. same-entry coordination;
2. destination validation and optional `expectedVersion` check;
3. one sibling copy (`copyfile` with clone request and ACL preservation);
4. in-place bridge mutation on the copy;
5. format-specific preservation of unedited native owners, including `restoreUneditedBasicNativeValues` for Basic replacement, exact MP4 item retention and detached ID3 date-frame restoration during PropertyMap replay, unchanged MP4 custom-field arrays, and native ASF custom attributes;
6. semantic verification for the verified facade APIs;
7. `F_FULLFSYNC`/`fsync` of the copy;
8. final destination identity check;
9. atomic rename;
10. parent-directory sync.

Public bridge mutators use the same transaction principles when called directly, but perform only staged-file readability checks after mutation; they do not inherit the facade's semantic verification. See [Transactions](TRANSACTIONS.md).

A complex `MetadataPatch` can open and save the staged file separately for number pairs, advisory, property-map values, and artwork. Consolidating these into one container-aware bridge delta remains follow-up work; the current design keeps the proven transaction and mutation paths instead of expanding the risk surface. The transaction is still one copy and one rename.

## Metadata model and write semantics

`MetadataPatch` expresses omission explicitly: absent fields are unchanged, `.remove` clears a property, `explicitAdvisory` retains all four advisory states, and artwork distinguishes unchanged, replacement, and removal. Typed fields are validated for kind and numeric range against `MetadataFieldRegistry` before staging. Schema-known keys are rejected from `customFields`, including aliases and case variants. Role-qualified fields such as `.performer` are rejected by the typed Patch API; use `RawMetadataPatch` or `StructuredMetadata` when roles are part of the key.

Most property changes are applied as a bridge delta to the current `PropertyMap`; MP4 track/disc pairs, movement, and advisory data use native `trkn`, `disk`, `©mvi`/`©mvc`, and `rtng` mutation, while ID3 advisory uses the supported `TXXX` representation. Track/disc components are normalized from the engine's signed projection to their unsigned 16-bit storage; movement remains bounded to `0...32767`. TagLib still saves the affected native tag, so the guarantee is semantic omission rather than byte-for-byte container preservation.

PropertyMap replay is owner-aware for independent date slots. On MP4, untouched `©day`, `DATE`, `RELEASEDATE`, and `ORIGINALDATE` items are restored exactly, including absence; on ID3-backed files, untouched date frames are detached around `setProperties` and restored afterward so encoding, arrays, flags, and malformed text survive. A scalar custom field whose projection is unchanged retains an existing MP4 freeform name spelling and native array. ASF semantic custom fields bypass the PropertyMap and address native Unicode attributes. MP4 typed comments and lyrics use `©cmt`/`©lyr` rather than the qualified ID3 collection path; structured comment/lyric collections remain unsupported on MP4.

Basic replacement restores unchanged native date owners and, on MP4, unchanged modeled atoms and compatibility aliases before verification. Existing ID3v2.3 tags reject independent date changes, while an unrelated Basic edit preserves their dates. Encoded By and Encoder Settings, and Content Group, Grouping and Work, are verified through independent native owners rather than fallback projections.

Format field allowlists, when present in `FormatCapability`, are checked before staging for the typed Patch surface. Raw APIs remain container-permissive.

Patch text and value arrays are normalized once before mutation. Leading and trailing whitespace is removed, empty text/lists/elements are rejected, and the same normalized representation drives verification. `.remove` is the sole high-level deletion marker for field values.

Number pairs use container-aware paths:

- ID3-backed formats use combined `TRCK`/`TPOS` and `MVIN`;
- MP4 uses native `trkn`/`disk` and independent `©mvi`/`©mvc` movement atoms;
- generic/Xiph formats use separate number/total keys;
- ASF combines totals into native text attributes.

Track/disc integers begin at one; movement and BPM begin at zero. Native `trkn`/`disk` pairs are authoritative on MP4. Numeric writes do not create or rename the legacy `AUDIOMATOR_*_TEXT` or `TAGLIBAUDIOMETADATA_*_TEXT` atoms; existing values are preserved until an explicit normalization plan retires selected identities. Dedicated number-text APIs are the explicit formatted-input path.

`BasicMetadata` has replacement semantics only for fields the Basic replacement path actually writes. It preserves untouched multi-value arrays through exact native collections, restores unchanged native ID3 comment/lyric collections, and carries Xiph/APE text keys through their exact physical spelling. Other opaque or unmodeled data may survive because TagLib saves the native tag, but it is not reconstructed from the Basic model. `BasicMetadata` multi-value scalars are display strings with format-dependent separators and are not a lossless array representation. Removing a custom dictionary key does not request deletion; callers use `MetadataPatchValue.remove`.

The MP4-exclusive Basic properties (`director`, store IDs, TV fields, and related Booleans) are readable through `BasicMetadata` but are not written by `replaceBasicMetadata`: the bridge writer model has no corresponding properties. Use `MetadataPatch` or structured writes for those fields; see [Write semantics](PRESERVATION.md#basic-preservation-rules).

Structured ID3v2 text mutation uses TagLib string-list APIs, preserving ordered value cardinality. `TXXX` descriptions identify frames and are kept separate from their payload arrays. Structured verification compares those arrays element by element; an empty text/user-text payload is a removal request and is verified as absence. DSF/DSDIFF route native ID3 frame upserts through the structured writer while rejecting comment/lyric collection replacement. `StructuredID3v2Frame.fields` is merged into the bridge payload dictionary; it is reserved for future frame-specific fields and can collide with `id`, `type`, `value`, or `values`, so callers should leave it empty.

Structured artwork writes use dedicated ID3v2, MP4, ASF, FLAC/Xiph, and APE-family paths; the caller's `container` value is informational because the destination follows the file format. `structuredWriteSupport` describes non-artwork structured data, so a PropertyMap-level format can still support artwork when `canWriteArtwork` is true. Structured PropertyMap values are applied as a delta: omitted keys remain, empty value arrays remove one key, and non-empty properties with `includeProperties == false` are rejected.

The shared advisory model distinguishes field absence (`unspecified`) from present not-explicit, explicit, and clean. Canonical MP4/M4A native values are absent, `rtng = 0`, `rtng = 1`, and `rtng = 2`. ID3 and generic PropertyMap storage use `ITUNESADVISORY`. Unknown existing codes (for example MP4 `4`) are retained as `explicitAdvisoryRawValue` with `.unspecified` semantics; they are not silently recoded as explicit or clean. Explicit replacement with a known state is allowed.

Atomic rename provides a pathname-level all-or-nothing commit on one volume. It does not preserve inode identity or update sibling hard links. Both transaction engines reject setuid/setgid files before staging because clone/copy may drop privilege bits. Production does not run a separate deployment-specific metadata-preservation audit; clients with quarantine, immutable-flag, or security-scoped requirements must validate their environment. The caller needs read access to the file and create/rename access in its parent directory.

If rename succeeds but the final parent-directory sync fails, the new file is already committed. High-level Swift writes return `.durabilityUncertain`; they do not attempt rollback, and consumers must not blindly repeat the operation. The internal transaction helper retains the historical typed error.

## Schema, capabilities, and generated documentation

`MetadataFieldRegistry` is the Swift source of public field semantics. `MetadataMappingCatalog` is the checked-in declarative target table; it is not generated from Markdown. `MetadataFieldSchema` joins that catalog to display, category, patch-kind, and integer-constraint policy. `mappings` is derived from `nativeTargets`, so the legacy compatibility view cannot drift. The bridge retains a parallel ordered mapping table exposed through `metadataFieldMappings()` and `knownMetadataPropertyKeys()`; consistency tests compare every schema key and container mapping across the language boundary.

Adding a production schema requires updating the semantic registry and, where the bridge must address the native target directly, the bridge mapping, then running the parity and codec tests. The documentation pipeline consumes the Swift sources:

- `scripts/generate-api-reference.py` renders manager and model declarations;
- `scripts/generate-field-schema.py` renders the field tables and typed-patch policy;
- `scripts/generate-format-matrix.py` renders the capability registry;
- `scripts/generate-mapping-matrix.py` renders `MetadataMappingCatalog`.

`FormatCapability` separates read/write mechanics from evidence through `FormatSupportLevel`. UI code should query the extension and field being edited because aliases and container fields can have different evidence levels. `writeSupport(for:)` requires a writable target in the primary write family, so a secondary readable tag surface cannot authorize a semantic write; concrete tag version and native width can still reject. The complete matrix and its limits are in [Formats](../reference/FORMATS.md).

## Performance and concurrency

A complete snapshot uses one extraction call rather than three. A facade edit uses one clone-or-copy staging operation rather than a nested two-copy path. Basic post-write verification derives Basic and PropertyMap checks from one extraction instead of two.

A complex Patch can still open and save the staged file separately for number pairs, advisory, property-map values, and artwork. This is a deliberate trade-off: fewer, simpler mutation paths with known verification behavior rather than a larger one-shot encoder.

A process-wide recursive mutex covers TagLib object lifetimes and Objective-C objects populated while traversing them. Swift model conversion and filesystem copy, flush, and rename work are outside the lock. Same-entry transactions also share a directory-identity/name lock. Coordination is process-local, not a cross-process lock. See [Transactions](TRANSACTIONS.md).

## Source layout

| Path | Responsibility |
| --- | --- |
| `Package.swift` | Products, targets, platform minimums, binary pin, C++20. |
| `Sources/TagLibAudioMetadata/TagLibMetadataManager.swift` | Static facade entry points, nested write/result types, transaction coordinator, file identity. |
| `.../TagLibMetadataManager+Read.swift` | Basic/raw/snapshot reads, bridge projection conversion, diagnostic dump. |
| `.../TagLibMetadataManager+Write.swift` | Basic replacement/update, bridge-model write, raw whole-map writes, erase, number text. |
| `.../TagLibMetadataManager+Structured.swift` | Structured conversion, validation, write, verification. |
| `.../TagLibMetadataManager+Verification.swift` | Verification helpers, warning construction, raw normalization, explicit provenance. |
| `.../BasicNativePreservation.swift` | Restores untouched Basic native dates, MP4 owners/aliases, and absence before verification. |
| `.../TagLibMetadataManager+Compatibility.swift` | Deprecated-signature and pre-`expectedVersion` forwarding overloads. |
| `.../MetadataSnapshotPatch.swift` | Snapshot/version models, `MetadataPatch`, typed patch validation and application. |
| `.../RawMetadataPatch.swift` | Exact raw delta validation, application, and verification. |
| `.../MetadataNativePlanning.swift` | Semantic patch value to exact native target translation. |
| `.../MetadataNumberInventory.swift` | Number inventory, recovery, normalization plans, and application. |
| `.../MetadataMapping.swift` | Native family, storage, shape, target, and capability vocabulary. |
| `.../MetadataMappingCatalog.swift` | Declarative semantic-to-native target table (source of truth). |
| `.../MetadataAudioContentIdentity.swift` | Opt-in bounded audio scanner and guarded-write checks. |
| `.../TagLibMetadataModels.swift` | Basic, raw, structured, policy, and error models. |
| `.../MetadataFieldSchema.swift` | Public field keys, schema, mappings, and registry lookups. |
| `.../FormatCapability.swift` | Capability model and field-level support queries. |
| `Sources/CTagLibBridge/include/TagLibMetadataExtractor.h` | Public Foundation-only bridge header. |
| `Sources/CTagLibBridge/TagLibMetadataExtractor.mm` | Objective-C++ implementation; includes the subsystem `.inc` files. |
| `Sources/CTagLibBridge/TLBridgeTransactions.mm` | Bridge transaction coordinator, same-entry locks, process mutex, logging. |
| `Sources/CTagLibBridge/TLFormatRegistry.mm` | Format descriptor table and extension lookup. |
| `Sources/CTagLibBridge/Internal/*.hpp` | Private C++/Objective-C++ declarations and TagLib header compatibility. |
| `Sources/CTagLibBridge/Internal/*.inc` | Bridge subsystems compiled into the extractor translation unit. |
| `Sources/CTagLibBridgeInternalAPI/` | Non-product in-place mutation and coordination declarations used by the facade/tests. |
| `Tests/TagLibAudioMetadataTests/` | Single test target, physically organized by layer. |
| `IntegrationTests/Consumer/` | Facade-only and low-level consumer packages. |
| `scripts/` | Binary build, preservation-corpus generation, reference generators, documentation checks, full-suite gate and test evidence summarizer. |
| `docs/` | Current documentation; historical records under `docs/records/`. |

Public headers do not expose internal C++ declarations.

## Test layout

The single SwiftPM test target is organized physically by layer:

- `Capabilities/` checks the public capability model and cross-language schema consistency.
- `Integration/` owns real-fixture round trips, container projections, native parsers, and raw metadata behavior.
- `Transactions/` covers stale versions, failure atomicity, preservation, same-entry coordination, privilege rejection, and audio identity.
- `Concurrency/` contains cross-format and M4A stress coverage.
- `ModelSemantics/` covers pure value-model contracts.
- `Performance/` contains opt-in, non-gating throughput experiments.
- Root-level tests cover public Objective-C selectors, Swift nested types, current version-aware function references, and console-diagnostics hygiene.

`scripts/validate-tests.sh` runs the complete Debug or Release suite with strict warnings and writes evidence under `.build/test-evidence/`; `scripts/summarize-test-run.py` fails closed on missing framework summaries, unexpected skips, missing named matrices/oracles, case-count shrinkage, or named failures. `scripts/tests/` holds the gate-policy regressions. This hierarchy communicates failure semantics without multiplying XCTest targets or changing test discovery. See [Testing](../operations/TESTING.md) and [Mapping test acceptance](../operations/MAPPING_TEST_STRATEGY.md).
