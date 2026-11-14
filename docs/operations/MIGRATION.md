# Compatibility and migration

## Unreleased API cleanup (breaking)

This source branch intentionally removes compatibility-only API. It is not a patch-compatible replacement for the published 0.7.3 interface; publish it as an explicitly breaking release after consumer migration. Native target layouts and canonical mapping contract 2.2 are unchanged.

| Removed surface | Current API |
| --- | --- |
| `MetadataFieldKey.date` (meaning YEAR), `isLegacyYearAlias`, and its obsolete `conflictingYearRepresentations` error | `.year` for YEAR; `.standaloneDate` for independent DATE. Persisted field-key token `date` is rejected, never silently reinterpreted. `BasicMetadata.date` still means independent DATE. |
| `writeMetadata`, `writeMetadataWithVerification` facade aliases | `replaceBasicMetadata` for full replacement or `updateBasicMetadata` for a captured-version update |
| Optional `readMetadata`, `rawMetadata`, `readStructuredMetadata`, `rawMetadataText` aliases | Throwing `*Result` APIs or explicitly named `bestEffort*` functions |
| `failurePolicy` overloads and `VerificationFailurePolicy` | Verified mismatches always abort; handle typed errors and commit status |
| Old function-reference arities without `expectedVersion` | Bind the current version-aware function signature; ordinary calls may still use documented defaults |
| Writable Boolean `isExplicit` / bridge `explicitContent` and Boolean verification expectations | Set and verify the exact four-state `explicitAdvisory`; Boolean properties are read-only projections |
| `ArtworkVerificationExpectation.unchanged` | `.skip` (this concerns verification, not the separate artwork mutation `.unchanged`) |
| `isReadableFormat`, `isWritableFormat`, `formatCapability(for:)`, `FormatSupportLevel.verified`, `failedToRead` | Explicit extension lookup, `fixtureCovered`, and throwing error with underlying detail |

Existing native-file aliases and the legacy numbering inventory/explicit recovery plan remain supported. They preserve user data and do not reintroduce removed API meanings. Raw engine `DATE` can still denote YEAR on MP4/ID3; typed native ownership must be obtained from the catalog, not inferred from that engine key. Bridge `metadataFieldMappings()` now lists YEAR as the canonical PropertyMap spelling and DATE as its engine alias; consumers inspecting ordered descriptors must use that order. This is not a native-file rewrite. Old runtime bridge-selector probing and contradictory ignored native-target hints have been removed.


This guide describes source-compatibility expectations and the changes a consumer may need to make between tagged releases or when adopting unreleased APIs. Version `0.7.3` (2026-11-12) is the current release. Tagged-release sections below are historical migration instructions; the unreleased cleanup above supersedes their retained-alias advice. Review the behavioral changes that apply to your starting version.

### Diagnostic repair follow-up

Basic replacement now diffs a versioned snapshot and uses the typed native planner. Nil artwork removes the collection; MP4-exclusive changes use typed targets or reject when unsupported. Existing v2.3 dates are literal owners, not synthesized timestamps. Full low-level Basic replacements of v2.3 files reject safely; use Basic updates/typed deltas or non-date structured edits on preservable layouts. All facade mutation paths now guard the staged v2.3 date owners, even when optional readback verification is disabled. Structured date edits reject before staging; `versionedText` does not override this policy. Public direct raw, structured and number bridge writes to concrete v2.3 tags reject with code `9290`; full-model replacement rejects with `9261`. Explicit wipe remains intentional removal. Versioned text verification resolves the selected native identity for supported versions. Unsupported MP4/ASF structured Comment/Lyrics collections reject before staging. Empty structured writes validate the file/version without rewriting it. All Swift transactions validate staged readability even when semantic verification is disabled.

### Further architecture cleanup (same unreleased breaking candidate)

The unused facade `MetadataExtractionOptions` type is removed. No public facade operation accepted it; direct bridge clients retain `TagLibMetadataExtractionOptions` through the low-level product.

