# Public write-contract diagnostic remediation

| Field | Value |
| --- | --- |
| Record ID | `REM-2026-11-15-public-write-contract` |
| Type | Remediation |
| Date | `2026-11-15` |
| Status | Final, local acceptance |
| Examined revision | `903fa69e66d892542bae277310baadf90c1e1b3e` production baseline; handoff documentation `84a2ddbb488f08e1bc075a3ac6950554d86ff8a0` |
| Branch | `codex/public-write-contract-repairs-20261115` |
| Environment | macOS 27.2.1 (arm64), Xcode 27.2 (27B52), Apple Swift 6.4.2; pinned TagLib 2.3.1-r2 |
| Supersedes | `REM-2026-11-14-diagnostic-repairs` for the public write-contract findings below |
| Superseded by | `none` |
| Related records | `REM-2026-11-14-release-review-followup`, `REM-2026-11-14-diagnostic-repairs` |
| Scope | Package-only repairs for the adjudicated F-01…F-15 public write/read contract. No application-repository access, external engine source checkout, user-library mutation, release, tag, push or PR operation. |

## Summary

The adjudicated diagnostic gaps were reproduced or source-bounded against the reviewed production baseline, then repaired on
`codex/public-write-contract-repairs-20261115`. Confirmed repairs: legal ID3v2.3 frame-status flags and DSDIFF `PROP`-child
locating (F-05), full-model ownership of only modeled fields (F-06), structured bridge encoding/range/destination validation
(F-07), an explicit 64-character generated-padding bound (F-08), case-normalized MusicBrainz TXXX alias cleanup (F-09),
observed-version WAV/AIFF saves (F-10), canonical-key MP4 freeform raw edits (F-11), the narrow XM property-map tracker route
(F-13), the four real F-14 projection defects, and numberText preflight before staging (F-15).

The diagnostic's F-01/F-02/F-03/F-04/F-12 recommendations were not implemented literally. Ordinary pair aliases still retire
only for the explicitly edited pair after value recovery; private `AUDIOMATOR_*_TEXT` and
`TAGLIBAUDIOMETADATA_*_TEXT` provenance now survives ordinary whole-model writes. Basic MP4-exclusive writes remain
intentional (`.rate` read-only). The Basic YEAR prefix filter is frozen and documented rather than expanded into a calendar
grammar. F-04 remains an unverified defensive warning concern. Recognized ASF TITLE/ARTIST/ALBUM/COMMENT/GENRE aliases still
retire only on their explicit semantic edit.

## Scope and revision

The production baseline was `903fa69e66d892542bae277310baadf90c1e1b3e`; the documentation handoff `84a2ddbb…` added
`docs/plans/DIAGNOSTIC_REMEDIATION_PLAN_2026-11-15.md` with no production change. The repair branch was created from
`84a2ddbb…` before implementation. All writes in tests use disposable copies; repository fixtures were never mutated.
The diagnostic's Downloads and temporary probe directories were treated as optional evidence, not dependencies; all seeds
below are reconstructed by tests.

## Method

Targeted source inspection of the 45 implementation files named by the adjudication, followed by public-surface and
native-byte regressions. The primary oracle is an independent test-owned reader for each container (ID3v2.3 frame headers,
RIFF/AIFF chunks, DSDIFF chunks, ISO-BMFF atoms, FLAC comment blocks, XM header fields). Facade readback is supplementary,
not the only evidence. A narrow internal `MetadataFileTransaction.willStageForTesting` observer proves numberText preflight
ordering; it has no public controls.

## Findings and dispositions

