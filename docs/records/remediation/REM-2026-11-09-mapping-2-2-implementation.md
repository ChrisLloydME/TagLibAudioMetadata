# REM-2026-11-09 — mapping contract 2.2 package implementation

- **Record ID:** REM-2026-11-09
- **Date:** 2026-11-09
- **Type:** Remediation / implementation
- **Contract:** `AM-TLAM-MAPPING-2.2` in [METADATA_MAPPING_SPEC.md](../../reference/MAPPING_SPEC.md)
- **Assignment:** [MAPPING_REFACTOR_AGENT_PROMPT.md](../../plans/MAPPING_REFACTOR_AGENT_PROMPT.md)
- **Branch:** `codex/metadata-mapping-spec`
- **Implementation commits:** `67031a3` (`Implement AM-TLAM-MAPPING-2.2 package semantics`) and `73f8d9c` (`Add native ASF independent date attributes`)
- **Documentation commit:** the commit containing this record
- **Status:** Final for the package-side scope; bounded gaps recorded below

## Scope

Implemented and tested the package-side target contract in this repository only. No sibling repository, application project, resolved dependency source, or user library was opened. No release number was assigned, no tag/push/PR was created, and the external TagLib binary was not rebuilt.

The work is source-compatible except for documented semantic changes: `.date` remains a deprecated YEAR-slot spelling, `.year` and `.standaloneDate` are additive, and the private number-text migration behavior is reversed to preservation plus explicit cleanup.

## Method

- Read the full specification before editing.
- Generated the explicit registry catalog at development time from the normative matrix with `scripts/generate-mapping-registry.py`; production code consumes checked-in Swift values only.
- Used the Xcode MCP toolset for project inspection and `swift build`/`swift test` in the workspace for compilation and test evidence.
- Ran fixture-backed tests that exercise the real TagLib bridge, plus independent frame/atom/APE/RIFF/ASF inspectors already present in the suite.
- Compared the baseline and final suites with the same command and environment.

Environment: macOS 27.2 arm64, Xcode 27.2, Apple Swift 6.4.2. SwiftPM required `--disable-sandbox` because the host refused `sandbox_apply`; workspace-local Clang/Swift module caches were used because the default caches were not writable.

## Baseline

