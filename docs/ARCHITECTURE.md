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
        │
        ▼
Swift value models (copies of strings, arrays, data)
        │
        ▼
final identity check ──► MetadataSnapshot
```

For Ogg families the extractor opens the extension-selected `FileRef` and then a concrete `TagLib::Ogg::*::File` to confirm the codec identification packet; both operations occur inside the same serialized extraction call. The public contract is one coherent read, not a guarantee of one C++ file object for every parser family.

An identity check rejects a file changed during extraction. The Swift models are copies; no TagLib object escapes the parser interval.

Legacy Basic, raw, and structured entry points remain available. The unified snapshot eliminates three independent parses when an editor needs all views. `BasicMetadata` is normalized for convenience and is deliberately not a lossless round-trip representation. Raw and structured projections retain semantic multi-value and supported container-specific information, but unknown or opaque native payloads may be represented only by type/display summaries. `MetadataSnapshot` is therefore a comprehensive semantic snapshot, not a native byte-for-byte serialization.

Selective extraction avoids building unrequested projections:

| Call | Bridge options | Result |
| --- | --- | --- |
| `readSnapshot` | all | Basic, raw, structured in one extraction call. |
| `readMetadataResult` / `readBasicSnapshot` | basic + PropertyMap | Basic and raw cardinality; no structured inspector models. |
| `rawMetadataResult` | raw | Visible `PropertyMap` and raw frame summaries where exposed. |
| `readStructuredMetadataResult` | structured | Structured collections only. |
| `TagLibMetadataExtractor.metadataProjections(for:options:)` | caller selected | The requested subset of `basic`, `raw`, `structured`. |

The unified bridge still constructs its internal Basic carrier during a structured-only traversal; removing that allocation requires a wider format-extractor split. This is an implementation detail, not a public contract.

`readBasicSnapshot(from:)` returns the focused Basic projection with an exact optimistic-concurrency token. `updateBasicMetadata(at:_:)` uses this path before the version-checked replacement, so a Basic read/modify/write does not build unused structured inspector models.

Callers that split read and write across UI events should retain the token and pass it to `applyMetadataPatch`, `applyRawMetadataPatch`, `replaceBasicMetadata`, `writeStructuredMetadataWithVerification`, the whole-map raw writers, or `writeTagMetadata`. Without `expectedVersion`, a write intentionally targets the file state current when its transaction begins rather than the state previously shown to the user.

## Audio-content continuity

Snapshots can additionally stream an opt-in `MetadataAudioContentIdentity`, independently of supported metadata regions, while retaining the same revision checks. The scanner runs in Swift/CryptoKit outside the native parser lock, using bounded streaming reads without sample decoding. Typed and raw delta overloads require both the baseline token and the current `MetadataFileVersion`; they compare the staged copy's audio before mutation and retain the original final commit guard. Availability is limited to WAVE, AIFF/AIFF-C, and native FLAC; a missing token requires explicit reload. See [Audio-content continuity](AUDIO_CONTENT_CONTINUITY.md).

## Write pipeline

The facade transaction coordinator performs:

1. same-entry coordination;
2. destination validation and optional `expectedVersion` check;
3. one sibling copy (`copyfile` with clone request and ACL preservation);
4. in-place bridge mutation on the copy;
5. semantic verification for the verified facade APIs;
6. `F_FULLFSYNC`/`fsync` of the copy;
7. final destination identity check;
8. atomic rename;
9. parent-directory sync.

Public bridge mutators use the same transaction principles when called directly, but perform only staged-file readability checks after mutation; they do not inherit the facade's semantic verification. See [Transactions](TRANSACTIONS.md).

A complex `MetadataPatch` can open and save the staged file separately for number pairs, advisory, property-map values, and artwork. Consolidating these into one container-aware bridge delta remains follow-up work; the current design keeps the proven transaction and mutation paths instead of expanding the risk surface. The transaction is still one copy and one rename.

## Metadata model and write semantics

`MetadataPatch` expresses omission explicitly: absent fields are unchanged, `.remove` clears a property, `explicitAdvisory` retains all four advisory states, and artwork distinguishes unchanged, replacement, and removal. Typed fields are validated for kind and numeric range against `MetadataFieldRegistry` before staging. Schema-known keys are rejected from `customFields`, including aliases and case variants. Role-qualified fields such as `.performer` are rejected by the typed Patch API; use `RawMetadataPatch` or `StructuredMetadata` when roles are part of the key. Partial removal of a paired first component is rejected on native pair formats when a retained total cannot be represented.

Most property changes are applied as a bridge delta to the current `PropertyMap`; MP4 track/disc pairs and advisory data use native `trkn`, `disk`, and `rtng` mutation, while ID3 advisory uses the supported `TXXX` representation. TagLib still saves the affected native tag, so the guarantee is semantic omission rather than byte-for-byte container preservation.

Format field allowlists, when present in `FormatCapability`, are checked before staging for the typed Patch surface. Raw APIs remain container-permissive.

Patch text and value arrays are normalized once before mutation. Leading and trailing whitespace is removed, empty text/lists/elements are rejected, and the same normalized representation drives verification. `.remove` is the sole high-level deletion marker for field values.

Number pairs use container-aware paths:

- ID3-backed formats use combined `TRCK`/`TPOS` and `MVIN`;
- MP4 uses native `trkn`/`disk`;
- generic/Xiph formats use separate number/total keys;
- ASF combines totals into native text attributes.

Track/disc integers begin at one; movement and BPM begin at zero. Native `trkn`/`disk` pairs are authoritative on MP4. Changing a numeric component lazily migrates legacy AudioMator formatting provenance to a package-neutral key while preserving padding; an unchanged pair preserves legacy text and storage exactly. Dedicated number-text APIs remain the explicit formatted-input path.

`BasicMetadata` has replacement semantics only for fields it explicitly models. Schema-known non-Basic fields, full recording dates, documented aliases, qualified people keys, and custom fields absent from its projection are restored from the current raw state where supported. `BasicMetadata` multi-value scalars are display strings with format-dependent separators and are not a lossless array representation. Removing a custom dictionary key does not request deletion; callers use `MetadataPatchValue.remove`.

Structured ID3v2 text mutation uses TagLib string-list APIs, preserving ordered value cardinality. `TXXX` descriptions identify frames and are kept separate from their payload arrays. Structured verification compares those arrays element by element.

Structured artwork writes use dedicated ID3v2, MP4, ASF, FLAC/Xiph, and APE-family paths; the caller's `container` value is informational because the destination follows the file format. `structuredWriteSupport` describes non-artwork structured data, so a PropertyMap-level format can still support artwork when `canWriteArtwork` is true. Structured PropertyMap values are applied as a delta: omitted keys remain, empty value arrays remove one key, and non-empty properties with `includeProperties == false` are rejected.

The shared advisory model distinguishes field absence (`unspecified`) from a present not-explicit value, explicit, and clean. Canonical MP4/M4A native values are absent, `rtng = 0`, `rtng = 1`, and `rtng = 2`. ID3 and generic PropertyMap storage use `ITUNESADVISORY`. Readers accept documented legacy aliases, including MP4 value `4` as explicit; high-level writes use canonical values.

Atomic rename provides a pathname-level all-or-nothing commit on one volume. It does not preserve inode identity or update sibling hard links. Both transaction engines reject setuid/setgid files before staging because clone/copy may drop privilege bits. Production does not run a separate deployment-specific metadata-preservation audit; clients with quarantine, immutable-flag, or security-scoped requirements must validate their environment. The caller needs read access to the file and create/rename access in its parent directory.

If rename succeeds but the final parent-directory sync fails, the new file is already committed. High-level Swift writes return `.durabilityUncertain`; they do not attempt rollback, and consumers must not blindly repeat the operation. The internal transaction helper retains the historical typed error.

## Schema and capabilities

`MetadataFieldRegistry` is the Swift source of public field semantics. It defines each `MetadataFieldKey` once, with display name, category, `PropertyMap` aliases, container mappings, multi-value/people/role/artwork flags, accepted typed-patch kinds, and integer constraints. The bridge has a parallel ordered mapping table exposed through `metadataFieldMappings()` and `knownMetadataPropertyKeys()`; consistency tests compare every schema key and container mapping across the language boundary.

The tables are not generated from one machine-readable source yet. The documentation tables are generated from the Swift registry, but adding a production schema still requires updating both the Swift table and the bridge mapping and running the parity tests. Until a shared generator exists, treat the cross-language tests as the guardrail.

`FormatCapability` separates read/write mechanics from evidence through `FormatSupportLevel`. UI code should query the extension and field being edited because aliases and container fields can have different evidence levels. The complete matrix and its limits are in [Formats](FORMATS.md).

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
| `.../TagLibMetadataManager+Compatibility.swift` | Deprecated-signature and pre-`expectedVersion` forwarding overloads. |
| `.../MetadataSnapshotPatch.swift` | Snapshot/version models, `MetadataPatch`, typed patch validation and application. |
| `.../RawMetadataPatch.swift` | Exact raw delta validation, application, and verification. |
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
| `scripts/` | Binary build, preservation-corpus generation, documentation checks and field-table generation. |
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
- Root-level tests cover public Objective-C selectors, Swift nested types, deprecated function references, and console-diagnostics hygiene.

This hierarchy communicates failure semantics without multiplying XCTest targets or changing test discovery. See [Testing](TESTING.md) for commands and evidence limits.