- Use `allSchemas`; `canonicalSchemas`, `isCanonicalSemanticOwner` and the public shared/preferred/property-owner tables are removed. Every field schema now represents one canonical identity. `schema(forPropertyMapKey:)` keeps explicit engine/qualified aliases in a private single-owner index, and `canonicalSchema(forSemanticKey:)` remains the semantic lookup.
- `readSnapshot(from:includingAudioContent:)` and `readBasicSnapshot(from:includingAudioContent:)` are single functions with a default false flag. Full current function references include the Bool argument. Ordinary one-argument calls still compile through the default.
- Snapshot and Structured constructors have one current signature with default optional provenance/version values; old arity-only forwarding initializers are removed.
- Bool-only `eraseAllMetadata` and `writeRawMetadataPropertyMap` wrappers are removed. Use the verified result-bearing functions and inspect commit status, including committed-but-durability-uncertain outcomes.
- Uncalled retention/verification functions and the unused synchronized-number helper are removed. Native-file read aliases and explicit number recovery remain active.

### Registry introspection and exact advisory verification

At the earlier alias-removal stage, removing `.date` changed registry introspection: `propertyMapKeyOwners["DATE"]` and `["YEAR"]` each contain only `.year`; `sharedPropertyMapKeyOwners` and `preferredSharedPropertyMapKeyOwner` are empty. `canonicalSchemas` equals `allSchemas` for built-in entries. Engine lookup still resolves DATE/YEAR to YEAR; standalone DATE remains its own semantic field. Do not infer native storage from these formatless engine spellings. The subsequent strict-registry cleanup above removes these legacy alias/collision shapes; caller-created schemas now use the same canonical model.

`expectedExplicitAdvisory = .unspecified` now verifies absence of both the known state and unknown raw-code provenance. To verify preservation of an unknown existing code, also set `expectedExplicitAdvisoryRawValue` to that exact code. A non-nil raw expectation can be used on its own. Basic replacement supplies this expectation automatically for an unchanged unknown state and restores its native owners. An unrelated save must not turn an unknown code into absence. Erase verifies the final staged file after all clearing/wiping steps.

## Compatibility promises

- **Source compatibility:** breaking API removals require an explicitly breaking release and migration instructions. Compatibility-only aliases that contradict current field meanings are removed in this candidate.
- **Behavioral compatibility:** native-file read aliases and explicit legacy recovery preserve data; they do not authorize ambiguous source-level aliases or verification bypasses.
- **Binary compatibility:** the package does not promise a stable Swift ABI or a stable C++ ABI. Rebuild consumers against the package version they use.
- **Dependency compatibility:** the TagLib binary is pinned by version, URL, and checksum. Substituting an arbitrary TagLib build at link time is unsupported.
- **Error compatibility:** error enums gained cases. Exhaustive switches must handle new cases or use an appropriate wildcard/default pattern.

## Migrating from 0.7.2 to 0.7.3

Version `0.7.3` contains native-owner state-preservation repairs. There is no version bump to the TagLib binary, no new mapping contract, and no automatic user-file migration. Public signatures are unchanged. The behavior changes below matter when an application depends on engine projections or scalar round trips rather than native-owner behavior.

### Behavior changes