| ID | Disposition | Evidence level | Repair / retained decision | Regression |
| --- | --- | --- | --- | --- |
| F-01 | Retained policy + one ownership repair | Reproduced (diagnostic) + runtime final | Ordinary `TRACKTOTAL`/`DISCTOTAL` aliases retire only for the explicitly edited pair after value recovery. Untouched groups and both private formatting namespaces survive ordinary writes. Whole-model preservation no longer drops private provenance. | `ordinaryAliasRetiresOnlyForEditedPair`, `privateProvenanceSurvivesOrdinaryWrites` |
| F-02 | Documentation defect | Reproduced (diagnostic) + source | Basic uses the typed planner for MP4-exclusive fields; `.rate` remains read-only. Docs corrected. | `fullModelPreservesUnmodeledOwners` (ownership), registry tests |
| F-03 | Frozen contract | Reproduced (diagnostic) + runtime final | The Basic `isRepresentableYearText` prefix filter is documented and tested as-is. No calendar grammar, derivation or rewrite was added. | `yearPrefixFilterRemainsBasicSpecific` |
| F-04 | Unverified; no production claim | Not reproduced | No erase redesign and no public fault-injection API. Best-effort raw-read warnings remain as before; the record does not claim removal of every native structure. | none |
| F-05 | Fixed | Reproduced (diagnostic) + runtime final | Legal status flags `0x20/0x40/0x80/0xE0` read literally; reserved low bits reject; grouping consumes one bounded identifier byte; compression/encryption still fail closed. DSDIFF ID3 is located only inside a declared `PROP` child with checked bounds. | `legacyV23StatusFlagsReadLiteralDates`, `legacyV23GroupingFlagSkipsBoundedIdentifier`, `undecodableV23FrameTransformsStillReject`, `dsdiffPropertyChildID3UsesBoundedTraversal` |
| F-06 | Fixed | Reproduced (diagnostic) + independent native final | A whole-model write preserves schema-known but unmodeled owners, unknown owners and private provenance; modeled nil still removes. Verified for FLAC `PERFORMER` and MP4 `©dir`/`©alb`. | `fullModelPreservesUnmodeledOwners`, `privateProvenanceSurvivesOrdinaryWrites` |
| F-07 | Fixed | Reproduced (diagnostic) + runtime final | MP4 reserved atoms validate exact codec/range (`trkn`/`disk` 0…65535, movement 0…32767); unknown atom types reject; ASF type tokens canonicalize once and unknown types reject; ASF string/binary value classes validate; collections the destination does not consume reject before save. | `mp4IntPairOverflowRejectsWithoutMutation`, `mp4KnownAtomCannotChangeCodec`, `asfNoncanonicalTypeIsCanonicalTextOrRejected`, `crossFormatStructuredCollectionsRejectAtomically` |
| F-08 | Fixed | Source-supported (diagnostic) + safe runtime final | One documented maximum of 64 generated padding characters is checked before formatting or staging; 65, 2,000,000,000 and `Int.max` reject; 64 writes. No unbounded formatter was executed. | `generatedPaddingWidthRejectsBeforeFormatting`, `maximumGeneratedPaddingStillWrites` |
| F-09 | Fixed | Reproduced (diagnostic) + native final | TXXX alias removal normalizes both sides; the canonical MP3 `UFID` is written and the mixed-case legacy TXXX alias is absent. | `musicBrainzAliasCleanupUsesCaseInsensitiveIdentity` |
| F-10 | Fixed | Source-supported (diagnostic) + runtime final | Every WAV/AIFF save path now passes the observed ID3v2 major version; v2.3 WAV/AIFF `TYER`/`TDAT`/`TORY` and audio payload survive patch, raw and structured non-date edits. Direct v2.3 date restrictions remain. | `v23ContainersPreserveVersionDatesAndAudio` |
| F-11 | Fixed | Source-supported (diagnostic) + runtime final | Edited canonical keys and aliases resolve to exact MP4 freeform native items through the mapping descriptors; set and remove both persist. Untouched names/arrays survive; native `----:` keys remain rejected at raw boundaries. | `mp4RawCanonicalFreeformSetAndRemove`, `rawAPIsStillRejectNativeMP4Keys` |
| F-12 | Retained policy | Source + existing `CleanRoomNativeAliasTests` | Recognized ASF common aliases retire only on the explicit corresponding semantic edit; unrelated attributes and unchanged owners remain. Docs state the policy. | existing `asfCommonFieldEditsRemoveStaleCustomAliasesAndPreserveOtherAttributes` |
| F-13 | Fixed | Reproduced (diagnostic) + native final | XM tracker name is routed through a narrowly allowlisted property-map-only path; native XM header bytes show the fixed-width tracker field, zero padding and unchanged module suffix. | `xmTrackerNameTypedRouteWritesNativeBytes` |
| F-14 | Fixed in four subitems; three retained | Reproduced (diagnostic) + registry runtime final | Fixed: XM storable enumeration, role-qualified value-kind claims, MP4 total intPair descriptors, semantic dictionary/custom-template normalization. Retained: engine PropertyMap `DATE` → YEAR, native-key vs PropertyMap-key namespaces, best-available aggregate capability, Matroska target registrations with unsupported writes, role codec unavailable. | `registrySemanticAndTotalProjectionsAreConsistent`, `roleQualifiedTypedPatchStillRejects` |
| F-15 | Fixed | Reproduced (diagnostic) + runtime final | numberText is parsed, total-resolved and range-checked under the captured snapshot before the transaction stages a copy, then re-resolved on the staged file. MP4 70000 rejects with `integerOutOfRange`; ASF `0/5` rejects with `unsupportedPartialPairRemoval`; 32768/65535 remain valid. | `numberTextPreflightRunsBeforeStaging`, `asfZeroNumberTextPairRejectsBeforeStaging` |

