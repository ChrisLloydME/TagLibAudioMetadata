# Mapping test acceptance

Mapping conformance requires executable field-operation evidence. Registry membership, documentation agreement and a successful aggregate test count do not establish independent persistence.

## Required layers

1. `MappingContractCoverageTests` checks registry structure, aliases and capabilities. These tests remain useful but are not codec conformance evidence.
2. `SemanticLifecycleMatrixTests` freezes literal expected field/native identities outside the runtime registry. Its inventory accounts for all 101 public field keys: 86 independently specified MP4 fields plus 15 explicit specialized/API/read-only/unsupported decisions. New enum keys without a decision fail the inventory assertion. Existing schemas must not regenerate these expectations automatically to make failures pass.
3. Every field × operation is a separate parameterized case with its own temporary fixture. The 86 MP4 fields produce 258 set/replace/remove cases; native structured setup makes Replace/Remove independent of a broken semantic Set. Another 86 cases reject incorrect value kinds while checking that a valid companion field cannot partially commit. `IndependentMP4Probe` reads ISO BMFF bytes directly, including qualified freeform mean/name identities and numeric payloads; it does not use TagLib or the bridge to verify the destination. Every non-target ilst item payload and every mdat payload must remain byte-identical. Unknown multi-value metadata is also seeded and preserved.
4. The existing Content Group regression independently seeds native sibling arrays and covers all three owners with siblings absent/present. Dates, shared number pairs, comments, artwork, raw/structured operations and native collection semantics retain their specialized suites.
5. Unsupported/read-only/role-qualified MP4 typed writes must throw a validation error before any byte change. Other transaction, stale-version, privilege, raw-array, same-file concurrency and audio-content tests remain required.

Literal native expectations were initially transcribed from the mapping contract's documented targets. The document tables are generated from production, so this is not an external certification of their correctness. The behavioral and byte-level assertions add independence from the production encoder/decoder; future mapping changes require explicit review of the test contract. The MP4 atom reader is a deliberately limited test oracle, not a general media parser.

## Cross-format native matrices

`FLACSemanticLifecycleTests` covers 30 fields × three independent operations. `IndependentFLACProbe` reads native Vorbis Comment entries directly, retaining duplicate values and whitespace, and compares all non-target comments, non-padding metadata-block payloads and complete audio bytes. Vendor text and padding are not treated as immutable audio evidence.

`ID3SemanticLifecycleTests` covers 20 fields × three operations on MP3 with explicitly seeded ID3v2.4. `IndependentID3Probe` preserves qualified TXXX identities, exact non-target frames and the entire bytes after the tag. It intentionally rejects other tag versions, compression/unsynchronization and unsupported text encodings; those are coverage limits rather than guessed interpretations.

`NativeProbeContractTests` checks the new FLAC/ID3 readers against handcrafted known byte vectors, duplicate comments, truncated lengths and unsupported headers. `ReviewNativeContainerTests` now reuses the shared qualified MP4 parser instead of maintaining a second atom walker; its original native/audio preservation assertions remain active.

## Known limits

The systematic matrices cover MP4, FLAC and a 20-field ID3v2.4 MP3 subset, not the full field × format × tag-version cross-product. Existing tests cover other families and versions, but those do not yet have the same systematic per-operation independent-byte oracle. Multi-value writes, malformed existing values and native sibling collisions have specialized cases rather than universal coverage. Generic textual samples test storage, not every domain-specific text grammar. Minimum-platform builds and sanitizer jobs remain separate gates; this local acceptance does not imply that those jobs were run.

## Mixed-framework gate

Use `bash scripts/validate-tests.sh debug` and `bash scripts/validate-tests.sh release`. The scripts accept no filter/skip arguments. Restricted local environments may explicitly set `TAGLIB_DISABLE_MANIFEST_SANDBOX=1`; the default retains SwiftPM's sandbox behavior. Logs and machine-readable summaries are retained under ignored `.build/test-evidence`.

Both XCTest and Swift Testing must complete and pass. Swift Testing declaration counts must not be confused with parameterized case counts. A passing XCTest summary cannot hide a failed Swift Testing matrix. The only allowed optional skips are the existing external corpus and opt-in benchmark methods; new named skips, unnamed skip counts, missing framework summaries and nonzero runner status fail acceptance. The summary parser follows the current SwiftPM output format and fails closed if that format changes. Nineteen Python policy regressions verify gate failure modes, required named matrix/oracle evidence and case counts, exact class+method skip identities, and CLI validation. The earlier thirteen-test policy asserted only suite names and method-name suffixes and therefore accepted logs in which the matrix execution lines were removed or an allowlisted method name was skipped from another class. Required MP4, FLAC, ID3 and oracle-contract suites and named test functions must appear in the completed output. The gate requires at least 258 MP4 lifecycle cases, 90 FLAC cases, 60 ID3 cases, 86 wrong-kind cases, 5 unavailable-field cases, and the native-probe vectors; suite banners alone are not accepted. Swift Testing skips are rejected; only the two exact existing optional XCTest method names are allowed. Any failed framework summary remains a failure even if a later summary passes. Actual XCTest skip diagnostic lines have their own regression so they are not misclassified as Swift Testing skips.

CI uses the same Debug/Release entry points and uploads evidence even on failure. Existing strict, sanitizer, consumer and platform jobs are retained. A reproduced defect remains a normal failing case; do not whitelist it, mark it expected failure, or weaken a literal oracle to match the implementation.
