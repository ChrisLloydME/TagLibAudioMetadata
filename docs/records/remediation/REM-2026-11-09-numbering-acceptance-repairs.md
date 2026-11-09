# REM-2026-11-09 — numbering acceptance repairs

- Record ID: REM-2026-11-09-numbering-acceptance-repairs
- Date: 2026-11-09
- Type: Remediation / independent acceptance findings
- Baseline: `3d5087123296c1320b799daac57e457fd1209f7d`; repaired working tree on `codex/metadata-mapping-spec`
- Findings: [Independent mapping acceptance review](../reviews/REV-2026-11-09-mapping-acceptance.md), F1–F8
- Scope: Package-only numbering repairs; no application adoption, dependency upgrade or release

## Changes and acceptance evidence

| Finding | Repair | Regression evidence |
| --- | --- | --- |
| F1: ordinary native keys erased | Inventory recognizes native Xiph/APE number/total fields and ASF attributes; native use policy no longer treats them as missing | Original FLAC probe; ordinary native cleanup across FLAC, Ogg, APE, WavPack and ASF |
| F2: track cleanup removes disc aliases | Separate group-local identities; selected-group removal allowlists; untouched native/raw/structured group comparisons before publication | Original cross-group deletion probe; multi-format untouched-disc preservation |
| F3: stale plan token overridden | Apply always binds to plan.fileVersion and rejects a different explicit expectedVersion; plan properties are immutable | Original stale-plan/byte-preservation probe; existing stale plan tests |
| F4: native/alias conflict ignored | Resolve all candidates even with a positive native value; retain the native value alongside ambiguity; reject ordinary typed, Basic and formatted edits of a conflicted group | Original conflict/byte-preservation probe; explicit native and legacy resolution; existing contradictory-alias tests |
| F5: private-only recovery missing | Strictly parsed private values participate in recoverable components; exact namespace and selected private identities are retained in the plan | Original private-only probe; both historical namespaces, complete native restore/retirement, total-only private text and unrelated foreign namespace preservation |
| F6: disc replacement targets track | Replacement policy applies to every selected group; selected absence is verified, unselected values are not treated as replacement expectations | Original disc replacement probe; native removal and empty-group byte-preservation regressions |
| F7: unrelated ambiguity blocks edits | Resolve and validate only touched groups; Basic/number-text entry points use group-local ambiguity checks | Original untouched ambiguous-disc probe; existing Basic/typed tests |
| F8: old total-only prohibition | Native MP4 absent-number sentinel; ID3 /total serialization; concrete bounds checks; unverified ASF total-only remains rejected | Original MP4 probe; typed/Basic total-only readback; native frame assertions across MP3/AAC/WAV/AIFF/TTA/DSF/DSDIFF public writers |

Formatted convenience writes also materialize a sole recoverable orphan total before a number-only edit. All eight independent acceptance tests remain enabled. Seven additional repair regression tests cover related native-family and cleanup boundaries. Three old tests that explicitly required total-only rejection now assert the new native success contract instead; their unrelated preservation assertions remain or are strengthened. A formerly automatic conflicting-freeform cleanup test now requires explicit resolution before formatted writing.

## Implementation details

`MetadataNumberInventory.swift` performs strict parsing, per-component provenance resolution and group-specific planning. Ordinary primary fields are not deletion aliases. Multiple/malformed native values require explicit replacement. Private freeforms are recognized only under the exact package-compatible namespace; foreign lookalikes survive. Plans include exact retirement identities and are immutable once constructed.

`applyNumberNormalization` verifies selected native values, including absence, and selected retirement through MP4, ID3 and ordinary key reads. It compares unselected group inventories plus native/raw arrays and attributes before publication. Empty-group plans validate the captured version and perform no disk mutation. Verification failures abort staged changes; diagnostic warnings are separate from verification errors.

`MetadataSnapshotPatch.swift` resolves only touched numeric groups and validates native MP4 pair bounds at 65535. `TagLibMetadataManager+Write.swift` applies the same ambiguity boundary to Basic and formatted convenience writes. `TLBasicBridgeOperations.inc` serializes an absent ID3 number with a retained total as /total rather than inventing ordinal zero. Native MP4 zero remains an internal absence sentinel.

No expected token is cleared, no commit is retried, and no binary dependency or public product/platform minimum is changed. Both public consumers remain supported. The contract's RATE/media-label/MKV boundaries are not expanded by these repairs.

## Verification

Final source verification uses stable `/Applications/Xcode.app`, approved cache access, `--disable-sandbox --disable-keychain --disable-netrc`, and local compiler caches:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export CLANG_MODULE_CACHE_PATH="$PWD/.build/modulecache"
export SWIFT_MODULECACHE_PATH="$PWD/.build/modulecache"
swift build --disable-sandbox --disable-keychain --disable-netrc -Xswiftc -warnings-as-errors -Xcc -Werror
swift test --disable-sandbox --disable-keychain --disable-netrc
swift test -c release --disable-sandbox --disable-keychain --disable-netrc
swift run --disable-sandbox --disable-keychain --disable-netrc --package-path IntegrationTests/Consumer TagLibAudioMetadataConsumer
swift run --disable-sandbox --disable-keychain --disable-netrc --package-path IntegrationTests/Consumer TagLibAudioMetadataLowLevelConsumer
```

Final results: strict production compilation passed; Debug and Release each passed 154 XCTest tests with two unchanged opt-in skips and 108 Swift Testing tests; both facade and low-level public consumers passed. All eight independent acceptance probes and seven additional repair regressions passed in both test configurations. Documentation and both generated-catalog checks passed. These results are also recorded in [Status](../../operations/STATUS.md). The initial full repair pass exposed additional old tests expecting total-only rejection and a formatted-write test that silently resolved conflicts; these were revised to stronger target-contract assertions. Final verification was repeated after the last production-source change.

Temporary local logs use `/tmp/taglib-number-repairs-*.log` and are not committed. No sanitizer, minimum-platform/iOS runtime, external interoperability tool or companion application run was performed. Passing these repairs closes the eight reproduced numbering findings; it is not a claim that every native codec or all application workflows are validated.
