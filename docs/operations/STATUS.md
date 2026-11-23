# Current validation status

This page is a snapshot of the latest known validation state for the current source tree and the limits that remain. It is not a chronological log of every campaign. Historical evidence, including the original failing audits, is retained in [engineering records](../records/README.md).

## Release boundary

| Item | State |
| --- | --- |
| Current release | `0.8.1`, declared 2026-11-17 |
| Release source | `558df00`; release preparation changes documentation only |
| Release source | `558df00` (package-only Debug acceptance; `Sources/`, `Tests/` and `scripts/` are unchanged by the release commit) |
| Previous release | `0.8.0`, tag `9e986eb`, declared 2026-11-15; release source `959d688` |
| Later tag | None |
| Published binary identity | TagLib 2.3.1-r2; unchanged from `0.7.3` |
| Documentation scope | This page records release evidence. See [Migration](MIGRATION.md) and the [changelog](../../CHANGELOG.md) for release and development changes. |
| Current state | **Accepted for package-only Debug** on `558df00`: [REM-2026-11-17-numbering-contract-repairs](../records/remediation/REM-2026-11-17-numbering-contract-repairs.md) closes F-01, F-02, F-03, F-04 and F-07 from [AUD-2026-11-17-pre-release](../records/audits/AUD-2026-11-17-pre-release.md). The historical audit remains linked. |

The `0.8.1` source is accepted for the package-only **Debug** lane at commit `558df00`. The complete strict campaign accepted 181 XCTest declarations (179 passed, two reviewed opt-in skips), 306 Swift Testing declarations in 55 suites, 81/81 contract scenarios, 97 policy regressions and 23/23 killed calibration mutants; both package-owned consumers, focused ASan/TSan and five minimum-platform builds also passed. No Release lane, hosted CI, device run or application acceptance was performed for this source, and the release commit itself changes documentation only. The historical audit that found F-01–F-04 remains in the records index and is not rewritten as a pass.

Version `0.8.1` includes mapping contract 2.2, the `0.7.1` through `0.7.3` corrections, the `0.8.0` breaking API cleanup, public write-contract repairs and contract test system, and the `0.8.1` numbering repairs. The TagLib binary and mapping contract ID are unchanged from `0.7.3`. Release notes are in the [changelog](../../CHANGELOG.md).

