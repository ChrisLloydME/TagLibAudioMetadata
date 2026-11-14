# Release assessment adjudication and follow-up — 2026-11-14

| Field | Value |
| --- | --- |
| Record ID | `REM-2026-11-14-release-review-followup` |
| Type | Review / remediation |
| Date | `2026-11-14` |
| Status | Final |
| Examined revision | Assessment baseline `ef28fd6`, six third-party repairs through `12f6ce2`, follow-up through `de282df` |
| Branch | `codex/diagnostic-native-owner-repairs` |
| Environment | macOS 27.2.1 arm64, Xcode 27.2 (27B52), Swift 6.4.2, pinned TagLib 2.3.1-r2 |
| Supersedes | Current diagnostic disposition and pending acceptance in `REM-2026-11-14-diagnostic-repairs` |
| Superseded by | none |
| Related records | `REM-2026-11-14-package-architecture`; the six supplied remediation commits |
| Scope | Revalidate reported metadata-integrity defects and repair remaining preservation gaps. Retain documented concrete-version safety and independent date semantics. |

## Summary

The reported F-01 through F-06 are real defects in the assessed earlier source. The six third-party repairs are retained with additional staged-copy protections and stronger regression evidence. F-07 was harmless native residue and is now removed as well. Both final strict gates, targeted sanitizers, independent consumers and the AudioMator local-candidate gate are accepted. This is bounded automated acceptance of an unreleased breaking candidate, not publication or universal format/UI certification.

## Method

Inspected the six commits and current writer/extractor/transaction implementations against the supplied assessment and current mapping contract. Ran strict focused and complete package tests, tamper-policy tests, independent ASF/MP4 assertions, ASan/TSan, standalone API consumers and the serial AudioMator override gate. The full gates ran with filesystem access that can satisfy the unchanged privilege-test precondition; manifest sandboxing was disabled explicitly. No test was weakened or newly skipped.


## Scope and revision

Reviewed the supplied Independent Release Readiness Assessment of `ef28fd6` and the six repairs ending at `12f6ce25c570663ee9886622dfd856f7e9105277` on `codex/diagnostic-native-owner-repairs`. The assessment describes the earlier source; its failures are not claims that all six later repairs still fail. This follow-up preserves the breaking API and independent-field mapping contract. No release, tag, push or dependency-pin change was performed.

## Finding decisions

| Finding | Decision and treatment |
| --- | --- |
| F-01, legacy v2.3 date loss/merge | Real data-integrity defect. Retain conservative third-party rejection and standalone TDAT replay. Added a staged-copy date invariant for every facade writer, including raw replacement and number text with optional verification disabled. Recheck direct bridge rejection on the actual staged file. Bind structured preservation to the read version. |
| F-02, low-level fields omitted | Real. Retain the six-format read/modify/write regressions and bridge extraction repair for Content Group, ARTISTS and both peaks. |
| F-03, unknown advisory/ASF aliases | Real. Retain unknown raw codes and native case-variant alias retirement; do not infer absence from the enum alone. |
| F-04, APE release verification | Real projection mismatch. Verify RELEASETYPE/RELEASESTATUS engine keys while retaining canonical native owners. |
| F-05, stale ASF values | Real. Retain native second-pass updates and repeated-write regression. |
| F-06, Basic number text | Real for silently ignored inconsistent requests and cross-pair conflicts. Retain per-pair checks; empty text permits total-only edits. Numeric-container padding normalization remains intended. |
| F-07, empty covr | Harmless native residue rather than lost artwork. Cleaned up on explicit clear and asserted through an independent MP4 parser. |
| D-09, equal date patch rejected on v2.3 | Intended concrete-version read-only policy. Equality does not grant a write capability. |
| D-10, scalar projection | Display-only scalar selection is not alone a defect. New evidence of a successful write merging independent dates is a real preservation defect, covered by F-01. |
| Privilege precondition | Environment limitation, not production failure. Keep the test mandatory and run with host access; never count a red gate as accepted. |
| Performance comparison | Historic/current runs are not controlled paired evidence. No demonstrated regression, and no universal throughput claim. |
| Two transaction engines, process-local guard, fatal verification, format vs concrete-version capability | Intentional boundaries. No change without a reproduced contract violation. |

Additional review found that date duplicate detection conflated different TXXX descriptions and that delimiter-joined signatures could confuse an array with one text value. Native owner identity now includes exact description and value arrays, counted as a multiset. Empty structured no-ops still validate readability/version without rejecting a layout they do not modify.

## Previous-defect context

