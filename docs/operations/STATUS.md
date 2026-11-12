# Current validation status

This page is a snapshot of the latest known validation state for the current source tree and the limits that remain. It is not a chronological log of every campaign. Historical evidence, including the original failing audits, is retained in [engineering records](../records/README.md).

## Release boundary

| Item | State |
| --- | --- |
| Current release | `0.7.3`, declared 2026-11-12 |
| Source | Unreleased `codex/api-mapping-performance`, based on published `0.7.3` |
| Later tag | None |
| Documentation scope | Current source includes breaking API cleanup; tagged-release guidance is identified in [Migration](MIGRATION.md) |

Version `0.7.3` includes mapping contract 2.2, the `0.7.1` and `0.7.2` corrections, and the native-owner state-preservation repairs. The TagLib binary and mapping contract ID are unchanged from `0.7.2`. Release notes are in the [changelog](../../CHANGELOG.md).

## Write-preparation follow-up

The current follow-up narrows discarded readability projections and reuses same-open-file property evidence. Focused regressions and the bounded-concurrency profile pass; its full gates are pending. The previous API campaign's accepted 162-test gates below do not certify this follow-up. See [write-concurrency record](../records/remediation/REM-2026-11-12-write-concurrency.md).

## Unreleased API/performance candidate

This branch intentionally removes ambiguous compatibility-only API and keeps native mapping contract 2.2. It is not a source-compatible patch release. Final production implementation is `4dd2a60`; subsequent campaign edits are documentation/comments only. The [audit and performance record](../records/remediation/REM-2026-11-12-api-mapping-performance.md) contains the removal inventory, migration, all 33 before/after measurements and exact evidence boundaries.

| Check | Current observed result |
| --- | --- |
| Strict Debug and Release | Both accepted; 162 XCTest declarations (160 passed, two original opt-in skips), 179 Swift Testing declarations in 41 suites passed |
| Mandatory native matrices and new cache/lookup tests | Required named evidence present; no case-count reduction, unexpected skips or failures |
| Gate policy | 26 regressions passed |
| Documentation/generators | 54 Markdown files and all four generated-reference checks passed |
| Independent consumers | Both products built with strict warnings and ran successfully |
| AudioMator local candidate | 62 core and 579 serial app-hosted tests passed; unsigned Release/artifact validation passed; final affected erase journey also passed |
| Warm local I/O profile | Declared lookup roughly 80–120 times faster; metadata-heavy reads about 7–14% faster. Writes vary; some workloads are slower. No universal write-speed improvement claimed |
| Publication | No version bump, tag, push or publication; an explicitly breaking release and consumer migration are required |

Current strict-gate evidence: `.build/test-evidence/debug-20261112-133244-22151/` and `.build/test-evidence/release-20261112-133604-22116/`. The application record distinguishes its full-suite source snapshot from the subsequent exact-advisory erase check. Existing application XCTest isolation warnings remain visible. Sanitizers, minimum-platform/device runtime, cold storage, peak memory and large-artwork performance were not evaluated. Historical release-line evidence follows and is not a substitute for these candidate runs.

## Recorded 0.7.3 validation

The state-coverage repairs were validated on `codex/metadata-state-coverage-repairs`, then merged to `main` as `e9337f2` without source changes. The expanded gate requires the new state matrices, all previous matrices, at least 158 XCTest / 179 Swift Testing declarations, and 24 policy regressions.

| Check | Debug | Release |
| --- | --- | --- |
| Gate result | `accepted: true` | `accepted: true` |
| XCTest | 158 executed; 156 passed, two original opt-in skips, 0 failures | Same |
| Swift Testing | 179 declarations in 41 suites passed | Same |
| State matrices | 8,282 additional parameterized cases | Same |
| Gate policy | 24 Python regressions passed | Same |

Both gates compiled production and tests with Swift/C warnings as errors, and the mandatory privilege test passed with expanded filesystem access. Both independent consumers passed in separate runs, and all 24 policy tests passed. The evidence is recorded in [the state-coverage repair record](../records/remediation/REM-2026-11-11-state-coverage.md). These runs were on the pre-merge branch; no full accepted gate was rerun on the exact `0.7.3` release commit, and release preparation changes documentation only. Release preparation passed the documentation check over 53 Markdown files. Tag creation and publication remain maintainer-owned. Historical release-line results below do not certify `0.7.3`.

## Latest observed 0.7.2 release-line package gate

The recorded repair campaign examined the repaired working tree based on `c3f1481`; those repairs are included in the `0.7.2` release. The campaign used expanded filesystem access for module caches and the privilege-test prerequisites. Both configurations were accepted:

| Check | Debug | Release |
| --- | --- | --- |
| Gate result | `accepted: true` | `accepted: true` |
| XCTest | 158 executed; 156 passed, 2 existing opt-in skips, 0 failures | 158 executed; 156 passed, 2 existing opt-in skips, 0 failures |
| Swift Testing | 165 declarations in 36 suites passed | 165 declarations in 36 suites passed |
| Strict compilation | Swift and C/Objective-C warnings as errors | Same |
| Privilege rejection | Passed with expanded filesystem access | Same |
| Gate policy | 22 Python regressions passed | Same |

Additional recorded checks:

