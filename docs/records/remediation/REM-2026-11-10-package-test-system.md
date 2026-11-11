# Package mapping test-system audit and upgrade

Branch: `codex/package-test-system-upgrade`, based on the committed Content Group repair `dc94152`. Package production sources are unchanged by this test upgrade. No release/publication or commit is performed.

## Findings

Existing capability tests mostly verify registry contents and preferred targets. Broad Basic round trips often write a group of values together and read them through the same bridge. Many useful native/transaction tests already exist, so replacing the test framework or deleting those tests would lose coverage. The missing release boundary is systematic single-field lifecycle behavior with an independent native oracle.

The new static inventory and 86-case parameterized MP4 matrix immediately exposed four previously green defects:

- `encodedBy`: removing the field throws `Patched semantic field encodedBy remains after removal`.
- `encoderSettings`: single-field writing throws `Unedited PropertyMap field ENCODING changed during the patch`.
- `movementNumber`: the semantic write returns a value through its own read path, but the independent byte oracle cannot find required ©mvi storage.
- `movementCount`: the same mismatch for required ©mvc storage.

These failures persist in complete Debug and Release runs. They remain normal required failures in this branch; no package implementation workaround or test exclusion is added. The first oracle draft also incorrectly required a one-byte Boolean payload; HD Video uses a multi-byte numeric representation. The oracle now verifies a bounded numeric zero/one value, keeping presence distinct from removal, without assuming an undocumented width. That test correction did not remove the four genuine failures.

## Changes and verification

See [the current test strategy](../../operations/MAPPING_TEST_STRATEGY.md) for the inventory, byte oracle, explicit format limits and mixed-framework release gate. The matrix covers 82 passing field lifecycles and four blocked fields after correcting the Boolean-width assumption. Specialized typed rejection tests additionally verify five unavailable/read-only/role-qualified fields with byte-preserving validation failures.

Complete Debug and Release results: 158 XCTest executed (156 passed, two existing optional skips), and 116 Swift Testing declarations, with four issues in the new 86-case lifecycle test. Logs: `/tmp/taglib-test-upgrade-debug.log` and `/tmp/taglib-test-upgrade-release.log`. SwiftPM did not produce the requested xunit report for these mixed-framework failed runs; acceptance therefore retains the complete logs and explicitly checks completion/results of both frameworks.

Six Python gate-policy tests passed, including a clean XCTest result followed by failed Swift Testing, nonzero process exit despite pass text, missing framework summaries and unknown/missing skip evidence. The real failed Debug log produced `accepted: false` in `/tmp/taglib-gate-failed-summary.json`. These are executable gate tests, not just a plan.

## Sensitivity and final gate evidence

Temporarily disabled only the committed Content Group PropertyMap projection allowance, then ran the new matrix. The reintroduced Content Group error was detected. A `finally` block restored the exact original production-source bytes; `git diff -- Sources` is empty. Sensitivity log: `/tmp/taglib-test-upgrade-sensitivity.log`.

After restoration, the actual new full-suite entry point (`TAGLIB_DISABLE_MANIFEST_SANDBOX=1 bash scripts/validate-tests.sh debug`) exited nonzero with the same four genuine issues and wrote `accepted: false`, despite all XCTest assertions passing. Evidence: `.build/test-evidence/debug-20261110-191625-43076/`; launcher log: `/tmp/taglib-test-upgrade-gate.log`. This validates the real entry point, not just its parser unit tests. Six Python policy tests passed; documentation checks passed for 48 Markdown files; `git diff --check` passed. CI artifact upload itself and sanitizer/platform jobs were not run locally. New test expectations remain red until the four package implementation defects are repaired.