### F-14 subitem dispositions

| Subitem | Disposition |
| --- | --- |
| Engine `schema(forPropertyMapKey: "DATE") == .year` | Retained and documented; semantic `canonicalSchema(forSemanticKey: "DATE") == .standaloneDate`. |
| Native MP4 `----:com.apple.iTunes:PRODUCER` unresolved by PropertyMap lookup | Retained namespace boundary; tested as a distinct identity, not remapped. |
| XM `schemas(storableIn:)` empty | Fixed: enumeration uses the same destination-aware `writeSupport` policy as typed writes. |
| Role-qualified scalar/array kinds advertised | Fixed: `acceptedPatchValueKinds` is empty while the role codec is unavailable; inspection/raw access remains. |
| MP4 `trackTotal`/`discTotal` scalar descriptions | Fixed: both targets are `intPair`/`.total` descriptors. |
| Aggregate capability reports native | Retained as best-available summary; source comments and docs now say so; destination-aware capability remains authoritative. |
| `<explicit key>` lookup fails / `.custom.nativeTargets` empty | Fixed: catalog and schema dictionaries normalize construction and lookup identically and retain `"<description>"` as a template. |
| `hasMappingFor(.tagLibPropertyMap)` false while mappings list it | Retained registration-vs-native-capability semantics; documented and tested. |
| Matroska entries listed while capability unsupported | Retained target-only registration with unsupported writes; MKV remains unavailable. |

## Test ledger

All tests use fresh disposable copies and reconstruct seeds. "Native oracle" means a test-owned byte reader.

