# Compatibility and migration

This guide describes source-compatibility expectations and the changes a consumer may need to make between tagged releases or when adopting unreleased APIs. It does not assign a version number to untagged work.

The current release is `0.6.0`; changes since `0.5.3` are described in the [changelog](../CHANGELOG.md). The historical TagLib 2.3.1 migration report is preserved as [MIG-2026-09-01](records/migrations/MIG-2026-09-01-taglib-2.3.1.md).

## Compatibility promises

- **Source compatibility:** public API changes should keep existing source compiling where practical, using deprecated forwarding overloads. Typed function references are the supported compatibility shape; untyped references to overloaded names can become ambiguous.
- **Behavioral compatibility:** some methods are deprecated because their semantics were easy to misuse, not because they were removed. Deprecated verification policies do not bypass verification.
- **Binary compatibility:** the package does not promise a stable Swift ABI or a stable C++ ABI. Rebuild consumers against the package version they use.
- **Dependency compatibility:** the TagLib binary is pinned by version, URL, and checksum. Substituting an arbitrary TagLib build at link time is unsupported.
- **Error compatibility:** error enums gained cases. Exhaustive switches must handle new cases or use an appropriate wildcard/default pattern.

## Migrating from 0.5.3 to 0.6.0

These changes are additive or source-compatible with the 0.5 line unless noted.

### Minimum Swift tools

The package manifest now requires Swift tools 6.4. Toolchains older than 6.4 are rejected at manifest resolution. Swift 6.0 and 6.1 reject the source syntax, and Swift 6.3 cannot import macOS 26.5/27 SDK modules because its Clang lacks the SDK's `-target-arch-variant` support, so the previous 6.0 declaration could admit consumers that could not compile the package. Update Xcode or the Swift toolchain before resolving this version; the public source API is otherwise unchanged for 0.5 consumers.

### Audio-content continuity

- `readSnapshot(from:includingAudioContent:)` and `readBasicSnapshot(from:includingAudioContent:)` are additive. Default reads still return `nil` audio identity and do not scan audio.
- `applyMetadataPatch` and `applyRawMetadataPatch` gained guarded overloads requiring both `expectedVersion` and `expectedAudioContent`.
- Existing unguarded overloads retain behavior. Basic replacement, whole-map raw replacement, structured writes, and public bridge writes do not gain the audio guard.
- Availability is limited to WAV, AIFF/AIFF-C, and native FLAC. Unsupported layouts return `nil` on read and throw `MetadataAudioContentError.unavailable` from a guarded write. Two missing identities never establish continuity.
- WAVE `bext` and `iXML` are excluded from the identity because TagLib may relocate them during a metadata save. Other ancillary edits can still change the token.
- The deprecated typed `applyMetadataPatch(_:to:expectedVersion:failurePolicy:)` overload forwards to the unguarded path and cannot check audio identity.
- Empty typed/raw patches bypass the guards and return a no-op result.

See [Audio-content continuity](AUDIO_CONTENT_CONTINUITY.md).

### Deprecated names and replacements

| Deprecated API | Replacement |
| --- | --- |
| `readMetadata(from:)` | `bestEffortMetadata(from:)` or `readMetadataResult(from:)` |
| `rawMetadata(from:)` | `bestEffortRawMetadata(from:)` or `rawMetadataResult(from:)` |
| `readStructuredMetadata(from:)` | `bestEffortStructuredMetadata(from:)` or `readStructuredMetadataResult(from:)` |
| `rawMetadataText(from:)` | `bestEffortRawMetadataText(from:)` |
| `writeMetadata(_:to:)`, `writeMetadata(_:to:expectedVersion:)`, `writeMetadataWithVerification` | `replaceBasicMetadata` or `updateBasicMetadata` |
| `failurePolicy:` overloads | Omit the parameter; verification mismatches always throw |
| `VerificationFailurePolicy` | No replacement needed; `.warn` has no bypass effect |
| `BasicMetadata.isExplicit` setter | `explicitAdvisory` |
| `isReadableFormat(_:)`, `isWritableFormat(_:)` | `isReadableExtension(_:)`, `isWritableExtension(_:)` |
| `formatCapability(for:)` | `capability(forExtension:)` |
| `FormatSupportLevel.verified` | `fixtureCovered` or a concrete `probeFile` |
| `ArtworkVerificationExpectation.unchanged` | `.skip` |
| `TagLibManagerError.failedToRead` | `failedToReadWithUnderlying(_:)` |
| Message-only `operationFailed` emission | `operationFailedWithUnderlying(_:)`; the old case remains for compatibility |

