# Independent review adjudication and repairs — 2026-11-14

Branch: `codex/api-mapping-performance`; examined baseline `c4259cb`. The report correctly identifies a release-blocking false failure; it also includes intentional breaking design choices and non-reproduced risks. No existing history is rewritten and no release is published.

## Adjudication

| Report item | Classification | Resolution |
| --- | --- | --- |
| ASF/WMA alias-bearing erase fails | Confirmed functional regression | Move verification after raw clear/native wipe. Verify final enum, raw-code absence and remaining native attributes. Do not globally delete read-compatible aliases on unrelated edits. |
| Enum-only unspecified is not exact absence | Confirmed verification gap | Add exact raw-code expectation. Default `.unspecified` requires raw nil; Basic explicitly verifies unknown preservation. |
| Unknown code can be lost during unrelated Basic edits | Additional confirmed integrity defect | Baseline probes reproduced loss in FLAC/ASF. Expanded controls exposed the same staged loss in WAV/AIFF/TTA/DSF/DSDIFF when stricter verification was enabled. Restore unchanged unknown native owners; reject mismatches before commit. All sixteen format controls now pass. |
| `9e16ccc` does not compile | Confirmed historical process defect, already fixed at HEAD by `4dd2a60` | Correct the phase/evidence wording; keep existing history. Squashing/reordering historical commits is a separate maintainer decision. |
| Registry public introspection changes | Intended result of removing typed `.date`, with a real migration-note omission | Document singleton YEAR ownership, empty collision/preference tables and all-built-in-canonical entries. Existing lookup behavior stays intact. |
| Dump-text parser and writable-Boolean comment remain | Confirmed cleanup defects | Delete unreferenced `parsedPropertyEntries`; correct the read-only header comment. |
| Canonical-owner flag and empty tables are dead API | Not a functional defect | Keep the public schema/collision model: callers can construct a non-canonical schema, and introspection can legitimately report no shared owners. No runtime legacy field alias remains. |
| Basic-only transaction readability checks | Deliberate performance design | Same extension-selected parser, Accurate audio credibility, identity checks, full semantic/native save verification and durability. Materializing extra discarded views is not the readability contract. Allocation-only failure differences are a bounded residual risk, not a reproduced regression. |
| Static cache sticky exceptional failure | Plausible unobserved robustness risk | Retry bridge loading when cached families are empty or an extension descriptor was missing. Successful immutable caches retain the fast path. No claim of reproduced allocation failure. |
| Old/non-pinned TagLib source compatibility | Explicitly unsupported configuration | Keep the namespaced checksum-pinned 2.3.1-r2 dependency. Do not restore ambiguous host-framework fallback. |
| Removed public aliases / patch release compatibility | Intentional breaking API cleanup | Preserve migration notes and require an explicitly breaking release. No version bump/tag/publication here. |
| Performance measurements vary / opt-in benchmark | Correct limitation, not a confirmed regression | Keep descriptive measurements with source identity. Do not introduce noisy wall-clock release thresholds or claim all writes improved. |

## Reproduction before repairs

`AdvisoryEraseRegressionTests` uses fresh fixtures. Six ASF alias configurations × four codes include single aliases, mixed case and all aliases together. The baseline final red run had 22 issues: 15 alias erase failures, four exact-absence false acceptances and three unknown-code preservation assertion failures. Its 64 canonical erase controls passed. An initial MP4 oracle failure was a test-helper assumption that ilst must exist after erase; it was corrected before this baseline result and is not a production finding. Logs: `/tmp/taglib-review-advisory-before2.log`.

## Fix and preservation boundary

Erase now checks the final staged state. Ordinary writes retain their existing check/flush/rename sequence. Unknown-code preservation is explicit in `MetadataWriteVerificationContext.expectedExplicitAdvisoryRawValue`; an unknown projection is never silently equated with absent data. Basic restores original ASF attributes (including type/language/stream), ID3 frames or Xiph/APE values only when both the requested semantic state and raw provenance are unchanged. Native readback must match or the staged file is rejected. Known edits remain independent. No arbitrary new unknown-code assignment is introduced by this preservation path.

The MP4 oracle keeps its strict default; its explicit erased-metadata mode permits missing udta/meta/ilst while still requiring moov/mdat and valid bounds for every present atom. A literal malformed/missing-container contract test prevents this mode from becoming a generic parse-success bypass.

## Verification

Focused strict checks pass: the six advisory functions exercise 24 + 4 + 16 + 6 + 4 + 64 cases, and seven independent-probe contract tests execute. Existing focused fixture/capability checks pass. The mixed-framework gate now requires every advisory function and its minimum case count plus the erased-MP4 oracle contract; declaration floor is 186 Swift Testing / 164 XCTest. All 29 gate-policy tests pass, including missing advisory evidence and shrunken-case tampering.

Full final gates, sanitizer observations, consumers and application follow-up will be appended after execution. Minimum-platform/device runtime is not claimed.
