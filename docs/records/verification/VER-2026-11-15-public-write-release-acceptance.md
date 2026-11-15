# Package public-write release acceptance — 2026-11-15

| Field | Value |
| --- | --- |
| Record ID | `VER-2026-11-15-public-write-release-acceptance` |
| Type | Review / remediation / verification |
| Date | `2026-11-15` (Asia/Shanghai) |
| Status | Final |
| Examined revision | Third-party handoff `add4e9d`, repairs `dfa2da5` and `c3c655e` |
| Branch | `codex/public-write-contract-repairs-20261115` |
| Environment | macOS 27.2.1 arm64; stable Xcode 27.2 / Swift 6.4.2; pinned TagLib 2.3.1-r2 |
| Supersedes | Release-readiness disposition in `REM-2026-11-15-public-write-contract` |
| Superseded by | none |
| Related records | `REM-2026-11-14-release-review-followup`; `REM-2026-11-15-public-write-contract` |
| Scope | Package-only code acceptance and repairs; documentation completeness excluded from readiness, no application tests or release operation. |

## Summary

The handed-off implementation was not ready as supplied. New independent public-API regressions reproduced committed MP4 range/codec bypasses, removal of existing over-width number text, loss of read-only v2.3 date flags, and numeric overflow through scalar, whole-model and raw-map public writers. These defects are repaired on the same branch. The final production/test tree at `c3c655e` passes both complete canonical gates, targeted sanitizers, standalone consumers and all five minimum-platform compile/link targets. It is eligible for the already planned breaking release, not a patch-compatible 0.7.x claim. No application compatibility or universal file-layout guarantee is inferred.

## Method and source boundary

Read the actual implementation and new third-party tests against the adjudication plan, then added `ReleaseAcceptanceTests` on fresh disposable fixture copies. Retained baseline failure logs before repair. No dependency, manifest, product, platform, published binary, source fixture or Git history rewrite occurred. No application tests, push, PR, merge, tag or publication command was issued. Document changes do not decide the code verdict.

Initial host Debug verification of the handoff passed, including the unchanged privilege precondition. Subsequent development included transient test-compilation failures and deliberately red reproduction runs; those are not release acceptance. The final complete runs below supersede intermediate logs. The source was frozen before these runs and the sanitizer/platform/consumer campaign.

## Findings and repairs

| ID | Evidence and outcome |
| --- | --- |
| RA-01, High | Seven direct MP4 structured payloads succeeded when rejection was required: whitespace-wrapped trkn overflow; tmpo/rtng/stik overflow; incompatible pgap/tvsn codecs; numeric freeform. Original bytes changed. Replaced the incomplete atom whitelist with a private adapter to the pinned engine ItemFactory's encoder classification; validation and native Item creation agree. Numeric limits apply to the effective destination, including default text atoms and freeforms. Invalid/missing scalar values and malformed Boolean inputs reject. Pure structured validation now precedes file/staging access and is repeated on staged recursion. |
| RA-02, High | A full-model title-only write with an inherited 65-digit padded TRCK succeeded and removed TRCK. Reject unsupported generated width before writing; the formatter's defensive failure throws instead of returning the same nil used for intentional removal. Unchanged Basic deltas remain omission-safe. |
| RA-03, High | Unrelated title patches on legal read-only v2.3 dates succeeded after clearing status flags. Literal extraction now carries status/format/group evidence, and the central staged date invariant compares it. A nonpreservable protected layout rejects without committing; reading remains supported. |
| RA-04, High | All five direct numeric-surface probes committed MP4 overflow: scalar renumber, direct whole-model, wrapper whole-model with verification none, scalar raw map and array raw map. Added shared destination bounds and engine-derived validation of requested raw numeric owners, including cardinality. The same checks cover structured properties and targeted deltas without validating or rewriting omitted metadata. Full-model BPM/media-kind/store-ID input is validated. Nine mandatory parameterized cases cover the public paths and representative numeric encodings. |
| RA-05, Medium | The new numberText preflight still used a lenient comparison parser, accepting malformed components as zero. Input now has a strict ASCII-decimal pair parser; existing metadata comparison remains separate and lenient. Invalid strings reject before staging. Explicit `5/0` clears the total; only a genuinely number-only input recovers an existing total. |
| RA-06, Test correctness | The new legacy seed helper encoded only sub-128-byte tag sizes correctly. Corrected synchsafe size construction. Added a negative chunk-bound regression, independent MP4 boundary assertions and mandatory gate evidence for all ten new methods. |