- **Native date owners survive PropertyMap replay.** Unedited MP4 items and ID3 frames for YEAR, DATE, RELEASEDATE, and ORIGINALDATE are restored on raw, semantic-custom and structured writes, including native absence. The engine's `DATE` projection no longer authorizes creating, changing, or removing another native date owner.
- **Low-level date reads use native owners.** The bridge model resolves YEAR and standalone DATE from MP4/ID3/Xiph/APE-native storage rather than filling one from another engine projection. A file with DATE but no YEAR now returns an absent YEAR. That absence is intentional evidence, not a regression in the model.
- **MP4 typed comments and lyrics use native atoms.** `.comment` and `.lyrics` patches address `©cmt` and `©lyr`; they no longer enter the generic PropertyMap path that was appropriate for ID3's qualified collections. Structured `comments`/`lyrics` collections remain unsupported on MP4.
- **ASF semantic custom fields use native attributes.** A set, replace, or remove addresses the native Unicode attribute and reconciles only that field's case aliases. Verification uses the native attribute collection, so a same-named engine projection cannot hide a failed removal.
- **Untouched MP4 custom fields retain native state.** A changed custom field keeps the existing freeform name spelling and reconciles case aliases; an unchanged scalar projection does not collapse the native value array. A whole-map raw replacement retains arrays whose submitted values exactly equal the current visible array rather than normalizing them.
- **ARTIST and ARTISTS remain independent.** Generic PropertyMap replay no longer lets ARTISTS satisfy an ARTIST read. An application that relied on that fallback must read or write the field it actually means.

### Migration actions

1. If you compare low-level date values, expect native-owner absence rather than an inferred YEAR from DATE. Read the field whose owner you need.
2. If you inspect MP4 comments or lyrics outside the package, expect `©cmt`/`©lyr`; do not infer support for structured comment/lyric collections.
3. On ASF, do not assume a raw PropertyMap operation clears the native custom attribute. Patch the exact custom field and verify its native attribute if the distinction matters.
4. Do not assume a whole-map `.replace` normalizes an array that is already equal to the current visible value. Edit the array explicitly when normalization is intended.
5. Keep production dependencies on a tagged release. The `0.7.3` gate evidence does not make an untagged `main` state a release.

## Migrating from 0.7.1 to 0.7.2

Version `0.7.2` contains audit-integrity, native-mapping follow-up, package test-system and MP4 Content Group repairs. There is no automatic user-file migration. These changes are source-compatible unless an application depended on the old ownership or range behavior described below.

### Ownership and preservation corrections

- **Encoder fields are independent.** `encodedBy` owns ID3 `TENC`, MP4 `©enc` and ASF `WM/EncodedBy`; `encoderSettings` owns ID3 `TSSE`, MP4 `©too` and ASF `WM/EncodingSettings`. `ENCODEDBY`, `ENCODING` and `ENCODERSETTINGS` are read through their respective owners, not as fallbacks for one another. An application that previously relied on `ENCODING` to populate Encoded By must use `.encodedBy`.
- **MP4 movement is atomic.** Movement Number and Count use independent integer atoms `©mvi` and `©mvc`. A semantic edit changes only the requested component, including in a patch that also edits Track/Disc. Basic and low-level pair writes intentionally own both movement components. MP4 movement accepts `0...32767`; semantic, Basic and structured facade preflight reject larger values before staging.
- **MP4 track/disc pairs are unsigned.** Native `trkn`/`disk` components round-trip through `32768...65535`. The bridge normalizes the pinned engine's signed `IntPair` projection for Basic, number-text, structured and retention reads; external tools that decode the high half as signed may still display a different number.
- **Content Group, Grouping and Work are independent.** MP4 uses `©grp`, `----:com.apple.iTunes:GROUPING` and `©wrk`; ID3 uses `TIT1`, `GRP1` and `TXXX:WORK`; Xiph/APE use `CONTENTGROUP`, `GROUPING` and `WORK`. A missing MP4 Content Group no longer falls back to independent Grouping. Semantic verification permits the engine's overlapping PropertyMap projection for the edited owner while checking untouched native siblings.
- **Untouched Basic dates are preserved natively.** An unrelated Basic edit keeps existing date arrays, malformed text, duplicate values, whitespace and absence across MP4, ID3, Xiph and APE-backed formats. The preservation read is bound to the transaction version. Changing a date on an existing ID3v2.3 tag rejects before mutation; unchanged ID3v2.3 dates are preserved.
- **DSD structured writes accept ID3 frame upserts.** DSF and DSDIFF structured writes now support native ID3 text/user-text/URL/UFID/chapter frame upserts, PropertyMap deltas and artwork. Comment/lyric collection replacement remains unsupported and rejects without committing.
- **Structured ID3 text removal is verified as absence.** An ID3 `text` or `userText` entry with empty `values` and empty `value` removes that frame identity. Verification checks absence and preserves unrelated frames. URL/UFID removal has no empty-payload equivalent.

