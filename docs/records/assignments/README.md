# Historical assignments

This directory preserves assignment plans and startup prompts after their work was implemented or superseded. They are retained for provenance, not as current contracts, acceptance evidence, or a live backlog.

The text is unchanged from the revision at which the assignment was issued. It may describe a baseline, branch, test count, or planned command that the current source no longer matches. Earlier records may cite these files under their former `docs/plans/` path; that directory no longer exists. The [current documentation hub](../../README.md), the source code, and the linked records are authoritative for current behavior and evidence.

| Assignment | Scope as issued | Outcome |
| --- | --- | --- |
| [Mapping refactor agent prompt](MAPPING_REFACTOR_AGENT_PROMPT.md) | Implement the package-side `AM-TLAM-MAPPING-2.2` mapping contract and its tests | Implemented; see [REM-2026-11-09-mapping-2-2-implementation](../remediation/REM-2026-11-09-mapping-2-2-implementation.md) |
| [Diagnostic remediation plan](DIAGNOSTIC_REMEDIATION_PLAN_2026-11-15.md) | Adjudicate and remediate the F-01…F-15 public write/read contract findings against baseline `903fa69` | Implemented; see [REM-2026-11-15-public-write-contract](../remediation/REM-2026-11-15-public-write-contract.md) and [VER-2026-11-15-public-write-release-acceptance](../verification/VER-2026-11-15-public-write-release-acceptance.md) |
| [Diagnostic remediation agent prompt](DIAGNOSTIC_REMEDIATION_AGENT_PROMPT_2026-11-15.md) | Start a package-only repair branch and execute the diagnostic remediation plan | Implemented with the plan above |
| [Package test-system upgrade plan](PACKAGE_TEST_SYSTEM_UPGRADE_PLAN_2026-11-15.md) | Replace the matrix-only gate with public-surface coverage, independent native contracts, defect calibration, and fail-closed evidence | Implemented; see [VER-2026-11-15-package-test-system](../verification/VER-2026-11-15-package-test-system.md) and [REM-2026-11-15-test-system-acceptance](../remediation/REM-2026-11-15-test-system-acceptance.md) |
| [Package test-system agent prompt](PACKAGE_TEST_SYSTEM_AGENT_PROMPT_2026-11-15.md) | Start a new implementation branch and deliver package-only contract-system acceptance | Implemented with the plan above |

## Using these files

- Do not cite an assignment's planned behavior as evidence that the behavior exists.
- Use the linked record for the observed revision, findings, and final acceptance.
- Use [Testing](../../operations/TESTING.md), [Mapping test acceptance](../../operations/MAPPING_TEST_STRATEGY.md), and [Status](../../operations/STATUS.md) for current commands and validation state.
- If an assignment is reopened, create a new dated plan rather than editing the historical text.
