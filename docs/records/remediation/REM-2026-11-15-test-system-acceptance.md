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

## Calibration-driven follow-up

The first canonical run failed closed on a parameterized-log parsing mismatch;
that parser now has a direct policy regression. The second run killed six faults
but exposed a missing alias-absence assertion: canonical release text alone did
not detect a restored stale alias. The test now independently verifies both the
seeded alias and its removal; the fault witness is that exact native assertion.

Expanded ASan testing exposed a test-adapter stack overflow. The same Basic API
passed its direct native preservation test under ASan. Boxing the large test
command/result enums removes dispatch-frame pressure without moving calls to a
different thread, changing inputs or modifying production code. Both consumers
and all five minimum-platform strict builds passed during investigation.

Final expected scope: 181 XCTest declarations (two reviewed opt-in skips), 274
Swift Testing declarations / 51 suites, 75 contract scenarios and 62 adapters.
Final evidence is required on the frozen source; earlier failed calibrations and
sanitizer diagnostics remain under `.build/` and are not claimed as passing.