### Capability and test-operation changes

- `writeSupport(for:)` now requires a writable target in the primary write family. Secondary readable tags such as ID3 on FLAC or APE on MPEG do not authorize a semantic write. Formats with only a PropertyMap surface retain mapping and allowlist checks.
- `StructuredMetadata.id3v2MajorVersion` is optional read evidence. It does not convert a tag or make ID3v2.3 dates writable.
- Package acceptance uses `bash scripts/validate-tests.sh debug|release` and the gate-policy tests, not a bare aggregate `swift test` count. The test target demotes only `DeprecatedDeclaration` under strict compilation because compatibility tests deliberately reference obsolete API; production has no exception.

### Migration actions

1. Stop using Encoded By and Encoder Settings as interchangeable keys; patch the semantic field you intend to edit.
2. If you inspect movement fields on MP4, expect `©mvi`/`©mvc` and validate the `0...32767` bound before offering an edit.
3. If you decode MP4 track/disc pairs outside the package, handle the stored unsigned 16-bit value rather than assuming a signed high half.
4. Read `StructuredMetadata.id3v2MajorVersion` before offering date edits on a concrete ID3 file. Do not convert ID3v2.3 tags automatically to make dates writable.
5. Do not rely on Basic replacement to normalize or collapse untouched native date arrays. Use a patch and verify the fields you intentionally change.

## Migrating from 0.7.0 to 0.7.1

The `0.7.1` release corrects Xiph/APE YEAR/DATE ownership in both native and visible-map paths, verifies date siblings natively, and fixes active-family comment verification and qualified UFID writes. No date companions or automatic user-file migration are required.

- `StructuredMetadata.id3v2MajorVersion` is optional read evidence. The existing initializer signature remains available, so existing source continues to compile.
- Date writes to concrete ID3v2.3 tags are explicitly read-only until a verified independent codec exists. Typed date patches and Basic date changes reject safely; unchanged dates are preserved.
- Semantic write capability follows the primary write family. A secondary readable tag surface does not authorize a write there.
- Do not convert tags automatically or claim ID3v2.3 date support from an extension-wide ID3v2.4 capability result.

## Migrating from 0.6.0 to 0.7.0

These changes implement the package-side `AM-TLAM-MAPPING-2.2` target described in the [mapping contract](../reference/MAPPING_SPEC.md). They are source-compatible unless noted; behavioral changes are intentional and require application review. The changes are introduced in `0.7.0` and are not part of `0.6.0`.

### New field identities

- `MetadataFieldKey.year` is the canonical YEAR identity. `date` remains a legacy YEAR-slot spelling for source compatibility. Supplying both in one patch throws `MetadataPatchValidationError.conflictingYearRepresentations`.
- `MetadataFieldKey.standaloneDate` is the independent DATE identity. It is not a YEAR projection. `BasicMetadata.date` carries this standalone DATE value; it is not the typed `.date` legacy YEAR alias.
- `contentGroup`, `artists`, `replayGainTrackPeak`, and `replayGainAlbumPeak` are new semantic fields.
- `director`, `itunesAccount`, `itunesComposerID`, `itunesCountryID`, `itunesGapless`, `itunesHDVideo`, `itunesOwner`, `rate`, `showMovement`, `storeDescription`, `tvEpisode`, `tvEpisodeID`, `tvNetwork`, `tvSeason`, `tvShow`, and `tvShowSort` register the MP4-exclusive identities. `rate` is read-only for typed writes; the media-kind label vocabulary is not bound to numeric codes.
- The MP4-exclusive properties are readable through `BasicMetadata`, but `replaceBasicMetadata`/`updateBasicMetadata` do not write them. Use `MetadataPatch` or structured writes.

