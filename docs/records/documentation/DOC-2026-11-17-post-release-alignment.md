# DOC-2026-11-17: post-release documentation alignment

| Field | Value |
| --- | --- |
| Record ID | `DOC-2026-11-17-post-release-alignment` |
| Type | Documentation |
| Date | `2026-11-17` |
| Status | Final |
| Examined revision | `e42d085` working tree; accepted source `558df00`; latest release tag `0.8.0` at `9e986eb` |
| Branch | `main` |
| Environment | macOS 27.2.1 arm64; Xcode 27.2 / Apple Swift 6.4.2; Python 3 |
| Supersedes | Current-state claims in `DOC-2026-11-15-current-state-alignment` |
| Superseded by | none |
| Related records | `REM-2026-11-16-automatic-numbering`, `REM-2026-11-17-numbering-contract-repairs`, `AUD-2026-11-17-pre-release` |
| Scope | Documentation and records only. No production, test, dependency, binary, release, or gate change; no acceptance gate was re-run. |

## Summary

The repository documentation still identified current `main` as the `0.8.0` release commit. It omitted the post-`0.8.0` numbering behavior, carried stale claims that private numbering provenance survives ordinary edits, and attributed the larger 36-contract/81-scenario/23-mutant lane to the release instead of current `main`. This pass re-read the source, the 2026-11-16 and 2026-11-17 records, and the contract/calibration inventories, then separated the published release boundary from the unreleased source.

The result describes three states explicitly: published `0.8.0` at `9e986eb`, release source `959d688`, and the examined `main` working tree at `e42d085` with accepted source `558df00`. No historical record body was rewritten.

## Scope and revision

- Source of truth: `Sources/TagLibAudioMetadata`, `Sources/CTagLibBridge`, `Package.swift`, the test target, and the contract/calibration inventories.
- Latest published release: `0.8.0`, tag `9e986eb`; release source `959d688` (code-identical after the documentation-only release commit).
- Current `main`: `e42d085`, 17 commits after the tag. `Sources/` and `Tests/` end at `558df00`; later commits are documentation, records, generated references, and commit-message/check tooling.
- Accepted evidence: `558df00` package-only Debug — 181 XCTest, 306 Swift Testing declarations in 55 suites, 81/81 scenarios, 97 policy regressions, 23/23 mutants, consumers, focused ASan/TSan, five platform builds. `0.8.0` release source remains `959d688` — 274/51/75/92/13.
- Excluded: no source, test, script, manifest, binary, or publication change; no fresh package gate.

## Changes

| Area | Change |
| --- | --- |
| Entry point | Added release versus unreleased status, refreshed the write summary, corrected private-provenance retirement, and replaced the long `0.7.3` section with a compact earlier-release summary. |
| Documentation hub | Split latest published release, release source, current source and current accepted source; added an "updating from 0.8.0" path and an unreleased release-contents row. |
| Status | Distinguished `0.8.0` from current `main`, marked the current state accepted rather than ready, added the post-release behavior summary, and retained F-05/F-06/F-10 as boundaries. |
| Migration | Added the unreleased numbering section: automatic resolution, selected-group provenance retirement, explicit-zero intent, opaque-recovery rejection, retained boundaries, and migration actions. |
| Changelog | Added `[Unreleased]` with the post-tag numbering, test and documentation changes. |
| Writing and preservation | Corrected provenance retirement, explicit-zero semantics, absent-versus-opaque recovery, and the F-05 Basic unchanged-zero exception. |
| Architecture | Corrected automatic resolution/retirement and the current 23-mutant calibration lane. |
| Mapping contract and formats | Added the unreleased amendment, explicit-zero and opaque rules, removed the stale typed `.date` MP4 claim, and scoped alias cleanup to the facade surfaces. |
| Testing and mapping acceptance | Distinguished release from current counts, described the 23 mutants and numbering intent matrices, and corrected the 13/92/34/75 attributions. |

## Verification

| Check | Result | Counts / limits |
| --- | --- | --- |
| `python3 scripts/check-docs.py` | Passed | 75 Markdown files; links, fragments, headings, tables, hub coverage, generated references, bridge and format coverage |
| `python3 -m unittest discover -s scripts/tests` | Passed | 97 policy regressions; not package acceptance |
| `git diff --check` | Passed | No whitespace errors or conflict markers |
| Generated reference checks | Passed | The API, model, field, format and mapping generators reported no stale output; this pass did not change their sources |

These checks establish structural documentation consistency and the current policy-test result. They do not re-establish the `558df00` package acceptance or the `0.8.0` release evidence.

## Remaining limitations

- `0.8.0` remains the latest published release. Current `main` and `558df00` are not a release, and no later tag exists.
- The acceptance counts and sanitizer/platform results are quoted from the linked record; this pass did not rerun the package suite or a Release lane.
- The contract system and numbering matrices are finite; 23 mutants demonstrate detection of reviewed defect classes, not universal correctness.
- Historical records keep their own revisions, counts and verdicts. The index explains current relevance; record bodies remain evidence for their own revision.
- Records under `docs/records/assignments/` preserve instructions as issued and are not current contracts.

## References

- Commits: `9e986eb` `docs: prepare 0.8.0 release`; `44fe742` `fix: resolve ordinary numbering edits atomically`; `51c05d1` `fix: honor explicit numbering intent across write surfaces`; `558df00` accepted source; `e42d085` current documentation HEAD.
- Records: [REM-2026-11-16-automatic-numbering](../remediation/REM-2026-11-16-automatic-numbering.md), [REM-2026-11-17-numbering-contract-repairs](../remediation/REM-2026-11-17-numbering-contract-repairs.md), [AUD-2026-11-17-pre-release](../audits/AUD-2026-11-17-pre-release.md).
- Current documentation: [hub](../../README.md), [status](../../operations/STATUS.md), [migration](../../operations/MIGRATION.md), [preservation](../../explanation/PRESERVATION.md), [testing](../../operations/TESTING.md).

## Addendum — 0.8.1 release inclusion

This record was written while the numbering repairs were accepted but unreleased. The maintainer subsequently prepared `0.8.1` from that source: the release commit assigns the version in the changelog, moves `[Unreleased]` under `0.8.1`, updates the release boundary across the README, hub, guides, reference and operations pages, and adds no automatic user-file migration. Tag creation and publication remain maintainer-owned and are not part of this record. The findings, evidence and limits above are unchanged; the statement that no later tag existed describes the revision this record examined, and the current release boundary belongs to [Status](../../operations/STATUS.md).
