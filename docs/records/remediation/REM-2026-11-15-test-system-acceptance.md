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

The original combined number-coercion mutant is now two independent faults:
malformed-text coercion and explicit-zero recovery. Each must activate its own
required test and native/ordering assertion; the total calibration set is 13.
The earlier zero-recovery run failed at the intended numeric assertion rather
than the speculative error string, so its activation witness was corrected to
the actual failed expression. That run remained rejected.

The development subset subsequently killed all six selected faults (both number
faults, unreachable capability, removed adapter call, removed preservation
assertion and malformed-text oracle). Its result is `partial`, never accepted.

## Non-documentation inspection scope

Reviewed the implementation/public boundary, native owner planning and codecs,
transaction/read validation and concurrency boundaries, package/binary manifest,
public product consumers, generated schema/mapping/API consistency, Python/shell
gates and CI evidence handling. The 45 implementation files, package manifest,
public APIs, dependencies, binary checksum and consumer sources are unchanged
from `de39d42`; no additional production defect was reproduced. The repaired
code is test infrastructure and test coverage. Scripts pass syntax/bytecode checks;
all four generated reference checks match their source registries.

## Final independent acceptance

**Code verdict: ready for the maintainer's release workflow.** No remaining
reproduced release-blocking production defect was found. The repaired test
system passes complete package-only acceptance; this is a finite contract
campaign, not a guarantee about every future file or caller.

Final tested source: `959d68854db600a5726b6b9cb9c05018b9335f22`.
Campaign source hash: `09bd72f3b566ca956d62392e2ce217eacba149c7eff7bd2018083028d2c82787`.
This results-only addendum changes documentation after that tested revision;
no executable source, tests, scripts, dependency or configuration changes follow it.

| Check | Observed result |
| --- | --- |
| Canonical Debug | accepted; 181 XCTest, 2 reviewed opt-in skips, 0 failures; 274 Swift Testing / 51 suites; 75/75 scenarios |
| Canonical Release | accepted; same declaration, skip, suite and scenario counts |
| Canonical calibration | 13/13 compiled, activated and killed by actual required tests; initial/final controls pass; source restored |
| Policy tests | 92 passed; replay, assertion substitution, incomplete manifests, missing/duplicate invocations and incomplete calibration reject |
| Adapter execution | 134 observed calls across 31 tests; all 62 registered adapters have exact identity/outcome/multiplicity expectations |
| Full ASan | 181 XCTest (2 existing skips), 274 Swift Testing / 51 suites; no failures or sanitizer findings |
| Full TSan | same counts; no failures or sanitizer findings |
| Standalone consumers | both public products pass real writes, independent native/audio assertions; facade also checks stale-version rejection |
| Minimum platforms | strict macOS 13 arm64/x86_64; iOS 16 arm64; iOS 16 simulator arm64/x86_64 builds pass |
| Integrity/reference checks | all four schema/format/mapping/API generators match; inventory reconciliation, shell/Python syntax and 67-file docs check pass |

Commands: `python3 scripts/calibrate-test-system.py --require-all-killed --run-id
independent-canonical-acceptance`; then both `bash scripts/validate-contracts.sh
<mode>` lanes with `TAGLIB_CALIBRATION_RESULT` pointing to that same frozen
campaign. Build/test commands use the stable installed Xcode and explicit
`--disable-sandbox --disable-keychain --disable-netrc` with Swift/C warnings as
errors. The full host permits the privilege-bit precondition; it passed without
changing/skipping/waiving the test.

Evidence (ignored local artifacts):

- `.build/test-calibration/independent-canonical-acceptance/calibration.json`
- `.build/test-evidence/debug-independent-acceptance/`
- `.build/test-evidence/release-independent-acceptance/`
- `.build/independent-policy-acceptance.log`
- `.build/independent-asan-full.log`, `.build/independent-tsan-full.log`
- `.build/independent-consumers-final.log`, `.build/independent-platform-evidence.json`

The sanitizer executables contain the final Swift/bridge/test code; later
calibration-definition and record changes do not change that code. The pinned
upstream TagLib binary is not sanitizer-instrumented. Existing finite-format
limits remain (including unverified Speex/IT/S3M fixtures, target-only Matroska
and unavailable public MP4 audio identity). No hosted CI, device runtime or
external-corpus lane was executed. No sibling application was accessed, built,
tested or used for acceptance. No push, PR, merge, tag or publication occurred.

A final independent replay against genuine accepted logs retained the passing
Debug control and rejected Debug scenarios paired with genuine Release evidence,
same-count placeholder assertions/fictitious adapter labels, missing post-run
manifest and matching minimal manifests. The real calibration CLI rejected a
subset with `--require-all-killed` before creating a workspace. Results are in
`.build/independent-tamper-results.json`. Dynamic framework/rpath, identity,
license resources and non-vendoring checks also passed.