### Behavioral changes

- `BasicMetadata.year` returns the complete stored YEAR text. It is never truncated to four characters and never derived from `releaseDate` or MP4 `©day`-as-release-date logic.
- YEAR, DATE, RELEASEDATE, and ORIGINALDATE are independent. Changing or clearing one no longer rewrites another. `updateBasicMetadata` no longer reconciles MP4 dates, and `MetadataValidationError.conflictingMP4Date` is retained only for source compatibility.
- MP4 `©day` is the YEAR slot. RELEASEDATE is the `RELEASEDATE` freeform; DATE is the `DATE` freeform. Applications that previously wrote full release dates to `©day` must migrate to `.releaseDate`.
- `.date` is a legacy YEAR spelling and writes the same YEAR target as `.year` where that target is writable. It is not marked `@available(*, deprecated)` in the enum; treat it as legacy in new code.
- `publisher` writes MP4 `©pub`, `conductor` writes `©con`, `work` writes `©wrk`, `contentGroup` writes `©grp`, `grouping` writes `GROUPING`, `encodedBy` writes `©enc`, `encoderSettings` writes `©too`, and `mediaType` writes the `MEDIA` freeform.
- Both `AUDIOMATOR_*_TEXT` and `TAGLIBAUDIOMETADATA_*_TEXT` MP4 namespaces are legacy provenance. No default write surface, including formatted-number APIs, creates or renames them. They remain readable and are preserved until an explicit normalization plan retires them.
- Formatted MP4 number text no longer persists padding. It writes the native pair and displays the normalized pair. A number-only formatted value preserves the resolved existing total.
- Typed pair edits recover a sole valid orphan total before writing, so `TRCK=3` plus `TXXX:TRACKTOTAL=12` becomes `3/12`. Contradictory aliases are `.ambiguous` and block the edit without mutation.
- Removing a first track/disc component with a retained total remains supported on MP4 (`0/total`) and ID3-backed formats (`/total`). ASF is the format that rejects a number-zero-plus-total request; earlier documentation that listed most formats was incorrect.
- `replaceBasicMetadata` and `updateBasicMetadata` validate YEAR text and throw `MetadataValidationError.invalidYearText` for non-date text. The typed `.year` patch path does not run this Basic-specific validator.
- A Basic replacement always supplies an advisory projection, so it can retire recognized MP4 freeform advisory aliases even when the caller did not intentionally edit the advisory. Use the typed advisory field when alias retirement must be scoped.
- `StructuredID3v2Frame.fields` is merged into the bridge payload dictionary and can overwrite reserved keys; leave it empty. `versionedText` is a supported ID3 write type alongside `text`, `userText`, `url`, `ufid`, `chapter`, `tableOfContents`, and `podcast`.
- Structured comments/lyrics replace-all is limited to ID3-backed formats and TrueAudio. MP4 ignores structured comments/lyrics; APE-family and FLAC/Ogg reject them.

### New APIs

- `MetadataFieldRegistry.canonicalSchemas`, `schemasBySemanticKey`, `canonicalSchema(forSemanticKey:)`, and `duplicatePreferredWriteTargets`.
- `MetadataFieldSchema.semanticKey`, `nativeTargets`, `capability(for:)`, `writeTarget(for:)`, and `mappingContractVersion`.
- `MetadataMappingCatalog` and the `MetadataNativeFamily`/`MetadataNativeTarget`/`MetadataMappingCapability` vocabulary.
- `numberingInventory(at:)`, `planNumberNormalization(at:policy:groups:)`, and `applyNumberNormalization(_:to:expectedVersion:)`.
- `MetadataNumberResolutionPolicy` values `.useNative`, `.useLegacy`, and `.replace(number:total:)`.
- `explicitAdvisoryRawValue` and the native number-private-text inventory types.