Command:

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/modulecache" \
SWIFT_MODULECACHE_PATH="$PWD/.build/modulecache" \
swift test --disable-sandbox --disable-keychain --disable-netrc
```

| Runner | Result |
| --- | --- |
| XCTest | 153 executed, 2 skipped, 0 failed |
| Swift Testing | 72 tests in 19 suites, 1 environment-dependent failure |
| Overall | 1 failure: `CleanRoomPrivilegeTests.privilegedFilesRejectBeforeCloneInBothTransactionEngines` precondition `before.st_mode & 0o7777 == permissions` |

The privilege test was not modified or hidden. The host strips setuid/setgid bits; the production rejection path could not be exercised on this host.

## Final

Same command, after the changes:

| Runner | Result |
| --- | --- |
| XCTest | 156 executed, 2 skipped, 0 failed |
| Swift Testing | 93 tests in 22 suites, 1 environment-dependent failure |
| Overall | 243 passed, 2 skipped, 1 environment-dependent failure of 246 exercised |

The only failure is the same privilege-bit precondition. No new baseline failure remains.

Build: `swift build --disable-sandbox --disable-keychain --disable-netrc` passed. Documentation: `python3 scripts/check-docs.py` passed for 36 Markdown files. Generated checks passed:

```sh
python3 scripts/generate-mapping-registry.py --check
python3 scripts/generate-field-schema.py --check
```

## Phase gates

| Phase | Gate | Result | Evidence |
| --- | --- | --- | --- |
| 0 | Baseline and traced acceptance ledger | Pass | Baseline/final runs above; this record and the section status table. |
| 1 | Complete registry, semantic keys, native targets, capability states, collision detection | Pass | 101 `MetadataFieldKey` cases; 100 semantic profiles; 26 MP4-exclusive rows; two MKV registrations; `FormatCapabilityTests` and `MappingContractCoverageTests` cover bridge parity, YEAR owner, the complete 26-row atom ledger, MKV gates, duplicate-target invariants, and the `.date`/`.year` collision rejection. |
| 2 | Independent reads with full YEAR text and DATE/RELEASEDATE/ORIGINALDATE provenance | Pass for MP3/MP4/FLAC/Ogg | `AuditRemediationRegressionTests.testBasicPreservesFullRecordingDateWithoutLegacyYearDuplication`, `FixtureMetadataRoundTripTests.testRecordingAndReleaseDatesRemainIndependentWhereRepresentable`, `ReviewMetadataIntegrityTests.basicUnrelatedEditPreservesIndependentYearAndDate`, `testMP4KeepsYearStandaloneDateAndReleaseDateIndependent`. |
| 3 | Independent writes, version-aware ID3 dates, no reconciliation | Pass | Same date tests plus `CleanRoomContractTests.mp4DateEditsKeepYearAndReleaseDateIndependentWithoutContradictionChecks`; no `conflictingMP4Date` throw path remains. |
| 4 | Native totals, orphan recovery, no private creation/renaming, explicit cleanup | Pass | `LegacyNumberingRecoveryTests` (9 tests): ID3 orphan total migration, MP4 orphan total migration, unrelated preservation, ambiguous rejection without mutation, scoped/version-guarded plan, both namespaces retained or removed explicitly, formatted number APIs create no private atoms. |
| 5 | Four-state advisory, 26 MP4-exclusive entries, two MKV gates | Partial, as specified | `MP4ExclusiveFieldTests` (6 tests) covers every MP4-exclusive row except the writable `RATE` scale; `MappingContractCoverageTests` asserts the full 26-entry atom ledger and that `rate` is the only read-only row. Label↔code vocabulary for `ITUNESMEDIATYPE` is not bound; the native integer code is lossless. MKV registrations report `.unsupported`. |
| 6 | Preservation/regression sweep | Pass | Full suite; exact native preservation for Xiph/APE aliases and qualified keys; MP4 atom/cardinality preservation; ID3 collection preservation; tag version preserved on save. |
| 7 | Docs, schema, honest capability report | Pass | API/FIELD_SCHEMA/FORMATS/PRESERVATION/USAGE/MIGRATION/ARCHITECTURE/README/CHANGELOG updated; spec section status added; `check-docs.py` passes. |

## Field/entry ledger

- **Core additions:** `year`, `standaloneDate`, `contentGroup`, `artists`, `replayGainTrackPeak`, `replayGainAlbumPeak`. `.date` is a deprecated alias of YEAR and is excluded from canonical enumeration.
- **Independent dates:** YEAR full text; standalone DATE; RELEASEDATE; ORIGINALDATE. MP4 YEAR `©day`; DATE `F(DATE)`; RELEASEDATE `F(RELEASEDATE)`; ORIGINALDATE `F(ORIGINALDATE)`. ID3 v2.3 `TYER`/`TDAT`/`EXTFRAME(TDRL)`/`TORY`; v2.4 `TDRC`/`TXXX(DATE)`/`TDRL`/`TDOR`. Xiph/APE use exact YEAR/DATE/RELEASEDATE/ORIGINALDATE keys.
- **Totals:** `trkn`/`disk` (MP4), `TRCK`/`TPOS` plus legacy `TXXX` totals (ID3), `TRACK`/`DISC` (APE family), `TRACKNUMBER`/`DISCNUMBER` (Xiph), ASF text pairs. Native positive components win; sole orphan totals are recovered; conflicting aliases are ambiguous.
- **Private namespaces:** `AUDIOMATOR_*_TEXT` and `TAGLIBAUDIOMETADATA_*_TEXT` are read and preserved, never created or renamed. Explicit plans remove only listed identities.
- **MP4-exclusive rows:** DIRECTOR `©dir`; ITUNESACCOUNT `apID`; ITUNESADVISORY `rtng`; ITUNESALBUMID `plID`; ITUNESARTISTID `atID`; ITUNESCATALOGID `cnID`; ITUNESCOMPOSERID `cmID`; ITUNESCOUNTRYID `sfID`; ITUNESGAPLESS `pgap`; ITUNESGENREID `geID`; ITUNESHDVIDEO `hdvd`; ITUNESMEDIATYPE `stik`; ITUNESOWNER `ownr`; ITUNESPURCHASEDATE `purd`; RATE `rate`; SHOWMOVEMENT `shwm`; STOREDESCRIPTION `sdes`; TOTALDISCS `disk`; TOTALTRACKS `trkn`; TVEPISODE `tves`; TVEPISODEID `tven`; TVNETWORK `tvnn`; TVSEASON `tvsn`; TVSHOW `tvsh`; TVSHOWSORT `sosn`; WORK `©wrk`.
- **MKV-exclusive registrations:** TVEPISODE `PART_NUMBER@TargetTypeValue=50`; TVSEASON `PART_NUMBER@TargetTypeValue=60`. Both read-only/unsupported, no preferred write target.
- **Advisory:** absent, present `0`, present `1`, present `2`; unknown codes retained as raw provenance. `0` is not absence.

## Repairs

- Added `MetadataMapping.swift`, `MetadataMappingCatalog.swift` (generated), `MetadataNativePlanning.swift`, and `MetadataNumberInventory.swift`.
- Extended `MetadataFieldSchema` and `MetadataFieldRegistry`; `.year` owns YEAR canonically, `.date` remains an alias.
- Reworked typed-patch storage selection by primary format and exact native target; added MP4 atom removal, ID3 `versionedText`, native Xiph/APE key mutation, and MP4 numeric/Boolean atom writes.
- Reworked Basic preservation to use exact native collections instead of whole-map engine `PropertyMap` replay; added the numbering inventory/plan/apply API.
- Removed four-character YEAR truncation from read and write paths, removed MP4 date reconciliation, and retained complete YEAR text.
- Stopped all private number-text creation/renaming; retained legacy reads and added explicit retirement.
- Added `explicitAdvisoryRawValue`, 16 MP4-exclusive fields, and MKV target registrations without advertising unsupported writes.
- Added fixture tests for independent dates, legacy numbering recovery, private retirement, advisory states, and MP4-exclusive fields.
- Regenerated `FIELD_SCHEMA.md` and extended the documentation checker/generator to consume the native catalog.

## Verification limitations

- `RATE` typed write is intentionally unsupported: no verified native type/scale in this profile. Existing values are read and preserved.
- `ITUNESMEDIATYPE` label vocabulary is not bound to numeric codes; known and unknown integer codes round-trip, but the application must not infer labels from list order.
- MKV native read/write codec is not implemented; only target registrations exist.
- Cross-tool fixtures, independent FFprobe/FFmpeg oracles, AIFF/Opus date conformance, ASan, TSan, minimum-platform builds, iOS runtime, x86_64, and device tests were not run in this pass. Release-mode tests and a strict Swift `-warnings-as-errors` build did run and matched the Debug result.
- The privilege-bit test cannot pass on this host; the production path was not weakened.
- AudioMator, the mirrored specification, and application adoption were not touched. Package-only migration instructions are in [MIGRATION.md](../../operations/MIGRATION.md#migrating-from-0-6-0-to-0-7-0).

## References

- Branch: `codex/metadata-mapping-spec`
- Implementation commits: `67031a3`, `73f8d9c`
- Contract: [METADATA_MAPPING_SPEC.md](../../reference/MAPPING_SPEC.md)
- Current docs: [STATUS.md](../../operations/STATUS.md), [FIELD_SCHEMA.md](../../reference/FIELDS.md), [PRESERVATION.md](../../explanation/PRESERVATION.md), [MIGRATION.md](../../operations/MIGRATION.md)
- Tests: `Tests/TagLibAudioMetadataTests/Capabilities/FormatCapabilityTests.swift`, `Capabilities/MappingContractCoverageTests.swift`, `Integration/FixtureMetadataRoundTripTests.swift`, `Integration/CleanRoomContractTests.swift`, `Integration/ReviewMetadataIntegrityTests.swift`, `Integration/LegacyNumberingRecoveryTests.swift`, `Integration/MP4ExclusiveFieldTests.swift`