| Check | Result |
| --- | --- |
| Strict production build | Passed; the test-target `DeprecatedDeclaration` exception does not apply to production |
| Package consumers | Facade-only and low-level executables passed |
| Documentation | 52 Markdown files and all four generated-reference checks passed at the last documentation pass |
| AudioMator local override | 62 core and 574 serial app-hosted tests passed; unsigned Release artifact validation passed |
| Release tag and publication | Maintainer-owned; not created by this documentation pass |
| Hosted CI, sanitizers, minimum-platform runtime for this tree | Not re-run for the `0.7.2` release commit; no additional validation was performed for release preparation |

Evidence: `.build/test-evidence/debug-20261111-124030-69547/`, `.build/test-evidence/release-20261111-124120-69890/`, the restricted rerun `.build/test-evidence/debug-20261111-132710-75098/`, and the [audit repair record](../records/remediation/REM-2026-11-11-audit-integrity-repairs.md).

No full accepted gate has been rerun on the exact `0.7.2` release commit. An earlier restricted rerun reproduced the same 158 XCTest and 165 Swift Testing counts, but failed only `privilegedFilesRejectBeforeCloneInBothTransactionEngines` because the host strips the privilege bits before the test can observe them. That is an environment-precondition failure, not evidence that the recorded acceptance failed. The full gate remains red in such an environment; use the authoritative gate and its prerequisites when making a release decision.

## What changed in 0.7.2

- Audit repairs preserve untouched Basic date arrays, malformed text, duplicates, whitespace and absence; separate Encoded By from Encoder Settings; retire only explicitly edited MP4 aliases; normalize MP4 pairs to unsigned 16-bit values; and verify Basic Date, Content Group, structured ID3 text removal, ASF projections and APE engine aliases.
- Native-mapping follow-up repairs MP4 Content Group, Grouping and Work ownership; MP4 Movement Number/Count atoms; encoder ownership; ID3v2.4 Content Group; and FLAC/Ogg/ID3 container reads.
- The test system adds independent MP4, FLAC, APE-family, Ogg, ASF and ID3-container lifecycle matrices, named gate evidence and strict compilation. See [Mapping test acceptance](MAPPING_TEST_STRATEGY.md).
- DSF/DSDIFF structured writes now accept native ID3 frame upserts while retaining the explicit comment/lyric collection-replacement rejection.

## What changed in 0.7.3

- Native MP4 item and ID3 date-frame owners survive PropertyMap replay, including absence; low-level date reads use native owners on MP4, ID3, Xiph, and APE.
- MP4 `.comment`/`.lyrics` use native `©cmt`/`©lyr`; ASF semantic custom fields use native Unicode attributes and reconcile only their case aliases.
- Whole-map replacement retains unchanged submitted arrays literally; MP4 custom-field writes retain existing name spelling and unchanged projections do not collapse native arrays; ARTIST no longer falls back to ARTISTS.
- The mixed-framework gate requires the sparse-state matrices and 8,282 additional cases. See [Mapping test acceptance](MAPPING_TEST_STRATEGY.md#sparse-state-and-write-surface-acceptance).

## Coverage and limits

- The lifecycle and sparse-state matrices are explicit field/state subsets, not a complete field × format × tag-version × writer cross-product. The coverage inventory and minimum case counts are owned by [Mapping test acceptance](MAPPING_TEST_STRATEGY.md).
- Existing ID3v2.3 tags are read-only for independent date writes. Inspect `StructuredMetadata.id3v2MajorVersion`; an extension-level ID3v2.4 capability does not prove a concrete v2.3 file is writable.
- MP4 track/disc components are unsigned 16-bit values through 65535; MP4 movement is bounded to 0...32767. External readers may decode MP4 native pairs differently.
- Audio-content identity remains unavailable for many layouts, including MP3, MP4/M4A, raw AAC, Ogg, ASF, APE-family, DSD, and ambiguous chunk layouts. A nil identity never establishes continuity; see [Audio-content continuity](../explanation/AUDIO_CONTENT_CONTINUITY.md).
- Fixture coverage is finite. `fixtureCovered` does not certify every codec variant, unknown native structure, minimum-OS runtime, device, or external decoder.
- A successful package test run does not validate an embedding application's signing, rpath, entitlement, or interactive UI behavior.

## Historical evidence

| Revision or release | Evidence | Current interpretation |
| --- | --- | --- |
| `0.7.3` | Current release, declared 2026-11-12; source branch merged as `e9337f2` | Includes the native-owner state-preservation repairs above |
| `0.7.2` | Release tag, declared 2026-11-11 | Previous release; includes the audit, native-mapping, test-system and MP4 Content Group repairs; does not include `0.7.3` |
| `0.7.1` | Release tag and merge `649b7a9`; date/ownership, comment verification and UFID repairs | Previous release; does not include the `0.7.2` repairs |
| `0.7.0` | Release tag and mapping contract 2.2 | Introduced the field identities and date/number model described by the current mapping contract |
| `AUD-2026-11-11` | Independent audit on the pre-repair tree | Historical failing evidence; the reproduced blockers were repaired by the audit-integrity campaign |
| Earlier test-system and native-mapping records | [Records index](../records/README.md) | Historical branch evidence; current source and status supersede their pass/fail claims |

## Maintaining this page

Update this page only when the latest known state changes: a new release or tag, a changed accepted gate result, a new limitation, or a materially different environment. Campaign narratives, superseded failures, and per-run evidence belong in [engineering records](../records/README.md). Do not turn this page into a chronological log, and do not claim a configured CI job passed for a revision that did not run it.
