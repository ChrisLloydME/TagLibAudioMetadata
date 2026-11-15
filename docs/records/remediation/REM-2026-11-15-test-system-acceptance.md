# Test-system acceptance repairs — 2026-11-15

Package-only work on `codex/package-test-system-upgrade-20261115`.

The independent review reproduced cross-configuration evidence replay, same-count
placeholder assertions/fictitious adapter labels, missing build identity, orphaned
adapters and calibration against duplicate probe code. These are test-system
acceptance defects; they do not establish a new production metadata defect.

## Repair

- Bind scenario and actual adapter invocation records to campaign UUID, configuration
  and source hash. Require complete, matching before/after build manifests.
- Freeze reviewed assertion identities and exact runtime adapter/outcome multiplicities;
  reject substitutions, duplicates, missing records and unobserved registered adapters.
- Exercise all 62 registered adapters on real package-owned files. Add native preservation
  checks for formerly orphaned routes, full-model release-alias retirement and malformed
  UTF-8 oracle rejection.
- Replace duplicate calibration executables/oracles with isolated builds and execution of
  actual gate-required tests. Compile failures, timeouts and unrelated failures do not
  count as kills. Require the full mutant set, named activation witnesses, restored source
  and passing controls. Acceptance requires calibration for the same source and commit.
- Never overwrite a named evidence campaign; reject unsafe identifiers and claim-blessing
  mode during acceptance. Include CI/configuration inputs in the source manifest.

Initial checks: 43 contract tests passed; 90 Python policies passed before the additional
static inventory check. Final calibration and release evidence will be recorded below.
No sibling application is inspected or used. No push, tag or publication is performed.