| Finding | Public entry point | Format / version | Seed | Native oracle | Baseline result | Final result |
| --- | --- | --- | --- | --- | --- | --- |
| F-05 status flags | `readSnapshot` / `readMetadataResult` | MP3 ID3v2.3 | TYER 2004, TDAT 0906, TORY 1999 with frame status `0x20/0x40/0x80/0xE0` | `RepairID3v23Container` | Diagnostic: read failed | Pass; literal dates, bytes unchanged |
| F-05 grouping | `readSnapshot` | MP3 ID3v2.3 | TYER/TDAT with format `0x20` and group bytes | `RepairID3v23Container` | Not previously covered | Pass |
| F-05 transforms | `readSnapshot` | MP3 ID3v2.3 | compressed/encrypted format bits | bytes unchanged | Intended reject | Pass (still fail-closed) |
| F-05 DSDIFF | `readSnapshot` | DSDIFF `FRM8`/`PROP` | ID3 child inside `PROP` with TYER/TDAT | Test-owned DSDIFF walk | Diagnostic: rejected | Pass; DSD audio unchanged |
| F-06 FLAC | `writeTagMetadata` | FLAC | `PERFORMER=Alice`, `TITLE=Old`; model title only | `IndependentFLACProbe` | Diagnostic: PERFORMER lost | Pass; PERFORMER retained |
| F-06 MP4 | `writeTagMetadata` | M4A | `©dir`, `©alb`; model title only | `IndependentMP4Probe` | Source: known-but-unmodeled loss | Pass; `©dir` retained, modeled `©alb` cleared |
| F-07 trkn | `writeStructuredMetadata` | M4A | trkn 3/12; attempt first=70000 | `IndependentMP4Probe` | Diagnostic: 4464 | Pass; rejects, bytes unchanged |
| F-07 ASF type | `writeStructuredMetadata` | WMA | `type="String", value="hello"` | structured readback + bytes | Diagnostic: int 0 | Pass; text `hello`; unknown type rejects |
| F-07 collections | `writeStructuredMetadata` | M4A | valid atom + `asfAttributes` | `IndependentMP4Probe` | Diagnostic: silently discarded | Pass; rejects atomically |
| F-08 padding | `writeTrackNumber` | MP3 | widths 65, 2e9, `Int.max`, 64 | `IndependentID3Probe` | Source-supported hazard | Pass; rejects/64 writes |
| F-09 alias | `writeTagMetadata` | MP3 ID3v2.4 | TXXX `MusicBrainz Track Id` | `IndependentID3Probe` | Diagnostic: stale TXXX | Pass; UFID written, TXXX absent |
| F-10 WAV | patch/raw/structured | WAV ID3v2.3 | TIT2/TYER/TDAT/TORY | `RepairID3v23Container` | Diagnostic: source-supported v2.4 conversion | Pass; version 3, dates/audio retained |
| F-10 AIFF | patch/raw/structured | AIFF ID3v2.3 | same | `RepairID3v23Container` | Diagnostic: source-supported | Pass; version 3, dates/audio retained |
| F-11 MP4 raw | `applyRawMetadataPatch` | M4A | `MusicBrainz Album Type`, `MusicBrainz Track Id` | `IndependentMP4Probe` | Diagnostic: old value restored | Pass; set/remove, unrelated freeform retained |
| F-13 XM | `applyMetadataPatch(.trackerName)` | XM | existing module | `RepairXMHeader` | Diagnostic: unsupported | Pass; tracker field/padding correct; suffix unchanged |
| F-14 registry | public registry APIs | cross-format | static registry | direct assertions | Diagnostic: inconsistent | Pass |
| F-15 numberText | `applyMetadataPatch(numberText:)` | M4A / WMA | `"70000"`, `"0/5"` | staging observer + bytes | Diagnostic: late verification failure | Pass; typed preflight, no staging |

## Verification

| Check | Result | Counts / limits |
| --- | --- | --- |
| Focused new regressions | Pass | 23 Swift Testing declarations (35 executed cases) in `PublicWriteContractRepairTests` |
| Policy tests (`python3 -m unittest discover -s scripts/tests`) | Pass | 39 tests |
| Documentation check | Pass | 61 Markdown files |
| Canonical Debug gate | See final handoff | Complete suite; 181 XCTest floor retained and Swift Testing floor raised to 221 |
| Canonical Release gate | See final handoff | Complete suite |
| Consumer products | See final handoff | Debug/Release package consumers |
| ASan/TSan focused | See final handoff | Precompiled TagLib is not instrumented |

## Remaining limitations

- F-04 is not reproduced and remains an unverified defensive warning concern; erase is still best effort and no public
  fault-injection API exists.
- XM/S3M/IT fixed-width tracker storage may normalize comment/tracker text; the tracked fix covers the allowlisted XM
  tracker-name path and native header bytes, not every tracker module variant.
- DSDIFF locating covers a checked `PROP` child and the existing DSF/SDIFF layouts. Other arbitrary offsets remain
  unsupported rather than guessed.
- The pinned TagLib binary is precompiled; sanitizer runs cover package code only.
- WAV/AIFF v2.3 preservation is tested on reconstructed seeds; third-party v2.3 containers remain bounded by the same
  save-version call audit.
- No application-repository integration, release, tag, push or PR operation was performed or validated.

## References

- Branch: `codex/public-write-contract-repairs-20261115`, based on `84a2ddbb488f08e1bc075a3ac6950554d86ff8a0`.
- Production baseline: `903fa69e66d892542bae277310baadf90c1e1b3e`.
- Regression source: `Tests/TagLibAudioMetadataTests/Integration/PublicWriteContractRepairTests.swift`.
- Current contracts: [Writing](../../guide/WRITING.md), [Preservation](../../explanation/PRESERVATION.md), [Mapping spec](../../reference/MAPPING_SPEC.md).