### Application migration instructions

1. Replace `.date` with `.year` for Year edits and `.standaloneDate` for a standalone Date edit. Do not supply both `date` and `year`.
2. Stop inferring Year from Release Date. Display and validate the two fields independently.
3. Migrate MP4 Release Date edits from `©day` to `.releaseDate`; keep `.year` for `©day`.
4. Stop writing or renaming private `AUDIOMATOR_*_TEXT`/`TAGLIBAUDIOMETADATA_*_TEXT` atoms. If cleanup is required, present `planNumberNormalization` output for preview and apply that exact plan under the captured version.
5. Replace any assumption that zero is absence for `ITUNESADVISORY`, `pgap`, `hdvd`, or `shwm`. Present `0` as a present false/not-explicit value.
6. Read `numberingInventory` before a number edit when the file may contain legacy standalone totals; surface `.ambiguous` instead of choosing a value.
7. Treat the MP4-exclusive fields as container-specific and patch-only at the Basic surface. Do not advertise them for non-MP4 families; `rate` is read-only for typed writes.
8. Do not expect `replaceBasicMetadata` to write MP4-exclusive fields; use `applyMetadataPatch` or `writeStructuredMetadataWithVerification`.

## Migrating from 0.5.3 to 0.6.0

The `0.6.0` release added audio-content continuity, validated public API additions, and raised the minimum Swift tools to 6.4. These changes are historical for the tagged release; `0.7.x` adds contract 2.2 behavior and the date/ownership corrections on top.

### Minimum Swift tools

The package manifest requires Swift tools 6.4. Toolchains older than 6.4 are rejected at manifest resolution. Swift 6.0 and 6.1 reject the source syntax, and Swift 6.3 cannot import macOS 26.5/27 SDK modules because its Clang lacks the SDK's `-target-arch-variant` support, so the previous 6.0 declaration could admit consumers that could not compile the package. Update Xcode or the Swift toolchain before resolving this version.

### Audio-content continuity

- `readSnapshot(from:includingAudioContent:)` and `readBasicSnapshot(from:includingAudioContent:)` are additive. Default reads still return `nil` audio identity and do not scan audio.
- `applyMetadataPatch` and `applyRawMetadataPatch` gained guarded overloads requiring both `expectedVersion` and `expectedAudioContent`.
- Existing unguarded overloads retain behavior. Basic replacement, whole-map raw replacement, structured writes, and public bridge writes do not gain the audio guard.
- Availability is limited to WAV, AIFF/AIFF-C, and native FLAC. Unsupported layouts return `nil` on read and throw `MetadataAudioContentError.unavailable` from a guarded write. Two missing identities never establish continuity.
- WAVE `bext` and `iXML` are excluded from the identity because TagLib may relocate them during a metadata save. Other ancillary edits can still change the token.
- The deprecated typed `applyMetadataPatch(_:to:expectedVersion:failurePolicy:)` overload forwards to the unguarded path and cannot check audio identity.
- Empty typed/raw patches bypass the guards and return a no-op result.

See [Audio-content continuity](../explanation/AUDIO_CONTENT_CONTINUITY.md).

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
| Message-only `operationFailed` emission | `operationFailedWithUnderlying(_:)`; the old case remains for compatibility and is still emitted by one numbering guard |

Deprecated declarations remain callable where source compatibility is practical. Do not build new code on them. The complete compatibility-overload table is in the [manager API](../reference/API.md).

### Behavior changes to account for

