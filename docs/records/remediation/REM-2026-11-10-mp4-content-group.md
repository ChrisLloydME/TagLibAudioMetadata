# MP4 Content Group verification repair

Branch: `codex/mp4-content-group-verification`, based on published 0.7.1 (`649b7a9`). No release version, tag, binary bridge rebuild, publication or commit is part of this repair.

AudioMator's independent field lifecycle matrix exposed Content Group-only writes rejected with `Unedited PropertyMap field GROUPING changed during the patch`. Package reproduction ran before the fix and recorded five failures across set/replace/removal with siblings absent/present. Log: `/tmp/taglib-content-group-before.log`.

TagLib projects native ©grp into its engine PropertyMap GROUPING key; semantic GROUPING instead belongs to ----:com.apple.iTunes:GROUPING. Verification now allows this projection to change when Content Group is explicitly edited, while independently comparing untouched native Content Group, Grouping and Work atoms (including value arrays). This does not remap semantic keys or bypass native preservation checks.

A second defect surfaced when removing Content Group with a native Grouping value present: Basic reading fell back from missing ©grp to the engine grouping value and falsely resurrected Content Group. MP4 reading now uses its native Content Group owner exclusively; other formats retain their existing behavior.

`MP4ContentGroupVerificationTests.singleFieldLifecyclePreservesIndependentNativeSiblings` covers three fields × three lifecycle operations × siblings absent/present (18 operation cases), with explicit native keys and semantic reads, and exact untouched sibling-atom comparisons. Original multi-value siblings are seeded via the structured writer so the failing semantic path cannot block fixture construction. The focused test passed after the fix (`/tmp/taglib-content-group-fixed.log`).

Final package and consumer results are appended below. This local repair does not change the published 0.7.1 dependency.

## Validation

Both complete Debug and Release package suites passed: 158 XCTest executed (156 passed, two existing skips), plus 113 Swift Testing tests passed. Logs: `/tmp/taglib-content-group-full.log` and `/tmp/taglib-content-group-release.log`.

AudioMator's complete serial app-hosted suite used its existing ignored local override workspace and executed 574 tests with zero failures, including the formerly red dedicated Content Group lifecycle matrix. The resolved-package log explicitly names this local checkout. Consumer log: `/tmp/audiomator-content-group-local-override.log`. The normal project remains pinned to published 0.7.1; no lock file or application workaround was changed to hide the old failure.

`swift build --disable-sandbox --disable-keychain --disable-netrc -Xswiftc -warnings-as-errors` passed (`/tmp/taglib-content-group-strict.log`). `python3 scripts/check-docs.py` passed for 46 Markdown files after regenerating API source references. `git diff --check` passed in both repositories. No publication or commit occurred.
