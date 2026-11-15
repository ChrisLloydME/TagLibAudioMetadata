# DOC-2026-11-15: current-state documentation alignment

| Field | Value |
| --- | --- |
| Record ID | `DOC-2026-11-15-current-state-alignment` |
| Type | Documentation |
| Date | `2026-11-15` |
| Status | Final |
| Examined revision | `05416aa` working tree; latest accepted source `959d688` |
| Branch | `main` |
| Environment | macOS 27.2.1 arm64; Xcode 27.2 / Apple Swift 6.4.2; Python 3 |
| Supersedes | Current-state claims in `DOC-2026-11-09-documentation-reconstruction` and later status prose |
| Superseded by | none |
| Related records | `REM-2026-11-15-test-system-acceptance`, `VER-2026-11-15-package-test-system`, `REM-2026-11-15-public-write-contract`, `VER-2026-11-15-public-write-release-acceptance` |
| Scope | Documentation only. No production, test, dependency, binary, or release change; no test gate was re-run. |

## Summary

The repository documentation still described the 2026-11-15 write-contract and contract-system assignments as future work, and several current pages carried superseded gate commands and counts. This pass re-read the records and scripts at `05416aa`, updated the current documents to describe the merged source and the accepted `959d688` package-only evidence, and archived the completed assignments under `docs/records/assignments/`.

No current document now presents the completed campaigns as pending. The documentation distinguishes the published `0.7.3` release from the unreleased `main` source, identifies the canonical acceptance lane, and keeps historical record text unchanged except for relocated-link repair.

## Scope and revision

- Documentation source of truth: `Package.swift`, the Swift/C++ sources, `scripts/validate-contracts.sh`, `scripts/validate-tests.sh`, the contract-system inventories, and the linked engineering records.
- Latest accepted source: `959d688` (181 XCTest, 274 Swift Testing declarations in 51 suites, 75/75 scenarios, 92 policy regressions, 13/13 calibration mutants, full ASan/TSan, consumers, five minimum-platform builds).
- `05416aa` is the current `main` merge. Its changes after `959d688` are documentation and acceptance evidence only.
- This pass did not rebuild the package, re-run the strict gates, or change the pinned TagLib binary.

## Changes

| Area | Change |
| --- | --- |
| Project entry point | Added the unreleased-source framing and a concise "Beyond 0.7.3" summary; pointed current acceptance to the contract-system record and `Status`. |
| Documentation hub | Replaced the two future-work assignment sections with a current-source status table, updated the release boundary to `main` at `05416aa`, and added assignment archival to the documentation rules. |
| Status | Reorganized around the accepted `959d688` gates, the prior `c3c655e` write-contract campaign, and a compact earlier-candidate history; refreshed coverage limits and the historical evidence table. |
| Testing | Documented the canonical `validate-contracts.sh` lane, the inner framework gate's calibration prerequisite, the `ContractSystem/` layer, current inventory counts, and the CI jobs. |
| Mapping test acceptance | Distinguished the tagged `0.7.3` gate from the current contract gate; removed the obsolete deprecation-warning exception and updated policy/scenario floors. |
| Mapping contract | Added an unreleased-source note: contract 2.2 and native registrations are unchanged, while write-contract validation and the XM/freeform routes were repaired. |
| Migration | Moved the public write-contract behavior changes into the unreleased section and marked the `0.7.2` gate command as historical. |
| Architecture and development | Added the contract system to source/test layout, evidence description, and change-workflow guidance. |
| Audio continuity | Replaced the obsolete `readSnapshot` overload ambiguity with the current default-flag signature and limited the untyped-reference caveat to the patch overloads. |
| Changelog | Grouped unreleased production repairs, added the contract test system under a dedicated heading, and updated the open-finding register for the removed failure-policy API. |
| Records | Archived five completed plans/prompts under `docs/records/assignments/`, added an assignment index, repaired relocated links, and marked the earlier test-system verification record as superseded for final acceptance. |

## Verification

| Check | Result |
| --- | --- |
| `python3 scripts/check-docs.py` | Passed: 69 Markdown files, links/fragments, headings, tables, hub coverage, generated references, bridge and format coverage |
| `python3 -m unittest discover -s scripts/tests` | Passed: 92 tests |
| `git diff --check` | Passed: no whitespace errors |
| Generated references | Unchanged; all four generator checks passed as part of the documentation check |
| Relative links after the assignment move | Passed; no remaining link to `docs/plans/` |

These checks establish that the documentation is structurally consistent and that the policy tests still pass in this environment. They do not re-establish the package acceptance recorded at `959d688`.

## Remaining limitations

- `0.7.3` remains the only current release. The unreleased source is not a tagged release and must not be described as one.
- The accepted counts and sanitizer/platform results come from the linked acceptance record, not from a fresh run in this pass.
- Historical records retain their own revisions and counts. The index explains current relevance; the record body remains evidence for its own revision.
- The contract system and lifecycle matrices remain finite coverage, not a universal format or caller guarantee.
- `docs/records/assignments/` preserves assignment text as issued. It may name former branches, baselines, commands, or counts.

## References

- [Documentation hub](../../README.md).
- [Records index](../README.md).
- [Contract-system acceptance](../remediation/REM-2026-11-15-test-system-acceptance.md).
- [Public write-contract acceptance](../verification/VER-2026-11-15-public-write-release-acceptance.md).
- [Historical assignments](../assignments/README.md).