1. **Basic replacement vs. update.** `replaceBasicMetadata` replaces the complete modeled Basic projection; empty/default fields clear values. `updateBasicMetadata` captures a version and is the safe read/modify/write form. Do not treat `BasicMetadata.empty` as a partial patch.
2. **Verification always throws.** A mismatch aborts before commit. `warnings` on a successful result are residual container advisories.
3. **Low-level product.** Starting in 0.5, the facade does not re-export `CTagLibBridge`. Add `.product(name: "TagLibAudioMetadataLowLevel", ...)` and `import CTagLibBridge` if you name bridge types.
4. **Raw native keys.** Raw APIs accept prefixless TagLib `PropertyMap` keys. `----:` native MP4 atom keys reject; use `StructuredMetadata.mp4Atoms`.
5. **MP4 dates.** In `0.7.x`, MP4 YEAR is `©day`; `.date` is a legacy YEAR alias and `.standaloneDate`/`.releaseDate` use freeforms. The older 0.6.0 behavior treated `.releaseDate` as `©day`; that is historical, not current.
6. **Number pairs.** Native ID3 families write combined `TRCK`/`TPOS`; MP4 uses `trkn`/`disk`; generic/Xiph uses separate total keys; ASF uses native text pairs. Partial removal with a retained total is supported on MP4/ID3/Xiph/APE and rejected on ASF.
7. **Privilege-bearing files.** setuid/setgid files reject before staging. Clear the bits explicitly if editing is intended.
8. **TrueAudio mixed surfaces.** Files with unmodeled APEv2 fields reject rather than silently leaving a conflicting secondary tag.
9. **Durability status.** High-level writes return `commitStatus`. `.durabilityUncertain` means the rename already committed. Do not retry blindly.
10. **ASF and structured removal.** ASF attributes are upserts. ID3 URL/UFID frames have no individual structured removal; empty payloads reject. (Structured ID3 *text* removal uses empty values and is supported.)
11. **Structured writes are collection-scoped.** Omitted collections are preserved; non-empty artwork/lyrics/comments replace their collection where supported. Empty collections require `replacingCollections` to remove the final entries.
12. **`writeTagMetadata` is not a patch.** It writes the bridge model's mapped fields. Read current values first if you intend a partial edit, and supply a verification context if you need readback. It cannot write the MP4-exclusive facade fields.
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
- [ ] Pin production dependencies to `0.7.3` or an earlier tagged release; do not rely on an untagged `main` state.
- [ ] Add the low-level product only if you directly use bridge declarations.
- [ ] Replace deprecated reads/writes with the named alternatives.
- [ ] Remove `failurePolicy:` arguments and handle thrown verification failures.
- [ ] Update exhaustive error switches for new cases.
- [ ] Use typed function references if you store API references.
- [ ] Pass `expectedVersion` when editing from a snapshot.
- [ ] Adopt the audio guard only if automatic conflict rebasing needs it; require explicit reload when an identity is missing.
- [ ] Check `RIFFMetadataWritePolicy` scope if you write structured metadata to non-RIFF formats.
- [ ] Move Year edits to `.year`, standalone Date edits to `.standaloneDate`, and MP4 Release Date edits to `.releaseDate`.
- [ ] Audit code that assumes `BasicMetadata` edits cover every Basic property; use `MetadataPatch` for the MP4-exclusive fields.
- [ ] Check concrete ID3v2.3 tags with `StructuredMetadata.id3v2MajorVersion` before offering date edits.
- [ ] Do not infer a YEAR from DATE in low-level reads; check the native owner and absence directly.
- [ ] If you inspect MP4 comments or lyrics, expect `©cmt`/`©lyr` from typed patches; structured comment/lyric collections are still unsupported on MP4.
- [ ] Verify the final app embeds and signs the namespaced framework.
- [ ] Run your own type, integration, and distribution checks; the package's tests do not validate your app.

## What is not promised

- A stable Swift ABI or C++ ABI.
- That every 0.4/0.5 source pattern compiles without adjustment.
- That a deprecated overload behaves like the replacement in every respect.
- That a package update changes an application's conflict policy automatically.
- That an untagged `main` state is a release.
- That `replaceBasicMetadata` writes every property present on `BasicMetadata`.