- D-01: standalone TDAT needs preservation, not automatic synthesis of a year. The repaired Basic/structured paths replay it; unsafe layouts fail closed.
- D-02, D-03, D-06, D-07, D-11 and D-12: the earlier fixes remain valid within their documented scope. F-03 covers the separate low-level advisory gap; F-07 covers only the empty artwork owner.
- D-04 and D-05: version-specific identity verification alone was insufficient. Concrete v2.3 date edits are now read-only across structured and typed surfaces; raw and direct bridge paths cannot bypass preservation. Supported v2.4 versioned writes remain tested.
- D-08: API-specific native projection drift was real, including APE release verification and repeated ASF updates; the new low-level regressions cover those repairs.
- Native planner and bridge tables remain separate for semantic versus container/low-level APIs. Their duplication is architecture debt with demonstrated past drift, not proof that every low-level operation must be routed through the semantic planner. This repair does not claim a completed single-source registry refactor.

## Verification

Source checkpoints: `5a78449` (production and integrity regressions), `55a9f0c` (mandatory regression evidence), `de282df` (independent ASF assertions and both ReplayGain peaks). The last commit changes tests only. Host: macOS 27.2.1 arm64, Xcode 27.2 (27B52), Apple Swift 6.4.2.

- Strict focused remediation: 13 XCTest methods passed.
- ASan and TSan: each passed 16 XCTest and 12 Swift Testing declarations with no findings.
- Both consumer products built with warnings as errors and ran successfully.
- Gate-policy suite: 36 passed; documentation and all reference generators: 59 Markdown files passed.
- Evidence for those checks: `.build/test-evidence/review-20261114-de282df/`. Sanitizer commands use `swift test --scratch-path .build/review-sanitizers --disable-sandbox --disable-keychain --disable-netrc -Xswiftc -warnings-as-errors -Xcc -Werror --sanitize=address` (then `thread`) with filter `RemediationPreservationTests|IndependentDiagnosticRepairTests|SameFileTransactionTests`.

Final production source is `5a78449`; `55a9f0c` and `de282df` change gates/tests only. Both final gates exercised the complete `de282df` test tree:

| Check | Result | Evidence |
| --- | --- | --- |
| Strict Debug | Accepted; 181 XCTest (179 passed, two existing opt-in skips), 198 Swift Testing in 43 suites; no failures | `.build/test-evidence/debug-20261114-233512-4938/` |
| Strict Release | Accepted; same declarations and skips, no failures | `.build/test-evidence/release-20261114-232509-5048/` |
| Privilege precondition and rejection | Passed unchanged in both complete gates | `privilegedFilesRejectBeforeCloneInBothTransactionEngines` named result |
| AudioMator local candidate | 62 core and 580 serial app-hosted tests accepted; unsigned Release build and artifact checks passed | AudioMator `.deriveddata-codex/Validation/20261114-231903-1620/` |

Commands: `TAGLIB_DISABLE_MANIFEST_SANDBOX=1 bash scripts/validate-tests.sh debug` and `release`; `python3 -m unittest discover -s scripts/tests`; `python3 scripts/check-docs.py`; both `swift run --package-path IntegrationTests/Consumer --disable-sandbox --disable-keychain --disable-netrc -Xswiftc -warnings-as-errors -Xcc -Werror` consumer products. AudioMator ran `bash scripts/validate-release.sh --local-package /Users/lloyd/Developer/Xcode/TagLibAudioMetadata`. Its source manifest records app `625024d3`, package `12f6ce2` and candidate diff hash `3f9119fc2a43d13405d740d00376d9e8956633a91b8f1f42588abf87d1fc068d`; the compiled production changes are committed as `5a78449`. Later package edits are tests/gates/docs only. App commit `b84887e6` records that acceptance; app production and published `0.7.3` resolution remain unchanged.

## Remaining limitations

No automatic tag conversion, no full arbitrary-native-structure preservation claim, no cross-process lock, no minimum-OS/device/x86_64 runtime or interactive UI acceptance. The prebuilt TagLib dependency is not sanitizer-instrumented. Local AudioMator validation does not change its published dependency pin.

## References

- [Current status](../../operations/STATUS.md), [test policy](../../operations/MAPPING_TEST_STRATEGY.md), [preservation](../../explanation/PRESERVATION.md), [bridge semantics](../../reference/BRIDGE.md).
- [Earlier diagnostic record](REM-2026-11-14-diagnostic-repairs.md); its D-10 interpretation predates the later write-loss evidence and must not be treated as the current disposition.
- Production repair `5a78449`; gate repair `55a9f0c`; independent regression strengthening `de282df`.
- `Sources/TagLibAudioMetadata/ID3v23DateSafety.swift`, `Storage/MetadataFileTransaction.swift`, `TagLibMetadataManager+Structured.swift` and the corresponding bridge entry points.
- `RemediationPreservationTests`, `IndependentDiagnosticRepairTests`, `SameFileTransactionTests`, `scripts/tests/test_test_gate.py`.