`0.8.1` is a patch release: no public signature was removed, but numbering behavior changed and some previously accepted ambiguous recovery now rejects. Consumers should review [Migration](MIGRATION.md#migrating-from-0-8-0-to-0-8-1). Version `0.8.0` remains the breaking release that removed compatibility-only API; consumers upgrading from `0.7.x` must also review [that section](MIGRATION.md#migrating-from-0-7-3-to-0-8-0). No user-file migration is automatic.

## Current 0.8.1 acceptance (2026-11-17)

The `0.8.1` release source is accepted for the package-only **Debug** contract campaign on commit `558df00db502044e23d9935aa0b9fb328f237369` (branch `codex/numbering-contract-repairs-20261117`). The campaign source hash was `5cbc2ba2b6030751e624dc5f523fd6352ce9ac46e726c753e71df68ebb9b1032`; the before/after manifests were identical and the tracked diff was empty. Tag creation and publication are maintainer-owned.

| Gate | Result | Evidence |
| --- | --- | --- |
| Canonical Debug | **accepted: true**; 181 XCTest (179 passed, two reviewed opt-in skips), 306 Swift Testing declarations in 55 suites, 81/81 scenarios, no named failures or unexpected skips | `.build/test-evidence/debug-numbering-repairs-accepted2-20261117/` |
| Calibration | **23/23 killed**; control build/run pass; all mutants restored; source restored | `.build/test-calibration/20261117T122517-35984/calibration.json` |
| Policy and inventory | 97 policy regressions; 907 public-surface rows, 36 contracts, 81 scenarios, 62 adapters reconcile | `.build/numbering-repairs-accepted2-gate.log` |
| Consumers | Both package-owned consumers passed real writes, native assertions and audio checks | `.build/numbering-repairs-consumers.log` |
| Focused sanitizers | ASan and TSan each passed 26 tests in 3 suites without findings | `.build/numbering-repairs-asan.log`, `.build/numbering-repairs-tsan.log` |
| Minimum platforms | 5/5 strict Debug builds: macOS 13 arm64/x86_64, iOS 16 device arm64, iOS 16 simulator arm64/x86_64 | `.build/platform-*.log` |

The acceptance closes F-01, F-02, F-03, F-04 and F-07 from the [pre-release audit](../records/audits/AUD-2026-11-17-pre-release.md). F-05 (Basic unchanged-zero semantics), F-06 (exact alias ownership) and F-10 (low-level private-owner preservation) remain deliberate boundaries. The record/index/status and release-preparation edits that describe this result are documentation-only; the accepted source commit is the gate commit. See [REM-2026-11-17-numbering-contract-repairs](../records/remediation/REM-2026-11-17-numbering-contract-repairs.md).

## What changed in 0.8.1

- **Ordinary numbering edits are automatic and atomic.** Typed, Basic and `numberText` track/disc edits resolve an explicit component first, then the canonical native sibling, then an unambiguous legacy candidate, and retire recognized private provenance of the edited group in the same staged transaction. Untouched groups and foreign namespaces survive.
- **Explicit zero is authoritative.** `5/0` and an empty total after a slash store zero instead of recovering the previous total; only an omitted total resolves. The Swift preflight, MP4 native branch, PropertyMap branch and ID3 inventory parsing agree.
- **Opaque recovery fails closed.** Malformed or multi-value private evidence cannot supply a missing canonical component; ordinary writes reject with `ambiguousNumberRecovery` before staging, while full explicit replacement succeeds. The existing Basic unchanged-zero and low-level private-owner rules remain deliberate boundaries.
- **The contract lane expanded.** 907 public-surface rows now reconcile against 36 contracts, 81 scenarios, 62 adapters, 97 policy regressions and 23 calibration mutants; the suite reports 306 Swift Testing declarations in 55 suites. See [Testing](TESTING.md) and the [repair record](../records/remediation/REM-2026-11-17-numbering-contract-repairs.md).

## Accepted 0.8.0 release source

Final independent acceptance ran on source commit `959d688`. The campaign source hash was `09bd72f3b566ca956d62392e2ce217eacba149c7eff7bd2018083028d2c82787`; no production, test or configuration change followed it. The release commit and later work changed documentation, records and tooling only. Both strict lanes ran the policy suite, inventory/catalog reconciliation, the 13-mutant calibration set, and the complete framework gate:

| Gate | Result | Evidence |
| --- | --- | --- |
| Canonical Debug | Accepted: 181 XCTest executed (179 passed, two reviewed opt-in skips), 274 Swift Testing declarations in 51 suites, 75/75 scenarios, zero failures | `.build/test-evidence/debug-independent-acceptance/` |
| Canonical Release | Accepted: same counts and 75/75 scenarios, zero failures | `.build/test-evidence/release-independent-acceptance/` |
| Canonical calibration | 13/13 mutants compiled, activated, and were killed by the required tests; controls passed and source was restored | `.build/test-calibration/independent-canonical-acceptance/calibration.json` |
| Policy and inventory | 92 policy regressions; 907 public-surface rows, 34 contracts, 75 scenarios, 62 adapters and all decisions reconcile | `.build/independent-policy-acceptance.log` |
| Adapter execution | 134 observed calls across 31 tests; all 62 registered adapters match exact identity, outcome, and multiplicity | Scenario evidence under each lane |
| Full AddressSanitizer | 181 XCTest (two existing skips), 274 Swift Testing in 51 suites, no failures or sanitizer findings | `.build/independent-asan-full.log` |
| Full ThreadSanitizer | Same counts; no failures or sanitizer findings | `.build/independent-tsan-full.log` |
| Consumers | Both public products wrote real files and passed independent native and audio assertions | `.build/independent-consumers-final.log` |
| Minimum platforms | Strict macOS 13 arm64/x86_64, iOS 16 arm64, and iOS 16 simulator arm64/x86_64 builds completed | `.build/independent-platform-evidence.json` |
| Documentation | The campaign's 67 Markdown files passed link, heading, table, and all four generated-reference checks | `python3 scripts/check-docs.py` |

The unchanged privilege test passed in the full host environment without weakening or skipping it. The pinned upstream TagLib binary is not sanitizer-instrumented, so the sanitizer runs cover package code and tests only. No hosted CI, device runtime, external-corpus lane, or application acceptance was executed for this source. No gate was rerun on the `0.8.0` release commit; release preparation changes documentation only, so the accepted source and the release commit compile from the same code. The contract system is finite: passing it does not prove every file, codec, tag layout, or caller correct. See [the acceptance record](../records/remediation/REM-2026-11-15-test-system-acceptance.md) for the full ledger and remaining limits.

## What changed in 0.8.0

- Breaking API cleanup removes the typed `.date` YEAR alias, obsolete read/write and failure-policy overloads, old function-reference arities, Boolean advisory setters and verification expectations, and outdated capability/error aliases. Native mapping contract 2.2 and its target layouts are unchanged; see [Migration](MIGRATION.md#migrating-from-0-7-3-to-0-8-0).
- Public writers share destination-aware validation: scalar, whole-model, structured and raw writes reject out-of-range native representations before staging, and whole-model writes preserve known-but-unmodeled and private owners.
- Legacy reads and preservation are stricter: legal ID3v2.3 status flags, bounded grouping and DSDIFF `PROP`-child ID3 are read literally, WAV/AIFF saves retain the observed ID3 version, and generated number padding and `numberText` are preflighted.
- Storage, projection reads and transactions have explicit internal ownership, and unrequested native projections are skipped while keeping the parser guard, exact verification and durable atomic commits.
- At `0.8.0`, the contract lane replaced the matrix-only gate: 907 public-surface rows, 34 contracts, 75 scenarios, 62 adapters, 13 calibration mutants and source-bound evidence had to reconcile. The `0.8.1` lane is 36/81/23 as described above. See [Testing](TESTING.md).

## 2026-11-15 public write-contract campaign

The earlier public write-contract campaign accepted `c3c655e` with 181 XCTest (179 passed, two opt-in skips), 231 Swift Testing declarations in 45 suites, 41 policy regressions, focused sanitizers, both consumers, and all five minimum-platform builds. Its production repairs are included in `0.8.0`; the later contract-system acceptance above supersedes its counts and evidence. See [the remediation record](../records/remediation/REM-2026-11-15-public-write-contract.md) and [the acceptance record](../records/verification/VER-2026-11-15-public-write-release-acceptance.md).

## Earlier candidate history

These campaigns accepted their own revisions and are superseded for current-source evidence. Details, per-finding dispositions, and measurements are in the linked records.

| Revision | Scope | Accepted evidence |
| --- | --- | --- |
| [`de282df`](../records/remediation/REM-2026-11-14-release-review-followup.md) | Release-review follow-up: native-owner, advisory, APE verification, Basic numbering, legacy-date and artwork-owner repairs | 181 XCTest (179 passed, two skips), 198 Swift Testing in 43 suites, 36 policy regressions, targeted ASan/TSan, both consumers, AudioMator local candidate |
| [`f2ac9ad`](../records/remediation/REM-2026-11-14-package-architecture.md) | Architecture and selective-I/O candidate: canonical API, storage/read/model boundaries, projection skipping | 167 XCTest (165 passed, two skips), 186 Swift Testing in 42 suites, 30 policy regressions, targeted ASan/TSan, both consumers, AudioMator local candidate |
| [`a93c2f0`](../records/remediation/REM-2026-11-14-independent-review-repairs.md) | Independent-review repairs: ASF alias erase, exact advisory absence, unknown-code preservation | 164 XCTest (162 passed, two skips), 186 Swift Testing in 42 suites, 29 policy regressions, targeted ASan/TSan, AudioMator local candidate |
| [`bbf64c3`](../records/remediation/REM-2026-11-12-write-concurrency.md) | Write-preparation follow-up: discarded readability projections and same-open-file property evidence | 164 XCTest (162 passed, two skips), 179 Swift Testing in 41 suites, 27 policy regressions |
| [`4dd2a60`](../records/remediation/REM-2026-11-12-api-mapping-performance.md) | API/performance candidate: compatibility cleanup and measured I/O optimization | 162 XCTest (160 passed, two skips), 179 Swift Testing in 41 suites, 26 policy regressions |

The 48-row baseline/final profile showed faster selective reads and metadata-heavy writes, while ordinary MP3/M4A writes and some full snapshots were slower in individual runs. Those are local measurements, not a universal improvement claim. See the [architecture/removal/performance record](../records/remediation/REM-2026-11-14-package-architecture.md) and [write-concurrency record](../records/remediation/REM-2026-11-12-write-concurrency.md).

## Recorded 0.7.3 validation

The state-coverage repairs were validated on `codex/metadata-state-coverage-repairs`, then merged to `main` as `e9337f2` without source changes. The expanded gate required the new state matrices, all previous matrices, at least 158 XCTest / 179 Swift Testing declarations, and 24 policy regressions.

| Check | Debug | Release |
| --- | --- | --- |
| Gate result | `accepted: true` | `accepted: true` |
| XCTest | 158 executed; 156 passed, two original opt-in skips, 0 failures | Same |
| Swift Testing | 179 declarations in 41 suites passed | Same |
| State matrices | 8,282 additional parameterized cases | Same |
| Gate policy | 24 Python regressions passed | Same |

Both gates compiled production and tests with Swift/C warnings as errors, and the mandatory privilege test passed with expanded filesystem access. Both independent consumers passed in separate runs. The evidence is recorded in [the state-coverage repair record](../records/remediation/REM-2026-11-11-state-coverage.md). These runs were on the pre-merge branch; no full accepted gate was rerun on the exact `0.7.3` release commit, and release preparation changes documentation only. Tag creation and publication remain maintainer-owned.

## What changed in 0.7.3

- Native MP4 item and ID3 date-frame owners survive PropertyMap replay, including absence; low-level date reads use native owners on MP4, ID3, Xiph, and APE.
- MP4 `.comment`/`.lyrics` use native `©cmt`/`©lyr`; ASF semantic custom fields use native Unicode attributes and reconcile only their case aliases.
- Whole-map replacement retains unchanged submitted arrays literally; MP4 custom-field writes retain existing name spelling and unchanged projections do not collapse native arrays; ARTIST no longer falls back to ARTISTS.
- The mixed-framework gate requires the sparse-state matrices and 8,282 additional cases. See [Mapping test acceptance](MAPPING_TEST_STRATEGY.md#sparse-state-and-write-surface-acceptance).

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
| Strict production build | Passed; the test-target deprecation exception that existed at that revision does not apply to the current source |
| Package consumers | Facade-only and low-level executables passed |
| Documentation | 52 Markdown files and all four generated-reference checks passed at the last documentation pass for that release line |
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

## Coverage and limits

- The lifecycle and sparse-state matrices are explicit field/state subsets, not a complete field × format × tag-version × writer cross-product. The contract catalog adds another finite decision layer; it is not a universal safety claim. The coverage inventory and minimum case counts are owned by [Mapping test acceptance](MAPPING_TEST_STRATEGY.md); the contract system is described in [Testing](TESTING.md).
- Existing ID3v2.3 tags are read-only for independent date writes. Inspect `StructuredMetadata.id3v2MajorVersion`; an extension-level ID3v2.4 capability does not prove a concrete v2.3 file is writable.
- MP4 track/disc components are unsigned 16-bit values through 65535; MP4 movement is bounded to 0...32767. External readers may decode MP4 native pairs differently.
- Audio-content identity remains unavailable for many layouts, including MP3, MP4/M4A, raw AAC, Ogg, ASF, APE-family, DSD, and ambiguous chunk layouts. A nil identity never establishes continuity; see [Audio-content continuity](../explanation/AUDIO_CONTENT_CONTINUITY.md).
- Fixture coverage is finite. `fixtureCovered` does not certify every codec variant, unknown native structure, minimum-OS runtime, device, or external decoder.
- Ogg Speex, IT and S3M remain explicit unverified catalog decisions with no typed runtime scenario. Matroska registrations remain target-only with no registered family, native codec, or fixture.
- Calibration proves that the representative defect classes are detectable, not that every future defect will be caught. The pinned TagLib binary is not sanitizer-instrumented and its correctness is not established by package tests.
- The `0.8.1` release rests on package-only Debug acceptance. No Release lane, hosted CI, device run, minimum-OS runtime, or application acceptance was executed for its release source.
- A successful package test run does not validate an embedding application's signing, rpath, entitlement, or interactive UI behavior.

## Historical evidence

| Revision or release | Evidence | Current interpretation |
| --- | --- | --- |
| `0.8.1` | Current release, declared 2026-11-17; release source `558df00`; release preparation changes documentation only | Packages the numbering repairs, explicit-zero intent and opaque-recovery rejection above; no public signature, mapping-contract or binary change |
| `0.8.0` | Previous release (tag `9e986eb`), declared 2026-11-15; accepted source `959d688`; release preparation changes documentation only | Packages the breaking API cleanup, public write-contract repairs and contract test system above; does not include the `0.8.1` numbering repairs |
| `05416aa` | Merge of the contract-system upgrade; documentation and evidence only after `959d688` | Included in `0.8.0`; production code unchanged |
| `558df00` | Numbering-contract repair Debug acceptance: 181 XCTest / 306 Swift Testing / 81 scenarios / 97 policy / 23 calibration mutants, focused ASan/TSan, consumers, five platform builds | `0.8.1` release source; package-only Debug evidence |
| `959d688` | Final `0.8.0` package-only acceptance: 181 XCTest / 274 Swift Testing / 75 scenarios / 92 policy / 13 calibration mutants, full ASan/TSan | `0.8.0` release source |
| `c3c655e` | Public write-contract acceptance: 181 XCTest / 231 Swift Testing / 41 policy | Superseded counts; production repairs are included in `0.8.0` |
| `0.7.3` | Release tag, declared 2026-11-12; source branch merged as `e9337f2` | Earlier release; includes the native-owner state-preservation repairs above |
| `0.7.2` | Release tag, declared 2026-11-11 | Earlier release; includes the audit, native-mapping, test-system and MP4 Content Group repairs; does not include `0.7.3` |
| `0.7.1` | Release tag and merge `649b7a9`; date/ownership, comment verification and UFID repairs | Earlier release; does not include the `0.7.2` repairs |
| `0.7.0` | Release tag and mapping contract 2.2 | Introduced the field identities and date/number model described by the current mapping contract |
| `AUD-2026-11-11` | Independent audit on the pre-repair tree | Historical failing evidence; the reproduced blockers were repaired by the audit-integrity campaign |
| Earlier test-system and native-mapping records | [Records index](../records/README.md) | Historical branch evidence; current source and status supersede their pass/fail claims |

## Maintaining this page

Update this page only when the latest known state changes: a new release or tag, a changed accepted gate result, a new limitation, or a materially different environment. Campaign narratives, superseded failures, and per-run evidence belong in [engineering records](../records/README.md). Do not turn this page into a chronological log, and do not claim a configured CI job passed for a revision that did not run it.