RA-01/02/03/04 have preserved pre-fix runtime failures. RA-05 combines source-supported preflight hardening and positive/negative final regressions; it is not described as a captured pre-fix data-loss reproduction. The original F-04 erase warning hypothesis remains unverified and nonblocking. Retained-by-design engine DATE aliases, explicit ordinary-pair alias cleanup, private-provenance normalization rules, ASF common-alias cleanup, read-only role/rate policy and unsupported Matroska writes are unchanged.

## Verification

| Check | Result / evidence |
| --- | --- |
| Full strict Debug | `accepted: true`; 181 XCTest (179 pass, two original opt-in skips, zero failures); 231 Swift Testing declarations in 45 suites. `.build/test-evidence/debug-20261115-133414-38325/` |
| Full strict Release | Same accepted counts; `.build/test-evidence/release-20261115-133737-38148/` |
| Privilege test | `privilegedFilesRejectBeforeCloneInBothTransactionEngines` executed and passed unchanged in both final full gates with authorized host filesystem access. |
| Test-gate policy | 41 passed; named new tests and parameterized minima 7/9 are mandatory. |
| Focused ASan | 3 XCTest plus 33 Swift Testing declarations passed; no sanitizer findings. |
| Focused TSan | Same passing counts; no sanitizer findings. |
| Consumers | Both standalone facade and low-level products compiled and ran with warnings as errors. Facade reports 37 readable extensions. |
| Minimum-platform compile/link | macOS 13 arm64/x86_64; iOS 16 arm64; iOS 16 simulator arm64/x86_64 — all passed with strict warning flags. |
| App tests | Not run, per the maintainer's instruction. |

Canonical commands: `TAGLIB_DISABLE_MANIFEST_SANDBOX=1 bash scripts/validate-tests.sh debug` and `release`; `python3 -m unittest discover -s scripts/tests`; both `swift run --package-path IntegrationTests/Consumer --disable-sandbox --disable-keychain --disable-netrc -Xswiftc -warnings-as-errors -Xcc -Werror` consumer products. Sanitizers use `swift test --scratch-path .build/review-sanitizers --disable-sandbox --disable-keychain --disable-netrc -Xswiftc -warnings-as-errors -Xcc -Werror --sanitize=address` then `thread`, filtered to `ReleaseAcceptanceTests|PublicWriteContractRepairTests|SameFileTransactionTests`. Cross builds use `swift build --scratch-path .build/release-audit-platforms --disable-sandbox --disable-keychain --disable-netrc --triple <triple> --sdk <matching SDK> -Xswiftc -warnings-as-errors -Xcc -Werror`.

Supplementary retained logs: `.build/test-evidence/release-audit-20261115-c3c655e/`. Source commits `dfa2da5` and `c3c655e` contain all production/test/gate changes. The commit recording this document changes documentation only.

## Remaining limitations

The precompiled TagLib binary is not sanitizer-instrumented. Sanitizers are focused, not full-suite evidence. Minimum-platform checks compile/link; they are not minimum-OS/device/x86_64 runtime certification. External corpora, hosted CI, application integration and UI acceptance were not executed. The package still deliberately rejects independent v2.3 date writes and nonpreservable protected layouts. Do not claim cross-process locking, lossless preservation of every opaque structure or exhaustive field/value/container combinations.

## References

- [Prior handoff record](../remediation/REM-2026-11-15-public-write-contract.md).
- [Original remediation plan](../assignments/DIAGNOSTIC_REMEDIATION_PLAN_2026-11-15.md).
- [Pinned engine encoding implementation](https://github.com/taglib/taglib/blob/v2.3.1/taglib/mp4/mp4itemfactory.cpp); the adapter calls the supplied public/protected factory interface, without copying the engine's dispatch table or vendoring its implementation.
- `ReleaseAcceptanceTests.swift`, `PublicWriteContractRepairTests.swift`, `scripts/summarize-test-run.py`, `scripts/required-test-inventory.json` and `scripts/tests/test_test_gate.py`.