Deprecated declarations remain callable where source compatibility is practical. Do not build new code on them. The complete compatibility-overload table is in the [API reference](API_REFERENCE.md#compatibility-overloads).

### Behavior changes to account for

1. **Basic replacement vs. update.** `replaceBasicMetadata` replaces the complete modeled Basic projection; empty/default fields clear values. `updateBasicMetadata` captures a version and is the safe read/modify/write form. Do not treat `BasicMetadata.empty` as a partial patch.
2. **Verification always throws.** A mismatch aborts before commit. `warnings` on a successful result are residual container advisories.
3. **Low-level product.** Starting in 0.5, the facade does not re-export `CTagLibBridge`. Add `.product(name: "TagLibAudioMetadataLowLevel", ...)` and `import CTagLibBridge` if you name bridge types.
4. **Raw native keys.** Raw APIs accept prefixless TagLib `PropertyMap` keys. `----:` native MP4 atom keys reject; use `StructuredMetadata.mp4Atoms`.
5. **MP4 dates.** MP4 has one `©day` atom. `.date` is unsupported for typed MP4 writes; use `.releaseDate` or `updateBasicMetadata`. A full Basic replacement must supply consistent non-empty year/releaseDate projections.
6. **Number pairs.** Native ID3 families write combined `TRCK`/`TPOS`; MP4 uses `trkn`/`disk`; generic/Xiph uses separate total keys; ASF uses native text pairs. A first component cannot be removed while retaining a total where the container cannot represent it.
7. **Privilege-bearing files.** setuid/setgid files reject before staging. Clear the bits explicitly if editing is intended.
8. **TrueAudio mixed surfaces.** Files with unmodeled APEv2 fields reject rather than silently leaving a conflicting secondary tag.
9. **Durability status.** High-level writes return `commitStatus`. `.durabilityUncertain` means the rename already committed. Do not retry blindly.
10. **ASF and structured removal.** ASF attributes are upserts. ID3 URL/UFID frames have no individual structured removal; empty payloads reject.
11. **Structured writes are collection-scoped.** Omitted collections are preserved; non-empty artwork/lyrics/comments replace their collection. Empty collections require `replacingCollections` to remove the final entries.
12. **`writeTagMetadata` is not a patch.** It writes the bridge model's mapped fields. Read current values first if you intend a partial edit, and supply a verification context if you need readback.
13. **RIFF policy scope.** `RIFFMetadataWritePolicy` is meaningful only for structured WAV and AIFF/AIFF-C writes. `.syncBasicFieldsToInfo` rejects for those extensions; other formats ignore the policy value.

### Source-compatibility caveat: untyped function references

Adding overloads with the same base name can make an untyped reference ambiguous:

```swift
// May fail to compile because readSnapshot has multiple overloads.
let reader = TagLibMetadataManager.readSnapshot

// Supported: give the reference an explicit function type.
let reader: (URL) throws -> MetadataSnapshot = TagLibMetadataManager.readSnapshot
```

The same caveat applies to `readBasicSnapshot`, `applyMetadataPatch`, `applyRawMetadataPatch`, and `BasicMetadataSnapshot.init`. Typed references and direct calls are supported; untyped references are not guaranteed across overload additions.

## Migrating from 0.4 to 0.5

The 0.5 line introduced the current product split and the explicit low-level boundary.

| 0.4 use | 0.5 migration |
| --- | --- |
| `import TagLibAudioMetadata` and direct bridge types | Add the `TagLibAudioMetadataLowLevel` product and `import CTagLibBridge`; facade-only code should not name bridge types. |
| Generic `TagLib.framework` assumptions | Use the namespaced `TagLibAudioMetadataTagLib.framework` and its install name. |
| Whole-object write APIs as partial updates | Use `MetadataPatch`/`updateBasicMetadata`; whole-object writes replace modeled fields. |
| Warning-based verification policy | Remove `failurePolicy:`; mismatches throw. |
| Boolean-only explicit metadata | Use `ExplicitAdvisory` when absence, not-explicit, explicit, and clean must remain distinct. |

The dependency artifact changed from TagLib 2.1.1 to 2.3.1 during the migration. The framework name, install name, bundle identifier, and module map are namespaced to avoid collisions with a generic `TagLib.framework`. See [Installation](INSTALLATION.md) and [Third-party notices](THIRD_PARTY_NOTICES.md).

## Migration checklist

- [ ] Resolve the package at a tag or an explicit revision; do not rely on an unnamed branch state.
- [ ] Add the low-level product only if you directly use bridge declarations.
- [ ] Replace deprecated reads/writes with the named alternatives.
- [ ] Remove `failurePolicy:` arguments and handle thrown verification failures.
- [ ] Update exhaustive error switches for new cases.
- [ ] Use typed function references if you store API references.
- [ ] Pass `expectedVersion` when editing from a snapshot.
- [ ] Adopt the audio guard only if automatic conflict rebasing needs it; require explicit reload when an identity is missing.
- [ ] Check `RIFFMetadataWritePolicy` scope if you write structured metadata to non-RIFF formats.
- [ ] Verify the final app embeds and signs the namespaced framework.
- [ ] Run your own type, integration, and distribution checks; the package's tests do not validate your app.

## What is not promised

- A stable Swift ABI or C++ ABI.
- That every 0.4 source pattern compiles without adjustment.
- That a deprecated overload behaves like the replacement in every respect.
- That a package update changes an application's conflict policy automatically.
- That an untagged `main` state is a release.
