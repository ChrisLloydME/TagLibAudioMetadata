# Expanded package test-system implementation

| Field | Value |
| --- | --- |
| Record ID | `REM-2026-11-10-expanded-test-system` |
| Type | Remediation / verification |
| Date | 2026-11-10 |
| Status | Final for this test-system increment; implementation failures remain open |
| Examined revision | `e0a4091` plus the recorded working-tree test changes |
| Branch | `codex/package-test-system-upgrade` |
| Environment | macOS arm64, stable Xcode 27.2 (27B52), Apple Swift 6.4.2 |
| Supersedes | none |
| Superseded by | none |
| Related records | `REM-2026-11-10-package-test-system` |
| Scope | Test matrices, independent native readers and acceptance gate; no package production repair or other-platform runtime certification |


Branch: `codex/package-test-system-upgrade`. This extends the committed initial test audit without changing package production sources. No failures are converted to skips or expected failures. No release or commit is performed.

## Completed changes

- Split the MP4 loop into 258 independently seeded field/operation cases (86 fields × set/replace/remove). A broken semantic Set can no longer stop replacement/removal coverage. Added 86 wrong-value-kind cases, each with a valid companion field and exact file-byte atomicity assertion.
- Added 90 FLAC cases (30 fields × three operations), backed by direct FLAC metadata/comment/audio parsing independent of package readers.
- Added 60 ID3v2.4 MP3 cases (20 fields × three operations), with qualified frame identities, exact untouched-frame and audio-byte preservation.
- Added three native-probe contract tests with handcrafted known vectors and malformed/truncated metadata. Reused the qualified MP4 parser in the older native-container suite, removing its duplicate atom walker. Seven focused oracle/native-container tests passed.
- Strengthened gate policy with mandatory completed suite checks, Swift Testing skip detection, exact optional-skip names, earlier-failure detection and CLI rejection of extra/invalid arguments. Thirteen Python gate tests passed. Actual XCTest optional-skip source diagnostics are tested separately from Swift Testing skip events.

## Exposed implementation defects

MP4 retains the four previously identified field problems: Encoded By removal, Encoder Settings verification, and Movement Number/Count native ownership. Independent operation seeding additionally proves replacement/removal failures and unintended native changes for the movement fields; these are not merely missing initial writes.

FLAC additionally rejects Content Group set/replace with `Patched semantic field contentGroup differs after save`, and Encoder Settings set/replace with `Patched semantic field encoderSettings differs after save`.

ID3v2.4 rejects Content Group set/replace/remove with `Unedited PropertyMap field WORK changed during the patch`.

These are seven field/format failure combinations, not nineteen unrelated bugs: some cases produce multiple assertion issues. No implementation repair is mixed into this test-only branch increment. First-draft test issues (a RawMetadataPatch parameter name and recognition of the registered GRP1 text frame in the new oracle) were corrected before final validation.

## Verification

The focused oracle/native-container run passed seven tests (`/tmp/taglib-probe-consolidation.log`). Thirteen Python gate-policy tests passed via `python3 -m unittest discover -s scripts/tests`.

Full Debug/Release acceptance results and evidence paths are appended below. Current systematic coverage still excludes the full field × format × tag-version product; see [the current strategy](../../operations/MAPPING_TEST_STRATEGY.md). No sanitizer, minimum-platform or external-decoder conformance run is implied by this record.

## Final results

The actual full Debug and Release entry points both ran 158 XCTest declarations (156 passed, two known opt-in skips) and 122 Swift Testing declarations. Both modes reported the same 19 assertion issues across the seven field/format combinations above. Declaration counts are not parameterized-operation counts. No new skip or missing mandatory suite was accepted; both gates correctly returned `accepted: false`.

Evidence directories: `.build/test-evidence/debug-20261110-202226-46955/` and `.build/test-evidence/release-20261110-202251-46731/`. Launcher logs: `/tmp/taglib-testing-upgrade-acceptance-debug.log` and `/tmp/taglib-testing-upgrade-acceptance-release.log`. After the final parser hardening, both real logs were replayed and correctly rejected, with no unexpected skips and no missing required suites (`/tmp/taglib-test-system-current-debug-summary.json` and `/tmp/taglib-test-system-current-release-summary.json`).

Thirteen Python policy tests passed. Documentation checks passed for 49 Markdown files; `git diff --check` passed. Production `Sources/` has no diff. CI uploads, sanitizers, minimum-platform jobs and external-tool verification were not exercised locally. Follow-up: repair the exposed package implementations on a separate functional increment, then rerun the unchanged matrices; do not weaken these assertions to obtain a green release gate.
